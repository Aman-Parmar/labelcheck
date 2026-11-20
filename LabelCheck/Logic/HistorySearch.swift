import Foundation

/// History search: filter scanned rows by name, brand, or barcode.
/// Free for every user (searching your own on-device history); Pro's
/// value is the unlimited history there is to search. Matching is
/// case- and diacritic-insensitive, so "cafe" finds "Café". No new
/// network call, no new data leaves the phone.
enum HistorySearch {
    static func filter(_ items: [ScannedProduct], query: String) -> [ScannedProduct] {
        let needle = query.trimmed
        guard !needle.isEmpty else { return items }
        return items.filter { matches(item: $0, query: needle) }
    }

    static func matches(item: ScannedProduct, query: String) -> Bool {
        let fields: [String?] = [item.name, item.brand, item.barcode]
        return fields.contains { field in
            field?.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
