import SwiftData
import SwiftUI

/// LabelCheck — Scan any packaged food, know what's in it in 2 seconds, privately.
/// No account, no analytics, no ads. All scan history and allergen profiles
/// live on the device in SwiftData. The only data that leaves the phone is the
/// scanned barcode (to fetch that product), the product category on a D/E card
/// (to fetch same-category alternatives), and, with Pro, the words typed to
/// search by product name, all sent only to Open Food Facts.
@main
struct LabelCheckApp: App {
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .modelContainer(for: [ScannedProduct.self, AllergenProfile.self, CachedProduct.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            AllergenProfilesView()
                .tabItem {
                    Label("Allergens", systemImage: "exclamationmark.shield")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .task {
            // Screenshot mode only: seed deterministic sample history so the
            // UITest screenshot lane never depends on the network.
            ScreenshotSeeder.seedIfNeeded(modelContext: modelContext)
        }
    }
}
