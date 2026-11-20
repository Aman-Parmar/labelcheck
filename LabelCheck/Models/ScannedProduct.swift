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
/// Diet filters (vegan, gluten-free, no seed oils) ride on the same profile:
/// they are matched the same way, on-device, against the product data the
/// card already fetched. The first profile is free; additional profiles are
/// Pro, same as allergens.
@Model
final class AllergenProfile: CommaSeparatedAllergens {
    var name: String
    /// Comma-separated allergen keys, e.g. "milk, peanut, gluten".
    var allergens: String
    /// Comma-separated diet filter keys, e.g. "vegan, gluten-free".
    /// Added 2026-11-19 (diet filters); empty for profiles created
    /// before then. SwiftData lightweight migration covers the added
    /// property; pre-launch there are no shipped installs to migrate.
    var dietFilters: String = ""
    var isActive: Bool
    var createdAt: Date

    init(name: String, allergens: [String], dietFilters: [String] = [], isActive: Bool = true) {
        self.name = name
        self.allergens = allergens.commaJoined
        self.dietFilters = dietFilters.commaJoined
        self.isActive = isActive
        self.createdAt = Date()
    }

    /// Diet filter keys on this profile, e.g. ["vegan", "gluten-free"].
    var dietFilterList: [String] {
        dietFilters.commaSeparatedList
    }
}
