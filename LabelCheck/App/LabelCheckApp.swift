import SwiftData
import SwiftUI

/// LabelCheck — Scan any packaged food, know what's in it in 2 seconds, privately.
/// No account, no analytics, no ads. All scan history and allergen profiles
/// live on the device in SwiftData. The only network call is the scanned
/// barcode sent to Open Food Facts to fetch that product's data.
@main
struct LabelCheckApp: App {
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .modelContainer(for: [ScannedProduct.self, AllergenProfile.self])
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
