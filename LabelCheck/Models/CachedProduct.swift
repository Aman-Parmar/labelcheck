import Foundation
import SwiftData

/// One cached Open Food Facts lookup response (LC-2), stored on-device
/// only. The raw JSON is kept verbatim so a re-scan or a History tap can
/// rebuild the full product card with no signal. Deleting the app deletes
/// the cache, like history. The cache is not history: clearing History
/// leaves cached payloads in place until they age out of the cap
/// (see ProductPayloadStore.maxEntries).
@Model
final class CachedProduct {
    @Attribute(.unique) var barcode: String
    var payload: Data
    var cachedAt: Date

    init(barcode: String, payload: Data, cachedAt: Date = Date()) {
        self.barcode = barcode
        self.payload = payload
        self.cachedAt = cachedAt
    }
}
