import XCTest

@testable import LabelCheck

/// Nutri-Score / NOVA display mapping. Copy rule, enforced by these tests:
/// the app never says "healthy" or "unhealthy" — grades are general
/// information from Open Food Facts, not health verdicts.
final class NutriScoreTests: XCTestCase {
    func testNormalisesGrades() {
        XCTAssertEqual(NutriScore.normalised("E"), "e")
        XCTAssertEqual(NutriScore.normalised(" a "), "a")
        XCTAssertNil(NutriScore.normalised("z"))
        XCTAssertNil(NutriScore.normalised(nil))
        XCTAssertNil(NutriScore.normalised(""))
    }

    func testRanks() {
        XCTAssertEqual(NutriScore.rank("a"), 0)
        XCTAssertEqual(NutriScore.rank("E"), 4)
        XCTAssertEqual(NutriScore.rank(" c "), 2)
        XCTAssertNil(NutriScore.rank("z"))
        XCTAssertNil(NutriScore.rank(nil))
    }

    func testBadgeLetters() {
        XCTAssertEqual(NutriScore(grade: "a").badgeLetter, "A")
        XCTAssertEqual(NutriScore(grade: "e").badgeLetter, "E")
        XCTAssertNil(NutriScore(grade: "").badgeLetter)
    }

    func testExplanationsNeverSayHealthyOrUnhealthy() {
        for grade in ["a", "b", "c", "d", "e", ""] {
            let text = NutriScore(grade: grade).explanation.lowercased()
            XCTAssertFalse(text.contains("healthy"), "grade \(grade)")
            XCTAssertFalse(text.contains("unhealthy"), "grade \(grade)")
        }
    }

    func testNovaExplanations() {
        XCTAssertTrue(NutriScore.novaExplanation(1).contains("group 1"))
        XCTAssertTrue(NutriScore.novaExplanation(4).contains("ultra-processed"))
        XCTAssertTrue(NutriScore.novaExplanation(nil).contains("No NOVA group"))
        XCTAssertTrue(NutriScore.novaExplanation(9).contains("No NOVA group"))
    }

    func testPlainEnglishSummaryNeverGivesVerdicts() {
        let product = FoodProduct(
            barcode: "3017620422003",
            name: "Nutella",
            brand: "Ferrero",
            nutriScoreGrade: "e",
            novaGroup: 4,
            allergenTags: ["en:milk"],
            ingredientsText: "Sugar, palm oil, hazelnuts."
        )
        let summary = LabelExplainer.plainEnglishSummary(for: product).lowercased()
        XCTAssertFalse(summary.contains("healthy"))
        XCTAssertFalse(summary.contains("unhealthy"))
        XCTAssertTrue(summary.contains("not medical or dietary advice"))
        XCTAssertTrue(summary.contains("check the physical label"))
    }
}
