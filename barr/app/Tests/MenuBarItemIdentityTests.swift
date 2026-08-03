import XCTest

@testable import Barr

final class MenuBarItemIdentityTests: XCTestCase {
    func testKeepsUniqueIdentifiersUnchanged() {
        XCTAssertEqual(
            MenuBarItemIdentity.disambiguatedStableIdentifiers(
                rawIdentifiers: ["primary", nil],
                titles: ["One", "Secondary"]
            ),
            ["primary", "Secondary"]
        )
    }

    func testDisambiguatesDuplicateTitles() {
        XCTAssertEqual(
            MenuBarItemIdentity.disambiguatedStableIdentifiers(
                rawIdentifiers: [nil, nil],
                titles: ["Status", "Status"]
            ),
            ["Status#1", "Status#2"]
        )
    }

    func testDisambiguatesUnnamedItems() {
        XCTAssertEqual(
            MenuBarItemIdentity.disambiguatedStableIdentifiers(
                rawIdentifiers: [nil, "  ", nil],
                titles: ["", nil, "   "]
            ),
            [
                "barr-unnamed-item-1",
                "barr-unnamed-item-2",
                "barr-unnamed-item-3"
            ]
        )
    }
}
