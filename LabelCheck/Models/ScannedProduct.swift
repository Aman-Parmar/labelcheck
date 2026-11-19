import Foundation
import SwiftData

/// One scanned product, stored on-device only. History never leaves the phone.
/// Free tier shows the most recent 10; Pro shows unlimited history.
@Model
final class ScannedProduct {
    @Attribute(.unique) var barcode: String
    var name: String?
    var brand: String?
    var nutriScoreGrade: String?
    var novaGroup: Int?
    /// Comma-separated plain allergen names, e.g. "milk, gluten".
    var allergens: String
    var scannedAt: Date

    init(product: FoodProduct, scannedAt: Date = Date()) {
        self.barcode = product.barcode
        self.name = product.name
        self.brand = product.brand
        self.nutriScoreGrade = product.nutriScoreGrade
        self.novaGroup = product.novaGroup
        self.allergens = product.allergenNames.joined(separator: ", ")
        self.scannedAt = scannedAt
    }

    var allergenList: [String] {
        allergens.commaSeparatedList
    }

    var displayName: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "Unknown product"
    }
}

/// One allergen profile: a named set of allergens to match against products.
/// Matching runs on-device. A match is a warning to check the physical label,
/// never a safety guarantee.
@Model
final class AllergenProfile {
    var name: String
    /// Comma-separated allergen keys, e.g. "milk,peanut,gluten".
    var allergens: String
    var isActive: Bool
    var createdAt: Date

    init(name: String, allergens: [String], isActive: Bool = true) {
        self.name = name
        self.allergens = allergens.joined(separator: ",")
        self.isActive = isActive
        self.createdAt = Date()
    }

    var allergenList: [String] {
        allergens.commaSeparatedList
    }
}
