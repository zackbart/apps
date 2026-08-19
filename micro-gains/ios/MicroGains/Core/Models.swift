import Foundation

// MARK: - Catalog

enum Pattern: String, Codable, CaseIterable, Sendable {
    case push, squat, hinge, core, cardio, mobility
}

enum SetUnit: String, Codable, Sendable {
    case reps, seconds
}

enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// One step gentler. `easy` is the floor.
    var eased: Difficulty {
        switch self {
        case .hard: return .medium
        case .medium: return .easy
        case .easy: return .easy
        }
    }
}

struct Exercise: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let pattern: Pattern
    let unit: SetUnit
    let easy: Int
    let medium: Int
    let hard: Int
    let cue: String
    let officeOk: Bool
    let needsFloor: Bool
    let intense: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, pattern, unit, easy, medium, hard, cue
        case officeOk = "office_ok"
        case needsFloor = "needs_floor"
        case intense
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        pattern = try c.decode(Pattern.self, forKey: .pattern)
        unit = try c.decode(SetUnit.self, forKey: .unit)
        easy = try c.decode(Int.self, forKey: .easy)
        medium = try c.decode(Int.self, forKey: .medium)
        hard = try c.decode(Int.self, forKey: .hard)
        cue = try c.decode(String.self, forKey: .cue)
        officeOk = try c.decode(Bool.self, forKey: .officeOk)
        needsFloor = try c.decode(Bool.self, forKey: .needsFloor)
        // The server omits `intense` on older catalog versions.
        intense = try c.decodeIfPresent(Bool.self, forKey: .intense) ?? false
    }

    init(
        id: String,
        name: String,
        pattern: Pattern,
        unit: SetUnit,
        easy: Int,
        medium: Int,
        hard: Int,
        cue: String,
        officeOk: Bool,
        needsFloor: Bool,
        intense: Bool
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.unit = unit
        self.easy = easy
        self.medium = medium
        self.hard = hard
        self.cue = cue
        self.officeOk = officeOk
        self.needsFloor = needsFloor
        self.intense = intense
    }

    func target(at difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return easy
        case .medium: return medium
        case .hard: return hard
        }
    }

    /// "15 air squats" or "Forearm plank, 40 seconds".
    func prescription(target: Int) -> String {
        switch unit {
        case .reps:
            return "\(target) \(Exercise.pluralPhrase(for: id, name: name))"
        case .seconds:
            return "\(name.replacingOccurrences(of: " (per side)", with: "")), \(target) seconds"
        }
    }

    /// Names that a naive "+s" would mangle.
    private static let pluralOverrides: [String: String] = [
        "incline_pushup": "incline push-ups on the desk",
        "sit_to_stand": "sit-to-stands",
        "standing_knee_to_elbow": "standing knee-to-elbow reps",
        "single_leg_rdl": "single-leg deadlifts per side",
        "seated_thoracic_rotation": "thoracic rotations per side"
    ]

    static func pluralPhrase(for id: String, name: String) -> String {
        if let override = pluralOverrides[id] { return override }
        let perSide = name.contains("(per side)")
        var base = name.replacingOccurrences(of: " (per side)", with: "")
        base = base.prefix(1).lowercased() + base.dropFirst()
        if !base.hasSuffix("s") { base += "s" }
        return perSide ? base + " per side" : base
    }
}

// MARK: - Settings

struct AppSettings: Codable, Equatable, Sendable {
    var intervalMinutes: Int
    var difficulty: Difficulty
    var activeStartMinute: Int
    var activeEndMinute: Int
    var activeDays: Int
    var officeMode: Bool
    var floorOk: Bool
    var enabled: Bool
    var pausedUntil: Date?
    var exerciseLevels: [String: Difficulty]
    var timezone: String

    enum CodingKeys: String, CodingKey {
        case intervalMinutes = "interval_minutes"
        case difficulty
        case activeStartMinute = "active_start_minute"
        case activeEndMinute = "active_end_minute"
        case activeDays = "active_days"
        case officeMode = "office_mode"
        case floorOk = "floor_ok"
        case enabled
        case pausedUntil = "paused_until"
        case exerciseLevels = "exercise_levels"
        case timezone
    }

    static let intervalOptions = [60, 90, 120, 180, 240]

    static var `default`: AppSettings {
        AppSettings(
            intervalMinutes: 120,
            difficulty: .medium,
            activeStartMinute: 540,
            activeEndMinute: 1140,
            activeDays: 127,
            officeMode: false,
            floorOk: true,
            enabled: true,
            pausedUntil: nil,
            exerciseLevels: [:],
            timezone: TimeZone.current.identifier
        )
    }

