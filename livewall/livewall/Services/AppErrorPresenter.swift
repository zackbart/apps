import SwiftUI
import AppKit
import Combine

/// A user-visible error with a clear title, explanation, and optional recovery hint.
struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.title == rhs.title && lhs.message == rhs.message
    }
}

/// Shared, single-slot error state surfaced by services. Presents as a SwiftUI
/// alert via the `.appErrorAlert()` modifier attached once at each window root.
///
/// Services should not call `present` directly — use `AppErrorPresenter.report(...)`
/// which handles the main-actor hop from any context.
@MainActor
final class AppErrorPresenter: ObservableObject {
    static let shared = AppErrorPresenter()

    @Published var currentError: AppError?

    /// Internal so test code can construct an isolated presenter without
    /// mutating `.shared`. App code should always go through `.shared`.
    init() {}

    /// Present an error. If an identical error is already showing, this is a no-op
    /// (prevents alert stomping when several displays fail simultaneously).
    ///
    /// If no SwiftUI `WindowGroup` window is currently visible to host the
    /// `.appErrorAlert()` modifier — for example, when the user is interacting
    /// only with the menu bar popover — falls back to a synchronous `NSAlert`
    /// so the error is never silently dropped.
    func present(_ error: AppError) {
        if let current = currentError, current == error { return }
        currentError = error

        if !hasAlertHostWindow() {
            presentViaNSAlert(error)
        }
    }

    func dismiss() {
        currentError = nil
    }

    /// True iff there is a visible SwiftUI `WindowGroup` window able to host
    /// the SwiftUI alert modifier. Popovers (MenuBarExtra) do not satisfy
    /// this — `.alert(...)` does not propagate through MenuBarExtra content.
    private func hasAlertHostWindow() -> Bool {
        NSApp.windows.contains { window in
            window.isVisible && window.styleMask.contains(.titled)
        }
    }

    private func presentViaNSAlert(_ error: AppError) {
        let alert = NSAlert()
        alert.messageText = error.title
        if let recovery = error.recoverySuggestion {
            alert.informativeText = "\(error.message)\n\n\(recovery)"
        } else {
            alert.informativeText = error.message
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        // The user has acknowledged this error via the modal — clear so the
        // SwiftUI binding doesn't re-present it the next time a window opens.
        currentError = nil
    }
}

extension AppErrorPresenter {
    /// Non-isolated convenience for services and KVO callbacks to surface an
    /// error from any context. Returns immediately — the hop to the main
    /// actor is internal.
    ///
    /// This is a `nonisolated` static method on the presenter (rather than a
    /// top-level function) to avoid colliding with `NSResponder.presentError(_:)`
    /// when called from NSView subclasses.
    nonisolated static func report(
        title: String,
        message: String,
        recoverySuggestion: String? = nil
    ) {
        let error = AppError(title: title, message: message, recoverySuggestion: recoverySuggestion)
        Task { @MainActor in
            AppErrorPresenter.shared.present(error)
        }
    }
}

// MARK: - View modifier

extension View {
    /// Attach once per window root. Observes the shared presenter and shows a
    /// SwiftUI alert whenever `currentError` is non-nil.
    func appErrorAlert() -> some View {
        modifier(AppErrorAlertModifier())
    }
}

private struct AppErrorAlertModifier: ViewModifier {
    @ObservedObject private var presenter = AppErrorPresenter.shared

    func body(content: Content) -> some View {
        content.alert(
            presenter.currentError?.title ?? "Error",
            isPresented: Binding(
                get: { presenter.currentError != nil },
                set: { if !$0 { presenter.dismiss() } }
            ),
            presenting: presenter.currentError
        ) { _ in
            Button("OK", role: .cancel) { presenter.dismiss() }
        } message: { error in
            if let recovery = error.recoverySuggestion {
                Text("\(error.message)\n\n\(recovery)")
            } else {
                Text(error.message)
            }
        }
    }
}
