import CoreGraphics

enum MenuBarMoveGeometry {
    /// WindowServer inserts a status item on the side of the destination point.
    /// A point inside the anchor can be normalized to either edge, so always
    /// request the point immediately to its left.
    static func pointImmediatelyLeft(of anchorFrame: CGRect) -> CGPoint {
        CGPoint(x: anchorFrame.minX - 1, y: anchorFrame.midY)
    }

    static func preparedAnchorLength(
        currentLength: CGFloat,
        anchorFrame: CGRect,
        screenFrame: CGRect,
        collapsedLength: CGFloat
    ) -> CGFloat? {
        let insertionX = screenFrame.minX + 8
        guard anchorFrame.minX < insertionX else { return nil }
        return max(
            collapsedLength,
            currentLength - (insertionX - anchorFrame.minX)
        )
    }
}
