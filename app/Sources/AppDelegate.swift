import AppKit
import ApplicationServices
import OSLog

private let barrMembershipLogger = Logger(
    subsystem: "com.cursorkittens.Barr",
    category: "Membership"
)
private let barrActivationLogger = Logger(
    subsystem: "com.cursorkittens.Barr",
    category: "Activation"
)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = ShelfModel()
    private var statusItem: NSStatusItem!
    private var storageAnchor: NSStatusItem!
    private var shelfPanel: ShelfPanel!
    private var returnMonitor: Any?
    private var returnFallback: DispatchWorkItem?
    private var pendingReturn: (() -> Void)?
    private var shelfGlobalDismissMonitor: Any?
    private var shelfLocalDismissMonitor: Any?
    private var storageUpdateGeneration = 0
    private var handledInitialRefresh = false
    private var startupReconciliationComplete = false
    private var startupShelfRequested = false
    private var persistedItemReconciliationInProgress = false
    private var runningApplicationsGeneration = 0
    private var environmentRefreshGeneration = 0
    private var foregroundBundleIdentifier: String?
    private var stableStorageLength: CGFloat?
    private var resolvedStatusWindowIDs = [String: CGWindowID]()
    private let collapsedStorageLength: CGFloat = 2

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Construct the SwiftUI host and let its initial layout finish before
        // macOS begins laying out the Control Center-hosted status-item scenes.
        // Interleaving those two layout passes re-enters AppKit on macOS 26.
        if model.movedItemKeys.isEmpty {
            model.setManaging(true)
        }
        shelfPanel = ShelfPanel(model: model)
        DispatchQueue.main.async { [weak self] in
            self?.finishApplicationLaunch()
        }
    }

    private func finishApplicationLaunch() {
        configureStatusItems()
        foregroundBundleIdentifier =
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        startupReconciliationComplete = model.movedItemKeys.isEmpty
        model.onItemsChanged = { [weak self] in
            self?.itemsChanged()
        }
        model.onLayoutChanged = { [weak self] in
            self?.shelfPanel.scheduleResizeToFit()
        }
        model.onRefreshCompleted = { [weak self] in
            self?.refreshCompleted()
        }
        model.onActivate = { [weak self] item in
            self?.activateFromShelf(item)
        }
        model.onRestart = { [weak self] in
            self?.restartApplication()
        }
        model.onMembershipChange = { [weak self] item, moveToBarr, completion in
            self?.changeMembership(of: item, moveToBarr: moveToBarr, completion: completion)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(environmentChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(runningApplicationsChanged),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(runningApplicationsChanged),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(foregroundApplicationChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.refreshScannerExclusions()
            self?.model.refresh()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.requestStartupShelf()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        returnHiddenItemNow()
        removeShelfDismissMonitors()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard statusItem != nil else { return true }
        // Reopening an accessory app leaves Finder (or the launcher) in the
        // foreground. Its activation notification can arrive after this
        // delegate callback and close a shelf that was just shown. Let that
        // notification settle before presenting the drawer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.showShelf()
        }
        return true
    }

    private func itemsChanged() {
        shelfPanel.scheduleResizeToFit()
        if startupReconciliationComplete {
            updateStorageState()
        } else {
            storageAnchor.length = collapsedStorageLength
            refreshScannerExclusions()
        }
    }

    private func refreshCompleted() {
        if !handledInitialRefresh {
            handledInitialRefresh = true
        }

        if startupReconciliationComplete {
            updateStorageState()
            reconcileNewlyVisiblePersistedItems()
            presentStartupShelfIfReady()
            return
        }

        // Keep the parking boundary collapsed until Accessibility becomes
        // available. The permissions UI must still be reachable, and the next
        // successful permission refresh will resume restoration automatically.
        guard PermissionCenter.isAccessibilityGranted else {
            presentStartupShelfIfReady()
            return
        }
        restorePersistedItemsAfterLaunch()
    }

    private func restorePersistedItemsAfterLaunch() {
        guard !persistedItemReconciliationInProgress else { return }
        persistedItemReconciliationInProgress = true
        storageAnchor.length = collapsedStorageLength
        refreshScannerExclusions()

        guard
            PermissionCenter.isAccessibilityGranted,
            let anchorWindowID = windowID(for: storageAnchor)
        else {
            persistedItemReconciliationInProgress = false
            finishStartupReconciliation()
            return
        }

        let persistedItems = model.barrItems.filter(\.isMovableByBarr)
        guard !persistedItems.isEmpty else {
            persistedItemReconciliationInProgress = false
            finishStartupReconciliation()
            return
        }

        reconcile(
            persistedItems,
            beside: anchorWindowID
        ) { [weak self] _ in
            guard let self else { return }
            self.persistedItemReconciliationInProgress = false
            self.finishStartupReconciliation()
        }
    }

    private func finishStartupReconciliation() {
        startupReconciliationComplete = true
        model.refresh(captureImages: false)
        updateStorageState()
        presentStartupShelfIfReady()
    }

    private func reconcileNewlyVisiblePersistedItems() {
        guard
            !persistedItemReconciliationInProgress,
            PermissionCenter.isAccessibilityGranted,
            let anchorWindowID = windowID(for: storageAnchor)
        else { return }

        let anchorFrame = PrivateWindowServer.frame(of: anchorWindowID)
        let liveWindowIDs = Set(PrivateWindowServer.menuBarWindowIDs())
        let visiblePersistedItems = model.barrItems.filter { item in
            item.isMovableByBarr &&
                liveWindowIDs.contains(item.windowID) &&
                anchorFrame.map { anchor in item.frame.midX >= anchor.midX } == true
        }
        guard !visiblePersistedItems.isEmpty else { return }

        persistedItemReconciliationInProgress = true
        reconcile(
            visiblePersistedItems,
            beside: anchorWindowID
        ) { [weak self] movedAnyItem in
            guard let self else { return }
            self.persistedItemReconciliationInProgress = false
            if movedAnyItem {
                self.model.refresh(captureImages: self.shelfPanel?.isVisible == true)
            }
        }
    }

    private func reconcile(
        _ persistedItems: [MenuBarItem],
        beside anchorWindowID: CGWindowID,
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var movedAnyItem = false
            for persistedItem in persistedItems {
                for attempt in 0..<2 {
                    let scannedItems = MenuBarScanner.scan(captureImages: false)
                    guard let currentItem = scannedItems.first(where: {
                        $0.storageKey == persistedItem.storageKey
                    }) else {
                        break
                    }

                    let liveWindowIDs = Set(PrivateWindowServer.menuBarWindowIDs())
                    guard
                        liveWindowIDs.contains(currentItem.windowID),
                        let anchorFrame = PrivateWindowServer.frame(of: anchorWindowID),
                        currentItem.frame.midX >= anchorFrame.midX
                    else {
                        break
                    }

                    let targetPoint = self.parkingTarget(in: anchorFrame)
                    guard MenuBarMover.move(
                        windowID: currentItem.windowID,
                        sourcePID: currentItem.ownerPID,
                        beside: anchorWindowID,
                        at: targetPoint
                    ) else {
                        continue
                    }

                    Thread.sleep(forTimeInterval: attempt == 0 ? 0.14 : 0.22)
                    let refreshedItem = MenuBarScanner.scan(captureImages: false).first {
                        $0.storageKey == persistedItem.storageKey
                    }
                    let refreshedLiveIDs = Set(PrivateWindowServer.menuBarWindowIDs())
                    let refreshedAnchorFrame =
                        PrivateWindowServer.frame(of: anchorWindowID) ?? anchorFrame
                    let isParked = refreshedItem.map {
                        !refreshedLiveIDs.contains($0.windowID) ||
                            $0.frame.midX < refreshedAnchorFrame.midX
                    } ?? !refreshedLiveIDs.contains(currentItem.windowID)
                    if isParked {
                        movedAnyItem = true
                        break
                    }
                }
            }

            DispatchQueue.main.async {
                completion(movedAnyItem)
            }
        }
    }

    private func requestStartupShelf() {
        startupShelfRequested = true
        presentStartupShelfIfReady()
    }

    private func presentStartupShelfIfReady() {
        guard
            startupShelfRequested,
            handledInitialRefresh,
            startupReconciliationComplete || !PermissionCenter.isAccessibilityGranted
        else { return }
        startupShelfRequested = false
        showShelf(refreshItems: false)
    }

    private func activateFromShelf(_ item: MenuBarItem) {
        returnHiddenItemNow()
        closeShelf()

        // Most status items expose AXPress even while their hosted window is
        // parked offscreen. Prefer that path because it opens the app's menu
        // without reordering a single menu-bar window. Synthetic reveal/repark
        // remains below for unusual items that do not expose a press action.
        if MenuBarActivator.activate(item) {
#if DEBUG
            barrActivationLogger.notice(
                "Activation target=\(item.storageKey, privacy: .public) direct=true activated=true"
            )
#endif
            model.activationFailed = false
            return
        }

        guard
            let controlWindowID = windowID(for: statusItem),
            let controlFrame = PrivateWindowServer.frame(of: controlWindowID)
        else {
            model.activationFailed = true
            return
        }

        let revealPoint = CGPoint(x: controlFrame.minX - 1, y: controlFrame.midY)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scannedItems = MenuBarScanner.scan(captureImages: false)
            let currentItem =
                scannedItems.first { $0.windowID == item.windowID } ??
                scannedItems.first { $0.storageKey == item.storageKey } ??
                item
            let moved = MenuBarMover.move(
                windowID: currentItem.windowID,
                sourcePID: currentItem.ownerPID,
                beside: controlWindowID,
                at: revealPoint
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                guard let self else { return }
                let revealedCandidates = MenuBarScanner.scan(captureImages: false).filter {
                    $0.storageKey == item.storageKey
                }
                let revealedItem =
                    revealedCandidates.min {
                        abs($0.frame.midX - revealPoint.x) <
                            abs($1.frame.midX - revealPoint.x)
                    } ??
                    currentItem
                let activated = moved && MenuBarActivator.activate(revealedItem)
#if DEBUG
                barrActivationLogger.notice(
                    """
                    Activation target=\(item.storageKey, privacy: .public) \
                    moved=\(moved) activated=\(activated) \
                    revealedWindow=\(revealedItem.windowID)
                    """
                )
#endif
                self.model.activationFailed = !activated
                guard moved else {
                    self.showShelf()
                    return
                }
                if activated {
                    // Carry the exact Control Center proxy that was revealed.
                    // Multiple proxy windows can share an app identity, and
                    // falling back to the first storage-key match can re-park
                    // a stale proxy while leaving the live icon visible.
                    self.armReturn(item: revealedItem)
                } else {
                    self.parkItem(revealedItem)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showShelf()
                    }
                }
            }
        }
    }

    private func armReturn(item: MenuBarItem) {
        pendingReturn = { [weak self] in self?.parkItem(item) }

        returnMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.returnHiddenItemNow()
            }
        }

        let fallback = DispatchWorkItem { [weak self] in self?.returnHiddenItemNow() }
        returnFallback = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: fallback)
    }

    private func parkItem(
        _ originalItem: MenuBarItem,
        attempt: Int = 0,
        anchorPrepared: Bool = false
    ) {
        guard
            let initialAnchorWindowID = windowID(for: storageAnchor),
            let initialAnchorFrame = PrivateWindowServer.frame(of: initialAnchorWindowID),
            let anchorScreen = storageAnchor.button?.window?.screen ?? NSScreen.main
        else {
            retryParking(originalItem, attempt: attempt)
            return
        }

        let insertionX = anchorScreen.frame.minX + 8
        if !anchorPrepared, initialAnchorFrame.minX < insertionX {
            // WindowServer will not accept a drop beside the off-display edge
            // of an expanded spacer. Shorten it only enough to expose a valid
            // insertion point. Keeping almost all of its width prevents it
            // from crossing neighboring status items and changing its order.
            let amountToExpose = insertionX - initialAnchorFrame.minX
            let preparedLength = max(
                collapsedStorageLength,
                storageAnchor.length - amountToExpose
            )
            storageUpdateGeneration += 1
            storageAnchor.length = preparedLength
            refreshScannerExclusions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.parkItem(
                    originalItem,
                    attempt: attempt,
                    anchorPrepared: true
                )
            }
            return
        }

        guard
            let anchorWindowID = windowID(for: storageAnchor),
            let anchorFrame = PrivateWindowServer.frame(of: anchorWindowID)
        else {
            retryParking(originalItem, attempt: attempt)
            return
        }

        let targetPoint = parkingTarget(in: anchorFrame)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scannedItems = MenuBarScanner.scan(captureImages: false)
            let currentItem =
                scannedItems.first { $0.windowID == originalItem.windowID } ??
                scannedItems.first { $0.storageKey == originalItem.storageKey } ??
                originalItem