    var timeZone: TimeZone { TimeZone(identifier: timezone) ?? .current }

    // MARK: - Active window invariant

    /// The Worker's rule, spelled the same way here so the app never sends a
    /// body `PUT /api/settings` will reject: `0 <= start < end <= 1440` and
    /// `end > start + interval` (server/src/validation.ts).
    static func isValidWindow(start: Int, end: Int, interval: Int) -> Bool {
        guard interval > 0 else { return false }
        guard start >= 0, start < end, end <= 1440 else { return false }
        return end > start + interval
    }

    /// The nearest legal window to the one asked for. `end` moves to the
    /// smallest valid value first; `start` only moves when that would run past
    /// midnight. Always returns a pair `isValidWindow` accepts.
    static func repairedWindow(start: Int, end: Int, interval: Int) -> (start: Int, end: Int) {
        let interval = min(max(interval, 1), 1439)
        var start = min(max(start, 0), 1439)
        var end = max(end, start + interval + 1)
        if end > 1440 {
            end = 1440
            start = max(0, end - interval - 1)
        }
        return (start, end)
    }

    var hasValidWindow: Bool {
        AppSettings.isValidWindow(start: activeStartMinute, end: activeEndMinute, interval: intervalMinutes)
    }

    /// Nudges the window back inside the invariant. Returns true when something
    /// moved, so the caller knows the edit was not taken literally.
    @discardableResult
    mutating func repairWindow() -> Bool {
        guard !hasValidWindow else { return false }
        let fixed = AppSettings.repairedWindow(
            start: activeStartMinute,
            end: activeEndMinute,
            interval: intervalMinutes
        )
        activeStartMinute = fixed.start
        activeEndMinute = fixed.end
        return true
    }

    /// Slots per active day at the current interval and window. Rule 8.
    var setsPerDay: Int {
        guard activeEndMinute > activeStartMinute, intervalMinutes > 0 else { return 0 }
        let span = activeEndMinute - activeStartMinute
        return (span + intervalMinutes - 1) / intervalMinutes
    }

    var activeDayCount: Int {
        (0..<7).reduce(0) { $0 + ((activeDays >> $1) & 1) }
    }

    func isActive(weekdayIndex: Int) -> Bool {
        (activeDays >> weekdayIndex) & 1 == 1
    }

    func level(for exerciseID: String) -> Difficulty {
        exerciseLevels[exerciseID] ?? difficulty
    }
}

// MARK: - Set log

enum SetStatus: String, Codable, Sendable {
    case done, skipped
}

enum SkipReason: String, Codable, CaseIterable, Sendable {
    case badTime = "bad_time"
    case tooHard = "too_hard"
    case notHere = "not_here"

    var title: String {
        switch self {
        case .badTime: return "Bad time"
        case .tooHard: return "Too hard"
        case .notHere: return "Can't here"
        }
    }
}

enum SetSource: String, Codable, Sendable {
    case notification, app
}

struct SetLog: Codable, Equatable, Sendable {
    var id: String
    var exerciseID: String
    var target: Int
    var unit: SetUnit
    var status: SetStatus
    var skipReason: SkipReason?
    var scheduledAt: Date?
    var loggedAt: Date
    var localDate: String
    var source: SetSource

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseID = "exercise_id"
        case target, unit, status
        case skipReason = "skip_reason"
        case scheduledAt = "scheduled_at"
        case loggedAt = "logged_at"
        case localDate = "local_date"
        case source
    }
}

struct Stats: Codable, Equatable, Sendable {
    var todayDone: Int
    var todaySkipped: Int
    var streakDays: Int
    var bestStreakDays: Int
    var totalDone: Int
    var totalReps: Int
    var totalSeconds: Int

    enum CodingKeys: String, CodingKey {
        case todayDone = "today_done"
        case todaySkipped = "today_skipped"
        case streakDays = "streak_days"
        case bestStreakDays = "best_streak_days"
        case totalDone = "total_done"
        case totalReps = "total_reps"
        case totalSeconds = "total_seconds"
    }

    static let zero = Stats(
        todayDone: 0, todaySkipped: 0, streakDays: 0,
        bestStreakDays: 0, totalDone: 0, totalReps: 0, totalSeconds: 0
    )
}

struct HistoryDay: Codable, Equatable, Sendable {
    var date: String
    var done: Int
    var skipped: Int
    var reps: Int
    var seconds: Int
}
