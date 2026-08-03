import Testing
import Foundation
@testable import Persistence

@Suite("CredentialsStore")
struct CredentialsStoreTests {

    @Test func deviceIdGeneratesAndPersists() throws {
        let store = CredentialsStore(service: "com.cursorkittens.jellytv.test.\(UUID().uuidString)")
        defer { try? store.clear() }

        let first = try store.deviceId()
        let second = try store.deviceId()

        #expect(first == second, "deviceId should return the same value on repeated calls")
        // Verify it's a valid UUID.
        #expect(UUID(uuidString: first) != nil, "deviceId should be a valid UUID string")
    }

    @Test func serverURLRoundTrip() throws {
        let store = CredentialsStore(service: "com.cursorkittens.jellytv.test.\(UUID().uuidString)")
        defer { try? store.clear() }

        let url = URL(string: "http://192.168.1.50:8096")!
        try store.setServerURL(url)
        let retrieved = try store.serverURL()
        #expect(retrieved == url)

        // Clear it and confirm nil.
        try store.setServerURL(nil)
        let afterClear = try store.serverURL()
        #expect(afterClear == nil)
    }

    @Test func accessTokenRoundTrip() throws {
        let store = CredentialsStore(service: "com.cursorkittens.jellytv.test.\(UUID().uuidString)")
        defer { try? store.clear() }

        let token = "abc123-access-token"
        try store.setAccessToken(token)
        let retrieved = try store.accessToken()
        #expect(retrieved == token)

        try store.setAccessToken(nil)
        let afterClear = try store.accessToken()
        #expect(afterClear == nil)
    }

    @Test func clearWipesAll() throws {
        let store = CredentialsStore(service: "com.cursorkittens.jellytv.test.\(UUID().uuidString)")
        defer { try? store.clear() }

        // Set all three.
        try store.setServerURL(URL(string: "http://192.168.1.50:8096")!)
        try store.setAccessToken("some-token")
        let preClearDeviceId = try store.deviceId()

        // Clear everything.
        try store.clear()

        #expect(try store.serverURL() == nil)
        #expect(try store.accessToken() == nil)

        // deviceId should regenerate to a NEW value after clear.
        let postClearDeviceId = try store.deviceId()
        #expect(postClearDeviceId != preClearDeviceId, "deviceId should regenerate after clear()")
        #expect(UUID(uuidString: postClearDeviceId) != nil, "regenerated deviceId should be a valid UUID")
    }
}
