import XCTest

@testable import LabelCheck

/// LC-3 search by product name: search-response decoding, the client's
/// `search_terms` request, and the screenshot-mode sample filter. No test
/// here touches the real network: live-path tests answer through a stub
/// URLProtocol, sample-path tests read the bundled sample products.
final class ProductSearchTests: XCTestCase {
    private let searchJSON = """
        {
          "products": [
            {
              "code": "3017620422003",
              "product_name": "Nutella",
              "brands": "Ferrero",
              "nutriscore_grade": "e",
              "nova_group": 4,
              "allergens_tags": ["en:milk"],
              "ingredients_text": "Sugar, palm oil, hazelnuts.",
              "image_url": null,
              "nutriments": {"energy-kcal_100g": 539}
            },
            {
              "code": "3017620690969",
              "product_name": "Kinder Bueno",
              "brands": "Ferrero",
              "nutriscore_grade": "e",
              "nova_group": 4,
              "allergens_tags": ["en:milk"],
              "ingredients_text": "Milk chocolate.",
              "image_url": null,
              "nutriments": null
            },
            {
              "product_name": "Nameless Spread",
              "brands": "No Barcode",
              "nutriscore_grade": "d",
              "nova_group": 4
            }
          ]
        }
        """

    override func tearDown() {
        SearchStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSearchResponseDecodes() throws {
        let response = try JSONDecoder().decode(
            OpenFoodFactsSearchResponse.self,
            from: Data(searchJSON.utf8)
        )
        let products = try XCTUnwrap(response.products)
        XCTAssertEqual(products.count, 3)
        XCTAssertEqual(products[0].code, "3017620422003")
        XCTAssertEqual(products[0].productName, "Nutella")
        XCTAssertNil(products[2].code)
    }

    func testSearchByNameReturnsProductsWithBarcodes() async throws {
        SearchStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(self.searchJSON.utf8))
        }
        let client = OpenFoodFactsClient(session: .searchStubbed)
        let results = try await client.searchByName("nutella")
        // The entry with no `code` is dropped: a result without a barcode
        // cannot be opened or saved to History.
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].displayName, "Nutella")
        XCTAssertEqual(results[0].barcode, "3017620422003")
        XCTAssertEqual(results[1].displayName, "Kinder Bueno")
    }

    func testSearchByNameSendsSearchTerms() async throws {
        var capturedURL: URL?
        SearchStubURLProtocol.handler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"products\": []}".utf8))
        }
        let client = OpenFoodFactsClient(session: .searchStubbed)
        let results = try await client.searchByName("oat milk")
        XCTAssertTrue(results.isEmpty)
        let url = try XCTUnwrap(capturedURL)
        XCTAssertTrue(url.absoluteString.contains("search_terms=oat%20milk"))
        XCTAssertTrue(url.absoluteString.contains("json=1"))
        XCTAssertTrue(url.absoluteString.contains("action=process"))
    }

    func testSearchByNameEmptyQuerySkipsNetwork() async throws {
        SearchStubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let client = OpenFoodFactsClient(session: .searchStubbed)
        let results = try await client.searchByName("   ")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchByNameHttpErrorThrows() async {
        SearchStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = OpenFoodFactsClient(session: .searchStubbed)
        do {
            _ = try await client.searchByName("nutella")
            XCTFail("Expected an HTTP error to throw")
        } catch let error as OpenFoodFactsError {
            guard case .httpStatus(500) = error else {
                return XCTFail("Expected httpStatus(500), got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Screenshot-mode sample filter: name and brand match, case
    /// insensitive. The sample JSON lives in the app bundle; a unit-test
    /// host that cannot see it skips instead of failing on the bundle,
    /// and the UI screenshot test (test11) covers the same path
    /// end-to-end in the real app.
    func testSampleSearchFiltersByNameAndBrand() throws {
        guard !SampleProducts.all.isEmpty else {
            throw XCTSkip("SampleProducts.json not visible to the test host")
        }
        let byName = SampleProducts.search(query: "nutella")
        XCTAssertEqual(byName.map(\.barcode), ["3017620422003"])
        let byBrand = SampleProducts.search(query: "FERRERO")
        XCTAssertEqual(byBrand.map(\.barcode).sorted(),
                       ["3017620422003", "3017620690969"])
        XCTAssertTrue(SampleProducts.search(query: "zzz-no-such-food").isEmpty)
        XCTAssertTrue(SampleProducts.search(query: "   ").isEmpty)
    }

    func testSampleSearchThroughClient() async throws {
        guard !SampleProducts.all.isEmpty else {
            throw XCTSkip("SampleProducts.json not visible to the test host")
        }
        let client = OpenFoodFactsClient()
        await client.setUseSampleData(true)
        let results = try await client.searchByName("coca")
        XCTAssertEqual(results.map(\.barcode), ["5449000000996"])
    }
}

// MARK: - URLProtocol stub

/// Answers every request from a handler the test sets, so client tests
/// never touch the real network. Reset in tearDown. Named differently
/// from ProductCacheTests' private stub so the two files can coexist.
private final class SearchStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.notConnectedToInternet)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    /// A session whose requests are answered by SearchStubURLProtocol.
    static var searchStubbed: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SearchStubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
