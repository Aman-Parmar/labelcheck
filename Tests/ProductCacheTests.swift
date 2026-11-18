import SwiftData
import XCTest

@testable import LabelCheck

/// LC-2 offline cache: payload round-trip through SwiftData, and the
/// client serving a cached product with the network stubbed out, plus
/// persisting a network response into the store. No test here touches
/// the real network.
final class ProductCacheTests: XCTestCase {
    private let nutellaJSON = """
        {
          "product": {
            "product_name": "Nutella",
            "brands": "Ferrero",
            "nutriscore_grade": "e",
            "nova_group": 4,
            "allergens_tags": ["en:milk", "en:nuts", "en:soybeans"],
            "ingredients_text": "Sugar, palm oil, hazelnuts 13%, skimmed milk powder 8.7%, fat-reduced cocoa 7.4%, emulsifier: lecithins (soya), vanillin.",
            "image_url": null,
            "nutriments": {
              "energy-kcal_100g": 539,
              "fat_100g": 30.9,
              "saturated-fat_100g": 10.6,
              "carbohydrates_100g": 57.5,
              "sugars_100g": 56.3,
              "fiber_100g": 0,
              "proteins_100g": 6.3,
              "salt_100g": 0.107
            }
          }
        }
        """

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CachedProduct.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func cachedCount(in container: ModelContainer) throws -> Int {
        let context = ModelContext(container)
        return try context.fetchCount(FetchDescriptor<CachedProduct>())
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        await store.save(barcode: "3017620422003", payload: Data(nutellaJSON.utf8))
        let product = try XCTUnwrap(await store.load(barcode: "3017620422003"))
        XCTAssertEqual(product.displayName, "Nutella")
        XCTAssertEqual(product.displayBrand, "Ferrero")
        XCTAssertEqual(product.nutriScoreGrade, "e")
        XCTAssertEqual(product.novaGroup, 4)
        XCTAssertEqual(product.allergenNames, ["milk", "nuts", "soybeans"])
        XCTAssertEqual(product.nutriments.energyKcal, 539)
        XCTAssertEqual(product.nutriments.sugars, 56.3)
        XCTAssertTrue(product.ingredientsText?.contains("hazelnuts") == true)
    }

    func testLoadUnknownBarcodeReturnsNil() async throws {
        let store = ProductPayloadStore(container: try inMemoryContainer())
        XCTAssertNil(await store.load(barcode: "0000000000000"))
    }

    func testLoadCorruptPayloadReturnsNil() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        await store.save(barcode: "3017620422003", payload: Data("not json".utf8))
        XCTAssertNil(await store.load(barcode: "3017620422003"))
    }

    func testSaveOverwritesSameBarcode() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        await store.save(barcode: "3017620422003", payload: Data(nutellaJSON.utf8))
        let renamed = nutellaJSON.replacingOccurrences(of: "Nutella", with: "Nutella Light")
        await store.save(barcode: "3017620422003", payload: Data(renamed.utf8))
        XCTAssertEqual(try cachedCount(in: container), 1)
        let product = try XCTUnwrap(await store.load(barcode: "3017620422003"))
        XCTAssertEqual(product.displayName, "Nutella Light")
    }

    func testPrunesBeyondCap() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        for index in 0...ProductPayloadStore.maxEntries {
            await store.save(
                barcode: String(format: "400000000%04d", index),
                payload: Data("{}".utf8))
        }
        XCTAssertEqual(try cachedCount(in: container), ProductPayloadStore.maxEntries)
    }

    func testClientServesCachedProductWithoutNetwork() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        await store.save(barcode: "3017620422003", payload: Data(nutellaJSON.utf8))
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let client = OpenFoodFactsClient(session: .stubbed)
        await client.setPayloadStore(store)
        let product = try await client.fetchProduct(barcode: "3017620422003")
        XCTAssertEqual(product?.displayName, "Nutella")
        XCTAssertEqual(product?.nutriScoreGrade, "e")
    }

    func testClientPersistsNetworkResponseToStore() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(self.nutellaJSON.utf8))
        }
        let client = OpenFoodFactsClient(session: .stubbed)
        await client.setPayloadStore(store)
        let product = try await client.fetchProduct(barcode: "3017620422003")
        XCTAssertEqual(product?.displayName, "Nutella")
        // The payload is in the store now, even though this client never
        // saw it cached: a second client with a dead network reads it back.
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let offlineClient = OpenFoodFactsClient(session: .stubbed)
        await offlineClient.setPayloadStore(store)
        let cached = try await offlineClient.fetchProduct(barcode: "3017620422003")
        XCTAssertEqual(cached?.displayName, "Nutella")
    }
}

// MARK: - URLProtocol stub

/// Answers every request from a handler the test sets, so client tests
/// never touch the real network. Reset in tearDown.
private final class StubURLProtocol: URLProtocol {
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
    /// A session whose requests are answered by StubURLProtocol.
    static var stubbed: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
