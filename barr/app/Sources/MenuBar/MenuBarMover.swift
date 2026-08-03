import AppKit
import CoreGraphics

enum MenuBarMover {
    private static let targetedWindowField = CGEventField(rawValue: 0x33)
    private static let offscreenStartPoint = CGPoint(x: 20_000, y: 20_000)
    private static let moveLock = NSLock()

    /// Reorders a status item with the WindowServer-routed event sequence used
    /// by established menu-bar managers. The offscreen mouse-down is
    /// intentional: on Tahoe, using the user's current cursor position makes
    /// the result depend on where the pointer happens to be.
    static func move(
        windowID: CGWindowID,
        sourcePID: pid_t,
        beside anchorWindowID: CGWindowID,
        at targetPoint: CGPoint
    ) -> Bool {
        moveLock.lock()
        defer { moveLock.unlock() }

        guard let targetedWindowField else { return false }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        guard let originalCursorPosition = CGEvent(source: nil)?.location else { return false }
        let permitted: CGEventFilterMask = [
            .permitLocalMouseEvents,
            .permitLocalKeyboardEvents,
            .permitSystemDefinedEvents
        ]
        source.setLocalEventsFilterDuringSuppressionState(permitted, state: .eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(permitted, state: .eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval = 0

        guard
            let down = event(
                source: source,
                type: .leftMouseDown,
                point: offscreenStartPoint,
                windowID: windowID,
                targetPID: sourcePID,
                targetedWindowField: targetedWindowField,
                flags: .maskCommand
            ),
            let up = event(
                source: source,
                type: .leftMouseUp,
                point: targetPoint,
                windowID: anchorWindowID,
                targetPID: sourcePID,
                targetedWindowField: targetedWindowField,
                flags: []
            )
        else { return false }

        let cursorDisplay = display(containing: originalCursorPosition)
        let cursorWasHidden =
            CGDisplayHideCursor(cursorDisplay) == .success
        defer {
            // CGEventPost queues the release in WindowServer. Restore only
            // after that queue has drained, then balance the cursor hide even
            // if a future early return is added above.
            Thread.sleep(forTimeInterval: 0.06)
            CGWarpMouseCursorPosition(originalCursorPosition)
            if cursorWasHidden {
                CGDisplayShowCursor(cursorDisplay)
            }
        }

        down.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: 0.08)
        up.post(tap: .cgSessionEventTap)
        return true
    }

    private static func display(containing point: CGPoint) -> CGDirectDisplayID {
        var displayID = CGMainDisplayID()
        var count: UInt32 = 0
        guard
            CGGetDisplaysWithPoint(point, 1, &displayID, &count) == .success,
            count > 0
        else {
            return CGMainDisplayID()
        }
        return displayID
    }

    private static func event(
        source: CGEventSource,
        type: CGEventType,
        point: CGPoint,
        windowID: CGWindowID,
        targetPID: pid_t,
        targetedWindowField: CGEventField,
        flags: CGEventFlags
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return nil }

        event.flags = flags
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(targetPID))
        event.setIntegerValueField(.eventSourceUserData, value: Int64(truncatingIfNeeded: UInt64(mach_absolute_time())))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        event.setIntegerValueField(targetedWindowField, value: Int64(windowID))
        return event
    }
}
