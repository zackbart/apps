import Foundation

/// The exercise list. Ships in the bundle so a fresh install works offline, and
/// is replaced by the server copy when one arrives.
final class Catalog: @unchecked Sendable {
    private(set) var exercises: [Exercise]
    private(set) var version: String?
    private let cacheURL: URL
    private let lock = NSLock()

    static let shared = Catalog()

    init(bundle: Bundle = .main, cacheURL: URL? = nil) {
        self.cacheURL = cacheURL ?? AppPaths.applicationSupport.appendingPathComponent("catalog.json")
        let cached = Catalog.decode(url: self.cacheURL)
        let bundled = Catalog.decode(url: bundle.url(forResource: "catalog", withExtension: "json"))
        exercises = cached ?? bundled ?? []
        version = UserDefaults.standard.string(forKey: "catalog_version")
    }

    var isEmpty: Bool { exercises.isEmpty }

    func exercise(id: String) -> Exercise? {
        lock.lock(); defer { lock.unlock() }
        return exercises.first { $0.id == id }
    }

    func snapshot() -> [Exercise] {
        lock.lock(); defer { lock.unlock() }
        return exercises
    }

    /// Replaces the in-memory list and writes the cache atomically. Ignores an
    /// empty payload so a bad server response cannot brick the app.
    func replace(with exercises: [Exercise], version: String?) {
        guard !exercises.isEmpty else { return }
        lock.lock()
        self.exercises = exercises
        self.version = version
        lock.unlock()

        UserDefaults.standard.set(version, forKey: "catalog_version")
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private static func decode(url: URL?) -> [Exercise]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoded = try? JSONDecoder().decode([Exercise].self, from: data)
        return (decoded?.isEmpty == false) ? decoded : nil
    }
}

enum AppPaths {
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }
}
