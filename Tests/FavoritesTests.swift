import SwiftData
import XCTest

@testable import LabelCheck

/// Favorites: toggle round-trip, uniqueness by barcode, and the shared
/// full-product loader (cached payload wins, summary fields fall back).
/// No test here touches the real network.
final class FavoritesTests: XCTestCase {
    private let nutella = FoodProduct(
        barcode: "3017620422003",
        name: "Nutella",
        brand: "Ferrero",
        nutriScoreGrade: "e",
        novaGroup: 4,
        allergenTags: ["en:milk", "en:nuts"]
    )

    private let nutellaJSON = """
        {
          "product": {
            "product_name": "Nutella",
            "brands": "Ferrero",
            "nutriscore_grade": "e",
            "nova_group": 4,
            "allergens_tags": ["en:milk", "en:nuts", "en:soybeans"],
            "ingredients_text": "Sugar, palm oil, hazelnuts 13%, skimmed milk powder 8.7%.",
            "image_url": null,
            "nutriments": {
              "energy-kcal_100g": 539,
              "fat_100g": 30.9
            }
          }
        }
        """

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FavoriteProduct.self, CachedProduct.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func favoriteCount(in container: ModelContainer) throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<FavoriteProduct>())
    }

    func testToggleAddsThenRemoves() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        XCTAssertFalse(FavoriteProduct.isFavorite(barcode: nutella.barcode, in: context))
        XCTAssertTrue(FavoriteProduct.toggle(product: nutella, in: context))
        XCTAssertTrue(FavoriteProduct.isFavorite(barcode: nutella.barcode, in: context))
        XCTAssertEqual(try favoriteCount(in: container), 1)
        XCTAssertFalse(FavoriteProduct.toggle(product: nutella, in: context))
        XCTAssertFalse(FavoriteProduct.isFavorite(barcode: nutella.barcode, in: context))
        XCTAssertEqual(try favoriteCount(in: container), 0)
    }

    func testFavoriteKeepsSummaryFields() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        FavoriteProduct.toggle(product: nutella, in: context)
        let saved = try XCTUnwrap(
            FavoriteProduct.fetch(barcode: nutella.barcode, in: context))
        XCTAssertEqual(saved.displayName, "Nutella")
        XCTAssertEqual(saved.brand, "Ferrero")
        XCTAssertEqual(saved.nutriScoreGrade, "e")
    }

    func testFullProductServesCachedPayload() async throws {
        let container = try inMemoryContainer()
        let store = ProductPayloadStore(container: container)
        await store.save(barcode: nutella.barcode, payload: Data(nutellaJSON.utf8))
        let loaded = await fullProduct(
            barcode: nutella.barcode,
            name: "Nutella",
            brand: "Ferrero",
            nutriScoreGrade: "e",
            novaGroup: 4,
            allergenTags: ["en:milk"],
            in: container
        )
        // The cached payload wins: it carries the ingredients text the
        // summary row does not have.
        XCTAssertEqual(loaded.ingredientsText, "Sugar, palm oil, hazelnuts 13%, skimmed milk powder 8.7%.")
        XCTAssertEqual(loaded.allergenNames.sorted(), ["milk", "nuts", "soybeans"])
    }

    func testFullProductFallsBackToSummary() async throws {
        let container = try inMemoryContainer()
        let loaded = await fullProduct(
            barcode: nutella.barcode,
            name: "Nutella",
            brand: "Ferrero",
            nutriScoreGrade: "e",
            novaGroup: 4,
            allergenTags: ["en:milk"],
            in: container
        )
        XCTAssertEqual(loaded.displayName, "Nutella")
        XCTAssertEqual(loaded.nutriScoreGrade, "e")
        XCTAssertNil(loaded.ingredientsText)
    }
}
