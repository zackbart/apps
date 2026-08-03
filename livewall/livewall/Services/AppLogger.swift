import Foundation
import os

/// Centralized `os.Logger` namespace for livewall.
///
/// Filter in Console.app with `subsystem == "com.cursorkittens.livewall"`
/// or on the command line:
/// `log stream --predicate 'subsystem == "com.cursorkittens.livewall"' --level debug`
enum AppLogger {
    static let subsystem = "com.cursorkittens.livewall"

    static let app       = Logger(subsystem: subsystem, category: "app")
    static let engine    = Logger(subsystem: subsystem, category: "engine")
    static let catalog   = Logger(subsystem: subsystem, category: "catalog")
    static let download  = Logger(subsystem: subsystem, category: "download")
    static let playback  = Logger(subsystem: subsystem, category: "playback")
    static let thumbnail = Logger(subsystem: subsystem, category: "thumbnail")
    static let settings  = Logger(subsystem: subsystem, category: "settings")
}
