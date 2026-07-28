import AppKit
import CoreGraphics

enum StatusWindowGeometry {
    static func matches(
        frame: CGRect,
        buttonFrame: CGRect,
        displayBounds: CGRect?
    ) -> Bool {
        guard abs(frame.height - buttonFrame.height) < 20 else { return false }
        if
            let displayBounds,
            !displayBounds.contains(CGPoint(x: frame.midX, y: frame.midY))
        {
            return false
        }

        // Hosted status windows include padding around the button, so their
        // widths need not be identical. Their horizontal centers do remain
        // tightly aligned. A center bound prevents a neighboring status item
        // (or an identically positioned item on a vertically stacked display)
        // from becoming Barr's control or parking anchor.
        let centerTolerance = max(
            10,
            min(80, (frame.width + buttonFrame.width) * 0.25)
        )
        return abs(frame.midX - buttonFrame.midX) <= centerTolerance
    }

    static func quartzDisplayBounds(for screen: NSScreen) -> CGRect? {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        guard
            let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber
        else { return nil }
        return CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
    }
}
