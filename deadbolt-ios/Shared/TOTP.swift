import CryptoKit
import Foundation

struct TOTP {
    enum Algorithm: String { case sha1 = "SHA1", sha256 = "SHA256", sha512 = "SHA512" }
    let secret: Data
    let digits: Int
    let period: Int
    let algorithm: Algorithm

    init(uri: String) throws {
        if !uri.contains("://") {
            guard let decoded = Self.base32(uri), !decoded.isEmpty else { throw VaultFailure.unavailable("Invalid TOTP secret.") }
            secret = decoded
            digits = 6
            period = 30
            algorithm = .sha1
            return
        }
        guard let url = URLComponents(string: uri), url.scheme?.lowercased() == "otpauth", url.host?.lowercased() == "totp" else {
            throw VaultFailure.unavailable("Use an otpauth TOTP setup link.")
        }
        let items = url.queryItems ?? []
        func unique(_ name: String) throws -> String? {
            let values = items.filter { $0.name.lowercased() == name }
            guard values.count <= 1 else { throw VaultFailure.unavailable("Duplicate TOTP parameter.") }
            return values.first?.value
        }
        guard let text = try unique("secret"), let decoded = Self.base32(text), !decoded.isEmpty else { throw VaultFailure.unavailable("Invalid TOTP secret.") }
        secret = decoded
        digits = Int(try unique("digits") ?? "6") ?? 0
        period = Int(try unique("period") ?? "30") ?? 0
        guard [6, 8].contains(digits), (1...300).contains(period), let algorithm = Algorithm(rawValue: (try unique("algorithm") ?? "SHA1").uppercased()) else { throw VaultFailure.unavailable("Unsupported TOTP parameters.") }
        self.algorithm = algorithm
    }

    func code(at date: Date = Date()) throws -> String {
        let steps = date.timeIntervalSince1970 / Double(period)
        guard steps.isFinite, steps >= 0, steps < Double(UInt64.max) else { throw VaultFailure.unavailable("Invalid TOTP time.") }
        var counter = UInt64(steps).bigEndian
        let message = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: secret)
        let digest: [UInt8]
        switch algorithm {
        case .sha1: digest = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: digest = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: digest = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let offset = Int(digest.last! & 15)
        let value = (UInt32(digest[offset] & 127) << 24) | (UInt32(digest[offset + 1]) << 16) | (UInt32(digest[offset + 2]) << 8) | UInt32(digest[offset + 3])
        return String(format: "%0*u", digits, value % (digits == 8 ? 100_000_000 : 1_000_000))
    }

    static func base32(_ text: String) -> Data? {
        guard text.utf8.allSatisfy({ $0 < 128 }) else { return nil }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var accumulator: UInt32 = 0
        var bits = 0
        var result = Data()
        var padding = 0
        var symbols = 0
        for character in text.uppercased() {
            if character == "=" { padding += 1; continue }
            guard padding == 0, let index = alphabet.firstIndex(of: character) else { return nil }
            symbols += 1
            accumulator = (accumulator << 5) | UInt32(index)
            bits += 5
            if bits >= 8 { bits -= 8; result.append(UInt8((accumulator >> bits) & 255)) }
            accumulator &= bits == 0 ? 0 : (1 << bits) - 1
        }
        let remainder = symbols % 8
        guard [0, 2, 4, 5, 7].contains(remainder), accumulator == 0 else { return nil }
        if padding > 0, (remainder == 0 || padding != 8 - remainder) { return nil }
        return result
    }
}
