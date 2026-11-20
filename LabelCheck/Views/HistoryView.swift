import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// History: scanned products, on-device only. Free shows the most recent 10;
/// Pro shows unlimited history. No account, no sync, no server.
struct HistoryView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ScannedProduct.scannedAt, order: .reverse)
    private var scanned: [ScannedProduct]

    @State private var selectedProduct: FoodProduct?
    @State private var showingPaywall = false
    @State private var showingExporter = false

    private static let freeHistoryLimit = 10

    private var visibleItems: [ScannedProduct] {
        store.isPro ? scanned : Array(scanned.prefix(Self.freeHistoryLimit))
    }

    private var hiddenCount: Int {
        max(0, scanned.count - visibleItems.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if scanned.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(visibleItems) { item in
                            Button {
                                // LC-2: open the full cached product when
                                // one exists, so a History tap works with
                                // no signal. Falls back to the summary
                                // fields stored on the row (no ingredients
                                // or nutrition data) when nothing is cached.
                                Task {
                                    selectedProduct = await fullProduct(
                                        barcode: item.barcode,
                                        name: item.name,
                                        brand: item.brand,
                                        nutriScoreGrade: item.nutriScoreGrade,
                                        novaGroup: item.novaGroup,
                                        allergenTags: item.allergenList
                                            .compactMap(AllergenMatcher.key(forLabel:))
                                            .map { "en:\($0)" },
                                        in: modelContext.container
                                    )
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if let brand = item.brand {
                                            Text(brand)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(item.scannedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NutriScoreBadge(grade: item.nutriScoreGrade, size: 32, font: .headline.bold())
                                }
                            }
                            // Plain style: the default button tint paints the
                            // whole row accent-blue, which turned the brand
                            // and date (foregroundStyle .secondary, a
                            // hierarchical level of the current foreground)
                            // blue too. Plain keeps the explicit primary /
                            // secondary styles, so the row reads like a
                            // normal iOS list row.
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                        if hiddenCount > 0 {
                            Button("See all \(scanned.count) scans with Pro") {
                                showingPaywall = true
                            }
                            .accessibilityIdentifier("history-pro-upsell")
                        }
                    }
                    // The iOS 26 floating tab bar overlays scroll content;
                    // a bottom content margin lets the last row scroll fully
                    // above the pill.
                    .contentMargins(.bottom, 110, for: .scrollContent)
                }
            }
            .navigationTitle("History")
            .navigationDestination(item: $selectedProduct) { product in
                ProductView(product: product)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .toolbar {
                if !scanned.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if store.isPro {
                                showingExporter = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export history as CSV")
                        .accessibilityIdentifier("history-export-button")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            for item in scanned { modelContext.delete(item) }
                            try? modelContext.save()
                        }
                        .accessibilityIdentifier("history-clear-button")
                    }
                }
            }
            // CSV export, Pro only. The system share/save sheet writes the
            // file where the user chooses; nothing is uploaded anywhere.
            .fileExporter(
                isPresented: $showingExporter,
                document: HistoryCSVDocument(csv: HistoryCSV.csv(for: scanned)),
                contentType: .commaSeparatedText,
                defaultFilename: "labelcheck-history.csv"
            ) { _ in }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true) // Decorative; the "No scans yet" heading follows.
            Text("No scans yet")
                .font(.title3.bold())
            Text("Scan a barcode and it will show up here, on this phone only.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleItems[index])
        }
        try? modelContext.save()
    }
}
