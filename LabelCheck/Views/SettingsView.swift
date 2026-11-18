import SwiftUI

/// Settings: privacy, attribution, support and Pro. No account anywhere.
///
/// Layout note: the whole list must fit above the iOS 26 floating tab bar
/// at rest, because the listing screenshot (test07) captures it without
/// scrolling, and the list does not move under test gestures. So the
/// sections are kept short and few: Restore purchases is a toolbar button,
/// the version is the Support section footer, and the Data attribution rows
/// live in the Privacy section, instead of each having a section or row of
/// its own. Do not add a section or row here without checking the 07
/// screenshot still shows every row fully.
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
                        Text("Free: unlimited barcode scans, forever. Pro adds unlimited history, multiple profiles, OCR explain, and export.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                // Support sits second, not last: at rest the support URLs
                // clear the iOS 26 floating tab bar, so the listing
                // screenshot (test07) shows them fully instead of cut off
                // behind the pill. It is also the row a user most often
                // needs, so earlier is better discoverability, not just
                // framing. The URLs are bare and single-line so neither
                // wraps.
                Section("Support", footer: { Text("Version 1.0 (1)") }) {
                    Text("labelcheck.singhsec.com/labelcheck-support")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("labelcheck.singhsec.com/labelcheck-privacy")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                // Data attribution lives here, not in its own section:
                // the list is long enough already, and the Open Food Facts
                // credit plus the general-information disclaimer must stay
                // visible at rest in the listing screenshot.
                Section("Privacy") {
                    Text("No account. No analytics. No ads. No tracking. Deleting the app deletes your history and profiles.")
                    Text("Only the scanned barcode leaves this phone. History and profiles stay on this phone.")
                    Text("Product data: Open Food Facts (ODbL).")
                    Text("General information only, not medical or dietary advice, and not an allergy safety guarantee.")
                }
            }
            // The iOS 26 floating tab bar overlays scroll content; a bottom
            // content margin lets the last rows scroll fully above the pill.
            .contentMargins(.bottom, 110, for: .scrollContent)
            // Tight section spacing helps the whole list fit above the
            // tab bar at rest (see the layout note above).
            .listSectionSpacing(8)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await store.restore() }
                    }
                    .accessibilityIdentifier("restore-purchases-button")
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .task {
                await store.loadProducts()
            }
        }
    }
}
