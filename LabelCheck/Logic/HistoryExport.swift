import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// History export (CSV), a Pro feature. The paywall and Settings already
/// promise "export", so this makes the promise real before submission:
/// advertising a paid feature that does not exist would be a review risk.
///
/// Pure CSV building, no UI, no network, no file access. The export itself
/// is a SwiftUI `.fileExporter` presenting the system share/save sheet with
/// the CSV as a document, so the file never leaves the phone except where
/// the user explicitly sends it.
enum HistoryCSV {
    static let header = "Date,Name,Brand,Barcode,Nutri-Score,NOVA group,Allergens"

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// One CSV row per scanned product, newest first. Fields are escaped
    /// per RFC 4180: a field containing a comma, quote or newline is wrapped
    /// in quotes, and quotes inside are doubled.
    static func csv(for items: [ScannedProduct]) -> String {
        var lines = [header]
        for item in items {
            let fields = [
                isoFormatter.string(from: item.scannedAt),
                item.displayName,
                item.brand ?? "",
                item.barcode,
                item.nutriScoreGrade?.uppercased() ?? "",
                item.novaGroup.map(String.init) ?? "",
                item.allergenList.joined(separator: "; "),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// The CSV as a document for `.fileExporter`. The filename is set by the
/// caller through `defaultFilename`, not here.
struct HistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let csv: String

    init(csv: String) {
        self.csv = csv
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.csv = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(csv.utf8))
    }
}