#if DEBUG
            barrActivationLogger.notice(
                """
                Park start target=\(originalItem.storageKey, privacy: .public) \
                preferredWindow=\(originalItem.windowID) currentWindow=\(currentItem.windowID) \
                targetPoint=\(NSStringFromPoint(targetPoint), privacy: .public)
                """
            )
#endif
            let attempted = MenuBarMover.move(
                windowID: currentItem.windowID,
                sourcePID: currentItem.ownerPID,
                beside: anchorWindowID,
                at: targetPoint
            )

            var parkedItem: MenuBarItem?
            var parked = false
            if attempted {
                for delay in [0.18, 0.32, 0.5] where !parked {
                    Thread.sleep(forTimeInterval: delay)
                    let parkedCandidates = MenuBarScanner.scan(captureImages: false).filter {
                        $0.storageKey == originalItem.storageKey
                    }
                    parkedItem = parkedCandidates.min {
                        abs($0.frame.midX - targetPoint.x) <
                            abs($1.frame.midX - targetPoint.x)
                    }
                    parked = parkedItem.map {
                        $0.frame.midX < anchorFrame.midX
                    } == true
                }
            }
#if DEBUG
            barrActivationLogger.notice(
                """
                Park result target=\(originalItem.storageKey, privacy: .public) \
                attempted=\(attempted) parked=\(parked) \
                observedWindow=\(parkedItem?.windowID ?? 0) \
                observedFrame=\(parkedItem.map { NSStringFromRect($0.frame) } ?? "none", privacy: .public)
                """
            )
