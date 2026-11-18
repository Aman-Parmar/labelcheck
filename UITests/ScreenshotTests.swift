import XCTest

/// App Store screenshot lane — 9 shots on the iPhone 17 Pro Max simulator.
/// Real simulator screenshots of the real app, never mockups. The app runs
/// in `--screenshot-mode`: lookups come from bundled sample JSON (Nutella,
/// Coca-Cola, Kinder Bueno), history is seeded, and the OCR shot uses
/// bundled sample label text. No network, fully deterministic.
///
/// CI runs this lane in parallel with the unit-test lane (see
/// .github/workflows/ios.yml) and uploads the PNGs as an artifact.
/// After a run, check framing: scan button, Nutri-Score badge and allergen
/// banner fully visible in each shot, no clipping.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()
    }

    // MARK: - 01 Scan

    func test01Scan() {
        app.tabBars.buttons["Scan"].tap()
        // No scroll: the Scan screen is laid out so the "Scan with camera"
        // button clears the floating tab bar at rest (inline title + tight
        // camera card). Scrolling it caused the large-title collapse to
        // ghost over the card in runs 44250358989 and 44254094663.
        saveScreenshot(named: "01-scan")
    }

    // MARK: - 02 Product card

    func test02ProductCard() {
        app.tabBars.buttons["Scan"].tap()
        let field = app.textFields["manual-barcode-field"]
        field.tap()
        field.typeText("3017620422003")
        app.buttons["manual-lookup-button"].tap()
        let productName = app.staticTexts["product-name"]
        XCTAssertTrue(productName.waitForExistence(timeout: 10))
        // LC-1: Nutella is grade E, so the alternatives section loads from
        // bundled sample data (offline). It sits below the fold, so it does
        // not change this shot; test10 captures it. The heading text is
        // the wait target: a plain VStack's identifier did not surface in
        // the XCUI tree (run 44379182540), even though the section rendered.
        XCTAssertTrue(app.staticTexts["Higher Nutri-Score in this category"].waitForExistence(timeout: 10))
        saveScreenshot(named: "02-product-card")
    }

    // MARK: - 03 Allergens

    func test03Allergens() {
        app.tabBars.buttons["Allergens"].tap()
        XCTAssertTrue(app.staticTexts["Maya"].waitForExistence(timeout: 10))
        saveScreenshot(named: "03-allergens")
    }

    // MARK: - 04 History

    func test04History() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        // No scroll: neither a coordinate drag nor app.swipeUp() moves
        // these Lists under test (the rows capture the touch / the gesture
        // is a no-op — 07 came back byte-identical twice). The last row
        // sitting partly behind the pill is normal list behaviour; the
        // first two rows are fully visible.
        saveScreenshot(named: "04-history")
    }

    // MARK: - 05 OCR fallback

    func test05OCRFallback() {
        app.tabBars.buttons["Scan"].tap()
        app.buttons["ocr-sample-button"].tap()
        XCTAssertTrue(app.staticTexts["ocr-text"].waitForExistence(timeout: 10))
        // Let the push animation finish: an earlier capture was taken
        // mid-transition (top half black, tab bar overlapping text).
        Thread.sleep(forTimeInterval: 1.0)
        saveScreenshot(named: "05-ocr-fallback")
    }

    // MARK: - 06 Paywall

    func test06Paywall() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings-get-pro-button"].tap()
        XCTAssertTrue(app.staticTexts["LabelCheck Pro"].waitForExistence(timeout: 10))
        // Wait for the prices, not just the title: StoreKit products load
        // async, and the screenshot-mode fallback rows load after them.
        // Capturing on the title alone caught the loading spinner instead
        // of the price cards in run 44291564737. "$9.99" appears on both
        // paths (real product displayPrice, or the .storekit fallback row).
        XCTAssertTrue(app.staticTexts["$9.99"].waitForExistence(timeout: 10))
        saveScreenshot(named: "06-paywall")
    }

    // MARK: - 07 Settings

    func test07Settings() {
        app.tabBars.buttons["Settings"].tap()
        // No scroll: see test04History — the List does not move under test
        // gestures. The Support section sits second now, so the support
        // URL clears the floating tab bar at rest and is fully visible.
        saveScreenshot(named: "07-settings")
    }

    // MARK: - 08 Add allergen profile (no screenshot)

    /// Covers the add-profile navigation push (AllergenProfilesView used to
    /// carry two .sheet modifiers on the same view, the same latent bug as
    /// the OCR sheet). Screenshot mode seeds two profiles ("Maya" and
    /// "Leo"), so the test deletes both to reach the empty state, then adds
    /// a profile and checks it appears in the list. Runs last but one
    /// alphabetically, so the deletion cannot affect the screenshot tests
    /// above; test09 only touches History.
    func test08AddProfile() {
        app.tabBars.buttons["Allergens"].tap()
        XCTAssertTrue(app.staticTexts["Maya"].waitForExistence(timeout: 10))
        for name in ["Maya", "Leo"] {
            let cell = app.cells.containing(.staticText, identifier: name).element
            cell.swipeLeft()
            app.buttons["Delete"].tap()
        }
        XCTAssertTrue(app.buttons["add-profile-empty-button"].waitForExistence(timeout: 10))
        app.buttons["add-profile-empty-button"].tap()
        let nameField = app.textFields["profile-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Sam")
        app.buttons["allergen-option-Milk"].tap()
        app.buttons["save-profile-button"].tap()
        XCTAssertTrue(app.staticTexts["Sam"].waitForExistence(timeout: 10))
    }

    // MARK: - 09 Export gating (no screenshot)

    /// History export is Pro-only: in screenshot mode the store is not Pro,
    /// so tapping Export must open the paywall instead of the system share
    /// sheet. The CSV text itself is covered by HistoryCSVTests.
    func test09ExportGating() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        app.buttons["history-export-button"].tap()
        XCTAssertTrue(app.staticTexts["LabelCheck Pro"].waitForExistence(timeout: 10))
    }

    // MARK: - 10 Alternatives (LC-1 screenshot)

    /// The alternatives section sits below the fold on the product card,
    /// so it gets its own shot: Nutella (grade E) with three bundled
    /// sample alternatives (Funkie praliné C, Bonne Maman D, Funkie D).
    /// Runs last alphabetically, after test09, so it cannot disturb the
    /// earlier shots; it only navigates.
    func test10Alternatives() {
        app.tabBars.buttons["Scan"].tap()
        let field = app.textFields["manual-barcode-field"]
        field.tap()
        field.typeText("3017620422003")
        app.buttons["manual-lookup-button"].tap()
        XCTAssertTrue(app.staticTexts["product-name"].waitForExistence(timeout: 10))
        // Wait on the section heading text, not the section container's
        // identifier: see test02.
        XCTAssertTrue(app.staticTexts["Higher Nutri-Score in this category"].waitForExistence(timeout: 10))
        // Scroll the section into view: the card is a ScrollView, so a
        // swipe moves it (unlike the Lists in test04/test07). Stop as
        // soon as the first alternative row is tappable.
        let firstAlternative = app.buttons["alternative-product-3760336830357"]
        for _ in 0..<5 where !firstAlternative.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(firstAlternative.waitForExistence(timeout: 10))
        saveScreenshot(named: "08-alternatives")
    }

    // MARK: - 11 Search (LC-3 screenshot)

    /// Search by name (LC-3, Pro): in screenshot mode the Pro gate is
    /// bypassed so the lane can capture real results offline. Typing
    /// "nutella" matches the bundled Nutella sample only. Runs after
    /// test10, so it cannot disturb the earlier shots; it only navigates
    /// within the Scan tab.
    func test11Search() {
        app.tabBars.buttons["Scan"].tap()
        // The search section sits below the manual entry card: scroll it
        // into view first. The Scan screen is a ScrollView, so a swipe
        // moves it (unlike the Lists in test04/test07).
        let field = app.textFields["search-field"]
        for _ in 0..<3 where !field.isHittable {
            app.swipeUp()
        }
        field.tap()
        field.typeText("nutella")
        app.buttons["search-button"].tap()
        let result = app.buttons["search-result-3017620422003"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        for _ in 0..<5 where !result.isHittable {
            app.swipeUp()
        }
        saveScreenshot(named: "09-search")
    }

    // MARK: - 12 Search gating (no screenshot)

    /// Search is Pro-only: with a real (non-Pro) store, tapping Search
    /// must open the paywall instead of running the search. Relaunches
    /// without `--screenshot-mode`, because screenshot mode bypasses the
    /// gate so test11 can capture results. Runs last alphabetically, so
    /// the relaunch cannot disturb the earlier shots.
    func test12SearchGating() {
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["Scan"].tap()
        let field = app.textFields["search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        for _ in 0..<3 where !field.isHittable {
            app.swipeUp()
        }
        field.tap()
        field.typeText("nutella")
        app.buttons["search-button"].tap()
        XCTAssertTrue(app.staticTexts["LabelCheck Pro"].waitForExistence(timeout: 10))
    }

    // MARK: - Helper

    /// Saves the screenshot both as an XCTAttachment (in the xcresult) and
    /// as a PNG in /tmp/labelcheck-screenshots, which CI uploads as an
    /// artifact. The simulator shares the host /tmp, so this path works.
    private func saveScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = URL(fileURLWithPath: "/tmp/labelcheck-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
