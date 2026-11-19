import Foundation

/// A food product as returned by the Open Food Facts API v3.
/// Endpoint: GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json
/// No API key. Open Food Facts data is crowdsourced (ODbL licensed): the app
/// never auto-trusts it and always shows a "verify on the physical label" state.
struct FoodProduct: Identifiable, Equatable, Hashable {
    var id: String { barcode }
    let barcode: String
    let name: String?
    let brand: String?
    /// Nutri-Score grade from Open Food Facts, "a" (best) to "e". Nil when unknown.
    let nutriScoreGrade: String?
    /// NOVA group 1 (unprocessed) to 4 (ultra-processed). Nil when unknown.
    let novaGroup: Int?
    /// Allergen tags, e.g. ["en:milk", "en:gluten"]. Normalised to plain
    /// lowercased names by `allergenNames`.
    let allergenTags: [String]
    let ingredientsText: String?
    let nutriments: Nutriments
    let imageURL: URL?
    /// Open Food Facts category tags, e.g. ["en:breakfasts",
    /// "en:chocolate-spreads"]. Used to find same-category products with
    /// a higher Nutri-Score (LC-1). Empty when the entry lists none.
    let categoriesTags: [String]

    var displayName: String {
        name.displayNameOrUnknown
    }

    var displayBrand: String? {
        brand?.trimmed.nilIfEmpty
    }

    /// Plain allergen names, e.g. ["milk", "gluten"].
    var allergenNames: [String] {
        allergenTags.map { tag in
            tag.replacingOccurrences(of: "en:", with: "")
                .replacingOccurrences(of: "-", with: " ")
        }
    }

    /// Comma-separated allergen list, e.g. "milk, gluten". Nil when none
    /// listed. Shared by the product card, the plain-English explainer,
    /// and history storage, which all had the same join (hygiene dedupe,
    /// 2026-11-19).
    var listedAllergens: String? {
        allergenNames.isEmpty ? nil : allergenNames.commaJoined
    }

    init(dto: OpenFoodFactsProductDTO, barcode: String) {
        self.barcode = barcode
        self.name = dto.productName
        self.brand = dto.brands
        self.nutriScoreGrade = dto.nutriscoreGrade?.lowercased().nilIfEmpty
        self.novaGroup = dto.novaGroup
        self.allergenTags = dto.allergensTags ?? []
        self.ingredientsText = dto.ingredientsText?.nilIfEmpty
        self.nutriments = Nutriments(dto: dto.nutriments)
        self.imageURL = dto.imageURL.flatMap(URL.init(string:))
        self.categoriesTags = dto.categoriesTags ?? []
    }

    init(
        barcode: String,
        name: String? = nil,
        brand: String? = nil,
        nutriScoreGrade: String? = nil,
        novaGroup: Int? = nil,
        allergenTags: [String] = [],
        ingredientsText: String? = nil,
        nutriments: Nutriments = Nutriments(),
        imageURL: URL? = nil,
        categoriesTags: [String] = []
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.nutriScoreGrade = nutriScoreGrade
        self.novaGroup = novaGroup
        self.allergenTags = allergenTags
        self.ingredientsText = ingredientsText
        self.nutriments = nutriments
        self.imageURL = imageURL
        self.categoriesTags = categoriesTags
    }
}

/// Nutriments per 100 g, as reported by Open Food Facts. Every field is
/// optional: crowdsourced products often have partial nutrition data.
struct Nutriments: Equatable, Hashable {
    var energyKcal: Double?
    var fat: Double?
    var saturatedFat: Double?
    var carbohydrates: Double?
    var sugars: Double?
    var fiber: Double?
    var proteins: Double?
    var salt: Double?

    var isEmpty: Bool {
        energyKcal == nil && fat == nil && carbohydrates == nil
            && sugars == nil && proteins == nil && salt == nil
    }

    init(
        energyKcal: Double? = nil,
        fat: Double? = nil,
        saturatedFat: Double? = nil,
        carbohydrates: Double? = nil,
        sugars: Double? = nil,
        fiber: Double? = nil,
        proteins: Double? = nil,
        salt: Double? = nil
    ) {
        self.energyKcal = energyKcal
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.carbohydrates = carbohydrates
        self.sugars = sugars
        self.fiber = fiber
        self.proteins = proteins
        self.salt = salt
    }

