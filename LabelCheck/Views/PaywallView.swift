import StoreKit
import SwiftUI

/// Paywall: two products, one Pro entitlement. Free keeps unlimited barcode
/// scans and the product card forever; Pro is depth only.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var purchaseError: String?
    @State private var sampleRows: [ScreenshotStoreRow] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LabelCheck Pro")
                            .font(.largeTitle.bold())
                        Text("For people who scan every week.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "clock.arrow.circlepath", text: "Unlimited scan history")
                        FeatureRow(icon: "exclamationmark.shield", text: "Multiple allergen profiles")
                        FeatureRow(icon: "text.viewfinder", text: "OCR label explain")
                        FeatureRow(icon: "magnifyingglass", text: "Search products by name")
                        FeatureRow(icon: "square.and.arrow.up", text: "Export your history")
                    }
                    Text("Free keeps unlimited barcode scans and the full product card, forever. No ads, no account, no tracking either way.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if store.isLoading {
                        ProgressView()
                    } else if !store.products.isEmpty {
                        ForEach(store.products.sorted(by: { $0.price < $1.price })) { product in
                            Button {
                                Task {
                                    do {
                                        try await store.purchase(product)
                                        if store.isPro { dismiss() }
                                    } catch {
                                        purchaseError = error.localizedDescription
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName)
                                            .font(.headline)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("buy-\(product.id)")
                        }
                    } else if ScreenshotMode.isEnabled, !sampleRows.isEmpty {
                        // Screenshot mode only: StoreKit products may not
                        // load under the UITest runner, so shot 06 renders
                        // the same prices from the real bundled
                        // LabelCheck.storekit file, purchases disabled.
                        // Never shown in a shipping build.
                        ForEach(sampleRows) { row in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(row.displayName)
                                        .font(.headline)
                                    Text(row.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("$\(row.displayPrice)")
                                    .font(.headline)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("buy-\(row.id)")
                        }
                    } else {
                        Text("Products could not be loaded. Check your connection and try again. Purchases are handled by Apple.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let purchaseError {
                        Text(purchaseError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                    .buttonStyle(.bordered)
                    Text("Payment is handled by Apple. Subscriptions renew automatically unless cancelled in iPhone Settings. General information only, not medical or dietary advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await store.loadProducts()
                if ScreenshotMode.isEnabled {
                    sampleRows = ScreenshotStoreProducts.load()
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
    }
}

/// Screenshot-mode paywall rows, parsed from the real bundled
/// LabelCheck.storekit file — same source of truth as the scheme's StoreKit
/// configuration. Only used when StoreKit products did not load under the
/// UITest runner. Never shown in a shipping build.
private struct ScreenshotStoreRow: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
}

private enum ScreenshotStoreProducts {
    private struct File: Decodable {
        let products: [Product]
        struct Product: Decodable {
            let id: String
            let displayPrice: String
            let localizations: [Localization]
            struct Localization: Decodable {
                let displayName: String
                let description: String
            }
        }
    }

    static func load() -> [ScreenshotStoreRow] {
        guard let url = Bundle.main.url(forResource: "LabelCheck", withExtension: "storekit"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else { return [] }
        return file.products.map {
            ScreenshotStoreRow(
                id: $0.id,
                displayName: $0.localizations.first?.displayName ?? $0.id,
                description: $0.localizations.first?.description ?? "",
                displayPrice: $0.displayPrice
            )
        }
    }
}
