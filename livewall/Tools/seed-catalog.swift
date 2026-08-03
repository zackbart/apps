#!/usr/bin/env swift
//
// seed-catalog.swift
//
// Generate a Pexels-backed seed catalog for livewall.
//
// Usage:
//     PEXELS_API_KEY=your_key_here swift Tools/seed-catalog.swift
//
// Reads PEXELS_API_KEY from the environment, hits the Pexels Videos API
// across a small curated set of search terms, deduplicates by video ID, and
// writes the result to livewall/Resources/catalog.generated.json in the
// schema consumed by `WallpaperCatalog.loadSeedCatalog`.
//
// The generated file is intentionally NOT written to catalog.json directly —
// the existing catalog.json contains hand-curated entries that may already be
// referenced by users' applied wallpapers (persisted by ID in UserDefaults).
// Review the generated file and rename it manually if you want to replace
// the bundled seed catalog.
//
// Pexels free tier: 200 requests/hour. This script makes one request per
// query term (8 total) and is well under that limit.
//

import Foundation

// MARK: - Configuration

let queries = [
    "nature",
    "ocean",
    "space",
    "abstract",
    "city skyline",
    "forest",
    "aurora",
    "underwater"
]
let resultsPerQuery = 40
let throttleBetweenQueries: TimeInterval = 0.3

let outputPath = "livewall/Resources/catalog.generated.json"

// MARK: - Argument / env handling

guard let apiKey = ProcessInfo.processInfo.environment["PEXELS_API_KEY"], !apiKey.isEmpty else {
    FileHandle.standardError.write(Data("Error: PEXELS_API_KEY environment variable is not set.\n\nUsage:\n    PEXELS_API_KEY=your_key swift Tools/seed-catalog.swift\n\nGet a free API key at https://www.pexels.com/api/\n".utf8))
    exit(1)
}

// MARK: - Pexels response models

struct PexelsResponse: Decodable {
    let videos: [PexelsVideo]
}

struct PexelsVideo: Decodable {
    let id: Int
    let width: Int
    let height: Int
    let duration: Int
    let url: String
    let image: String
    let user: PexelsUser
    let videoFiles: [PexelsVideoFile]

    enum CodingKeys: String, CodingKey {
        case id, width, height, duration, url, image, user
        case videoFiles = "video_files"
    }
}

struct PexelsUser: Decodable {
    let name: String
}

struct PexelsVideoFile: Decodable {
    let id: Int
    let quality: String
    let fileType: String
    let width: Int?
    let height: Int?
    let link: String

    enum CodingKeys: String, CodingKey {
        case id, quality, link
        case fileType = "file_type"
        case width, height
    }
}

// MARK: - livewall catalog models (mirrors livewall/Models/Wallpaper.swift)

struct CatalogWallpaper: Encodable {
    let id: String
    let title: String
    let thumbnailURL: String
    let videoURL: String
    let resolution: String
    let tags: [String]
    let source: String
    let duration: Double
}

struct CatalogFile: Encodable {
    let wallpapers: [CatalogWallpaper]
}

// MARK: - Sync HTTP helper

func fetchJSON(url: URL, headers: [String: String]) -> Data? {
    var request = URLRequest(url: url)
    for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }

    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    var resultError: Error?

    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let error {
            resultError = error
            return
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            FileHandle.standardError.write(Data("HTTP \(http.statusCode) for \(url.absoluteString)\n".utf8))
            return
        }
        resultData = data
    }.resume()

    semaphore.wait()
    if let resultError {
        FileHandle.standardError.write(Data("Network error: \(resultError.localizedDescription)\n".utf8))
        return nil
    }
    return resultData
}

// MARK: - Mapping helpers

/// Pick the highest-quality MP4 file under or equal to 4K, preferring "hd".
func bestVideoFile(from files: [PexelsVideoFile]) -> PexelsVideoFile? {
    let mp4 = files.filter { $0.fileType.contains("mp4") }
    if mp4.isEmpty { return nil }
    // Sort by area descending, capped at 4K (3840x2160 = 8_294_400 px).
    return mp4
        .filter { ($0.width ?? 0) <= 3840 && ($0.height ?? 0) <= 2160 }
        .max { lhs, rhs in
            let la = (lhs.width ?? 0) * (lhs.height ?? 0)
            let ra = (rhs.width ?? 0) * (rhs.height ?? 0)
            return la < ra
        } ?? mp4.first
}

func mapResolution(width: Int?, height: Int?) -> String {
    guard let w = width, let h = height else { return "unknown" }
    if w >= 3840 || h >= 2160 { return "3840x2160" }
    if w >= 2560 || h >= 1440 { return "2560x1440" }
    if w >= 1920 || h >= 1080 { return "1920x1080" }
    return "unknown"
}

// MARK: - Fetch loop

var seenIDs = Set<Int>()
var collected: [CatalogWallpaper] = []

print("Fetching from Pexels across \(queries.count) queries...")

for (index, query) in queries.enumerated() {
    let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    guard let url = URL(string: "https://api.pexels.com/videos/search?query=\(escaped)&per_page=\(resultsPerQuery)&page=1") else {
        continue
    }

    print("  [\(index + 1)/\(queries.count)] \"\(query)\"...", terminator: "")
    fflush(stdout)

    guard let data = fetchJSON(url: url, headers: ["Authorization": apiKey]) else {
        print(" failed")
        continue
    }

    do {
        let response = try JSONDecoder().decode(PexelsResponse.self, from: data)
        var added = 0
        for video in response.videos where !seenIDs.contains(video.id) {
            seenIDs.insert(video.id)
            guard let file = bestVideoFile(from: video.videoFiles) else { continue }
            let resolution = mapResolution(width: file.width, height: file.height)
            let wallpaper = CatalogWallpaper(
                id: "pexels-\(video.id)",
                title: "\(video.user.name) — \(query.capitalized)",
                thumbnailURL: video.image,
                videoURL: file.link,
                resolution: resolution,
                tags: [query, "video"],
                source: "catalog",
                duration: Double(video.duration)
            )
            collected.append(wallpaper)
            added += 1
        }
        print(" +\(added) (total \(collected.count))")
    } catch {
        print(" parse error: \(error.localizedDescription)")
    }

    if index < queries.count - 1 {
        Thread.sleep(forTimeInterval: throttleBetweenQueries)
    }
}

// MARK: - Write output (atomic)

let catalog = CatalogFile(wallpapers: collected)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let outputData: Data
do {
    outputData = try encoder.encode(catalog)
} catch {
    FileHandle.standardError.write(Data("Failed to encode catalog: \(error.localizedDescription)\n".utf8))
    exit(2)
}

let cwd = FileManager.default.currentDirectoryPath
let outputURL = URL(fileURLWithPath: cwd).appendingPathComponent(outputPath)
let parentDir = outputURL.deletingLastPathComponent()

do {
    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write(Data("Failed to create output directory: \(error.localizedDescription)\n".utf8))
    exit(3)
}

let tempURL = parentDir.appendingPathComponent(".catalog.generated.json.tmp")
do {
    try outputData.write(to: tempURL)
    if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
    }
    try FileManager.default.moveItem(at: tempURL, to: outputURL)
} catch {
    FileHandle.standardError.write(Data("Failed to write output: \(error.localizedDescription)\n".utf8))
    exit(4)
}

print("\nFetched \(collected.count) videos across \(queries.count) queries.")
print("Wrote to \(outputPath)")
print("Review and rename to catalog.json to apply.")
