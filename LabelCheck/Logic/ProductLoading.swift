import Foundation
import SwiftData

/// Loads the full product for a stored row: the cached Open Food Facts
/// payload when one exists (LC-2), otherwise the summary fields stored on
/// the row (no ingredients or nutrition data). Shared by History and
/// Favorites so both tabs open the same full card from the same code.
func fullProduct(
    barcode: String,
    name: String?,
    brand: String?,
    nutriScoreGrade: String?,
    novaGroup: Int?,
    allergenTags: [String],
    in container: ModelContainer
) async -> FoodProduct {
    let store = ProductPayloadStore(container: container)
    if let cached = await store.load(barcode: barcode) {
        return cached
    }
    return FoodProduct(
        barcode: barcode,
        name: name,
        brand: brand,
        nutriScoreGrade: nutriScoreGrade,
        novaGroup: novaGroup,
        allergenTags: allergenTags
    )
}