    init(dto: OpenFoodFactsNutrimentsDTO?) {
        self.energyKcal = dto?.energyKcal100g
        self.fat = dto?.fat100g
        self.saturatedFat = dto?.saturatedFat100g
        self.carbohydrates = dto?.carbohydrates100g
        self.sugars = dto?.sugars100g
        self.fiber = dto?.fiber100g
        self.proteins = dto?.proteins100g
        self.salt = dto?.salt100g
    }

    /// Ordered rows for the product card, skipping missing values.
    var rows: [(label: String, value: Double, unit: String)] {
        var out: [(label: String, value: Double, unit: String)] = []
        if let v = energyKcal { out.append(("Energy", v, "kcal")) }
        if let v = fat { out.append(("Fat", v, "g")) }
        if let v = saturatedFat { out.append(("Saturated fat", v, "g")) }
        if let v = carbohydrates { out.append(("Carbohydrates", v, "g")) }
        if let v = sugars { out.append(("Sugars", v, "g")) }
        if let v = fiber { out.append(("Fibre", v, "g")) }
        if let v = proteins { out.append(("Protein", v, "g")) }
        if let v = salt { out.append(("Salt", v, "g")) }
        return out
    }
}

// MARK: - Open Food Facts v3 wire format

struct OpenFoodFactsResponse: Decodable {
    let product: OpenFoodFactsProductDTO?
}

struct OpenFoodFactsProductDTO: Decodable {
    let productName: String?
    let brands: String?
    let nutriscoreGrade: String?
    let novaGroup: Int?
    let allergensTags: [String]?
    let ingredientsText: String?
    let nutriments: OpenFoodFactsNutrimentsDTO?
    let imageURL: String?
    let categoriesTags: [String]?
    /// Present in category-search results; the product lookup endpoint
    /// puts the barcode in the URL instead. Nil on the lookup path.
    let code: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriscoreGrade = "nutriscore_grade"
        case novaGroup = "nova_group"
        case allergensTags = "allergens_tags"
        case ingredientsText = "ingredients_text"
        case nutriments
        case imageURL = "image_url"
        case categoriesTags = "categories_tags"
        case code
    }
}

/// Category-search response from `cgi/search.pl` (LC-1). Same product
/// fields as the v3 lookup, plus `code` as the barcode, under `products`.
struct OpenFoodFactsSearchResponse: Decodable {
    let products: [OpenFoodFactsProductDTO]?
}

struct OpenFoodFactsNutrimentsDTO: Decodable {
    let energyKcal100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let proteins100g: Double?
    let salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case salt100g = "salt_100g"
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    /// Whitespace trimmed from both ends. Shared by every lookup, search,
    /// and display-name path, which all had the same
    /// `trimmingCharacters(in: .whitespacesAndNewlines)` call
    /// (hygiene dedupe, 2026-11-19).
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the string is empty or only whitespace.
    var isBlank: Bool {
        trimmed.isEmpty
    }

    /// Split a comma-separated list, trimming whitespace from each item.
    var commaSeparatedList: [String] {
        split(separator: ",").map { $0.trimmed }
    }
}

extension Array where Element == String {
    /// Join for display, e.g. ["milk", "gluten"] -> "milk, gluten".
    /// The inverse of `String.commaSeparatedList`. Shared by the product
    /// card, the allergen profiles list, and `FoodProduct.listedAllergens`,
    /// which all had the same join (hygiene dedupe, 2026-11-19).
    var commaJoined: String {
        joined(separator: ", ")
    }
}

extension Optional where Wrapped == String {
    /// Trimmed value, or "Unknown product" when nil or blank. Shared by
    /// `FoodProduct.displayName` and `ScannedProduct.displayName`, which
    /// had identical bodies (hygiene dedupe, 2026-11-19).
    var displayNameOrUnknown: String {
        self?.trimmed.nilIfEmpty ?? "Unknown product"
    }
}
