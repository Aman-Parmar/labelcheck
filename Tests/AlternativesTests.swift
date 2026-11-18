import XCTest

@testable import LabelCheck

/// Healthier alternatives (LC-1): grade ranking, selection from a category
/// search, and category-candidate ordering. Pure logic, no network.
final class AlternativesTests: XCTestCase {
    private func product(
        barcode: String,
        name: String? = "Test product",
        grade: String? = nil,
        categories: [String] = []
    ) -> FoodProduct {
        FoodProduct(
            barcode: barcode,
            name: name,
            nutriScoreGrade: grade,
            categoriesTags: categories
        )
    }

    // MARK: - When the section shows

    func testShowsAlternativesOnlyOnDOrE() {
        XCTAssertTrue(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: "d")))
        XCTAssertTrue(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: "E")))
        XCTAssertFalse(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: "a")))
        XCTAssertFalse(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: "b")))
        XCTAssertFalse(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: "c")))
        XCTAssertFalse(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: nil)))
        XCTAssertFalse(AlternativeProducts.showsAlternatives(for: product(barcode: "1", grade: "z")))
    }

    // MARK: - Selection

    func testSelectKeepsOnlyHigherGradesBestFirst() {
        let current = product(barcode: "000", grade: "e")
        let candidates = [
            product(barcode: "1", name: "Worse", grade: "e"),
            product(barcode: "2", name: "Same", grade: "e"),
            product(barcode: "3", name: "Better D", grade: "d"),
            product(barcode: "4", name: "Best C", grade: "c"),
            product(barcode: "5", name: "Ungraded", grade: nil),
            product(barcode: "6", name: nil, grade: "a"),
        ]
        let selected = AlternativeProducts.select(from: candidates, current: current)
        // Ungraded and unnamed products are dropped, even with a good grade.
        XCTAssertEqual(selected.map(\.barcode), ["4", "3"])
    }

    func testSelectExcludesTheCurrentProduct() {
        let current = product(barcode: "000", grade: "e")
        let candidates = [
            product(barcode: "000", name: "Same product", grade: "a"),
            product(barcode: "1", name: "Other", grade: "b"),
        ]
        let selected = AlternativeProducts.select(from: candidates, current: current)
        XCTAssertEqual(selected.map(\.barcode), ["1"])
    }

    func testSelectCapsAtThreeAndDedupes() {
        let current = product(barcode: "000", grade: "e")
        let candidates = (1...5).map {
            product(barcode: "\($0)", name: "Product \($0)", grade: "b")
        } + [product(barcode: "1", name: "Duplicate", grade: "a")]
        let selected = AlternativeProducts.select(from: candidates, current: current)
        XCTAssertEqual(selected.count, 3)
        XCTAssertEqual(Set(selected.map(\.barcode)).count, 3)
    }

    func testSelectReturnsEmptyWithoutAGrade() {
        let current = product(barcode: "000", grade: nil)
        let candidates = [product(barcode: "1", name: "Graded", grade: "a")]
        XCTAssertTrue(AlternativeProducts.select(from: candidates, current: current).isEmpty)
    }

    // MARK: - Category candidates

    func testCategoryCandidatesDropBroadTagsAndReverse() {
        let nutella = product(
            barcode: "3017620422003",
            grade: "e",
            categories: [
                "en:breakfasts", "en:spreads", "en:sweet-spreads",
                "en:chocolate-spreads", "en:hazelnut-spreads",
            ]
        )
        XCTAssertEqual(
            AlternativeProducts.categoryCandidates(from: nutella),
            ["en:hazelnut-spreads", "en:chocolate-spreads", "en:sweet-spreads", "en:spreads"]
        )
    }

    func testCategoryCandidatesFallBackWhenAllBroad() {
        let onlyBroad = product(barcode: "1", grade: "e", categories: ["en:breakfasts"])
        XCTAssertEqual(
            AlternativeProducts.categoryCandidates(from: onlyBroad),
            ["en:breakfasts"]
        )
        XCTAssertEqual(
            AlternativeProducts.categoryCandidates(from: product(barcode: "1", grade: "e")),
            []
        )
    }

    // MARK: - Search response parsing

    func testSearchResponseDecodesCodeAsBarcode() throws {
        let json = """
            {"products": [
              {"code": "3760336830357", "product_name": "Pâte à tartiner praliné",
               "brands": "Funkie", "nutriscore_grade": "c", "nova_group": 3,
               "allergens_tags": ["en:nuts"], "ingredients_text": null,
               "nutriments": null, "image_url": null,
               "categories_tags": ["en:spreads"]},
              {"code": "", "product_name": "No code", "brands": null,
               "nutriscore_grade": "a", "nova_group": null,
               "allergens_tags": null, "ingredients_text": null,
               "nutriments": null, "image_url": null,
               "categories_tags": null}
            ]}
            """
        let decoded = try JSONDecoder().decode(
            OpenFoodFactsSearchResponse.self,
            from: Data(json.utf8)
        )
        let products = (decoded.products ?? []).compactMap { dto -> FoodProduct? in
            guard let code = dto.code, !code.isEmpty else { return nil }
            return FoodProduct(dto: dto, barcode: code)
        }
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products[0].barcode, "3760336830357")
        XCTAssertEqual(products[0].displayName, "Pâte à tartiner praliné")
        XCTAssertEqual(products[0].nutriScoreGrade, "c")
        XCTAssertEqual(products[0].categoriesTags, ["en:spreads"])
    }
}
