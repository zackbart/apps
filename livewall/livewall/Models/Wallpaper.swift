import Foundation
import Observation

enum WallpaperSource: String, Codable {
    case catalog
    case local
}

enum WallpaperResolution: String, Codable {
    case hd = "1920x1080"
    case qhd = "2560x1440"
    case uhd4k = "3840x2160"
    case unknown = "unknown"
}

struct Wallpaper: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var thumbnailURL: String?
    var videoURL: String
    var resolution: WallpaperResolution
    var tags: [String]
    var source: WallpaperSource
    var duration: TimeInterval?

    var isLocal: Bool {
        source == .local
    }

    var localFileURL: URL? {
        guard isLocal else { return nil }
        return URL(fileURLWithPath: videoURL)
    }

    var remoteURL: URL? {
        guard !isLocal, let url = URL(string: videoURL) else { return nil }
        return url
    }

    static func local(title: String, fileURL: URL, resolution: WallpaperResolution = .unknown, duration: TimeInterval? = nil) -> Wallpaper {
        Wallpaper(
            id: UUID().uuidString,
            title: title,
            thumbnailURL: nil,
            videoURL: fileURL.path,
            resolution: resolution,
            tags: [],
            source: .local,
            duration: duration
        )
    }

    static func catalog(id: String, title: String, thumbnailURL: String, videoURL: String, resolution: WallpaperResolution = .uhd4k, tags: [String] = [], duration: TimeInterval? = nil) -> Wallpaper {
        Wallpaper(
            id: id,
            title: title,
            thumbnailURL: thumbnailURL,
            videoURL: videoURL,
            resolution: resolution,
            tags: tags,
            source: .catalog,
            duration: duration
        )
    }
}
