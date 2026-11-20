import Foundation
import SwiftData

/// A shopping list: a named group of products the user plans to buy, built
/// from favorites or from a product card. Free for every user, on-device
/// only, like Favorites: lists are the retention mechanic (the weekly
/// shop), not a Pro gate. Items are pointers back to scanned products
/// (name, brand, Nutri-Score for the row, plus the barcode so the full
/// card loads from the LC-2 offline cache on tap). No new network call,
/// no new data leaves the phone.
@Model
final class ShoppingList {
    var name: String
    var createdAt: Date

    /// Items are owned by the list: deleting the list deletes its items.
    @Relationship(deleteRule: .cascade)
    var items: [ShoppingListItem]

    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
        self.items = []
    }

    /// Creates a list with a trimmed name; returns nil for a blank name.
    @discardableResult
    static func create(name: String, in context: ModelContext) -> ShoppingList? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let list = ShoppingList(name: trimmed)
        context.insert(list)
        try? context.save()
        return list
    }

    /// Whether the list already holds a product with this barcode.
    func contains(barcode: String) -> Bool {
        items.contains { $0.barcode == barcode }
    }

    /// Adds a product to the list; returns false when it is already there
    /// (one row per product per list, so checking an item off the list
    /// never has a duplicate hiding behind it).
    @discardableResult
    func add(product: FoodProduct, in context: ModelContext) -> Bool {
        guard !contains(barcode: product.barcode) else { return false }
        items.append(ShoppingListItem(product: product))
        try? context.save()
        return true
    }

    /// Adds a favorite to the list; same one-row-per-product rule.
    @discardableResult
    func add(favorite: FavoriteProduct, in context: ModelContext) -> Bool {
        guard !contains(barcode: favorite.barcode) else { return false }
        items.append(ShoppingListItem(favorite: favorite))
        try? context.save()
        return true
    }

    /// Deletes every checked item in the list. Items are removed from
    /// the relationship array as well as deleted, so the in-memory list
    /// never holds a dangling reference to a deleted item.
    func clearChecked(in context: ModelContext) {
        let checked = items.filter { $0.isChecked }
        items.removeAll { $0.isChecked }
        for item in checked {
            context.delete(item)
        }
        try? context.save()
    }

    var checkedCount: Int {
        items.filter { $0.isChecked }.count
    }
}

/// One product on a shopping list. Unchecked by default; the user taps the
/// circle to check it off while shopping. Like a favorite row, it keeps
/// only summary fields, and the full card loads from the offline cache.
@Model
final class ShoppingListItem {
    var barcode: String
    var name: String?
    var brand: String?
    var nutriScoreGrade: String?
    var addedAt: Date
    var isChecked: Bool

    init(product: FoodProduct, addedAt: Date = Date()) {
        self.barcode = product.barcode
        self.name = product.name
        self.brand = product.brand
        self.nutriScoreGrade = product.nutriScoreGrade
        self.addedAt = addedAt
        self.isChecked = false
    }

    init(favorite: FavoriteProduct, addedAt: Date = Date()) {
        self.barcode = favorite.barcode
        self.name = favorite.name
        self.brand = favorite.brand
        self.nutriScoreGrade = favorite.nutriScoreGrade
        self.addedAt = addedAt
        self.isChecked = false
    }

    var displayName: String {
        name.displayNameOrUnknown
    }

    /// Toggles the checked-off state and saves.
    func toggleChecked(in context: ModelContext) {
        isChecked.toggle()
        try? context.save()
    }
}
