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

    // LC-1 alternatives: same-category products with a higher Nutri-Score.
    // Loaded once when the card appears; nil while loading, empty when
    // nothing better was found, hidden entirely when the fetch fails.
    @State private var alternativesClient = OpenFoodFactsClient()
    @State private var alternatives: [FoodProduct]?
    @State private var alternativesFailed = false
    @State private var selectedAlternative: FoodProduct?

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
                alternativesSection
                sourceFooter
            }
            .padding()
        }
        .task {
            await loadAlternatives()
        }
        // Detail screens use the full screen: hide the floating tab bar on
        // push, so the card is never half-hidden behind the pill (the 02
        // listing shot caught the Nutri-Score section under it).
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(product.displayName)
        .navigationBarTitleDisplayMode(.inline)
        // Tapping an alternative pushes its own card on the same stack.
        .navigationDestination(item: $selectedAlternative) { alternative in
            ProductView(product: alternative)
        }
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
                    Text("No match with your active allergen profiles. Still check the physical label. This data is crowdsourced and may be incomplete.")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "checkmark.shield")
                }
                .padding()
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Contains: \(matchedAllergens.commaJoined)", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                    Text("This matches an allergen in your active profile. Check the physical label before eating. This is not an allergy safety guarantee.")
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
        let score = NutriScore(grade: product.nutriScoreGrade ?? "")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if score.badgeLetter != nil {
                    VStack {
                        NutriScoreBadge(grade: product.nutriScoreGrade, size: 56, font: .largeTitle.bold())
                            .accessibilityIdentifier("nutriscore-badge")
                        Text("Nutri-Score")
                            .font(.caption)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(score.explanation)
                        .font(.subheadline)
                    Text(NutriScore.novaExplanation(product.novaGroup))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let listed = product.listedAllergens {
                Text("Listed allergens: \(listed)")
                    .font(.subheadline)
            }
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

    // MARK: - Alternatives (LC-1)

    /// Same-category products with a higher Nutri-Score, on D/E cards
    /// only. One tap opens that product's card. Never a health verdict:
    /// the rows show the Nutri-Score letter, which is general information
    /// from Open Food Facts. Hidden when the fetch fails, so a D/E card
    /// never shows a broken section.
    private var alternativesSection: some View {
        Group {
            if AlternativeProducts.showsAlternatives(for: product), !alternativesFailed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Higher Nutri-Score in this category")
                        .font(.headline)
                    Text("Same kind of product, from Open Food Facts. A higher Nutri-Score is general information, not dietary advice. Only the product category is sent to fetch these.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let alternatives {
                        if alternatives.isEmpty {
                            Text("No higher-scored products found in this category yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(alternatives) { alternative in
                                Button {
                                    selectedAlternative = alternative
                                } label: {
                                    HStack(spacing: 12) {
                                        NutriScoreBadge(grade: alternative.nutriScoreGrade, size: 36, font: .headline.bold())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(alternative.displayName)
                                                .font(.subheadline.bold())
                                            if let brand = alternative.displayBrand {
                                                Text(brand)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityHidden(true) // Decorative; the row is labelled by name and brand.
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("alternative-product-\(alternative.barcode)")
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
                // A plain VStack is not an accessibility element, so the
                // identifier below would not surface in the XCUI tree
                // (the screenshot lane waited 10 s for it and never found
                // it, run 44379182540). Grouping the children makes the
                // container itself an element carrying the identifier.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("alternatives-section")
            }
        }
    }

    private func loadAlternatives() async {
        guard AlternativeProducts.showsAlternatives(for: product),
              alternatives == nil, !alternativesFailed
        else { return }
        await alternativesClient.setUseSampleData(ScreenshotMode.isEnabled)
        do {
            alternatives = try await alternativesClient.fetchAlternatives(for: product)
        } catch {
            alternativesFailed = true
        }
    }

    // MARK: - Source

    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Data: Open Food Facts (ODbL), crowdsourced. Verify on the physical label. Product data may be incomplete or out of date.")
            Text("General information only, not medical or dietary advice, and not an allergy safety guarantee. Check with a doctor about dietary questions.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
