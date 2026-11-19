import Foundation
import SwiftData

/// Shared by the two SwiftData models that store allergens as one
/// comma-separated string. Both had the identical `allergenList` body
/// (hygiene dedupe, 2026-11-19).
protocol CommaSeparatedAllergens {
    var allergens: String { get }
}

extension CommaSeparatedAllergens {
    var allergenList: [String] {
        allergens.commaSeparatedList
    }
}

/// One scanned product, stored on-device only. History never leaves the phone.
/// Free tier shows the most recent 10; Pro shows unlimited history.
@Model
final class ScannedProduct: CommaSeparatedAllergens {
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
        self.allergens = product.listedAllergens ?? ""
        self.scannedAt = scannedAt
    }

    var displayName: String {
        name.displayNameOrUnknown
    }
}

/// One allergen profile: a named set of allergens to match against products.
/// Matching runs on-device. A match is a warning to check the physical label,
/// never a safety guarantee.
@Model
final class AllergenProfile: CommaSeparatedAllergens {
    var name: String
    /// Comma-separated allergen keys, e.g. "milk, peanut, gluten".
    var allergens: String
    var isActive: Bool
    var createdAt: Date

    init(name: String, allergens: [String], isActive: Bool = true) {
        self.name = name
        self.allergens = allergens.commaJoined
        self.isActive = isActive
        self.createdAt = Date()
    }
}
