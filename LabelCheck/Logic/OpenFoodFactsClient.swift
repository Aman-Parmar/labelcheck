import Foundation

/// Open Food Facts API v3 client. No API key, no account.
/// Product lookup: GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json
/// Category search (LC-1 alternatives): GET https://world.openfoodfacts.org/cgi/search.pl
/// User-Agent: LabelCheck/1.0 (aman@threatrepel.com)
/// Rate limits (per IP): 15 product reads/min, 10 searches/min.
/// Only the scanned barcode (lookup) or the product's category tag
/// (alternatives search) is ever sent. No name, email, location, or
/// device identifier is sent with either call.
/// Results are cached in memory so a re-scan never re-hits the network.
///
/// Data is crowdsourced (ODbL). The app never auto-trusts it: every product
/// card shows a "verify on the physical label" state.
actor OpenFoodFactsClient {
    static let userAgent = "LabelCheck/1.0 (aman@threatrepel.com)"
    static let baseURL = URL(string: "https://world.openfoodfacts.org/api/v3/product")!
    static let searchURL = URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!

    /// Set to true only in screenshot mode (UITests), where lookups are
    /// served from bundled sample JSON so screenshots are deterministic
    /// and offline. Never true in a shipping build.
    var useSampleData = false

    func setUseSampleData(_ enabled: Bool) {
        useSampleData = enabled
    }

    private var cache: [String: FoodProduct] = [:]
    private var alternativesCache: [String: [FoodProduct]] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Same-category products with a higher Nutri-Score than `product`
    /// (LC-1), up to 3, best score first. Only meaningful on a D/E card;
    /// returns an empty array otherwise, and on a live fetch that finds
    /// nothing better. Throws on network failure or a bad response, so
    /// the UI can hide the section instead of showing a broken one.
    /// In screenshot mode the bundled sample alternatives are returned
    /// (offline, deterministic); no network call is made.
    func fetchAlternatives(for product: FoodProduct) async throws -> [FoodProduct] {
        guard AlternativeProducts.showsAlternatives(for: product) else { return [] }
        if let cached = alternativesCache[product.barcode] { return cached }

        if useSampleData {
            let alternatives = SampleProducts.alternatives(forBarcode: product.barcode)
            alternativesCache[product.barcode] = alternatives
            return alternatives
        }

        var found: [FoodProduct] = []
        // Most specific category first; try the next one when the last
        // returned too few, up to 3 searches. The search endpoint ignores
        // a Nutri-Score filter, so the grade cut is done client-side.
        for category in AlternativeProducts.categoryCandidates(from: product).prefix(3) {
            let batch = try await searchCategory(category)
            found = AlternativeProducts.select(from: found + batch, current: product)
            if found.count >= AlternativeProducts.maxAlternatives { break }
        }
        alternativesCache[product.barcode] = found
        return found
    }

    /// One category search against `cgi/search.pl`. Returns the raw
    /// products (unfiltered); the caller applies the grade cut.
    private func searchCategory(_ category: String) async throws -> [FoodProduct] {
        var components = URLComponents(url: Self.searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "tagtype_0", value: "categories"),
            URLQueryItem(name: "tag_contains_0", value: "contains"),
            URLQueryItem(name: "tag_0", value: category),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriscore_grade,nova_group,allergens_tags,ingredients_text,nutriments,image_url,categories_tags"),
        ]
        guard let url = components.url else { throw OpenFoodFactsError.badResponse }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.badResponse
        }
        guard http.statusCode == 200 else {
            throw OpenFoodFactsError.httpStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
        return (decoded.products ?? []).compactMap { dto in
            guard let code = dto.code, !code.isEmpty else { return nil }
            return FoodProduct(dto: dto, barcode: code)
        }
    }

    /// Returns nil when the barcode is not in Open Food Facts. Throws on
    /// network failure or a bad response so the UI can show a retry state.
    func fetchProduct(barcode: String) async throws -> FoodProduct? {
        let clean = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let cached = cache[clean] { return cached }

        if useSampleData {
            let product = SampleProducts.product(forBarcode: clean)
            if let product { cache[clean] = product }
            return product
        }

        let url = Self.baseURL.appendingPathComponent("\(clean).json")
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.badResponse
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 404 { return nil }
            throw OpenFoodFactsError.httpStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        guard let dto = decoded.product else { return nil }
        let product = FoodProduct(dto: dto, barcode: clean)
        cache[clean] = product
        return product
    }
}

enum OpenFoodFactsError: Error, LocalizedError {
    case badResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Open Food Facts returned an unexpected response."
        case .httpStatus(let code): return "Open Food Facts returned status \(code)."
        }
    }
}
