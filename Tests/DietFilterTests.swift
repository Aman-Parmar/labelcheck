import SwiftData
import XCTest

@testable import LabelCheck

/// Diet filters (vegan, gluten-free, no seed oils): the on-device
/// matching against the product data the card already fetched. Pure
/// logic, no network. Tag values pinned here are the live Open Food
/// Facts values for the sample products, fetched 2026-11-19.
final class DietFilterTests: XCTestCase {
    private func product(
        analysisTags: [String] = [],
        labelsTags: [String] = [],
        allergenTags: [String] = [],
        ingredientsText: String? = nil
    ) -> FoodProduct {
        FoodProduct(
            barcode: "0000000000000",
            allergenTags: allergenTags,
            ingredientsText: ingredientsText,
            ingredientsAnalysisTags: analysisTags,
            labelsTags: labelsTags
        )
    }

    // MARK: - Vegan

    func testVeganPassesOnEnVegan() {
        let result = DietFilterChecker.check(.vegan, product: product(analysisTags: ["en:vegan"]))
        XCTAssertEqual(result.status, .pass)
        XCTAssertEqual(result.detail, "Listed as vegan by Open Food Facts.")
    }

    func testVeganFailsOnEnNonVegan() {
        // Kinder Bueno, live value 2026-11-19.
        let result = DietFilterChecker.check(
            .vegan,
            product: product(analysisTags: ["en:palm-oil", "en:non-vegan", "en:vegetarian"])
        )
        XCTAssertEqual(result.status, .fail)
        XCTAssertEqual(result.detail, "Listed as non-vegan by Open Food Facts.")
    }

    func testVeganUnknownOnMaybeVegan() {
        // Nutella and Coca-Cola are both "en:maybe-vegan" live: a guess
        // must never read as a pass.
        let result = DietFilterChecker.check(
            .vegan,
            product: product(analysisTags: ["en:palm-oil", "en:maybe-vegan", "en:vegetarian"])
        )
        XCTAssertEqual(result.status, .unknown)
    }

    func testVeganUnknownWhenTagsMissing() {
        XCTAssertEqual(DietFilterChecker.check(.vegan, product: product()).status, .unknown)
    }

    func testVeganMatchingIgnoresCase() {
        let result = DietFilterChecker.check(.vegan, product: product(analysisTags: ["EN:Non-Vegan"]))
        XCTAssertEqual(result.status, .fail)
    }

    // MARK: - Gluten-free

    func testGlutenFreePassesOnEnGlutenFree() {
        let result = DietFilterChecker.check(.glutenFree, product: product(labelsTags: ["en:gluten-free"]))
        XCTAssertEqual(result.status, .pass)
        XCTAssertEqual(result.detail, "Labelled gluten-free.")
    }

    func testGlutenFreePassesOnEnNoGluten() {
        // Nutella carries "en:no-gluten", not "en:gluten-free", live.
        let result = DietFilterChecker.check(
            .glutenFree,
            product: product(labelsTags: ["en:vegetarian", "en:no-gluten", "fr:triman"])
        )
        XCTAssertEqual(result.status, .pass)
    }

    func testGlutenFreeFailsOnAllergenTag() {
        // Kinder Bueno lists en:gluten.
        let result = DietFilterChecker.check(
            .glutenFree,
            product: product(allergenTags: ["en:milk", "en:nuts", "en:gluten", "en:soybeans"])
        )
        XCTAssertEqual(result.status, .fail)
        XCTAssertEqual(result.detail, "Gluten is listed in the allergens or ingredients.")
    }

    func testGlutenFreeFailsOnWheatFlourInIngredients() {
        let result = DietFilterChecker.check(
            .glutenFree,
            product: product(ingredientsText: "Milk chocolate, wheat flour, sugar.")
        )
        XCTAssertEqual(result.status, .fail)
    }

