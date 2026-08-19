import CryptoKit
import Foundation

/// Deterministic, process-stable hashing. `Hasher` is seeded per launch, so it
/// cannot be used for anything that has to reproduce the same jitter and the
/// same exercise pick across runs.
enum Seed {
    /// First 8 bytes of SHA256(parts joined by "|") as a big-endian UInt64.
    static func value(_ parts: String...) -> UInt64 {
        value(parts)
    }

    static func value(_ parts: [String]) -> UInt64 {
        let joined = parts.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        var result: UInt64 = 0
        for byte in digest.prefix(8) {
            result = (result << 8) | UInt64(byte)
        }
        return result
    }

    /// A value in `0..<upperBound`, stable for the same seed.
    static func index(_ seed: UInt64, upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(seed % UInt64(upperBound))
    }
}

/// RFC 4122 version 5 UUIDs (SHA-1, name based). Used so a slot identifier
/// always maps to the same set id on every device and on the server.
enum UUIDv5 {
    /// 6ba7b810-9dad-11d1-80b4-00c04fd430c8
    static let dnsNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    /// Namespace for Micro Gains slot identifiers. A v5 UUID under the DNS
    /// namespace for "microgains.zackbart.com", so it is reproducible anywhere.
    static let slotNamespace = UUIDv5.make(namespace: dnsNamespace, name: "microgains.zackbart.com")

    static func make(namespace: UUID, name: String) -> UUID {
        var bytes = Data()
        withUnsafeBytes(of: namespace.uuid) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: Array(name.utf8))

        // Insecure.SHA1 is exactly what RFC 4122 v5 specifies. It is not used
        // for anything security related here.
        var digest = Array(Insecure.SHA1.hash(data: bytes))
        digest[6] = (digest[6] & 0x0F) | 0x50 // version 5
        digest[8] = (digest[8] & 0x3F) | 0x80 // RFC 4122 variant

        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
}

enum ISO8601 {
    /// "2026-08-19T14:05:00Z". Used to build slot identifiers, so the format
    /// must never drift.
    static let utc: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Wire format for the API: internet date time with the device's offset.
    static func offsetString(_ date: Date, timeZone: TimeZone) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = timeZone
        return f.string(from: date)
    }

    static func parse(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return utc.date(from: string) ?? withFraction.date(from: string)
    }

    static func localDate(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
