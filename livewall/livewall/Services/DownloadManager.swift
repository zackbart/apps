import Foundation
import Combine
import os

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case completed(localURL: URL)
    case failed(String)

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.downloading(let lp), .downloading(let rp)): return lp == rp
        case (.completed(let ll), .completed(let rl)): return ll == rl
        case (.failed(let le), .failed(let re)): return le == re
        default: return false
        }
    }

    var isActive: Bool {
        if case .downloading = self { return true }
        return false
    }

    /// Convenience accessor for the active progress fraction (0...1) when in
    /// the `.downloading` state. Returns nil otherwise.
    var progressFraction: Double? {
        if case .downloading(let p) = self { return p }
        return nil
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [String: DownloadState] = [:]

    private let downloadDirectory: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.downloadDirectory = support.appendingPathComponent("livewall/wallpapers", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        } catch {
            AppLogger.download.error("Could not create download directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    func download(wallpaper: Wallpaper) async {
        guard let url = wallpaper.remoteURL else { return }

        let localURL = downloadDirectory.appendingPathComponent("\(wallpaper.id).mp4")

        if FileManager.default.fileExists(atPath: localURL.path) {
            downloads[wallpaper.id] = .completed(localURL: localURL)
            return
        }

        downloads[wallpaper.id] = .downloading(progress: 0)
        AppLogger.download.info("Starting download \(wallpaper.id, privacy: .public)")

        do {
            let tempFile = try await runDownload(url: url, wallpaperID: wallpaper.id)
            try FileManager.default.moveItem(at: tempFile, to: localURL)
            downloads[wallpaper.id] = .completed(localURL: localURL)
            AppLogger.download.info("Completed download \(wallpaper.id, privacy: .public)")
        } catch {
            AppLogger.download.error("Download failed for \(wallpaper.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            downloads[wallpaper.id] = .failed(error.localizedDescription)
        }
    }

    /// Internal so the progress delegate (and unit tests) can publish progress
    /// updates back onto the main actor.
    func updateProgress(id: String, fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        downloads[id] = .downloading(progress: clamped)
    }

    func localURL(for wallpaperID: String) -> URL? {
        let localURL = downloadDirectory.appendingPathComponent("\(wallpaperID).mp4")
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }

    func isDownloaded(wallpaperID: String) -> Bool {
        localURL(for: wallpaperID) != nil
    }

    // MARK: - Delegate-driven download

    /// Bridges the delegate-based URLSession download API to async/await while
    /// streaming progress updates back to `updateProgress(id:fraction:)`.
    /// Resumes its continuation exactly once, in `urlSession(_:task:didCompleteWithError:)`.
    private func runDownload(url: URL, wallpaperID: String) async throws -> URL {
        let delegate = ProgressDelegate(wallpaperID: wallpaperID, manager: self)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            delegate.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
}

/// Non-isolated `URLSessionDownloadDelegate` that streams progress callbacks
/// back to its owning `DownloadManager` via main-actor hops, then bridges the
/// terminal `didCompleteWithError` callback into a `CheckedContinuation`.
///
/// Why a separate class? `DownloadManager` is `@MainActor`, but URLSession
/// delivers its delegate callbacks on an arbitrary serial queue. Conforming
/// to `URLSessionDownloadDelegate` directly on `DownloadManager` would
/// violate actor isolation. The delegate is `final` and `@unchecked Sendable`
/// because all of its mutable state (`movedFileURL`, `continuation`) is only
/// touched from the URLSession's serial delegate queue, which Swift's
/// concurrency checker can't see through.
private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let wallpaperID: String
    private weak var manager: DownloadManager?

    /// Stable temp URL captured in `didFinishDownloadingTo` (the system
    /// deletes the original temp file the moment that delegate method
    /// returns, so we move it synchronously here and remember the new path).
    var movedFileURL: URL?
    var continuation: CheckedContinuation<URL, Error>?

    init(wallpaperID: String, manager: DownloadManager) {
        self.wallpaperID = wallpaperID
        self.manager = manager
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let denominator = max(totalBytesExpectedToWrite, 1)
        let fraction = Double(totalBytesWritten) / Double(denominator)
        let id = wallpaperID
        Task { @MainActor [weak manager] in
            manager?.updateProgress(id: id, fraction: fraction)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // We must move the file synchronously here — URLSession deletes the
        // temp file as soon as this method returns. Stash the new URL for the
        // terminal `didCompleteWithError` callback to consume.
        let stableURL = FileManager.default.temporaryDirectory.appendingPathComponent("livewall-\(wallpaperID)-\(UUID().uuidString).mp4")
        do {
            try FileManager.default.moveItem(at: location, to: stableURL)
            movedFileURL = stableURL
        } catch {
            AppLogger.download.error("Failed to move downloaded file to temp: \(error.localizedDescription, privacy: .public)")
            // Don't resume the continuation here — leave it to didCompleteWithError.
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Terminal callback. Resume exactly once and clear the continuation
        // so any spurious follow-up call can't double-resume.
        guard let cont = continuation else { return }
        continuation = nil

        if let error {
            cont.resume(throwing: error)
            return
        }
        if let url = movedFileURL {
            cont.resume(returning: url)
            return
        }
        cont.resume(throwing: URLError(.cannotCreateFile))
    }
}
