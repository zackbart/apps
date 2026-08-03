import Foundation
import os

/// Shared `os.Logger` instances for the JellyTV app. Logs from these show up
/// in Xcode's console (when running through Xcode), in `Console.app` filtered
/// by subsystem `tv.jelly.JellyTV`, and in the device log.
public enum JellytvLog {
    public static let api = Logger(subsystem: "tv.jelly.JellyTV", category: "api")
    public static let liveTV = Logger(subsystem: "tv.jelly.JellyTV", category: "livetv")
    public static let player = Logger(subsystem: "tv.jelly.JellyTV", category: "player")
    public static let session = Logger(subsystem: "tv.jelly.JellyTV", category: "session")
}
