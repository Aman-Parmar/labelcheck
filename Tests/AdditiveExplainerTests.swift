import XCTest

@testable import LabelCheck

/// Additive explainer: curated E-number notes, subtype fallback, and the
/// no-verdict guardrail. Pure logic, no network. Names and purposes are
/// from the public E-number list (Wikipedia, "E number", checked
/// 2026-11-19); the tests pin the entries the screenshot lane shows.
final class AdditiveExplainerTests: XCTestCase {
    private func product(barcode: String, additives: [String]) -> FoodProduct {
        FoodProduct(barcode: barcode, additivesTags: additives)
    }

    // MARK: - Lookup

    func testKnownAdditivesResolve() {
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e322")?.name, "Lecithins")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e150d")?.name, "Sulphite ammonia caramel")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e338")?.name, "Phosphoric acid")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e621")?.name, "Monosodium glutamate")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e951")?.name, "Aspartame")
    }

    func testLookupIgnoresPrefixAndCase() {
        XCTAssertEqual(AdditiveExplainer.note(forTag: "E322")?.code, "e322")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:E150D")?.code, "e150d")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "fr:e300")?.code, "e300")
    }

    func testSubtypeFallsBackToBaseCode() {
        // E322i is lecithins, E500ii is sodium carbonate, E960a is
        // steviol glycosides: the list carries the base code only.
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e322i")?.code, "e322")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e500ii")?.code, "e500")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e503ii")?.code, "e503")
        XCTAssertEqual(AdditiveExplainer.note(forTag: "en:e960a")?.code, "e960")
    }

    func testUnknownCodeReturnsNil() {
        XCTAssertNil(AdditiveExplainer.note(forTag: "en:e999"))
        XCTAssertNil(AdditiveExplainer.note(forTag: "en:e1234"))
        // E150d is listed, but the bare E150 group is not: subtypes
        // with different jobs must not collapse onto a wrong note.
        XCTAssertNil(AdditiveExplainer.note(forTag: "en:e150"))
    }

    // MARK: - Rows

    func testRowsShowCocaColaAdditivesInOrder() {
        let rows = AdditiveExplainer.rows(for: product(
            barcode: "5449000000996",
            additives: ["en:e150d", "en:e338"]
        ))
        XCTAssertEqual(rows.map(\.code), ["E150D", "E338"])
        XCTAssertEqual(rows[0].note?.name, "Sulphite ammonia caramel")
        XCTAssertEqual(rows[1].note?.name, "Phosphoric acid")
    }

    func testRowsDedupeSubtypesToOneRow() {
        // Kinder Bueno lists six tags; they collapse to three notes.
        let rows = AdditiveExplainer.rows(for: product(
            barcode: "3017620690969",
            additives: ["en:e322", "en:e322i", "en:e500", "en:e500ii", "en:e503", "en:e503ii"]
        ))
        XCTAssertEqual(rows.map(\.code), ["E322", "E500", "E503"])
        XCTAssertEqual(rows.map(\.note?.name), ["Lecithins", "Sodium carbonates", "Ammonium carbonates"])
    }

    func testRowsKeepUnknownCodesWithNoNote() {
        let rows = AdditiveExplainer.rows(for: product(
            barcode: "1",
            additives: ["en:e322", "en:e999"]
        ))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].code, "E999")
        XCTAssertNil(rows[1].note)
    }

    func testRowsEmptyWhenProductListsNone() {
        XCTAssertTrue(AdditiveExplainer.rows(for: product(barcode: "1", additives: [])).isEmpty)
    }

    func testDisplayCodeUppercases() {
        XCTAssertEqual(AdditiveExplainer.displayCode(forTag: "en:e322i"), "E322I")
        XCTAssertEqual(AdditiveExplainer.displayCode(forTag: "e150d"), "E150D")
    }

    // MARK: - Guardrails

    /// No note may carry a health verdict or a safety claim: the
    /// feature explains what an additive does, never whether it is
    /// good or bad for you. This test fails the build if a future
    /// entry smuggles one in.
    func testNoNoteContainsVerdictOrSafetyLanguage() {
        let banned = ["healthy", "unhealthy", "safe", "unsafe", "danger", "risk", "cancer", "toxic", "harmful", "avoid", "good for", "bad for"]
        for note in AdditiveExplainer.notes.values {
            let text = (note.name + " " + note.explanation).lowercased()
            for word in banned {
                XCTAssertFalse(text.contains(word), "\(note.code) contains banned word '\(word)': \(note.explanation)")
            }
        }
    }

    func testEveryNoteHasNameAndExplanation() {
        XCTAssertFalse(AdditiveExplainer.notes.isEmpty)
        for note in AdditiveExplainer.notes.values {
            XCTAssertFalse(note.name.isEmpty, note.code)
            XCTAssertFalse(note.explanation.isEmpty, note.code)
            // Codes are lowercase keys without a language prefix.
            XCTAssertEqual(note.code, note.code.lowercased(), note.code)
            XCTAssertFalse(note.code.contains(":"), note.code)
        }
    }

    // MARK: - Parsing

    func testAdditivesTagsDecodeFromProductPayload() throws {
        let json = """
            {"product": {"product_name": "Coca-Cola", "brands": "Coca-Cola",
             "additives_tags": ["en:e150d", "en:e338"]}}
            """
        let response = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: Data(json.utf8))
        let decoded = try XCTUnwrap(response.product.map {
            FoodProduct(dto: $0, barcode: "5449000000996")
        })
        XCTAssertEqual(decoded.additivesTags, ["en:e150d", "en:e338"])
        XCTAssertEqual(AdditiveExplainer.rows(for: decoded).count, 2)
    }

    func testMissingAdditivesTagsDecodeToEmpty() throws {
        let json = """
            {"product": {"product_name": "Nutella", "brands": "Ferrero"}}
            """
        let response = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: Data(json.utf8))
        let decoded = try XCTUnwrap(response.product.map {
            FoodProduct(dto: $0, barcode: "3017620422003")
        })
        XCTAssertTrue(decoded.additivesTags.isEmpty)
        XCTAssertTrue(AdditiveExplainer.rows(for: decoded).isEmpty)
    }
}
