import PhotosUI
import SwiftData
import SwiftUI

/// Scan tab: the one job of the app. Point the camera at a barcode, or type
/// the digits under it. Unlimited scans, free, forever.
struct ScanView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var client = OpenFoodFactsClient()
    @State private var manualBarcode = ""
    @State private var isLoading = false
    @State private var status: ScanStatus?
    @State private var selectedProduct: FoodProduct?
    @State private var showingScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var ocrText: String?
    @State private var showingOCR = false

    enum ScanStatus: Equatable {
        case notFound(String)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    cameraCard
                    manualEntry
                    ocrButton
                    if isLoading {
                        ProgressView("Looking up barcode…")
                            .accessibilityIdentifier("lookup-progress")
                    }
                    if let status {
                        statusCard(status)
                    }
                    disclaimer
                }
                .padding()
            }
            .navigationTitle("Scan")
            .navigationDestination(item: $selectedProduct) { product in
                ProductView(product: product)
            }
            .sheet(isPresented: $showingScanner) {
                scannerSheet
            }
            .sheet(isPresented: $showingOCR) {
                if let ocrText {
                    OCRResultView(text: ocrText)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { @MainActor in
                    await runOCR(on: item)
                }
            }
        }
    }

    // MARK: - Camera

    private var cameraCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("scan-icon")
            Text("Scan any packaged food")
                .font(.title3.bold())
            Text("Point the camera at the barcode. Know what's in it in 2 seconds, privately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Scan with camera") {
                showingScanner = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("scan-camera-button")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var scannerSheet: some View {
        NavigationStack {
            BarcodeScannerView { barcode in
                showingScanner = false
                lookup(barcode: barcode)
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingScanner = false }
                }
            }
        }
    }

    // MARK: - Manual entry

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or type the barcode")
                .font(.headline)
            HStack {
                TextField("Digits under the barcode", text: $manualBarcode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("manual-barcode-field")
                Button("Look up") {
                    lookup(barcode: manualBarcode)
                }
                .buttonStyle(.bordered)
                .disabled(manualBarcode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .accessibilityIdentifier("manual-lookup-button")
            }
            Text("Only the barcode is sent to Open Food Facts to fetch that product. Nothing else leaves the phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - OCR fallback

    private var ocrButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            if ScreenshotMode.isEnabled {
                Button("Read a label photo (sample)") {
                    ocrText = SampleProducts.ocrSampleText
                    showingOCR = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ocr-sample-button")
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Read a label photo", systemImage: "text.viewfinder")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ocr-photo-button")
            }
            Text("No barcode, or product not found? Read the ingredients panel from a photo. The text is recognised on this phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runOCR(on item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let cgImage = image.cgImage
        else { return }
        do {
            ocrText = try await OCRService.recogniseText(in: cgImage)
            showingOCR = true
        } catch {
            status = .error("Could not read that photo. Try again with the label flat and well lit.")
        }
    }

    // MARK: - Status

    private func statusCard(_ status: ScanStatus) -> some View {
        Group {
            switch status {
            case .notFound(let barcode):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not found")
                        .font(.headline)
                    Text("Barcode \(barcode) is not in Open Food Facts yet. The database is crowdsourced and still growing.")
                    Text("Try reading the label photo instead — the ingredients panel is on the packet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .error(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text(message)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("scan-status-card")
    }

    private var disclaimer: some View {
        Text("General information only — not medical or dietary advice, and not an allergy safety guarantee. Always check the physical label, and check with a doctor about dietary questions.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Lookup

    private func lookup(barcode: String) {
        let clean = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isLoading else { return }
        isLoading = true
        status = nil
        manualBarcode = ""
        Task { @MainActor in
            await client.setUseSampleData(ScreenshotMode.isEnabled)
            do {
                if let product = try await client.fetchProduct(barcode: clean) {
                    saveToHistory(product)
                    selectedProduct = product
                } else {
                    status = .notFound(clean)
                }
            } catch {
                status = .error(error.localizedDescription)
            }
            isLoading = false
        }
    }

    private func saveToHistory(_ product: FoodProduct) {
        let barcode = product.barcode
        let descriptor = FetchDescriptor<ScannedProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.scannedAt = Date()
        } else {
            modelContext.insert(ScannedProduct(product: product))
        }
        try? modelContext.save()
    }
}