    func testGlutenFreeUnknownWhenNothingListed() {
        XCTAssertEqual(DietFilterChecker.check(.glutenFree, product: product()).status, .unknown)
    }

    func testGlutenFreeDoesNotFailOnRiceFlour() {
        // Bare "flour" is not a gluten keyword: rice flour is gluten-free.
        let result = DietFilterChecker.check(
            .glutenFree,
            product: product(ingredientsText: "Rice flour, sugar, cocoa.")
        )
        XCTAssertEqual(result.status, .unknown)
    }

    // MARK: - No seed oils

    func testSeedOilsFailNamesTheOil() {
        let result = DietFilterChecker.check(
            .noSeedOils,
            product: product(ingredientsText: "Peanuts, sunflower oil, sugar.")
        )
        XCTAssertEqual(result.status, .fail)
        XCTAssertTrue(result.detail.contains("Sunflower Oil"))
    }

    func testSeedOilsPassOnPalmOil() {
        // Palm oil is a fruit oil, not a seed oil: Nutella and Kinder
        // Bueno both pass this filter.
        let result = DietFilterChecker.check(
            .noSeedOils,
            product: product(ingredientsText: "Sugar, palm oil, hazelnuts, cocoa.")
        )
        XCTAssertEqual(result.status, .pass)
        XCTAssertEqual(result.detail, "No seed oils listed in the ingredients.")
    }

    func testSeedOilsPassWhenNoneListed() {
        let result = DietFilterChecker.check(
            .noSeedOils,
            product: product(ingredientsText: "Carbonated water, sugar, phosphoric acid.")
        )
        XCTAssertEqual(result.status, .pass)
    }

    func testSeedOilsUnknownWithoutIngredients() {
        XCTAssertEqual(DietFilterChecker.check(.noSeedOils, product: product()).status, .unknown)
        XCTAssertEqual(
            DietFilterChecker.check(.noSeedOils, product: product(ingredientsText: "   ")).status,
            .unknown
        )
    }

    func testSeedOilsDoesNotFailOnVegetableOilOrCornFlour() {
        // "Vegetable oil" is a blend the data cannot resolve, and corn
        // flour is not corn oil: neither is a seed-oil match.
        XCTAssertEqual(
            DietFilterChecker.check(
                .noSeedOils,
                product: product(ingredientsText: "Vegetable oil, corn flour, salt.")
            ).status,
            .pass
        )
    }

    // MARK: - Profile storage

    func testProfileStoresDietFilterKeys() {
        let profile = AllergenProfile(
            name: "Maya",
            allergens: ["milk"],
            dietFilters: ["vegan", "no-seed-oils"]
        )
        XCTAssertEqual(profile.dietFilterList, ["vegan", "no-seed-oils"])
    }

    func testProfileWithoutDietFiltersHasEmptyList() {
        let profile = AllergenProfile(name: "Leo", allergens: ["gluten"])
        XCTAssertTrue(profile.dietFilterList.isEmpty)
    }

    // MARK: - No-verdict guardrail

    func testNoDetailContainsVerdictOrSafetyLanguage() {
        let banned = ["healthy", "unhealthy", "safe", "safety", "risk", "dangerous", "good for you", "bad for you"]
        let samples = [
            product(analysisTags: ["en:vegan"]),
            product(analysisTags: ["en:non-vegan"]),
            product(analysisTags: ["en:maybe-vegan"]),
            product(labelsTags: ["en:gluten-free"]),
            product(allergenTags: ["en:gluten"]),
            product(),
            product(ingredientsText: "Sunflower oil, sugar."),
            product(ingredientsText: "Palm oil, sugar."),
        ]
        for filter in DietFilter.allCases {
            for sample in samples {
                let detail = DietFilterChecker.check(filter, product: sample).detail.lowercased()
                for word in banned {
                    XCTAssertFalse(detail.contains(word), "\(filter.label): \(detail) contains \(word)")
                }
            }
        }
    }
}
