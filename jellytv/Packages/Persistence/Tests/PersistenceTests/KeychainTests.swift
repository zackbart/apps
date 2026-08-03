import Testing
import Foundation
@testable import Persistence

@Suite("Keychain")
struct KeychainTests {

    @Test func roundTripSetGetDelete() throws {
        let service = "com.cursorkittens.jellytv.test.\(UUID().uuidString)"
        let key = "testKey"
        let value = "hello-keychain"

        defer { try? Keychain.delete(forKey: key, service: service) }

        try Keychain.set(value, forKey: key, service: service)
        let retrieved = try Keychain.get(forKey: key, service: service)
        #expect(retrieved == value)

        try Keychain.delete(forKey: key, service: service)
        let afterDelete = try Keychain.get(forKey: key, service: service)
        #expect(afterDelete == nil)
    }

    @Test func overwriteExistingValue() throws {
        let service = "com.cursorkittens.jellytv.test.\(UUID().uuidString)"
        let key = "overwriteKey"

        defer { try? Keychain.delete(forKey: key, service: service) }

        try Keychain.set("first", forKey: key, service: service)
        try Keychain.set("second", forKey: key, service: service)
        let retrieved = try Keychain.get(forKey: key, service: service)
        #expect(retrieved == "second")
    }

    @Test func deleteIsIdempotent() throws {
        let service = "com.cursorkittens.jellytv.test.\(UUID().uuidString)"
        let key = "neverSetKey"
        // Should not throw even though nothing was stored.
        try Keychain.delete(forKey: key, service: service)
    }

    @Test func returnsNilOnMissingKey() throws {
        let service = "com.cursorkittens.jellytv.test.\(UUID().uuidString)"
        let result = try Keychain.get(forKey: "ghostKey", service: service)
        #expect(result == nil)
    }
}
