import AppKit
import CoreGraphics

enum MenuBarMover {
    private static let targetedWindowField = CGEventField(rawValue: 0x33)!
    private static let moveLock = NSLock()

    /// Reorders a status item without leaving the user's pointer at the drag
    /// destination. WindowServer treats these events as one global mouse
    /// stream, so only one synthetic drag may be in flight at a time.
    static func move(
        windowID: CGWindowID,
        sourcePID: pid_t,
        beside anchorWindowID: CGWindowID,
        at targetPoint: CGPoint
    ) -> Bool {
        moveLock.lock()
        defer { moveLock.unlock() }

        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
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
                point: originalCursorPosition,
                windowID: windowID,
                targetPID: sourcePID,
                flags: .maskCommand
            ),
            let up = event(
                source: source,
                type: .leftMouseUp,
                point: targetPoint,
                windowID: anchorWindowID,
                targetPID: sourcePID,
                flags: []
            )
        else { return false }

        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.08)
        up.post(tap: .cghidEventTap)

        if let safetyUp = event(
            source: source,
            type: .leftMouseUp,
            point: originalCursorPosition,
            windowID: anchorWindowID,
            targetPID: sourcePID,
            flags: []
        ) {
            safetyUp.post(tap: .cghidEventTap)
        }

        // CGEventPost queues the releases in WindowServer. Restoring before
        // that queue drains lets the delayed release move the pointer back to
        // the menu bar after our restore. Make the warp the final operation.
        Thread.sleep(forTimeInterval: 0.05)
        CGWarpMouseCursorPosition(originalCursorPosition)
        return true
    }

    private static func event(
        source: CGEventSource,
        type: CGEventType,
        point: CGPoint,
        windowID: CGWindowID,
        targetPID: pid_t,
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
