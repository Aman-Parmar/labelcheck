import XCTest

@testable import LabelCheck

/// History search: name / brand / barcode matching, case- and
/// diacritic-insensitive, blank query shows everything. No test here
/// touches the real network. ScannedProduct is not Equatable, so
/// results are compared by barcode (the AlternativesTests pattern).
final class HistorySearchTests: XCTestCase {
    private func item(name: String?, brand: String?, barcode: String) -> ScannedProduct {
        ScannedProduct(product: FoodProduct(
            barcode: barcode,
            name: name,
            brand: brand,
            nutriScoreGrade: nil,
            novaGroup: nil,
            allergenTags: []
        ))
    }

    private let nutella = ScannedProduct(product: FoodProduct(
        barcode: "3017620422003", name: "Nutella", brand: "Ferrero",
        nutriScoreGrade: "e", novaGroup: 4, allergenTags: []
    ))
    private let cocaCola = ScannedProduct(product: FoodProduct(
        barcode: "5449000000996", name: "Coca-Cola", brand: "Coca-Cola",
        nutriScoreGrade: "e", novaGroup: 4, allergenTags: []
    ))

    private func barcodes(_ items: [ScannedProduct]) -> [String] {
        items.map(\.barcode)
    }

    func testBlankQueryReturnsAll() {
        let items = [nutella, cocaCola]
        XCTAssertEqual(barcodes(HistorySearch.filter(items, query: "")), ["3017620422003", "5449000000996"])
        XCTAssertEqual(barcodes(HistorySearch.filter(items, query: "   ")), ["3017620422003", "5449000000996"])
    }

    func testNameMatchIsCaseInsensitive() {
        let items = [nutella, cocaCola]
        XCTAssertEqual(barcodes(HistorySearch.filter(items, query: "nutella")), ["3017620422003"])
        XCTAssertEqual(barcodes(HistorySearch.filter(items, query: "NUTELLA")), ["3017620422003"])
    }

    func testBrandMatch() {
        XCTAssertEqual(
            barcodes(HistorySearch.filter([nutella, cocaCola], query: "ferrero")),
            ["3017620422003"]
        )
    }

    func testBarcodeMatch() {
        let items = [nutella, cocaCola]
        XCTAssertEqual(barcodes(HistorySearch.filter(items, query: "3017620422")), ["3017620422003"])
        XCTAssertEqual(barcodes(HistorySearch.filter(items, query: "5449000000996")), ["5449000000996"])
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(HistorySearch.filter([nutella, cocaCola], query: "kinder").isEmpty)
    }

    func testQueryIsTrimmed() {
        XCTAssertEqual(
            barcodes(HistorySearch.filter([nutella, cocaCola], query: "  nutella  ")),
            ["3017620422003"]
        )
    }

    func testDiacriticInsensitiveMatch() {
        let cafe = item(name: "Café au lait", brand: nil, barcode: "4000000000000")
        XCTAssertEqual(barcodes(HistorySearch.filter([cafe], query: "cafe")), ["4000000000000"])
        XCTAssertEqual(barcodes(HistorySearch.filter([cafe], query: "café")), ["4000000000000"])
    }

    func testUnnamedProductStillMatchesBarcode() {
        let unnamed = item(name: nil, brand: nil, barcode: "4000000000001")
        XCTAssertEqual(barcodes(HistorySearch.filter([unnamed], query: "4000000000001")), ["4000000000001"])
        XCTAssertTrue(HistorySearch.filter([unnamed], query: "nutella").isEmpty)
    }
}
