import PhotosUI
import SwiftData
import SwiftUI

/// Scan tab: the one job of the app. Point the camera at a barcode, or type
/// the digits under it. Unlimited scans, free, forever.
struct ScanView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.modelContext) private var modelContext

    @State private var client = OpenFoodFactsClient()
    @State private var manualBarcode = ""
    @State private var isLoading = false
    @State private var status: ScanStatus?
    @State private var selectedProduct: FoodProduct?
    @State private var showingScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var ocrText: String?
    // LC-3 search by name (Pro).
    @State private var searchText = ""
    @State private var searchResults: [FoodProduct] = []
    @State private var isSearching = false
    @State private var searchStatus: SearchStatus?
    @State private var showingPaywall = false

    enum ScanStatus: Equatable {
        case notFound(String)
        case error(String)
    }

    enum SearchStatus: Equatable {
        case noResults(String)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    cameraCard
                    manualEntry
                    searchByName
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
            // The iOS 26 floating tab bar overlays scroll content, so the
            // last items could sit half-hidden behind the pill. A bottom
            // content margin lets everything scroll fully above it.
            .contentMargins(.bottom, 110, for: .scrollContent)
            .navigationTitle("Scan")
            // Inline title, not large: the large title pushed the camera
            // card down so far that the "Scan with camera" button sat
            // half-hidden behind the floating tab bar at rest — a real
            // defect, not just a screenshot problem (runs 44247113507
            // through 44254094663). Inline also removes the large-title
            // collapse, which ghosted over the card in the 01 captures.
            // The card's own "Scan any packaged food" heading carries the
            // screen's identity, so nothing is lost.
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // LC-2: wire the persistent offline cache once when the
                // tab appears. Lookups after this read the SwiftData cache
                // before hitting the network; the store is built from the
                // app's container, so it sees the same database as History.
                await client.setPayloadStore(
                    ProductPayloadStore(container: modelContext.container))
            }
            .navigationDestination(item: $selectedProduct) { product in
                ProductView(product: product)
            }
            // The OCR result is a navigation push, not a sheet. The sheet
            // never presented in CI (runs 44238639541, 44240348390: the tap
            // on the sample button succeeded yet the OCR view's strings
            // never appeared anywhere in the app log) — first as a second
            // .sheet on the NavigationStack, then attached to the button
            // view. A push uses the same mechanism as the product card,
            // which test02 proves works from this exact view.
            .navigationDestination(item: $ocrText) { text in
                OCRResultView(text: text)
            }
            // Same reason for the paywall: this view already has the
            // scanner .sheet, so a second .sheet is the pattern that
            // failed for OCR. A bool push presents the paywall instead.
            .navigationDestination(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingScanner) {
                scannerSheet
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
        VStack(spacing: 10) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true) // Decorative; the heading below says the same thing.
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
                .disabled(manualBarcode.isBlank || isLoading)
                .accessibilityIdentifier("manual-lookup-button")
            }
            Text("Only the barcode is sent to Open Food Facts to fetch that product. Nothing else leaves the phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Search by name (LC-3, Pro)

    private var searchByName: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or search by name")
                .font(.headline)
            HStack {
                TextField("Product or brand name", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("search-field")
                    .onSubmit { runSearch() }
                Button("Search") {
                    runSearch()
                }
                .buttonStyle(.bordered)
                .disabled(searchText.isBlank || isSearching)
                .accessibilityIdentifier("search-button")
            }
            Text("Search is a Pro feature. The words you type are sent to Open Food Facts to find matching products. Nothing else leaves the phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if isSearching {
                ProgressView("Searching…")
                    .accessibilityIdentifier("search-progress")
            }
            if let searchStatus {
                searchStatusCard(searchStatus)
            }
            if !searchResults.isEmpty {
                searchResultsList
            }
        }
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults) { product in
                Button {
                    openSearchResult(product)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let brand = product.displayBrand {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        NutriScoreBadge(grade: product.nutriScoreGrade, size: 32, font: .headline.bold())
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-result-\(product.barcode)")
                if product.id != searchResults.last?.id {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func searchStatusCard(_ status: SearchStatus) -> some View {
        Group {
            switch status {
            case .noResults(let query):
                VStack(alignment: .leading, spacing: 8) {
                    Text("No matches")
                        .font(.headline)
                    Text("Nothing in Open Food Facts matched \"\(query)\". Try fewer words, or scan the barcode instead.")
                }
            case .error(let message):
                errorCard(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("search-status-card")
    }

    private func runSearch() {
        let clean = searchText.trimmed
        guard !clean.isEmpty, !isSearching else { return }
        // Pro gate: search is Pro-only, like Yuka. Screenshot mode
        // bypasses the gate so the lane can capture real results offline;
        // the gate itself is covered by test12, which relaunches without
        // screenshot mode.
        guard store.isPro || ScreenshotMode.isEnabled else {
            showingPaywall = true
            return
        }
        isSearching = true
        searchStatus = nil
        searchResults = []
        Task { @MainActor in
            await client.setUseSampleData(ScreenshotMode.isEnabled)
            do {
                let results = try await client.searchByName(clean)
                if results.isEmpty {
                    searchStatus = .noResults(clean)
                } else {
                    searchResults = results
                }
            } catch {
                searchStatus = .error(error.localizedDescription)
            }
            isSearching = false
        }
    }

    /// Opens a search result the same way a scan opens a product: a full
    /// lookup by barcode (which also saves the payload to the offline
    /// cache, LC-2), saved to History, then the product card.
    private func openSearchResult(_ product: FoodProduct) {
        Task { @MainActor in
            await client.setUseSampleData(ScreenshotMode.isEnabled)
            do {
                if let full = try await client.fetchProduct(barcode: product.barcode) {
                    saveToHistory(full)
                    selectedProduct = full
                } else {
                    selectedProduct = product
                }
            } catch {
                selectedProduct = product
            }
        }
    }

    // MARK: - OCR fallback

    private var ocrButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            if ScreenshotMode.isEnabled {
                // Same label as the real button: this shot is a listing
                // screenshot, so it shows the app as users see it. The
                // tap loads bundled sample OCR text instead of the camera.
                Button("Read a label photo") {
                    ocrText = SampleProducts.ocrSampleText
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ocr-sample-button")
            } else if store.isPro {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Read a label photo", systemImage: "text.viewfinder")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ocr-photo-button")
            } else {
                // QA-6: OCR label explain is Pro-only (SUBSCRIPTION_PLAN.md,
                // paywall, listing). Free users get the paywall, like
                // search. Same label and identifier as the picker, so the
                // 01-scan shot and the gate test are unaffected.
                Button {
                    showingPaywall = true
                } label: {
                    Label("Read a label photo", systemImage: "text.viewfinder")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ocr-photo-button")
            }
            Text("No barcode, or product not found? Read the ingredients panel from a photo. Reading a label is a Pro feature. The text is recognised on this phone.")
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
                    Text("Try reading the label photo instead. The ingredients panel is on the packet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // Add a missing product: a deep link to the Open Food
                    // Facts add form, not an in-app write. The write API
                    // needs an account password, and the app holds no
                    // secrets, so the user adds it in their own browser
                    // with their own free account. The barcode travels
                    // only in the link they choose to open.
                    if let url = OpenFoodFactsLinks.addProductURL(barcode: barcode) {
                        Link("Add this product to Open Food Facts", destination: url)
                            .accessibilityIdentifier("add-product-link")
                        Text("Open Food Facts will ask you to sign in with a free account to add it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .error(let message):
                errorCard(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("scan-status-card")
    }

    /// Shared by the search and scan status cards: same headline and
    /// message layout, so the two error states can never drift apart.
    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Something went wrong")
                .font(.headline)
            Text(message)
        }
    }

    private var disclaimer: some View {
        Text("General information only, not medical or dietary advice, and not an allergy safety guarantee. Always check the physical label, and check with a doctor about dietary questions.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Lookup

    private func lookup(barcode: String) {
        let clean = barcode.trimmed
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
