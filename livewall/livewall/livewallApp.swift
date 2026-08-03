import SwiftUI
import AppKit

@main
struct LiveWallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            GalleryView()
                .appErrorAlert()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        WindowGroup(id: "settings") {
            SettingsView()
                .appErrorAlert()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        WindowGroup(id: "import") {
            ImportView()
                .appErrorAlert()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        MenuBarExtra {
            MenuBarExtraView()
        } label: {
            Image(systemName: "desktopcomputer")
        }
        .menuBarExtraStyle(.window)
    }
}

struct AppAmbientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.32),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var didBecomeActiveObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        WallpaperEngine.shared.refreshDisplays()
        WallpaperCatalog.shared.refreshStaleStatus()

        // Re-check stale-file status whenever the user returns to the app —
        // catches files that were moved or deleted while we were inactive.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            WallpaperCatalog.shared.refreshStaleStatus()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            didBecomeActiveObserver = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
