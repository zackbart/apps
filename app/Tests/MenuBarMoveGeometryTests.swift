import CoreGraphics
import XCTest

@testable import Barr

final class MenuBarMoveGeometryTests: XCTestCase {
    func testMoveTargetIsImmediatelyOutsideLeadingEdge() {
        let anchor = CGRect(x: 320, y: 0, width: 24, height: 30)

        XCTAssertEqual(
            MenuBarMoveGeometry.pointImmediatelyLeft(of: anchor),
            CGPoint(x: 319, y: 15)
        )
    }

    func testMoveTargetNeverFallsInsideExpandedAnchor() {
        let anchor = CGRect(x: 8, y: 0, width: 1_200, height: 30)
        let target = MenuBarMoveGeometry.pointImmediatelyLeft(of: anchor)

        XCTAssertLessThan(target.x, anchor.minX)
        XCTAssertEqual(target.y, anchor.midY)
    }

    func testExpandedAnchorIsShortenedToExposeInsertionPoint() {
        let length = MenuBarMoveGeometry.preparedAnchorLength(
            currentLength: 1_216,
            anchorFrame: CGRect(x: -8, y: 0, width: 1_216, height: 30),
            screenFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
            collapsedLength: 2
        )

        XCTAssertEqual(length, 1_200)
    }

    func testVisibleAnchorNeedsNoPreparation() {
        XCTAssertNil(
            MenuBarMoveGeometry.preparedAnchorLength(
                currentLength: 24,
                anchorFrame: CGRect(x: 32, y: 0, width: 24, height: 30),
                screenFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
                collapsedLength: 2
            )
        )
    }
}
