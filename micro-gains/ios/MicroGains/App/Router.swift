import UIKit

/// One hop between the notification delegate and whatever scene is on screen.
/// The delegate can fire before the scene exists, so the request is held until
/// a scene claims it.
@MainActor
final class Router {
    static let shared = Router()

    weak var sceneDelegate: SceneDelegate?
    private var pendingSetID: String??

    func openSet(setID: String?) {
        if let sceneDelegate {
            sceneDelegate.presentSet(setID: setID)
        } else {
            pendingSetID = .some(setID)
        }
    }

    func drainPending() {
        guard let pending = pendingSetID else { return }
        pendingSetID = nil
        sceneDelegate?.presentSet(setID: pending)
    }
}
