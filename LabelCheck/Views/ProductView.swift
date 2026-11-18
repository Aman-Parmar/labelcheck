import SwiftData
import SwiftUI

/// Product card: name, brand, Nutri-Score, NOVA, allergens, nutriments per
/// 100 g. Shows "not found / verify" states and never a health verdict:
/// Nutri-Score and NOVA are general information from Open Food Facts, and
/// the disclaimer says so on every card.
struct ProductView: View {
    let product: FoodProduct

    @Query(filter: #Predicate<AllergenProfile> { $0.isActive })
    private var activeProfiles: [AllergenProfile]

    @State private var modelExplanation: String?
    @State private var explaining = false

    private var matchedAllergens: [String] {
        // Profiles store allergen KEYS (e.g. "tree-nut"); match on keys.
        let keys = activeProfiles.flatMap { $0.allergenList }
        return AllergenMatcher.matches(
            profileAllergenKeys: keys,
            productAllergenNames: product.allergenNames,
            ingredientsText: product.ingredientsText
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                allergenBanner
                scoresSection
                nutrimentsSection
                ingredientsSection
                explainSection
                sourceFooter
            }
            .padding()
        }
        .navigationTitle(product.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.displayName)
                .font(.title2.bold())
                .accessibilityIdentifier("product-name")
            if let brand = product.displayBrand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("product-brand")
            }
            Text("Barcode \(product.barcode)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Allergens

    private var allergenBanner: some View {
        Group {
            if matchedAllergens.isEmpty {
                Label {
                    Text("No match with your active allergen profiles. Still check the physical label — this data is crowdsourced and may be incomplete.")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "checkmark.shield")
                }
                .padding()
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Contains: \(matchedAllergens.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text("This matches an allergen in your active profile. Check the physical label before eating — this is not an allergy safety guarantee.")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("allergen-banner")
            }
        }
    }

    // MARK: - Scores

    private var scoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if let letter = NutriScore(grade: product.nutriScoreGrade ?? "").badgeLetter {
                    VStack {
                        Text(letter)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(nutriScoreColor(letter), in: Circle())
                            .accessibilityIdentifier("nutriscore-badge")
                        Text("Nutri-Score")
                            .font(.caption)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(NutriScore(grade: product.nutriScoreGrade ?? "").explanation)
                        .font(.subheadline)
                    Text(NutriScore.novaExplanation(product.novaGroup))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !product.allergenNames.isEmpty {
                Text("Listed allergens: \(product.allergenNames.joined(separator: ", "))")
                    .font(.subheadline)
            }
        }
    }

    private func nutriScoreColor(_ letter: String) -> Color {
        switch letter {
        case "A": return .green
        case "B": return Color(red: 0.55, green: 0.75, blue: 0.25)
        case "C": return .yellow
        case "D": return .orange
        case "E": return .red
        default: return .gray
        }
    }

    // MARK: - Nutriments

    private var nutrimentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per 100 g")
                .font(.headline)
            if product.nutriments.isEmpty {
                Text("No nutrition data listed for this product.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(product.nutriments.rows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                        Spacer()
                        Text("\(row.value.formatted(.number.precision(.fractionLength(0...1)))) \(row.unit)")
                            .font(.subheadline.monospacedDigit())
                    }
                    .font(.subheadline)
                    Divider()
                }
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients")
                .font(.headline)
            Text(product.ingredientsText ?? "No ingredients listed for this product.")
                .font(.subheadline)
                .foregroundStyle(product.ingredientsText == nil ? .secondary : .primary)
        }
    }

    // MARK: - Explain

    private var explainSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In plain English")
                .font(.headline)
            Text(LabelExplainer.plainEnglishSummary(for: product))
                .font(.subheadline)
            if LabelExplainer.foundationModelsAvailable {
                if explaining {
                    ProgressView()
                } else if let modelExplanation {
                    Text(modelExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Explain with on-device AI") {
                        explaining = true
                        Task { @MainActor in
                            if #available(iOS 26.0, *) {
                                modelExplanation = await LabelExplainer.explainWithModel(product)
                            }
                            explaining = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("explain-ai-button")
                }
            }
        }
    }

    // MARK: - Source

    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Data: Open Food Facts (ODbL), crowdsourced — verify on the physical label. Product data may be incomplete or out of date.")
            Text("General information only — not medical or dietary advice, and not an allergy safety guarantee. Check with a doctor about dietary questions.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
