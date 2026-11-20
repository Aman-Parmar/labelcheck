import Foundation
import SwiftData

/// Screenshot mode: deterministic, offline, sample-data-only runs for the
/// UITest screenshot lane. Enabled by the `--screenshot-mode` launch argument
/// (set by `UITests/ScreenshotTests.swift`) or the
/// `LABELCHECK_SCREENSHOT_MODE=1` environment variable. Never enabled in a
/// shipping build: the App Store build has no launch argument and no env var.
///
/// In screenshot mode:
/// - `OpenFoodFactsClient` serves the 3 bundled sample products instead of
///   the network (see `SampleProducts.json`).
/// - History is seeded with those 3 products and two allergen profiles.
/// - Favorites is seeded with the first 2 sample products.
/// - One shopping list ("Weekly shop") is seeded with the same 2 products.
/// - The "Read a label photo" button shows the bundled sample OCR text
///   instead of opening the photo picker.
///
/// Real simulator screenshots from CI, never mockups. Sample data is clearly
/// labelled as such in the JSON file and in `LESSONS.md`.
enum ScreenshotMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
            || ProcessInfo.processInfo.environment["LABELCHECK_SCREENSHOT_MODE"] == "1"
    }
}

/// Bundled sample products (see `SampleProducts.json`). Loaded lazily.
enum SampleProducts {
    private struct File: Decodable {
        let products: [Entry]
        let ocrSampleText: String
        /// Sample alternatives per product barcode (LC-1), for the
        /// screenshot lane only. Only Nutella has bundled alternatives;
        /// other sample products return an empty list.
        let alternatives: [String: [Entry]]?
    }

    private struct Entry: Decodable {
        let barcode: String
        let product: OpenFoodFactsProductDTO
    }

    private static let loaded: File? = {
        guard let url = Bundle.main.url(forResource: "SampleProducts", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    /// The sample product for a barcode, or nil when the barcode is not one
    /// of the bundled samples.
    static func product(forBarcode barcode: String) -> FoodProduct? {
        guard let entry = loaded?.products.first(where: { $0.barcode == barcode }) else {
            return nil
        }
        return FoodProduct(dto: entry.product, barcode: barcode)
    }

    static var all: [FoodProduct] {
        loaded?.products.map { FoodProduct(dto: $0.product, barcode: $0.barcode) } ?? []
    }

    /// Sample OCR text for the 05-OCR screenshot.
    static var ocrSampleText: String {
        loaded?.ocrSampleText ?? ""
    }

    /// Bundled alternatives for a barcode (LC-1), or an empty list when
    /// none are bundled. Screenshot mode only; the live app fetches them
    /// from Open Food Facts instead.
    static func alternatives(forBarcode barcode: String) -> [FoodProduct] {
        loaded?.alternatives?[barcode]?.map {
            FoodProduct(dto: $0.product, barcode: $0.barcode)
        } ?? []
    }

    /// Sample search results (LC-3): bundled products whose name or
    /// brand contains the query, case-insensitive. Screenshot mode only;
    /// the live app searches Open Food Facts instead.
    static func search(query: String) -> [FoodProduct] {
        let needle = query.lowercased()
        guard !needle.isEmpty else { return [] }
        return all.filter { product in
            product.displayName.lowercased().contains(needle)
                || (product.displayBrand?.lowercased().contains(needle) ?? false)
        }
    }
}

/// Seeds SwiftData with the sample products and one sample allergen profile,
/// but only in screenshot mode, and only once per launch.
@MainActor
enum ScreenshotSeeder {
    static func seedIfNeeded(modelContext: ModelContext) {
        guard ScreenshotMode.isEnabled else { return }
        let existing = (try? modelContext.fetchCount(FetchDescriptor<ScannedProduct>())) ?? 0
        guard existing == 0 else { return }
        let now = Date()
        for (index, product) in SampleProducts.all.enumerated() {
            let scanned = ScannedProduct(
                product: product,
                scannedAt: now.addingTimeInterval(TimeInterval(-index * 3600))
            )
            modelContext.insert(scanned)
        }
        // Favorites: seed the first two samples so the 10-favorites shot
        // shows a list, not the empty state.
        for product in SampleProducts.all.prefix(2) {
            modelContext.insert(FavoriteProduct(product: product))
        }
        // Shopping lists (phase B): seed one list with the same two
        // samples so the 11-lists shot shows items, not the empty state.
        let weeklyShop = ShoppingList(name: "Weekly shop")
        for product in SampleProducts.all.prefix(2) {
            weeklyShop.items.append(ShoppingListItem(product: product))
        }
        modelContext.insert(weeklyShop)
        modelContext.insert(AllergenProfile(
            name: "Maya",
            allergens: ["milk", "tree-nut", "peanut"],
            isActive: true
        ))
        // A second profile so the 03-allergens listing shot shows the list
        // as a list, not one card in a lot of empty space. "Sam" is not
        // used here: test08 adds a profile called Sam.
        modelContext.insert(AllergenProfile(
            name: "Leo",
            allergens: ["gluten", "sesame"],
            isActive: true
        ))
        try? modelContext.save()
    }
}
