import Foundation

/// Open Food Facts API v3 client. No API key, no account.
/// Product lookup: GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json
/// Category search (LC-1 alternatives): GET https://world.openfoodfacts.org/cgi/search.pl
/// Name search (LC-3): same search endpoint, `search_terms` instead of a category tag.
/// User-Agent: LabelCheck/1.0 (support@singhsec.com)
/// Rate limits (per IP): 15 product reads/min, 10 searches/min.
/// Only the scanned barcode (lookup), the product's category tag
/// (alternatives search), or the words the user typed (name search) is
/// ever sent. No name, email, location, or device identifier is sent
/// with any call.
/// Results are cached in memory so a re-scan never re-hits the network,
/// and persisted in SwiftData (LC-2) so a re-scan or a History tap works
/// with no signal at all. The persistent store is set by the view layer
/// from the app's ModelContainer; the client works without it (memory
/// cache + network only).
///
/// Data is crowdsourced (ODbL). The app never auto-trusts it: every product
/// card shows a "verify on the physical label" state.
actor OpenFoodFactsClient {
    static let userAgent = "LabelCheck/1.0 (support@singhsec.com)"
    static let baseURL = URL(string: "https://world.openfoodfacts.org/api/v3/product")!
    static let searchURL = URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!
    /// Fields requested on every search, lookup and alternatives alike:
    /// everything the product card shows, plus the barcode itself.
    static let productFields = "code,product_name,brands,nutriscore_grade,nova_group,allergens_tags,ingredients_text,nutriments,image_url,categories_tags"
    /// Both network calls share one timeout and one search page size.
    static let requestTimeout: TimeInterval = 15
    static let searchPageSize = "20"

    /// Every network call goes through here: same User-Agent, same timeout.
    private static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.requestTimeout
        return request
    }

    /// Set to true only in screenshot mode (UITests), where lookups are
    /// served from bundled sample JSON so screenshots are deterministic
    /// and offline. Never true in a shipping build.
    var useSampleData = false

    func setUseSampleData(_ enabled: Bool) {
        useSampleData = enabled
    }

    /// Persistent payload store (LC-2), set by the view layer from the
    /// app's ModelContainer. Nil until set; the client works without it.
    private var payloadStore: ProductPayloadStore?

    func setPayloadStore(_ store: ProductPayloadStore?) {
        payloadStore = store
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

    /// Search by product name or brand (LC-3, Pro). Same `cgi/search.pl`
    /// endpoint as the alternatives search, with `search_terms` instead
    /// of a category tag. Only the words the user typed are sent. In
    /// screenshot mode the bundled sample products are filtered locally
    /// (offline, deterministic); no network call is made.
    func searchByName(_ query: String) async throws -> [FoodProduct] {
        let clean = query.trimmed
        guard !clean.isEmpty else { return [] }
        if useSampleData {
            return SampleProducts.search(query: clean)
        }
        return try await search(queryItems: [
            URLQueryItem(name: "search_terms", value: clean),
            URLQueryItem(name: "page_size", value: Self.searchPageSize),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "fields", value: Self.productFields),
        ])
    }

    /// One search against `cgi/search.pl`. Returns the raw products
    /// (unfiltered); the caller applies any grade cut.
    private func search(queryItems: [URLQueryItem]) async throws -> [FoodProduct] {
        guard var components = URLComponents(url: Self.searchURL, resolvingAgainstBaseURL: false) else {
            throw OpenFoodFactsError.badResponse
        }
        components.queryItems = [URLQueryItem(name: "action", value: "process")] + queryItems
        guard let url = components.url else { throw OpenFoodFactsError.badResponse }
        let request = Self.makeRequest(url: url)

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

    /// One category search against `cgi/search.pl`. Returns the raw
    /// products (unfiltered); the caller applies the grade cut.
    private func searchCategory(_ category: String) async throws -> [FoodProduct] {
        try await search(queryItems: [
            URLQueryItem(name: "tagtype_0", value: "categories"),
            URLQueryItem(name: "tag_contains_0", value: "contains"),
            URLQueryItem(name: "tag_0", value: category),
            URLQueryItem(name: "page_size", value: Self.searchPageSize),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "fields", value: Self.productFields),
        ])
    }

    /// Returns nil when the barcode is not in Open Food Facts. Throws on
    /// network failure or a bad response so the UI can show a retry state.
    func fetchProduct(barcode: String) async throws -> FoodProduct? {
        let clean = barcode.trimmed
        guard !clean.isEmpty else { return nil }
        if let cached = cache[clean] { return cached }

        if useSampleData {
            let product = SampleProducts.product(forBarcode: clean)
            if let product { cache[clean] = product }
            return product
        }

        // LC-2: persistent offline cache. Sample data wins over the cache
        // in screenshot mode (checked above) so the lane stays
        // deterministic; in the live app a cached payload means the
        // re-scan never touches the network.
        if let cached = await payloadStore?.load(barcode: clean) {
            cache[clean] = cached
            return cached
        }

        let url = Self.baseURL.appendingPathComponent("\(clean).json")
        let request = Self.makeRequest(url: url)

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
        // LC-2: persist the raw payload at scan time so the next re-scan
        // and History taps work with no signal.
        await payloadStore?.save(barcode: clean, payload: data)
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
