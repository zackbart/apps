import Foundation

/// Typed wrapper around `Keychain` that stores the three Phase 1 credentials
/// for JellyTV: server URL, access token, and device ID.
///
/// The `service` is injectable so tests can use a unique service per test,
/// avoiding cross-test pollution.
public struct CredentialsStore {

    // MARK: Storage keys

    private static let keyServerURL = "serverURL"
    private static let keyAccessToken = "accessToken"
    private static let keyDeviceId = "deviceId"

    // MARK: Properties

    public let service: String

    // MARK: Init

    public init(service: String = "com.cursorkittens.jellytv") {
        self.service = service
    }

    // MARK: Server URL

    /// Returns the stored server URL, or `nil` if none has been set.
    /// Throws if the stored string cannot be parsed as a `URL` (corrupted state).
    public func serverURL() throws -> URL? {
        guard let raw = try Keychain.get(forKey: Self.keyServerURL, service: service) else {
            return nil
        }
        guard let url = URL(string: raw) else {
            throw CredentialsStoreError.corruptedValue(key: Self.keyServerURL)
        }
        return url
    }

    /// Persists `url`. Pass `nil` to remove the stored value.
    public func setServerURL(_ url: URL?) throws {
        if let url {
            try Keychain.set(url.absoluteString, forKey: Self.keyServerURL, service: service)
        } else {
            try Keychain.delete(forKey: Self.keyServerURL, service: service)
        }
    }

    // MARK: Access Token

    /// Returns the stored access token, or `nil` if none has been set.
    public func accessToken() throws -> String? {
        try Keychain.get(forKey: Self.keyAccessToken, service: service)
    }

    /// Persists `token`. Pass `nil` to remove the stored value.
    public func setAccessToken(_ token: String?) throws {
        if let token {
            try Keychain.set(token, forKey: Self.keyAccessToken, service: service)
        } else {
            try Keychain.delete(forKey: Self.keyAccessToken, service: service)
        }
    }

    // MARK: Device ID

    /// Returns the device ID. On first access, generates a new `UUID` string,
    /// persists it, and returns it. Subsequent calls return the same value.
    ///
    /// This is a `func` (not a computed property) because the persist step can throw.
    public func deviceId() throws -> String {
        if let existing = try Keychain.get(forKey: Self.keyDeviceId, service: service) {
            return existing
        }
        let newId = UUID().uuidString
        try Keychain.set(newId, forKey: Self.keyDeviceId, service: service)
        return newId
    }

    // MARK: Clear

    /// Removes all three stored credentials. After calling this, `deviceId()` will
    /// generate a fresh UUID on the next access.
    public func clear() throws {
        try Keychain.delete(forKey: Self.keyServerURL, service: service)
        try Keychain.delete(forKey: Self.keyAccessToken, service: service)
        try Keychain.delete(forKey: Self.keyDeviceId, service: service)
    }
}

// MARK: - CredentialsStoreError

public enum CredentialsStoreError: Error {
    case corruptedValue(key: String)
}
