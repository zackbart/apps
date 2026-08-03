import Foundation
import Testing
@testable import livewall

@MainActor
struct DownloadManagerProgressTests {

    @Test
    func updateProgressPublishesDownloadingState() {
        let manager = DownloadManager()
        manager.updateProgress(id: "abc", fraction: 0.5)

        #expect(manager.downloads["abc"] == .downloading(progress: 0.5))
    }

    @Test
    func updateProgressClampsOutOfRangeValues() {
        let manager = DownloadManager()

        manager.updateProgress(id: "low", fraction: -0.25)
        #expect(manager.downloads["low"] == .downloading(progress: 0.0))

        manager.updateProgress(id: "high", fraction: 1.75)
        #expect(manager.downloads["high"] == .downloading(progress: 1.0))
    }

    @Test
    func updateProgressOverwritesPriorFraction() {
        let manager = DownloadManager()
        manager.updateProgress(id: "x", fraction: 0.1)
        manager.updateProgress(id: "x", fraction: 0.9)
        #expect(manager.downloads["x"] == .downloading(progress: 0.9))
    }
}
