import Foundation

/// Open Food Facts API v3 client. No API key, no account.
/// Endpoint: GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json
/// User-Agent: LabelCheck/1.0 (aman@threatrepel.com)
/// Rate limits (per IP): 15 product reads/min, 10 searches/min.
/// Only the scanned barcode is ever sent, and only to fetch that product.
/// Results are cached in memory so a re-scan never re-hits the network.
///
/// Data is crowdsourced (ODbL). The app never auto-trusts it: every product
/// card shows a "verify on the physical label" state.
actor OpenFoodFactsClient {
    static let userAgent = "LabelCheck/1.0 (aman@threatrepel.com)"
    static let baseURL = URL(string: "https://world.openfoodfacts.org/api/v3/product")!

    /// Set to true only in screenshot mode (UITests), where lookups are
    /// served from bundled sample JSON so screenshots are deterministic
    /// and offline. Never true in a shipping build.
    var useSampleData = false

    func setUseSampleData(_ enabled: Bool) {
        useSampleData = enabled
    }

    private var cache: [String: FoodProduct] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
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
