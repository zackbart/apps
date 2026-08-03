import Foundation
import Security

// MARK: - Error

public enum KeychainError: Error {
    case unhandled(OSStatus)
}

// MARK: - Keychain

public enum Keychain {

    // MARK: Set

    /// Stores `value` (UTF-8 encoded) for the given `key` in the specified `service`.
    /// Overwrites any existing value for the same key+service pair.
    public static func set(_ value: String, forKey key: String, service: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unhandled(errSecParam)
        }

        // Delete first so we can always do a clean add.
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.unhandled(deleteStatus)
        }

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandled(addStatus)
        }
    }

    // MARK: Get

    /// Returns the stored string for `key` in `service`, or `nil` if no item exists.
    /// Throws `KeychainError.unhandled` for any other non-success status.
    public static func get(forKey key: String, service: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.unhandled(errSecDecode)
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    // MARK: Delete

    /// Removes the item for `key` in `service`. Idempotent — does not throw if the item does not exist.
    public static func delete(forKey key: String, service: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}
