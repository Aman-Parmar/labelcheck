import XCTest

@testable import LabelCheck

/// Open Food Facts v3 response parsing. Uses a fixed snapshot of the real
/// Nutella entry (barcode 3017620422003) so parsing never depends on the network.
final class OpenFoodFactsParsingTests: XCTestCase {
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

    func testDecodesNutellaEntry() throws {
        let response = try JSONDecoder().decode(
            OpenFoodFactsResponse.self,
            from: Data(nutellaJSON.utf8)
        )
        let product = try XCTUnwrap(response.product.map {
            FoodProduct(dto: $0, barcode: "3017620422003")
        })
        XCTAssertEqual(product.displayName, "Nutella")
        XCTAssertEqual(product.displayBrand, "Ferrero")
        XCTAssertEqual(product.nutriScoreGrade, "e")
        XCTAssertEqual(product.novaGroup, 4)
        XCTAssertEqual(product.allergenNames, ["milk", "nuts", "soybeans"])
        XCTAssertEqual(product.nutriments.energyKcal, 539)
        XCTAssertEqual(product.nutriments.sugars, 56.3)
        XCTAssertFalse(product.nutriments.isEmpty)
    }

    func testMissingProductDecodesToNil() throws {
        let response = try JSONDecoder().decode(
            OpenFoodFactsResponse.self,
            from: Data("{\"product\": null}".utf8)
        )
        XCTAssertNil(response.product)
    }

    func testPartialDataSurvivesDecoding() throws {
        let json = """
            {"product": {"product_name": "Mystery Snack", "brands": null,
             "nutriscore_grade": null, "nova_group": null,
             "allergens_tags": null, "ingredients_text": null,
             "image_url": null, "nutriments": null}}
            """
        let response = try JSONDecoder().decode(
            OpenFoodFactsResponse.self,
            from: Data(json.utf8)
        )
        let product = try XCTUnwrap(response.product.map {
            FoodProduct(dto: $0, barcode: "0000000000000")
        })
        XCTAssertEqual(product.displayName, "Mystery Snack")
        XCTAssertNil(product.nutriScoreGrade)
        XCTAssertNil(product.novaGroup)
        XCTAssertTrue(product.allergenNames.isEmpty)
        XCTAssertTrue(product.nutriments.isEmpty)
    }

    func testNutrimentRowsSkipMissingValues() {
        let nutriments = Nutriments(energyKcal: 42, sugars: 10.6)
        let labels = nutriments.rows.map(\.label)
        XCTAssertEqual(labels, ["Energy", "Sugars"])
    }
}
