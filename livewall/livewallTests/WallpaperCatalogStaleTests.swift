import Foundation
import Testing
@testable import livewall

@MainActor
struct WallpaperCatalogStaleTests {

    @Test
    func detectsMissingFiles() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("livewall-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let presentFile = tempRoot.appendingPathComponent("present.mp4")
        let missingFile = tempRoot.appendingPathComponent("missing.mp4")
        try Data().write(to: presentFile)

        let presentWallpaper = Wallpaper.local(title: "present", fileURL: presentFile)
        let missingWallpaper = Wallpaper.local(title: "missing", fileURL: missingFile)

        let catalog = WallpaperCatalog()
        catalog.localWallpapers = [presentWallpaper, missingWallpaper]
        catalog.staleLocalWallpaperIDs = []

        catalog.refreshStaleStatus()

        #expect(catalog.staleLocalWallpaperIDs.contains(missingWallpaper.id))
        #expect(!catalog.staleLocalWallpaperIDs.contains(presentWallpaper.id))
    }

    @Test
    func clearsStaleSetWhenAllFilesPresent() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("livewall-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fileA = tempRoot.appendingPathComponent("a.mp4")
        let fileB = tempRoot.appendingPathComponent("b.mp4")
        try Data().write(to: fileA)
        try Data().write(to: fileB)

        let wpA = Wallpaper.local(title: "a", fileURL: fileA)
        let wpB = Wallpaper.local(title: "b", fileURL: fileB)

        let catalog = WallpaperCatalog()
        catalog.localWallpapers = [wpA, wpB]
        catalog.staleLocalWallpaperIDs = [wpA.id, wpB.id] // pretend both were stale

        catalog.refreshStaleStatus()

        #expect(catalog.staleLocalWallpaperIDs.isEmpty)
    }
}
