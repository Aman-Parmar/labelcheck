import SwiftData
import SwiftUI

/// Product card: name, brand, Nutri-Score, NOVA, allergens, nutriments per
/// 100 g. Shows "not found / verify" states and never a health verdict:
/// Nutri-Score and NOVA are general information from Open Food Facts, and
/// the disclaimer says so on every card.
struct ProductView: View {
    let product: FoodProduct

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<AllergenProfile> { $0.isActive })
    private var activeProfiles: [AllergenProfile]

    @State private var modelExplanation: String?
    @State private var explaining = false
    // Favorites: heart toggle, free for every user. Loaded on appear
    // because the favorite state lives in SwiftData, not in the product.
    @State private var isFavorite = false
    // Shopping lists (phase B): the sheet that adds this product to a list.
    @State private var showingAddToList = false

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

    /// Diet filters enabled on the active profiles, in canonical order
    /// (vegan, gluten-free, no seed oils), deduplicated. Empty when no
    /// active profile has a diet filter: the section hides then.
    private var activeDietFilters: [DietFilter] {
        let keys = Set(activeProfiles.flatMap { $0.dietFilterList })
        return DietFilter.allCases.filter { keys.contains($0.rawValue) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                allergenBanner
                scoresSection
                dietSection
                nutrimentsSection
                ingredientsSection
                additivesSection
                explainSection
                alternativesSection
                sourceFooter
            }
            .padding()
        }
        .task {
            isFavorite = FavoriteProduct.isFavorite(barcode: product.barcode, in: modelContext)
            await loadAlternatives()
        }
        // Detail screens use the full screen: hide the floating tab bar on
        // push, so the card is never half-hidden behind the pill (the 02
        // listing shot caught the Nutri-Score section under it).
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddToList = true
                } label: {
                    Image(systemName: "cart.badge.plus")
                }
                .accessibilityLabel("Add to a shopping list")
                .accessibilityIdentifier("add-to-list-button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFavorite = FavoriteProduct.toggle(product: product, in: modelContext)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Save to favorites")
                .accessibilityIdentifier("favorite-toggle-button")
            }
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListSheet(product: product)
        }
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

    // MARK: - Diet filters

    /// Diet filters from the active profiles (vegan, gluten-free, no
    /// seed oils), matched on-device against the product data the card
    /// already fetched. Hidden when no active profile has a diet filter,
    /// so cards look exactly as before for everyone else. A fail is a
    /// mismatch, not a hazard, so it reads orange, not the allergen
    /// red. Never a verdict: each row states what the data lists.
    private var dietSection: some View {
        Group {
            let filters = activeDietFilters
            if !filters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diet filters")
                        .font(.headline)
                    ForEach(filters, id: \.rawValue) { filter in
                        let result = DietFilterChecker.check(filter, product: product)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.symbolName)
                                .foregroundStyle(
                                    result.status == .pass ? .green
                                    : result.status == .fail ? .orange : .secondary
                                )
                                .accessibilityHidden(true) // Meaning is in the row text below.
                            VStack(alignment: .leading, spacing: 2) {
                                Text(filter.label)
                                    .font(.subheadline.bold())
                                Text(result.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("From Open Food Facts data. General information only, not dietary advice. Check the physical label.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // See additivesSection: a plain VStack's identifier does
                // not surface in the XCUI tree, so the container is
                // grouped and the heading text is the wait target.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("diet-filters-section")
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

    // MARK: - Additives

    /// Plain-English additive explainer: what each E-number on the
    /// label is and what it does, from the curated on-device list.
    /// Hidden when the entry lists no additives: crowdsourced entries
    /// often leave additives_tags blank, and an empty section would
    /// look like a claim that the product has none. Never a verdict:
    /// the rows say what an additive does, never whether it is good
    /// or bad for you.
    private var additivesSection: some View {
        Group {
            let rows = AdditiveExplainer.rows(for: product)
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additives")
                        .font(.headline)
                    ForEach(rows, id: \.code) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            if let note = row.note {
                                Text("\(row.code): \(note.name)")
                                    .font(.subheadline.bold())
                                Text(note.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(row.code)
                                    .font(.subheadline.bold())
                                Text("No plain-English note for this one yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Names and jobs from the E-number list on Wikipedia. General information only, not a safety verdict. Check the physical label.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // See alternativesSection: a plain VStack's identifier
                // does not surface in the XCUI tree, so the container is
                // grouped and the heading text is the wait target.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("additives-section")
            }
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
            // Report wrong data: a deep link to the product's Open Food
            // Facts page, where "Edit the page" corrects it. Same
            // no-secrets reason as the add-product link in ScanView:
            // the user edits in their own browser with their own
            // account. The barcode travels only in the link they open.
            if let url = OpenFoodFactsLinks.productPageURL(barcode: product.barcode) {
                Link("Report wrong data on Open Food Facts", destination: url)
                    // The footer tints everything secondary; the link
                    // keeps the accent colour so it still reads as a link.
                    .foregroundStyle(Color.accentColor)
                    .accessibilityIdentifier("report-data-link")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
