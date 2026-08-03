//
//  JellyTVApp.swift
//  JellyTV
//

import SwiftUI
import JellyfinAPI
import Persistence
import Settings

@main
struct JellyTVApp: App {
    @State private var sessionStore: SessionStore = Self.makeSessionStore()

    var body: some Scene {
        WindowGroup {
            RootView(sessionStore: sessionStore)
                .task {
                    await sessionStore.restore()
                }
        }
    }

    /// Wires up the live `JellyfinClient` + `CredentialsStore` and seeds them
    /// into a `SessionStore` for the app to share.
    private static func makeSessionStore() -> SessionStore {
        let credentials = CredentialsStore()
        let deviceId = (try? credentials.deviceId()) ?? UUID().uuidString
        let client = JellyfinClient(deviceId: deviceId)
        return SessionStore(client: client, credentials: credentials)
    }
}
