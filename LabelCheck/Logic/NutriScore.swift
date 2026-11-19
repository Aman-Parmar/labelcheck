import Foundation

/// Nutri-Score display mapping. Pure logic, no SwiftUI, so it is unit-testable.
/// Nutri-Score grades run A (best in this system) to E. The copy deliberately
/// never says "healthy" or "unhealthy": the grade is general information from
/// Open Food Facts, not a health verdict and not medical or dietary advice.
struct NutriScore {
    let grade: String

    /// Normalised grade letter, "a"..."e", or nil when unknown.
    static func normalised(_ raw: String?) -> String? {
        guard let letter = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(), ("a"..."e").contains(letter) else { return nil }
        return letter
    }

    /// Short label for the badge, e.g. "A". Nil when unknown.
    var badgeLetter: String? {
        Self.normalised(grade)?.uppercased()
    }

    /// Rank of a Nutri-Score grade: A = 0 (best) to E = 4. Nil when the
    /// grade is unknown, so ungraded products never qualify as "higher"
    /// (used by the LC-1 alternatives picker).
    static func rank(_ grade: String?) -> Int? {
        guard let letter = normalised(grade) else { return nil }
        return ["a", "b", "c", "d", "e"].firstIndex(of: letter)
    }

    /// Plain-language line for the product card. No health verdict.
    var explanation: String {
        guard let letter = Self.normalised(grade)?.uppercased() else {
            return "No Nutri-Score listed for this product."
        }
        switch letter {
        case "A": return "Nutri-Score A: the highest score in this system."
        case "E": return "Nutri-Score E: the lowest score in this system."
        default: return "Nutri-Score \(letter) in this system."
        }
    }

    /// NOVA group line. 1 = unprocessed/minimally processed, 4 = ultra-processed.
    /// Shown as general information only.
    static func novaExplanation(_ group: Int?) -> String {
        switch group {
        case 1: return "NOVA group 1: unprocessed or minimally processed."
        case 2: return "NOVA group 2: processed culinary ingredient."
        case 3: return "NOVA group 3: processed food."
        case 4: return "NOVA group 4: ultra-processed food."
        default: return "No NOVA group listed for this product."
        }
    }
}
