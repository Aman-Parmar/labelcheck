import Foundation
import SwiftData

/// One favorited product, stored on-device only. Favorites are free for
/// every user: they are the retention mechanic (the weekly shop), not a
/// Pro gate. A favorite is just a pointer back to a product the user
/// scanned: name, brand and Nutri-Score for the row, plus the barcode so
/// the full card loads from the LC-2 offline cache on tap. Favorites are
/// independent of History, so they survive the free 10-scan history cap
/// and clearing history.
@Model
final class FavoriteProduct {
    @Attribute(.unique) var barcode: String
    var name: String?
    var brand: String?
    var nutriScoreGrade: String?
    var favoritedAt: Date

    init(product: FoodProduct, favoritedAt: Date = Date()) {
        self.barcode = product.barcode
        self.name = product.name
        self.brand = product.brand
        self.nutriScoreGrade = product.nutriScoreGrade
        self.favoritedAt = favoritedAt
    }

    var displayName: String {
        name.displayNameOrUnknown
    }

    /// The favorite for a barcode, or nil when the product is not saved.
    static func fetch(barcode: String, in context: ModelContext) -> FavoriteProduct? {
        let descriptor = FetchDescriptor<FavoriteProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        return try? context.fetch(descriptor).first
    }

    static func isFavorite(barcode: String, in context: ModelContext) -> Bool {
        fetch(barcode: barcode, in: context) != nil
    }

    /// Toggles the favorite for a product; returns the new state (true
    /// when the product is now a favorite). The barcode is unique, so a
    /// second toggle removes the one row instead of adding a duplicate.
    @discardableResult
    static func toggle(product: FoodProduct, in context: ModelContext) -> Bool {
        if let existing = fetch(barcode: product.barcode, in: context) {
            context.delete(existing)
            try? context.save()
            return false
        }
        context.insert(FavoriteProduct(product: product))
        try? context.save()
        return true
    }
}
