import Foundation
import LocalAuthentication
import Security

enum VaultFailure: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let text): text }
    }
}

enum DeviceKey {
    private static var query: [String: Any] {
        var value: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "dev.zackbart.deadbolt.unlock",
                                   kSecAttrAccount as String: "vault-key",
                                   kSecAttrSynchronizable as String: false]
        if let group = Bundle.main.object(forInfoDictionaryKey: "DeadboltKeychainGroup") as? String, !group.contains("$(") {
            value[kSecAttrAccessGroup as String] = group
        }
        return value
    }

    private static func validateGroup() throws {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "DeadboltKeychainGroup") as? String,
              group.hasSuffix(".dev.zackbart.deadbolt.shared"), !group.contains("$(") else {
            throw VaultFailure.unavailable("Shared Keychain signing is unavailable.")
        }
    }

    static var isEnrolled: Bool {
        guard (try? validateGroup()) != nil else { return false }
        var item = query
        item[kSecReturnAttributes as String] = true
        item[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        let status = SecItemCopyMatching(item as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func save(_ key: String) throws {
        try validateGroup()
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, &error) else {
            throw VaultFailure.unavailable("Set a device passcode before enabling device unlock.")
        }
        var item = query
        item[kSecAttrAccessControl as String] = access
        item[kSecValueData as String] = Data(key.utf8)
        try remove()
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultFailure.unavailable("Unable to protect the device unlock key (\(status)).") }
    }

    static func read() throws -> String { try DeviceAuthentication().read() }

    static func read(context: LAContext) throws -> String {
        try validateGroup()
        var item = query
        item[kSecUseAuthenticationContext as String] = context
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw VaultFailure.unavailable("Device unlock was cancelled or is unavailable. Unlock in Deadbolt with your master password.")
        }
        return key
    }

    static func remove() throws {
        try validateGroup()
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultFailure.unavailable("The protected unlock key could not be removed (\(status)).") }
    }
}

final class DeviceAuthentication: @unchecked Sendable {
    private let context = LAContext()

    init() {
        context.localizedReason = "Unlock your Deadbolt vault"
        context.touchIDAuthenticationAllowableReuseDuration = 0
    }

    func read() throws -> String {
        defer { context.invalidate() }
        return try DeviceKey.read(context: context)
    }

    func cancel() { context.invalidate() }
}

protocol DeviceKeyStorage: Sendable {
    func save(_ key: String) throws
    func remove() throws
}

struct LiveDeviceKeyStorage: DeviceKeyStorage {
    func save(_ key: String) throws { try DeviceKey.save(key) }
    func remove() throws { try DeviceKey.remove() }
}
