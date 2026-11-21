import XCTest

/// App Store screenshot lane — 15 shots on the iPhone 17 Pro Max simulator.
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
            // The swipe-to-delete reveal can miss on a loaded CI runner
            // (run 44656643311: Delete never appeared after one swipe, while
            // test07 passed on the same run, so this is lane flake, not the
            // app). Retry the swipe once before failing.
            if !app.buttons["Delete"].waitForExistence(timeout: 3) {
                cell.swipeLeft()
                XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
            }
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

    // MARK: - 13 OCR gating (no screenshot)

    /// OCR label explain is Pro-only (QA-6): with a real (non-Pro) store,
    /// tapping "Read a label photo" must open the paywall instead of the
    /// photo picker. Relaunches without `--screenshot-mode`, because
    /// screenshot mode bypasses the gate so test05 can capture the OCR
    /// result. Runs last alphabetically, so the relaunch cannot disturb
    /// the earlier shots.
    func test13OCRGating() {
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["Scan"].tap()
        let ocrButton = app.buttons["ocr-photo-button"]
        for _ in 0..<5 where !ocrButton.isHittable {
            app.swipeUp()
        }
        ocrButton.tap()
        XCTAssertTrue(app.staticTexts["LabelCheck Pro"].waitForExistence(timeout: 10))
    }

    // MARK: - 14 Favorites (screenshot)

    /// Favorites tab: screenshot mode seeds the first two sample products
    /// (Nutella, Coca-Cola) as favorites, so the shot shows a list, not
    /// the empty state. Runs last alphabetically, so it cannot disturb the
    /// earlier shots; it only navigates.
    func test14Favorites() {
        app.tabBars.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        saveScreenshot(named: "10-favorites")
    }

    // MARK: - 15 Shopping lists (screenshot)

    /// Shopping lists (phase B): screenshot mode seeds one list
    /// ("Weekly shop") with Nutella and Coca-Cola, so the shot shows
    /// items, not the empty state. The Lists pane lives under the
    /// Favorites tab behind the segmented picker. Runs last
    /// alphabetically, so it cannot disturb the earlier shots; it only
    /// navigates.
    func test15Lists() {
        app.tabBars.buttons["Favorites"].tap()
        app.segmentedControls.buttons["Lists"].tap()
        let list = app.staticTexts["Weekly shop"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        list.tap()
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        saveScreenshot(named: "11-lists")
    }

    // MARK: - 16 Additives (screenshot)

    /// Additives explainer: Coca-Cola lists E150d and E338 in the live
    /// data (verified 2026-11-19), both covered by the curated list, so
    /// the shot shows two explained rows. The section sits below the
    /// fold on the product card, so it gets its own shot like the
    /// alternatives section. Runs last alphabetically, so it cannot
    /// disturb the earlier shots; it only navigates.
    func test16Additives() {
        app.tabBars.buttons["Scan"].tap()
        let field = app.textFields["manual-barcode-field"]
        field.tap()
        field.typeText("5449000000996")
        app.buttons["manual-lookup-button"].tap()
        XCTAssertTrue(app.staticTexts["product-name"].waitForExistence(timeout: 10))
        // Wait on the section heading text, not the section container's
        // identifier: see test02.
        XCTAssertTrue(app.staticTexts["Additives"].waitForExistence(timeout: 10))
        // Scroll the section into view: the card is a ScrollView, so a
        // swipe moves it (unlike the Lists in test04/test07). Stop as
        // soon as the heading is tappable.
        let heading = app.staticTexts["Additives"]
        for _ in 0..<5 where !heading.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        saveScreenshot(named: "12-additives")
    }

    // MARK: - 17 Not found (screenshot)

    /// Not-found state: a barcode the bundled sample data does not have
    /// shows the "Not found" card with the "Add this product" link to
    /// Open Food Facts. Runs last alphabetically, so it cannot disturb
    /// the earlier shots; it only uses the Scan tab.
    func test17NotFound() {
        app.tabBars.buttons["Scan"].tap()
        let field = app.textFields["manual-barcode-field"]
        field.tap()
        field.typeText("0000000000001")
        app.buttons["manual-lookup-button"].tap()
        XCTAssertTrue(app.staticTexts["Not found"].waitForExistence(timeout: 10))
        // The status card sits below the OCR section: scroll it into
        // view. A SwiftUI Link surfaces as a Button in the XCUI tree,
        // never as a StaticText: waiting on the static text waited the
        // full 10 s and never found it (CI run 44672621564), though the
        // link renders. Fall back to the links query in case a future
        // iOS exposes Link as XCUIElementTypeLink instead.
        let linkButton = app.buttons["Add this product to Open Food Facts"]
        let linkFound = linkButton.waitForExistence(timeout: 10)
            || app.links["Add this product to Open Food Facts"].waitForExistence(timeout: 5)
        XCTAssertTrue(linkFound)
        let link = linkButton.exists ? linkButton : app.links["Add this product to Open Food Facts"]
        for _ in 0..<5 where !link.isHittable {
            app.swipeUp()
        }
        saveScreenshot(named: "13-not-found")
    }

    // MARK: - 18 Diet filters (screenshot)

    /// Diet filters: Kinder Bueno is non-vegan and lists gluten in the
    /// live data (verified 2026-11-19), and its only oil is palm oil,
    /// so the shot shows two fails and one pass. The section sits below
    /// the scores on the product card, so it gets its own shot like the
    /// additives section. Runs last alphabetically, so it cannot
    /// disturb the earlier shots; it only navigates.
    ///
    /// Ordering trap: test08 deletes the seeded Maya/Leo profiles and
    /// adds a Sam profile with no diet filters, so the diet section
    /// would be hidden by test18 time if it relied on the seed. This
    /// test builds its own diet profile first (delete Sam, add one
    /// with all three filters), mirroring test08's proven pattern.
    /// The second-profile Pro gate does not apply: the add form opens
    /// because the list is empty when it is tapped.
    func test18DietFilters() {
        app.tabBars.buttons["Allergens"].tap()
        XCTAssertTrue(app.staticTexts["Sam"].waitForExistence(timeout: 10))
        let cell = app.cells.containing(.staticText, identifier: "Sam").element
        cell.swipeLeft()
        // Same retry as test08: the swipe-to-delete reveal can miss on
        // a loaded CI runner.
        if !app.buttons["Delete"].waitForExistence(timeout: 3) {
            cell.swipeLeft()
            XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        }
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["add-profile-empty-button"].waitForExistence(timeout: 10))
        app.buttons["add-profile-empty-button"].tap()
        let nameField = app.textFields["profile-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Alex")
        // The Diet filters section sits at the bottom of the form,
        // below 14 allergen rows: scroll it into view first, or the
        // buttons never enter the XCUI tree (Form rows are lazy, and
        // the first run failed tapping diet-option-vegan with no match).
        for rawValue in ["vegan", "gluten-free", "no-seed-oils"] {
            let option = app.buttons["diet-option-\(rawValue)"]
            for _ in 0..<5 where !option.exists {
                app.swipeUp()
            }
            XCTAssertTrue(option.waitForExistence(timeout: 10))
            option.tap()
        }
        app.buttons["save-profile-button"].tap()
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Scan"].tap()
        let field = app.textFields["manual-barcode-field"]
        field.tap()
        field.typeText("3017620690969")
        app.buttons["manual-lookup-button"].tap()
        XCTAssertTrue(app.staticTexts["product-name"].waitForExistence(timeout: 10))
        // Wait on the section heading text, not the section container's
        // identifier: see test02.
        XCTAssertTrue(app.staticTexts["Diet filters"].waitForExistence(timeout: 10))
        // Scroll the section into view: the card is a ScrollView, so a
        // swipe moves it (unlike the Lists in test04/test07). Stop as
        // soon as the heading is tappable.
        let heading = app.staticTexts["Diet filters"]
        for _ in 0..<5 where !heading.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Listed as non-vegan by Open Food Facts."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Gluten is listed in the allergens or ingredients."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No seed oils listed in the ingredients."].waitForExistence(timeout: 10))
        saveScreenshot(named: "14-diet-filters")
    }

    // MARK: - 19 History search (screenshot)

    /// History search: typing "nutella" filters the seeded history
    /// (Nutella, Coca-Cola, Kinder Bueno) down to the one Nutella row.
    /// Runs last alphabetically, so it cannot disturb the earlier shots;
    /// it only navigates within the History tab. The search field is
    /// the `.searchable` prompt "Search history", visible at rest
    /// above the list.
    func test19HistorySearch() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        let searchField = app.searchFields["Search history"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("nutella")
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Coca-Cola"].waitForExistence(timeout: 3))
        saveScreenshot(named: "15-history-search")
    }

    // MARK: - 20 History search, no match

    // Proves the "No scans match ..." empty state renders: it was
    // verified in code only when history search shipped (HistoryView
    // renders the row when filteredItems is empty). No screenshot: the
    // lane stays at 15 shots, this test asserts behaviour only.
    func test20HistorySearchNoMatch() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Nutella"].waitForExistence(timeout: 10))
        let searchField = app.searchFields["Search history"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["No scans match \"zzzz\""].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Nutella"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Coca-Cola"].waitForExistence(timeout: 3))
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
