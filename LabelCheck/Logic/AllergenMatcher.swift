import Foundation
import NaturalLanguage

/// On-device allergen matching. Runs entirely on the phone against the
/// product's allergen tags and ingredient text, plus OCR text when available.
///
/// A match is a warning to check the physical label. It is never an allergy
/// safety guarantee: Open Food Facts data is crowdsourced and may be
/// incomplete, and OCR can misread. The disclaimer on every product card
/// says so.
struct AllergenMatcher {
    /// The 14 EU/US-recognised allergen groups the app matches, with the
    /// words that signal each one in ingredient text.
    static let knownAllergens: [(key: String, label: String, keywords: [String])] = [
        ("milk", "Milk", ["milk", "whey", "casein", "lactose", "butter", "cream", "cheese", "yogurt", "yoghurt"]),
        ("gluten", "Gluten", ["gluten", "wheat", "barley", "rye", "oats", "spelt", "flour"]),
        ("egg", "Egg", ["egg", "albumin"]),
        ("peanut", "Peanut", ["peanut", "peanuts", "groundnut"]),
        ("tree-nut", "Tree nuts", ["almond", "hazelnut", "walnut", "cashew", "pecan", "pistachio", "macadamia", "brazil nut"]),
        ("soy", "Soy", ["soy", "soya", "soybean", "tofu", "edamame"]),
        ("fish", "Fish", ["fish", "anchovy", "salmon", "tuna", "cod"]),
        ("shellfish", "Shellfish", ["shrimp", "prawn", "crab", "lobster", "shellfish", "mollusc", "mussel", "oyster", "clam"]),
        ("sesame", "Sesame", ["sesame"]),
        ("mustard", "Mustard", ["mustard"]),
        ("celery", "Celery", ["celery", "celeriac"]),
        ("lupin", "Lupin", ["lupin", "lupine"]),
        ("sulphites", "Sulphites", ["sulphite", "sulfite", "sulfur dioxide", "sulphur dioxide"]),
        ("molluscs", "Molluscs", ["mollusc", "mussel", "oyster", "clam", "scallop", "snail"]),
    ]

    static var allLabels: [String] { knownAllergens.map(\.label) }

    static func key(forLabel label: String) -> String? {
        knownAllergens.first { $0.label == label }?.key
    }

    static func label(forKey key: String) -> String? {
        knownAllergens.first { $0.key == key }?.label
    }

    /// Allergens from the user's active profiles that appear in this product.
    /// - Parameters:
    ///   - profileAllergenKeys: allergen keys from the active profiles.
    ///   - productAllergenNames: plain names from the product (tags + OCR).
    ///   - ingredientsText: raw ingredient text, matched by keyword.
    /// - Returns: matched allergen labels, in known-allergen order.
    static func matches(
        profileAllergenKeys: [String],
        productAllergenNames: [String],
        ingredientsText: String?
    ) -> [String] {
        let wanted = Set(profileAllergenKeys.map { $0.lowercased() })
        guard !wanted.isEmpty else { return [] }
        let haystack = (productAllergenNames.joined(separator: " ")
            + " " + (ingredientsText ?? "")).lowercased()
        var found: [String] = []
        for allergen in knownAllergens where wanted.contains(allergen.key) {
            let hit = allergen.keywords.contains { keyword in
                haystack.range(of: keyword, options: .caseInsensitive) != nil
            } || productAllergenNames.contains { name in
                name.lowercased().contains(allergen.key)
                    || allergen.keywords.contains(name.lowercased())
            }
            if hit { found.append(allergen.label) }
        }
        return found
    }

    /// Extract allergen keywords from OCR text. Tokenises on-device with
    /// Natural Language, then falls back to plain substring matching so a
    /// tokeniser miss never loses a match.
    static func extractAllergens(from text: String) -> [String] {
        let lowered = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lowered
        var tokens = Set<String>()
        tokenizer.enumerateTokens(in: lowered.startIndex..<lowered.endIndex) { range, _ in
            tokens.insert(String(lowered[range]))
            return true
        }
        var found: [String] = []
        for allergen in knownAllergens {
            let tokenHit = allergen.keywords.contains { tokens.contains($0) }
            // Regex/substring fallback: multi-word keywords ("brazil nut",
            // "sulfur dioxide") never survive word tokenisation.
            let substringHit = allergen.keywords.contains { lowered.contains($0) }
            if tokenHit || substringHit { found.append(allergen.label) }
        }
        return found
    }
}
