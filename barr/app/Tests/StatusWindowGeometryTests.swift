import CoreGraphics
import XCTest

@testable import Barr

final class StatusWindowGeometryTests: XCTestCase {
    func testAcceptsHostedPaddingAroundSameButtonCenter() {
        XCTAssertTrue(
            StatusWindowGeometry.matches(
                frame: CGRect(x: 1_300, y: 0, width: 18, height: 30),
                buttonFrame: CGRect(x: 1_308, y: 1_050, width: 2, height: 30),
                displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
            )
        )
    }

    func testRejectsNeighboringStatusItem() {
        XCTAssertFalse(
            StatusWindowGeometry.matches(
                frame: CGRect(x: 1_321, y: 0, width: 38, height: 30),
                buttonFrame: CGRect(x: 1_308, y: 1_050, width: 2, height: 30),
                displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
            )
        )
    }

    func testRejectsMatchingHorizontalPositionOnAnotherDisplay() {
        XCTAssertFalse(
            StatusWindowGeometry.matches(
                frame: CGRect(x: 1_300, y: -1_080, width: 18, height: 30),
                buttonFrame: CGRect(x: 1_308, y: 1_050, width: 2, height: 30),
                displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
            )
        )
    }

    func testAcceptsExpandedParkingAnchor() {
        XCTAssertTrue(
            StatusWindowGeometry.matches(
                frame: CGRect(x: -8, y: 0, width: 1_329, height: 30),
                buttonFrame: CGRect(x: 0, y: 1_050, width: 1_305, height: 30),
                displayBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
            )
        )
    }
}
