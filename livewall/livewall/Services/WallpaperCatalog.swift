import Foundation
import AppKit
import AVFoundation
import Combine
import os

final class WallpaperCatalog: ObservableObject {
    static let shared = WallpaperCatalog()

    @Published var wallpapers: [Wallpaper] = []
    @Published var localWallpapers: [Wallpaper] = []

    /// IDs of local wallpapers whose backing file was missing when the catalog
    /// was last loaded (or became missing since). Gallery UI uses this set to
    /// show a stale badge and a "Remove Missing Entry" affordance.
    @Published var staleLocalWallpaperIDs: Set<String> = []

    init() {
        loadSeedCatalog()
        loadLocalWallpapers()
    }

    var allWallpapers: [Wallpaper] {
        localWallpapers + wallpapers
    }

    // MARK: - Catalog load (seed)

    func loadSeedCatalog() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            AppLogger.catalog.info("No bundled catalog.json found; starting with empty seed catalog")
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            AppLogger.catalog.error("Couldn't read catalog.json: \(error.localizedDescription, privacy: .public)")
            AppErrorPresenter.report(
                title: "Couldn't Load Catalog",
                message: "The bundled wallpaper catalog couldn't be read from disk.",
                recoverySuggestion: "Your imported wallpapers are still available."
            )
            return
        }

        do {
            let catalog = try JSONDecoder().decode(CatalogData.self, from: data)
            wallpapers = catalog.wallpapers
            AppLogger.catalog.info("Loaded \(self.wallpapers.count, privacy: .public) catalog wallpapers")
        } catch {
            AppLogger.catalog.error("Catalog JSON invalid: \(error.localizedDescription, privacy: .public)")
            AppErrorPresenter.report(
                title: "Catalog Format Error",
                message: "The wallpaper catalog file has an invalid format.",
                recoverySuggestion: "Your imported wallpapers are still available."
            )
        }
    }

    // MARK: - Local wallpapers

    func loadLocalWallpapers() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localDir = support.appendingPathComponent("livewall/imported", isDirectory: true)

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: localDir, includingPropertiesForKeys: nil)
        } catch {
            // Missing directory on fresh install is normal; don't surface.
            AppLogger.catalog.debug("No imported-wallpapers directory yet: \(error.localizedDescription, privacy: .public)")
            localWallpapers = []
            staleLocalWallpaperIDs = []
            return
        }

        var loaded: [Wallpaper] = []
        var stale: Set<String> = []
        for fileURL in contents where fileURL.pathExtension == "mp4" || fileURL.pathExtension == "mov" {
            let wallpaper = Wallpaper.local(
                title: fileURL.deletingPathExtension().lastPathComponent,
                fileURL: fileURL
            )
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                stale.insert(wallpaper.id)
            }
            loaded.append(wallpaper)
        }

        localWallpapers = loaded
        staleLocalWallpaperIDs = stale
        if !stale.isEmpty {
            AppLogger.catalog.warning("Found \(stale.count, privacy: .public) stale local wallpaper entries")
        }
    }

    /// Re-check all local wallpapers for file presence. Call when the user
    /// suspects files have moved or been deleted.
    func refreshStaleStatus() {
        var stale: Set<String> = []
        for wallpaper in localWallpapers {
            if let url = wallpaper.localFileURL,
               !FileManager.default.fileExists(atPath: url.path) {
                stale.insert(wallpaper.id)
            }
        }
        staleLocalWallpaperIDs = stale
    }

    /// Remove a local wallpaper from the library. Prunes the in-memory array
    /// and deletes the backing file if it still exists. Safe to call on stale
    /// entries whose file has already been deleted.
    func removeLocalWallpaper(_ wallpaper: Wallpaper) {
        guard wallpaper.isLocal else { return }

        localWallpapers.removeAll { $0.id == wallpaper.id }
        staleLocalWallpaperIDs.remove(wallpaper.id)

        if let fileURL = wallpaper.localFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                AppLogger.catalog.info("Removed local wallpaper file: \(fileURL.lastPathComponent, privacy: .public)")
            } catch {
                AppLogger.catalog.warning("Couldn't delete local wallpaper file: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Import

    func addLocalWallpaper(fileURL: URL) async -> Wallpaper? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let destDir = support.appendingPathComponent("livewall/imported", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            AppLogger.catalog.error("Couldn't create imports directory: \(error.localizedDescription, privacy: .public)")
            AppErrorPresenter.report(
                title: "Import Failed",
                message: "Couldn't create the imports folder in Application Support.",
                recoverySuggestion: "Check that livewall has permission to write to your Application Support directory."
            )
            return nil
        }

        let destURL = destDir.appendingPathComponent(fileURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destURL)

            let asset = AVURLAsset(url: destURL)
            let duration = try await asset.load(.duration).seconds
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let resolution: CGSize
            if let firstTrack = tracks.first {
                resolution = try await firstTrack.load(.naturalSize)
            } else {
                resolution = .zero
            }

            let wallpaperRes: WallpaperResolution
            if resolution.width >= 3840 {
                wallpaperRes = .uhd4k
            } else if resolution.width >= 2560 {
                wallpaperRes = .qhd
            } else if resolution.width >= 1920 {
                wallpaperRes = .hd
            } else {
                wallpaperRes = .unknown
            }

            let wallpaper = Wallpaper.local(
                title: fileURL.deletingPathExtension().lastPathComponent,
                fileURL: destURL,
                resolution: wallpaperRes,
                duration: duration
            )

            localWallpapers.append(wallpaper)
            AppLogger.catalog.info("Imported local wallpaper: \(wallpaper.title, privacy: .public)")

            Task {
                _ = await ThumbnailGenerator.shared.generateThumbnail(for: destURL, wallpaperID: wallpaper.id)
            }

            return wallpaper
        } catch {
            AppLogger.catalog.error("Failed to import wallpaper: \(error.localizedDescription, privacy: .public)")
            AppErrorPresenter.report(
                title: "Import Failed",
                message: error.localizedDescription,
                recoverySuggestion: "Make sure the file is a valid MP4 or MOV and that you have enough disk space."
            )
            return nil
        }
    }

    // MARK: - Search / filter

    func search(query: String) -> [Wallpaper] {
        guard !query.isEmpty else { return allWallpapers }
        let lowercased = query.lowercased()
        return allWallpapers.filter { wp in
            wp.title.lowercased().contains(lowercased) ||
            wp.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }

    func filter(by tag: String) -> [Wallpaper] {
        guard !tag.isEmpty else { return allWallpapers }
        return allWallpapers.filter { $0.tags.contains(tag) }
    }

    var allTags: [String] {
        Set(allWallpapers.flatMap(\.tags)).sorted()
    }
}

struct CatalogData: Codable {
    let wallpapers: [Wallpaper]
}
