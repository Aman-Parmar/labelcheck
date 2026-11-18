import XCTest

@testable import LabelCheck

/// On-device allergen matching: profile keys against product tags and
/// ingredient text, plus OCR-text extraction with its substring fallback.
final class AllergenMatcherTests: XCTestCase {
    func testMatchesAllergenTag() {
        let matches = AllergenMatcher.matches(
            profileAllergenKeys: ["milk", "peanut"],
            productAllergenNames: ["milk", "soybeans"],
            ingredientsText: nil
        )
        XCTAssertEqual(matches, ["Milk"])
    }

    func testMatchesKeywordInIngredients() {
        let matches = AllergenMatcher.matches(
            profileAllergenKeys: ["tree-nut"],
            productAllergenNames: [],
            ingredientsText: "Sugar, palm oil, hazelnuts 13%, cocoa."
        )
        XCTAssertEqual(matches, ["Tree nuts"])
    }

    func testNoProfileMeansNoMatches() {
        let matches = AllergenMatcher.matches(
            profileAllergenKeys: [],
            productAllergenNames: ["milk"],
            ingredientsText: "milk powder"
        )
        XCTAssertTrue(matches.isEmpty)
    }

    func testNoFalsePositiveOnUnrelatedProduct() {
        let matches = AllergenMatcher.matches(
            profileAllergenKeys: ["peanut", "fish"],
            productAllergenNames: [],
            ingredientsText: "Carbonated water, sugar, colour, phosphoric acid."
        )
        XCTAssertTrue(matches.isEmpty)
    }

    func testExtractAllergensFromOCRText() {
        let found = AllergenMatcher.extractAllergens(
            from: "Ingredients: skimmed milk powder, hazelnuts, lecithins (soya)."
        )
        XCTAssertTrue(found.contains("Milk"))
        XCTAssertTrue(found.contains("Tree nuts"))
        XCTAssertTrue(found.contains("Soy"))
    }

    func testExtractMultiWordAllergenViaSubstringFallback() {
        // "brazil nut" and "sulfur dioxide" never survive word tokenisation;
        // the substring fallback must still catch them.
        let found = AllergenMatcher.extractAllergens(
            from: "Contains brazil nut. Preservative: sulfur dioxide."
        )
        XCTAssertTrue(found.contains("Tree nuts"))
        XCTAssertTrue(found.contains("Sulphites"))
    }

    func testKnownAllergenLabelsRoundTrip() {
        for (key, label, _) in AllergenMatcher.knownAllergens {
            XCTAssertEqual(AllergenMatcher.key(forLabel: label), key)
            XCTAssertEqual(AllergenMatcher.label(forKey: key), label)
        }
    }
}
