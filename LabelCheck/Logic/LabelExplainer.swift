import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Plain-English label explanation.
///
/// The deterministic card (`plainEnglishSummary`) is the feature: it is built
/// from the product's own data, works on every device, and is what Free users
/// see. The Foundation Models version is a gated iOS 26+ enhancement only:
/// it is hidden on ineligible devices, never the core value prop, and its
/// output is shown next to the deterministic card, never instead of it.
///
/// Notes from the Clear Days voice work, applied here:
/// - Foundation Models runs on-device (iPhone 15 Pro+ with Apple Intelligence).
/// - iOS 26 context is 4096 tokens, not 8192. Keep prompts and inputs short.
/// - Never medical advice; the prompt says so, and the UI disclaimer says so.
enum LabelExplainer {
    /// Deterministic, on-device summary. No model, no network, always available.
    static func plainEnglishSummary(for product: FoodProduct) -> String {
        var lines: [String] = []
        lines.append("\(product.displayName) by \(product.displayBrand ?? "an unknown brand").")
        if let grade = NutriScore.normalised(product.nutriScoreGrade) {
            lines.append("Its Nutri-Score is \(grade.uppercased()).")
        } else {
            lines.append("No Nutri-Score is listed for this product.")
        }
        lines.append(NutriScore.novaExplanation(product.novaGroup))
        if product.allergenNames.isEmpty {
            lines.append("No allergens are listed for this product.")
        } else {
            lines.append("Listed allergens: \(product.allergenNames.joined(separator: ", ")).")
        }
        if let ingredients = product.ingredientsText {
            lines.append("Ingredients: \(ingredients)")
        }
        lines.append("General information only, not medical or dietary advice. Always check the physical label.")
        return lines.joined(separator: " ")
    }

    /// True only on iOS 26+ with an available on-device model.
    static var foundationModelsAvailable: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
#endif
        return false
    }

#if canImport(FoundationModels)
    /// Short on-device explanation. Input is kept small on purpose: the
    /// iOS 26 context is 4096 tokens. Returns nil when unavailable so the
    /// caller falls back to `plainEnglishSummary`.
    @available(iOS 26.0, *)
    static func explainWithModel(_ product: FoodProduct) async -> String? {
        guard SystemLanguageModel.default.availability == .available else { return nil }
        let session = LanguageModelSession(instructions: """
            Explain a food label in plain English in 3 short sentences.
            State only what the label data says. Never give medical or
            dietary advice, never say a food is healthy or unhealthy, and
            never claim allergy safety. End with: Check the physical label.
            """)
        let prompt = """
            Product: \(product.displayName).
            Nutri-Score: \(product.nutriScoreGrade ?? "unknown").
            NOVA: \(product.novaGroup.map(String.init) ?? "unknown").
            Allergens: \(product.allergenNames.joined(separator: ", ")).
            Ingredients: \(product.ingredientsText ?? "not listed").
            """
        do {
            return try await session.respond(to: prompt).content
        } catch {
            return nil
        }
    }
#endif
}
