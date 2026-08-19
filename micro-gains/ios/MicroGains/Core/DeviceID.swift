import Foundation
import Security

/// The only credential in the app: a UUID v4 in the Keychain. It survives app
/// reinstalls but not an erase-all-content, which is the behaviour we want.
enum DeviceID {
    private static let service = "com.zackbart.microgains"
    private static let account = "device-id"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: String?

    static var current: String {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        if let stored = read(), UUID(uuidString: stored) != nil {
            cached = stored
            return stored
        }
        let fresh = UUID().uuidString.lowercased()
        write(fresh)
        cached = fresh
        return fresh
    }

    /// Used by "Erase my data": the old id is unrecoverable afterwards.
    @discardableResult
    static func rotate() -> String {
        lock.lock()
        cached = nil
        lock.unlock()
        delete()
        return current
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) {
        delete()
        var query = baseQuery()
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
