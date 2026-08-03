import Foundation
import AppKit
import AVFoundation
import Observation
import os

@Observable
final class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    private let cacheDirectory: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("livewall/thumbnails", isDirectory: true)
        self.cacheDirectory = dir
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            AppLogger.thumbnail.error("Could not create thumbnail cache directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    func generateThumbnail(for videoURL: URL, wallpaperID: String) async -> URL? {
        let cachedPath = cacheDirectory.appendingPathComponent("\(wallpaperID).jpg")
        if FileManager.default.fileExists(atPath: cachedPath.path) {
            return cachedPath
        }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 250)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            if let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                try jpegData.write(to: cachedPath)
                return cachedPath
            }
        } catch {
            AppLogger.thumbnail.error("Thumbnail generation failed for \(wallpaperID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        return nil
    }

    func cachedThumbnail(for wallpaperID: String) -> URL? {
        let path = cacheDirectory.appendingPathComponent("\(wallpaperID).jpg")
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
}
