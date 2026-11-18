import Foundation
import SwiftData

/// On-device cache of Open Food Facts product payloads (LC-2).
///
/// Every scanned product's full lookup response is stored verbatim in
/// SwiftData at scan time, so a re-scan or a History tap shows the full
/// product card with no signal. The cache never leaves the phone, and it
/// holds only product data that was already fetched for a scan the user
/// made: no new network call, no new data sent anywhere.
///
/// The store owns its own ModelContext on this actor so the
/// OpenFoodFactsClient actor can call it without touching the main-actor
/// view context. Entries are capped (see maxEntries) so the cache cannot
/// grow without bound; the oldest payloads are dropped first.
actor ProductPayloadStore {
    /// Upper bound on cached payloads. A payload is a few kilobytes, so
    /// this caps the cache around a couple of megabytes.
    static let maxEntries = 200

    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    /// The cached product for a barcode, or nil when nothing is cached
    /// or the stored payload no longer decodes.
    func load(barcode: String) -> FoodProduct? {
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        guard let cached = try? context.fetch(descriptor).first,
              let decoded = try? JSONDecoder().decode(
                OpenFoodFactsResponse.self, from: cached.payload),
              let dto = decoded.product
        else { return nil }
        return FoodProduct(dto: dto, barcode: barcode)
    }

    /// Stores the raw lookup response for a barcode, replacing any older
    /// payload for the same barcode, then prunes the oldest entries past
    /// the cap.
    func save(barcode: String, payload: Data) {
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.payload = payload
            existing.cachedAt = Date()
        } else {
            context.insert(CachedProduct(barcode: barcode, payload: payload))
        }
        pruneIfNeeded()
        try? context.save()
    }

    private func pruneIfNeeded() {
        let descriptor = FetchDescriptor<CachedProduct>(
            sortBy: [SortDescriptor(\.cachedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor),
              all.count > Self.maxEntries
        else { return }
        for stale in all.dropFirst(Self.maxEntries) {
            context.delete(stale)
        }
    }
}
