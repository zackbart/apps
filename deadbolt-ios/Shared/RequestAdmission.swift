import Foundation

final class RequestAdmission: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var started = false

    func begin() -> Bool {
        lock.withLock {
            guard !cancelled, !started else { return false }
            started = true
            return true
        }
    }

    func cancel() { lock.withLock { cancelled = true } }
}
