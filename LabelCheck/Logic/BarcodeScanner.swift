import Foundation
import SwiftUI
import VisionKit

/// Barcode scanning, all on-device.
///
/// `DataScannerViewController` (VisionKit, iOS 16+) recognises EAN-13 / UPC
/// barcodes live from the camera. No scanned image ever leaves the phone.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        private var lastBarcode: String?
        private var lastFire = Date.distantPast

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let value = barcode.payloadStringValue
                else { continue }
                // Debounce: the same barcode fires repeatedly while in frame.
                if value == lastBarcode, Date().timeIntervalSince(lastFire) < 2 { continue }
                lastBarcode = value
                lastFire = Date()
                onBarcode(value)
            }
        }
    }
}
