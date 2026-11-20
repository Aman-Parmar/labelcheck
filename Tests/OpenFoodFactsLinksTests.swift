import XCTest
@testable import LabelCheck

/// The contribution deep links carry the barcode in the URL and
/// nothing else, and point at the real Open Food Facts pages.
final class OpenFoodFactsLinksTests: XCTestCase {
    func testAddProductURLCarriesBarcode() {
        XCTAssertEqual(
            OpenFoodFactsLinks.addProductURL(barcode: "3017620422003")?.absoluteString,
            "https://world.openfoodfacts.org/cgi/product.pl?type=add&code=3017620422003"
        )
    }

    func testProductPageURLCarriesBarcode() {
        XCTAssertEqual(
            OpenFoodFactsLinks.productPageURL(barcode: "3017620422003")?.absoluteString,
            "https://world.openfoodfacts.org/product/3017620422003"
        )
    }

    func testLinksUseHTTPSAndTheWorldHost() {
        for url in [
            OpenFoodFactsLinks.addProductURL(barcode: "5449000000996"),
            OpenFoodFactsLinks.productPageURL(barcode: "5449000000996"),
        ] {
            XCTAssertEqual(url?.scheme, "https")
            XCTAssertEqual(url?.host, "world.openfoodfacts.org")
        }
    }
}