#endif

            DispatchQueue.main.async {
                guard let self else { return }
                if parked {
                    self.updateStorageState()
                    self.model.refresh(captureImages: false)
                } else {
                    self.retryParking(originalItem, attempt: attempt)
                }
            }
        }
    }

    private func retryParking(_ item: MenuBarItem, attempt: Int) {
        guard attempt < 1 else {
            model.refresh(captureImages: false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.parkItem(item, attempt: attempt + 1)
        }
    }

    private func returnHiddenItemNow() {
        if let returnMonitor {
            NSEvent.removeMonitor(returnMonitor)
            self.returnMonitor = nil
        }
        returnFallback?.cancel()
        returnFallback = nil
        let action = pendingReturn
        pendingReturn = nil
        action?()
    }

    private func restartApplication() {
        let bundlePath = Bundle.main.bundlePath
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = [
            "-c",
            "sleep 0.8; /usr/bin/open -n \"$1\"",
            "barr-relauncher",
            bundlePath
        ]

        do {
            try relauncher.run()
            NSApp.terminate(nil)
        } catch {
            NSSound.beep()
        }
    }

    private func changeMembership(
        of item: MenuBarItem,
        moveToBarr: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        guard PermissionCenter.isAccessibilityGranted else {
            PermissionCenter.requestAccessibility()
            completion(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            self.refreshScannerExclusions()
            guard let (anchorWindowID, anchorFrame) = self.membershipAnchor(
                for: item,
                moveToBarr: moveToBarr
            ) else {
#if DEBUG
                barrMembershipLogger.notice(
                    "Move has no anchor target=\(item.storageKey, privacy: .public)"
                )
#endif
                completion(false)
                self.updateStorageState()
                return
            }

#if DEBUG
            barrMembershipLogger.notice(
                """
                Move start direction=\(moveToBarr ? "into-barr" : "to-menu-bar", privacy: .public) \
                target=\(item.storageKey, privacy: .public) window=\(item.windowID) \
                anchor=\(anchorWindowID) frame=\(NSStringFromRect(anchorFrame), privacy: .public)
                """
            )
#endif
            let targetPoint = moveToBarr
                ? parkingTarget(in: anchorFrame)
                : CGPoint(x: anchorFrame.minX - 1, y: anchorFrame.midY)
            DispatchQueue.global(qos: .userInitiated).async {
                let baselineItems = MenuBarScanner.scan(captureImages: false)
                let baselineSystemKeys = Set(
                    baselineItems
                        .filter { $0.isSystemItem && $0.storageKey != item.storageKey }
                        .map(\.storageKey)
                )
                var moved = false
                var lastScan = baselineItems
                for attempt in 0..<2 where !moved {
                    let currentItem = lastScan.first {
                        $0.storageKey == item.storageKey
                    } ?? (attempt == 0 ? item : nil)
                    guard let currentItem else { break }

#if DEBUG
                    barrMembershipLogger.notice(
                        """
                        Move attempt=\(attempt) target=\(currentItem.storageKey, privacy: .public) \
                        window=\(currentItem.windowID) sourceFrame=\(NSStringFromRect(currentItem.frame), privacy: .public) \
                        targetPoint=\(NSStringFromPoint(targetPoint), privacy: .public)
                        """
                    )
#endif
                    let attempted = MenuBarMover.move(
                        windowID: currentItem.windowID,
                        sourcePID: currentItem.ownerPID,
                        beside: anchorWindowID,
                        at: targetPoint
                    )
                    guard attempted else { continue }

                    var targetWasObserved = false
                    for delay in [0.08, 0.14, 0.22] where !moved {
                        Thread.sleep(forTimeInterval: delay)
                        lastScan = MenuBarScanner.scan(captureImages: false)
                        let liveMenuBarWindowIDs = Set(PrivateWindowServer.menuBarWindowIDs())
                        let verificationAnchorFrame =
                            PrivateWindowServer.frame(of: anchorWindowID) ?? anchorFrame
                        let movedItem = lastScan.first {
                            $0.storageKey == item.storageKey
                        }
#if DEBUG
                        barrMembershipLogger.notice(
                            """
                            Move poll delay=\(delay) targetSeen=\(movedItem != nil) \
                            observedWindow=\(movedItem?.windowID ?? 0) \
                            observedFrame=\(movedItem.map { NSStringFromRect($0.frame) } ?? "none", privacy: .public) \
                            observedLive=\(movedItem.map { liveMenuBarWindowIDs.contains($0.windowID) } ?? false) \
                            sourceLive=\(liveMenuBarWindowIDs.contains(currentItem.windowID)) \
                            liveAnchorFrame=\(NSStringFromRect(verificationAnchorFrame), privacy: .public)
                            """
                        )
#endif
                        targetWasObserved = targetWasObserved || movedItem != nil
                        moved = moveToBarr
                            ? movedItem.map {
                                !liveMenuBarWindowIDs.contains($0.windowID) ||
                                    $0.frame.midX < verificationAnchorFrame.midX
                            } ?? !liveMenuBarWindowIDs.contains(currentItem.windowID)
                            : movedItem.map {
                                liveMenuBarWindowIDs.contains($0.windowID)
                            } == true
                    }

                    // If the scanner lost the target entirely, another drag
                    // could act on a stale/reused window ID and disturb a
                    // neighboring system item. Let a later refresh reconcile it.
                    if !targetWasObserved && !moved {
                        break
                    }
                }

#if DEBUG
                barrMembershipLogger.notice(
                    """
                    Move result target=\(item.storageKey, privacy: .public) \
                    success=\(moved) observedItems=\(lastScan.count)
                    """
                )
                if moved && !baselineSystemKeys.isEmpty {
                    let presentKeys = Set(
                        MenuBarScanner.scan(captureImages: false).map(\.storageKey)
                    )
                    let missingKeys = baselineSystemKeys.subtracting(presentKeys)
                    if !missingKeys.isEmpty {
                        print("[Barr] System items missing after move: \(missingKeys.sorted())")
                    }
                }
#endif

                DispatchQueue.main.async {
                    completion(moved)
                    self.model.refresh()
                }
            }
        }
    }

    private func updateStorageState() {
        guard storageAnchor != nil else { return }
        storageUpdateGeneration += 1
        let generation = storageUpdateGeneration
        let keepShelfOpen = shelfPanel?.isVisible == true

        guard model.hasVisiblePersistedBarrItems else {
            stableStorageLength = nil
            if abs(storageAnchor.length - collapsedStorageLength) > 0.5 {
                storageAnchor.length = collapsedStorageLength
                refreshScannerExclusions()
            }
            repositionShelfIfNeeded(keepOpen: keepShelfOpen)
            return
        }

        configureStableStorage(
            generation: generation,
            keepShelfOpen: keepShelfOpen
        )
    }

    private func configureStableStorage(
        generation: Int,
        keepShelfOpen: Bool
    ) {
        if let stableStorageLength {
            if abs(storageAnchor.length - stableStorageLength) > 1 {
                storageAnchor.length = stableStorageLength
                refreshScannerExclusions()
            }
            repositionShelfIfNeeded(keepOpen: keepShelfOpen)
            return
        }

        // Size the parking lane once per display environment. Recomputing it
        // from every transient frame is the feedback loop that made the menu
        // bar walk and blink.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard
                let self,
                generation == self.storageUpdateGeneration,
                let windowID = self.windowID(for: self.storageAnchor),
                let anchorFrame = PrivateWindowServer.frame(of: windowID),
                let screen = self.storageAnchor.button?.window?.screen ?? NSScreen.main
            else { return }

            let length = min(
                max(
                    self.collapsedStorageLength,
                    anchorFrame.maxX - screen.frame.minX + 64
                ),
                screen.frame.width + 8
            )
            self.stableStorageLength = length
            if abs(self.storageAnchor.length - length) > 1 {
                self.storageAnchor.length = length
                self.refreshScannerExclusions()
            }
            self.repositionShelfIfNeeded(keepOpen: keepShelfOpen)
        }
    }

    nonisolated private func parkingTarget(in anchorFrame: CGRect) -> CGPoint {
        // The event is explicitly targeted at the anchor window. Keep the
        // release inside its leading half: releasing just outside a narrow
        // status item can be normalized to its trailing edge, which leaves the
        // item on the visible side of the parking boundary.
        CGPoint(
            x: anchorFrame.minX + min(1, anchorFrame.width / 4),
            y: anchorFrame.midY
        )
    }

    private func repositionShelfIfNeeded(keepOpen: Bool) {
        guard keepOpen, let button = statusItem.button else { return }
        shelfPanel.show(relativeTo: button)
    }

    private func configureStatusItems() {
        // AppKit updates this preference whenever neighboring status items are
        // reordered. That can strand Barr beneath the notch on the next launch,
        // leaving its panel visible with no reachable control. Barr is the
        // gateway to every parked item, so restore it to the highest visible
        // status-item priority every time the process starts.
        setPreferredPosition(0, autosaveName: "BarrControl", force: true)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "BarrControl"
#if DEBUG
        statusItem.button?.image = NSImage(
            systemSymbolName: "ladybug.fill",
            accessibilityDescription: "Barr debug build"
        )
        statusItem.button?.title = " DEBUG"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .systemFont(ofSize: 10, weight: .bold)
        statusItem.button?.toolTip = "Barr — Debug Build"
#else
        statusItem.button?.image = NSImage(
            systemSymbolName: "line.3.horizontal",
            accessibilityDescription: "Barr overflow shelf"
        )
        statusItem.button?.toolTip = "Barr"
#endif
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemPressed(_:))
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseUp])

        // A far-left parking boundary. It remains zero-width until at least one
        // explicitly selected item has been moved to its left.
        setPreferredPosition(1_000_000_000, autosaveName: "BarrStorageAnchor", force: true)
        storageAnchor = NSStatusBar.system.statusItem(withLength: collapsedStorageLength)
        storageAnchor.autosaveName = "BarrStorageAnchor"
        if let storageButton = storageAnchor.button {
            storageButton.image = nil
            storageButton.title = ""
            storageButton.toolTip = nil
            storageButton.isEnabled = false
            storageButton.alphaValue = 0
            storageButton.setAccessibilityElement(false)
        }
    }

    private func membershipAnchor(
        for item: MenuBarItem,
        moveToBarr: Bool
    ) -> (CGWindowID, CGRect)? {
        if moveToBarr {
            guard
                let windowID = windowID(for: storageAnchor),
                let frame = PrivateWindowServer.frame(of: windowID)
            else { return nil }
            return (windowID, frame)
        }

        if
            let neighbor = model.returnAnchor(for: item),
            PrivateWindowServer.menuBarWindowIDs().contains(neighbor.windowID),
            let frame = PrivateWindowServer.frame(of: neighbor.windowID)
        {
            return (neighbor.windowID, frame)
        }

        if
            let windowID = windowID(for: statusItem),
            let frame = PrivateWindowServer.frame(of: windowID)
        {
            return (windowID, frame)
        }

        guard
            let windowID = windowID(for: storageAnchor),
            let frame = PrivateWindowServer.frame(of: windowID)
        else { return nil }
        return (windowID, frame)
    }

    private func refreshScannerExclusions() {
        let windowIDs = [windowID(for: statusItem), windowID(for: storageAnchor)]
            .compactMap { $0 }
        MenuBarScanner.setExcludedWindowIDs(Set(windowIDs))
    }

    private func setPreferredPosition(
        _ position: CGFloat,
        autosaveName: String,
        force: Bool = false
    ) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        if force || UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(position, forKey: key)
        }
    }

    private func windowID(for item: NSStatusItem?) -> CGWindowID? {
        guard
            let item,
            let button = item.button,
            let window = button.window
        else { return nil }

        let number = window.windowNumber
        if
            number > 0,
            let windowID = CGWindowID(exactly: number),
            PrivateWindowServer.frame(of: windowID) != nil
        {
            if let autosaveName = item.autosaveName {
                resolvedStatusWindowIDs[autosaveName] = windowID
            }
            return windowID
        }

        // Tahoe hosts status items in another process, so NSWindow.windowNumber
        // can be -1. Resolve our item from its geometry on the display that
        // actually hosts the AppKit status button.
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let displayBounds = (window.screen ?? NSScreen.main).flatMap(
            StatusWindowGeometry.quartzDisplayBounds
        )
        let liveWindowIDs = PrivateWindowServer.menuBarWindowIDs()

        if
            let autosaveName = item.autosaveName,
            let cachedWindowID = resolvedStatusWindowIDs[autosaveName],
            liveWindowIDs.contains(cachedWindowID),
            let cachedFrame = PrivateWindowServer.frame(of: cachedWindowID),
            StatusWindowGeometry.matches(
                frame: cachedFrame,
                buttonFrame: buttonFrame,
                displayBounds: displayBounds
            )
        {
            return cachedWindowID
        }

        let match = liveWindowIDs
            .compactMap { windowID -> (CGWindowID, CGFloat)? in
                guard
                    let frame = PrivateWindowServer.frame(of: windowID),
                    frame.width > 0,
                    StatusWindowGeometry.matches(
                        frame: frame,
                        buttonFrame: buttonFrame,
                        displayBounds: displayBounds
                    )
                else {
                    return nil
                }
                let score =
                    abs(frame.midX - buttonFrame.midX) +
                    abs(frame.width - buttonFrame.width) * 0.5
                return (windowID, score)
            }
            .min { $0.1 < $1.1 }?
            .0

        if let autosaveName = item.autosaveName {
            resolvedStatusWindowIDs[autosaveName] = match
        }
        return match
    }

    @objc private func statusItemPressed(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            toggleShelf()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            toggleShelf()
        }
    }

    private func toggleShelf() {
        shelfPanel.isVisible ? closeShelf() : showShelf()
    }

    private func showShelf(attempt: Int = 0, refreshItems: Bool = true) {
        if attempt == 0, refreshItems {
            refreshScannerExclusions()
            model.refreshLoginItemStatus()
            model.refresh()
        }
        guard let button = statusItem.button, button.window != nil else {
            retryShowingShelf(after: attempt)
            return
        }
        if shelfPanel.show(relativeTo: button) {
            installShelfDismissMonitors()
        } else {
            removeShelfDismissMonitors()
            retryShowingShelf(after: attempt)
        }
    }

    private func retryShowingShelf(after attempt: Int) {
        guard attempt < 10 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showShelf(attempt: attempt + 1, refreshItems: false)
        }
    }

    private func closeShelf() {
        shelfPanel?.close()
        removeShelfDismissMonitors()
    }

    private func installShelfDismissMonitors() {
        removeShelfDismissMonitors()
        shelfGlobalDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closeShelf()
            }
        }
        shelfLocalDismissMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.closeShelf()
            } else if
                event.type != .keyDown,
                event.window !== self.shelfPanel,
                event.window !== self.statusItem.button?.window
            {
                self.closeShelf()
            }
            return event
        }
    }

    private func removeShelfDismissMonitors() {
        if let shelfGlobalDismissMonitor {
            NSEvent.removeMonitor(shelfGlobalDismissMonitor)
            self.shelfGlobalDismissMonitor = nil
        }
        if let shelfLocalDismissMonitor {
            NSEvent.removeMonitor(shelfLocalDismissMonitor)
            self.shelfLocalDismissMonitor = nil
        }
    }

    private func showContextMenu() {
        model.refreshLoginItemStatus()
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh icons", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        let openAtLoginItem = menu.addItem(
            withTitle: "Open at Login",
            action: #selector(toggleOpenAtLogin),
            keyEquivalent: ""
        )
        openAtLoginItem.target = self
        openAtLoginItem.state = model.opensAtLogin ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Screen Recording settings…", action: #selector(openScreenRecordingSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Accessibility settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Barr", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func environmentChanged(_ notification: Notification) {
        returnHiddenItemNow()
        closeShelf()
        resolvedStatusWindowIDs.removeAll()

        // Moving between Spaces does not change the storage geometry. Reusing
        // the captured length avoids a needless collapse/expand flash. A real
        // display topology change already rebuilds the system menu bar, so
        // reset to the narrow boundary and capture one new stable length after
        // that transition settles.
        if notification.name == NSApplication.didChangeScreenParametersNotification {
            stableStorageLength = nil
            storageUpdateGeneration += 1
            storageAnchor.length = collapsedStorageLength
            refreshScannerExclusions()
        }
        scheduleEnvironmentRefresh(delays: [0.15, 0.65])
    }

    @objc private func foregroundApplicationChanged(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        let bundleIdentifier = application?.bundleIdentifier
        switch application?.bundleIdentifier {
        case "com.cursorkittens.Barr", "com.cursorkittens.Barr.debug":
            return
        default:
            break
        }

        guard bundleIdentifier != foregroundBundleIdentifier else { return }
        foregroundBundleIdentifier = bundleIdentifier

        // The foreground app controls the width of the native application-menu
        // lane. Re-evaluate Barr after that layout settles, and never leave a
        // temporarily revealed item exposed across the transition.
        returnHiddenItemNow()
        closeShelf()
        scheduleEnvironmentRefresh(delays: [0.2])
    }

    private func scheduleEnvironmentRefresh(delays: [TimeInterval]) {
        environmentRefreshGeneration += 1
        let generation = environmentRefreshGeneration
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard
                    let self,
                    generation == self.environmentRefreshGeneration
                else { return }
                self.refreshScannerExclusions()
                self.model.refresh(captureImages: false)
            }
        }
    }

    @objc private func runningApplicationsChanged(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        if let application {
            switch application.bundleIdentifier {
            case "com.cursorkittens.Barr", "com.cursorkittens.Barr.debug":
                return
            default:
                break
            }
            if
                notification.name == NSWorkspace.didLaunchApplicationNotification,
                application.activationPolicy == .prohibited
            {
                return
            }
            if
                notification.name == NSWorkspace.didTerminateApplicationNotification,
                !model.containsItem(ownedBy: application.processIdentifier)
            {
                return
            }
        }

        runningApplicationsGeneration += 1
        let generation = runningApplicationsGeneration
        let delays = notification.name == NSWorkspace.didTerminateApplicationNotification
            ? [0.4]
            : [0.6, 2.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard
                    let self,
                    generation == self.runningApplicationsGeneration
                else { return }
                self.refreshScannerExclusions()
                self.model.refresh(captureImages: self.shelfPanel?.isVisible == true)
            }
        }
    }

    @objc private func refresh() {
        model.refresh()
    }

    @objc private func toggleOpenAtLogin() {
        model.setOpensAtLogin(!model.opensAtLogin)
    }

    @objc private func openScreenRecordingSettings() {
        PermissionCenter.openScreenRecordingSettings()
    }

    @objc private func openAccessibilitySettings() {
        PermissionCenter.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
