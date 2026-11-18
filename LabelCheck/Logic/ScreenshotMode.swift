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
