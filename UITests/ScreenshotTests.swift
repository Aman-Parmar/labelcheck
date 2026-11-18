import XCTest

/// App Store screenshot lane — 7 shots on the iPhone 17 Pro Max simulator.
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
    /// the OCR sheet). Screenshot mode seeds one profile ("Maya"), so the
    /// test deletes it first to reach the empty state, then adds a profile
    /// and checks it appears in the list. Runs last alphabetically, so the
    /// deletion cannot affect the screenshot tests above.
    func test08AddProfile() {
        app.tabBars.buttons["Allergens"].tap()
        XCTAssertTrue(app.staticTexts["Maya"].waitForExistence(timeout: 10))
        let mayaCell = app.cells.containing(.staticText, identifier: "Maya").element
        mayaCell.swipeLeft()
        app.buttons["Delete"].tap()
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
