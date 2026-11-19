import Foundation

/// Healthier alternatives (LC-1, Sprint 1): same-category products with a
/// higher Nutri-Score than the product on screen. Pure logic, no SwiftUI
/// and no network, so it is unit-testable.
///
/// "Higher" means strictly better in the Nutri-Score system (A best, E
/// worst). The app never says "healthy" or "healthier" about a product:
/// the section shows the Nutri-Score letter, which is general information
/// from Open Food Facts, not a health verdict.
enum AlternativeProducts {
    /// How many alternatives the card shows at most (ROADMAP acceptance:
    /// 2-3 on a D/E product card).
    static let maxAlternatives = 3

    /// Rank of a Nutri-Score grade: A = 0 (best) to E = 4. Nil when the
    /// grade is unknown, so ungraded products never qualify.
    static func rank(_ grade: String?) -> Int? {
        NutriScore.rank(grade)
    }

    /// Whether the product card shows the alternatives section at all:
    /// only on a D or E product, where a higher score exists to show.
    static func showsAlternatives(for product: FoodProduct) -> Bool {
        guard let rank = rank(product.nutriScoreGrade) else { return false }
        return rank >= 3
    }

    /// Picks up to `maxAlternatives` products from a category search:
    /// strictly higher Nutri-Score than `current`, never the current
    /// product itself, named products only, best score first. A product
    /// with no grade cannot be shown as "higher", so it is dropped.
    static func select(
        from candidates: [FoodProduct],
        current: FoodProduct,
        limit: Int = maxAlternatives
    ) -> [FoodProduct] {
        guard let currentRank = rank(current.nutriScoreGrade) else { return [] }
        var seen: Set<String> = []
        return candidates
            .filter { candidate in
                guard candidate.barcode != current.barcode,
                      candidate.name?.trimmed
                        .isEmpty == false,
                      let candidateRank = rank(candidate.nutriScoreGrade),
                      candidateRank < currentRank,
                      seen.insert(candidate.barcode).inserted
                else { return false }
                return true
            }
            .sorted {
                let left = rank($0.nutriScoreGrade) ?? Int.max
                let right = rank($1.nutriScoreGrade) ?? Int.max
                if left != right { return left < right }
                return $0.displayName < $1.displayName
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Category tags too broad to be a useful "same category": searching
    /// them returns unrelated products (cereals for a spread, meals for a
    /// snack). These are skipped when picking a search category.
    static let broadCategories: Set<String> = [
        "en:breakfasts",
        "en:snacks",
        "en:beverages",
        "en:foods",
        "en:meals",
        "en:frozen-foods",
        "en:plant-based-foods",
        "en:plant-based-foods-and-beverages",
    ]

    /// Category tags to search, most specific first. Open Food Facts lists
    /// a product's categories roughly broad to specific, so the list is
    /// reversed after dropping the too-broad ones. The client tries them
    /// in order until one returns enough higher-scored products.
    static func categoryCandidates(from product: FoodProduct) -> [String] {
        let specific = product.categoriesTags.filter { !broadCategories.contains($0) }
        let candidates = specific.isEmpty ? product.categoriesTags : specific
        return candidates.reversed()
    }
}
