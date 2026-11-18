import Foundation
import SwiftUI
import Vision
import VisionKit

/// Barcode scanning, all on-device.
///
/// Primary path: `DataScannerViewController` (VisionKit, iOS 16+), which
/// recognises EAN-13 / UPC barcodes live from the camera.
/// Fallback path: `detectBarcodes(in:)` runs a Vision barcode request over a
/// still image, for devices where the live scanner is unavailable.
/// No scanned image ever leaves the phone.
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

/// Vision still-image barcode detection (fallback path).
enum StillImageBarcodeScanner {
    static func detectBarcodes(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let codes = (request.results as? [VNBarcodeObservation])?
                    .compactMap(\.payloadStringValue) ?? []
                continuation.resume(returning: codes)
            }
            request.symbologies = [.ean13, .ean8, .upce]
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
