import SwiftUI

/// Settings: privacy, attribution, support and Pro. No account anywhere.
struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.isPro {
                        Label("LabelCheck Pro: thank you", systemImage: "checkmark.seal.fill")
                    } else {
                        Button("Get LabelCheck Pro") {
                            showingPaywall = true
                        }
                        .accessibilityIdentifier("settings-get-pro-button")
                        Text("Free keeps unlimited barcode scans forever. Pro adds unlimited history, multiple allergen profiles, OCR label explain, and export.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                // Support sits second, not last: at rest the support URL
                // clears the iOS 26 floating tab bar, so the listing
                // screenshot (test07) shows it fully instead of cut off
                // behind the pill. It is also the row a user most often
                // needs, so earlier is better discoverability, not just
                // framing.
                Section("Support") {
                    Text("Support: labelcheck.singhsec.com/labelcheck-support")
                    Text("Privacy policy: labelcheck.singhsec.com/labelcheck-privacy")
                    Text("Version 1.0 (1)")
                        .foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("No account. No analytics. No ads. No tracking.")
                    Text("Only the scanned barcode is sent to Open Food Facts to fetch that product's data. Scan history and allergen profiles stay on this phone.")
                    Text("Deleting the app deletes your history and profiles.")
                }
                Section("Data") {
                    Text("Product data: Open Food Facts (ODbL), crowdsourced. Verify on the physical label.")
                    Text("General information only, not medical or dietary advice, and not an allergy safety guarantee.")
                }
                Section {
                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                    .accessibilityIdentifier("restore-purchases-button")
                }
            }
            // The iOS 26 floating tab bar overlays scroll content; a bottom
            // content margin lets the last rows scroll fully above the pill.
            .contentMargins(.bottom, 110, for: .scrollContent)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .task {
                await store.loadProducts()
            }
        }
    }
}
