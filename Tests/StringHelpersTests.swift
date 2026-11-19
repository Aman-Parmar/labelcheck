import XCTest

@testable import LabelCheck

/// Shared string helpers (`trimmed` / `isBlank`), added by the 2026-11-19
/// hygiene dedupe of the `trimmingCharacters(in: .whitespacesAndNewlines)`
/// call repeated across lookup, search, display names, and profiles.
final class StringHelpersTests: XCTestCase {
    func testTrimmed() {
        XCTAssertEqual("  nutella\n".trimmed, "nutella")
        XCTAssertEqual("nutella".trimmed, "nutella")
        XCTAssertEqual("".trimmed, "")
    }

    func testIsBlank() {
        XCTAssertTrue("".isBlank)
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("\n\t".isBlank)
        XCTAssertFalse(" nutella ".isBlank)
    }

    func testCommaSeparatedListTrimsEachItem() {
        XCTAssertEqual("milk, gluten ,peanut".commaSeparatedList,
                       ["milk", "gluten", "peanut"])
    }
}
