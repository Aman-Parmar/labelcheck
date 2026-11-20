import Foundation

/// Diet filters beyond allergens: vegan, gluten-free, no seed oils.
/// Extends the allergen profile system: each profile stores diet filter
/// keys alongside its allergen keys, and matching runs on-device against
/// the product data already fetched for the card. No new network call,
/// no new data leaves the phone.
///
/// Sources (all from Open Food Facts, crowdsourced):
/// - Vegan: `ingredients_analysis_tags` (en:vegan / en:non-vegan /
///   en:maybe-vegan). "Maybe" and missing both read as unknown, never
///   as a pass: the app must not claim a product is vegan on a guess.
/// - Gluten-free: `labels_tags` (en:gluten-free / en:no-gluten, both
///   spellings exist in the data) for a pass; the gluten keywords
///   (same list as the allergen matcher, minus bare "flour", which
///   would false-positive on rice flour) in the allergen tags or the
///   ingredient text for a fail; otherwise unknown.
/// - No seed oils: the ingredient text is scanned for seed-oil
///   phrases ("sunflower oil", "canola oil", ...). Palm oil is a fruit
///   oil, not a seed oil, and never matches. "Vegetable oil" is not
///   matched: it is a blend and the data cannot say which oils.
///   No ingredient text means unknown, never a pass.
///
/// Results are facts from the data, never verdicts: the rows say what
/// is listed, never whether a product is good or bad for you.
enum DietFilter: String, CaseIterable {
    case vegan
    case glutenFree = "gluten-free"
    case noSeedOils = "no-seed-oils"

    var label: String {
        switch self {
        case .vegan: return "Vegan"
        case .glutenFree: return "Gluten-free"
        case .noSeedOils: return "No seed oils"
        }
    }
}

enum DietCheckStatus: Equatable {
    case pass
    case fail
    case unknown
}

/// One filter's result on one product: the status plus the factual
/// sentence the product card shows.
struct DietCheckResult: Equatable {
    let status: DietCheckStatus
    let detail: String

    /// SF Symbol for the row icon. A fail is a mismatch, not a hazard,
    /// so the card colours it orange, not the allergen red.
    var symbolName: String {
        switch status {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum DietFilterChecker {
    /// Seed oils as they appear in ingredient text. Only "X oil"
    /// phrases: bare "corn" or "soybean" would false-positive on corn
    /// flour or tofu, which are not seed oils.
    static let seedOilPhrases = [
        "sunflower oil", "canola oil", "rapeseed oil", "soybean oil",
        "soya bean oil", "corn oil", "safflower oil", "grapeseed oil",
        "grape seed oil", "cottonseed oil", "peanut oil", "sesame oil",
    ]

    /// Gluten signals in allergen tags or ingredient text. Same list as
    /// the allergen matcher, minus bare "flour" (rice flour is
    /// gluten-free, and "wheat flour" already matches "wheat").
    static let glutenKeywords = ["gluten", "wheat", "barley", "rye", "oats", "spelt"]

    static func check(_ filter: DietFilter, product: FoodProduct) -> DietCheckResult {
        switch filter {
        case .vegan: return checkVegan(product)
        case .glutenFree: return checkGlutenFree(product)
        case .noSeedOils: return checkSeedOils(product)
        }
    }

    private static func checkVegan(_ product: FoodProduct) -> DietCheckResult {
        let tags = Set(product.ingredientsAnalysisTags.map { $0.lowercased() })
        if tags.contains("en:vegan") {
            return DietCheckResult(status: .pass, detail: "Listed as vegan by Open Food Facts.")
        }
        if tags.contains("en:non-vegan") {
            return DietCheckResult(status: .fail, detail: "Listed as non-vegan by Open Food Facts.")
        }
        return DietCheckResult(status: .unknown, detail: "Open Food Facts does not list a vegan status for this product.")
    }

    private static func checkGlutenFree(_ product: FoodProduct) -> DietCheckResult {
        let labels = Set(product.labelsTags.map { $0.lowercased() })
        if labels.contains("en:gluten-free") || labels.contains("en:no-gluten") {
            return DietCheckResult(status: .pass, detail: "Labelled gluten-free.")
        }
        let haystack = (product.allergenNames.joined(separator: " ")
            + " " + (product.ingredientsText ?? "")).lowercased()
        if glutenKeywords.contains(where: { haystack.contains($0) }) {
            return DietCheckResult(status: .fail, detail: "Gluten is listed in the allergens or ingredients.")
        }
        return DietCheckResult(status: .unknown, detail: "Open Food Facts does not list a gluten-free status for this product.")
    }

    private static func checkSeedOils(_ product: FoodProduct) -> DietCheckResult {
        guard let ingredients = product.ingredientsText, !ingredients.isBlank else {
            return DietCheckResult(status: .unknown, detail: "No ingredients listed, so seed oils cannot be checked.")
        }
        let lowered = ingredients.lowercased()
        let found = seedOilPhrases.filter { lowered.contains($0) }
        if found.isEmpty {
            return DietCheckResult(status: .pass, detail: "No seed oils listed in the ingredients.")
        }
        let names = found.map { $0.capitalized }.commaJoined
        return DietCheckResult(status: .fail, detail: "Seed oils listed in the ingredients: \(names).")
    }
}
