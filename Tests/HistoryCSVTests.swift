import XCTest

@testable import LabelCheck

/// History CSV export: header, one row per scan, RFC 4180 escaping.
/// The export itself is a system share sheet (`.fileExporter` in
/// HistoryView); what is testable here is the exact CSV text.
final class HistoryCSVTests: XCTestCase {
    private func product(
        barcode: String,
        name: String? = "Nutella",
        brand: String? = "Ferrero",
        nutriScore: String? = "e",
        nova: Int? = 4,
        allergens: [String] = ["en:milk", "en:nuts"]
    ) -> ScannedProduct {
        ScannedProduct(
            product: FoodProduct(
                barcode: barcode,
                name: name,
                brand: brand,
                nutriScoreGrade: nutriScore,
                novaGroup: nova,
                allergenTags: allergens
            ),
            scannedAt: Date(timeIntervalSince1970: 1_794_000_000)
        )
    }

    func testHeaderAndOneRow() {
        let csv = HistoryCSV.csv(for: [product(barcode: "3017620422003")])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines[0], "Date,Name,Brand,Barcode,Nutri-Score,NOVA group,Allergens")
        XCTAssertTrue(lines[1].hasPrefix("2026-11-06T21:20"))
        XCTAssertTrue(lines[1].contains("Nutella"))
        XCTAssertTrue(lines[1].contains("Ferrero"))
        XCTAssertTrue(lines[1].contains("3017620422003"))
        XCTAssertTrue(lines[1].contains(",E,4,"))
        XCTAssertTrue(lines[1].contains("milk; nuts"))
    }

    func testEmptyHistoryIsHeaderOnly() {
        XCTAssertEqual(
            HistoryCSV.csv(for: []),
            "Date,Name,Brand,Barcode,Nutri-Score,NOVA group,Allergens\n"
        )
    }

    func testMissingFieldsBecomeEmptyColumns() {
        let item = product(
            barcode: "0000000000000",
            name: nil,
            brand: nil,
            nutriScore: nil,
            nova: nil,
            allergens: []
        )
        let csv = HistoryCSV.csv(for: [item])
        XCTAssertTrue(csv.contains("Unknown product"))
        XCTAssertTrue(csv.contains("0000000000000"))
        XCTAssertTrue(csv.contains(",,,"))
    }

    func testEscapesCommasAndQuotes() {
        let item = product(
            barcode: "123",
            name: "Beans, \"Spicy\" Blend",
            brand: "Acme, Inc.",
            allergens: []
        )
        let csv = HistoryCSV.csv(for: [item])
        XCTAssertTrue(csv.contains("\"Beans, \"\"Spicy\"\" Blend\""))
        XCTAssertTrue(csv.contains("\"Acme, Inc.\""))
    }

    func testEscapeLeavesPlainFieldsAlone() {
        XCTAssertEqual(HistoryCSV.escape("Nutella"), "Nutella")
        XCTAssertEqual(HistoryCSV.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(HistoryCSV.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(HistoryCSV.escape("line1\nline2"), "\"line1\nline2\"")
    }
}
