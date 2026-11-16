import Foundation

struct CredentialExchangeLogin: Equatable, Sendable {
    var name: String
    var username = ""
    var password = ""
    var url = ""
    var notes = ""
    var otp = ""
}

struct CredentialExchangePasskey: Equatable, Sendable {
    var name: String
    var relyingParty: String
    var username: String
    var displayName: String
    var credentialID: Data
    var userHandle: Data
    var privateKey: Data
}

struct CredentialExchangeRecord: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case login(CredentialExchangeLogin)
        case passkey(CredentialExchangePasskey)
    }

    let id: Int
    let source: String
    let content: Content

    var isPasskey: Bool { if case .passkey = content { true } else { false } }

    var title: String {
        switch content {
        case .login(let login): login.name
        case .passkey(let passkey): passkey.name
        }
    }

    var subtitle: String {
        switch content {
        case .login(let login): login.username.isEmpty ? login.url : login.username
        case .passkey(let passkey): passkey.username.isEmpty ? passkey.relyingParty : "\(passkey.username) · \(passkey.relyingParty)"
        }
    }

    var contents: [String] {
        switch content {
        case .login(let login):
            [login.password.isEmpty ? nil : "Password", login.otp.isEmpty ? nil : "Verification code", login.notes.isEmpty ? nil : "Notes"].compactMap { $0 }
        case .passkey: ["Passkey"]
        }
    }

    var payload: [String: Any] {
        switch content {
        case .login(let login):
            let fields: [String: [String: String]] = ["username": ["type": "text", "value": login.username], "password": ["type": "secret", "value": login.password], "url": ["type": "url", "value": login.url], "notes": ["type": "note", "value": login.notes], "otp": ["type": "otp", "value": login.otp]]
            return ["type": "login", "name": login.name, "fields": fields.filter { $0.value["value"]?.isEmpty == false }]
        case .passkey(let passkey):
            return ["type": "passkey", "name": passkey.name, "rp_id": passkey.relyingParty, "username": passkey.username, "display_name": passkey.displayName,
                    "credential_id": passkey.credentialID.base64EncodedString(), "user_handle": passkey.userHandle.base64EncodedString(), "private_key": passkey.privateKey.base64EncodedString()]
        }
    }
}

struct CredentialExchangeIssue: Identifiable, Equatable, Sendable {
    let id: Int
    let source: String
    let message: String
}

struct CredentialExchangePlan: Equatable, Sendable {
    var exporter: String
    var sourceItems: Int
    var records: [CredentialExchangeRecord]
    var excluded: [CredentialExchangeIssue]
    var notices: [CredentialExchangeIssue]

    var loginCount: Int { records.filter { !$0.isPasskey }.count }
    var passkeyCount: Int { records.filter(\.isPasskey).count }
}

enum CredentialExchangeSource {
    struct TOTP: Equatable, Sendable {
        var secret: Data
        var period: Int
        var digits: Int
        var algorithm: String
        var username: String?
        var issuer: String?
    }

    struct Passkey: Equatable, Sendable {
        var credentialID: Data
        var relyingParty: String
        var username: String
        var displayName: String
        var userHandle: Data
        var key: Data
        var extensions: [String] = []
    }

    enum Credential: Equatable, Sendable {
        case login(username: String, password: String)
        case generatedPassword(String)
        case passkey(Passkey)
        case totp(TOTP)
        case note(String)
        case unsupported(String)
    }

    struct Item: Equatable, Sendable {
        var title: String
        var urls: [String] = []
        var androidApps: [String] = []
        var tags: [String] = []
        var favorite = false
        var unsupportedMetadata: [String] = []
        var credentials: [Credential]
    }

    struct Export: Equatable, Sendable {
        var exporter: String
        var items: [Item]
        var collections = 0
    }
}

enum CredentialExchangeFormat {
    static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let queryValueCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func base32(_ data: Data) -> String {
        var result = ""
        var buffer: UInt32 = 0
        var bits = 0
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                result.append(base32Alphabet[Int((buffer >> UInt32(bits)) & 31)])
            }
            buffer &= (1 << UInt32(bits)) - 1
        }
        if bits > 0 { result.append(base32Alphabet[Int((buffer << UInt32(5 - bits)) & 31)]) }
        return result
    }

    static func otpURI(_ totp: CredentialExchangeSource.TOTP, fallbackIssuer: String) throws -> String {
        guard !totp.secret.isEmpty else { throw VaultFailure.unavailable("The verification code has no secret.") }
        guard [6, 8].contains(totp.digits) else { throw VaultFailure.unavailable("\(totp.digits)-digit verification codes aren’t supported.") }
        guard (1...300).contains(totp.period) else { throw VaultFailure.unavailable("A \(totp.period)-second verification code period isn’t supported.") }
        guard let algorithm = TOTP.Algorithm(rawValue: totp.algorithm.uppercased()) else { throw VaultFailure.unavailable("The \(totp.algorithm) verification code algorithm isn’t supported.") }
        let issuer = (totp.issuer ?? "").isEmpty ? fallbackIssuer : totp.issuer ?? ""
        let account = totp.username ?? ""
        let label = [issuer, account].filter { !$0.isEmpty }.joined(separator: ":")
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        components.path = "/" + (label.isEmpty ? "Imported" : label).replacingOccurrences(of: "/", with: "∕")
        var query = [URLQueryItem(name: "secret", value: base32(totp.secret)), URLQueryItem(name: "algorithm", value: algorithm.rawValue), URLQueryItem(name: "digits", value: String(totp.digits)), URLQueryItem(name: "period", value: String(totp.period))]
        if !issuer.isEmpty, let encoded = issuer.addingPercentEncoding(withAllowedCharacters: queryValueCharacters) { query.append(URLQueryItem(name: "issuer", value: encoded)) }
        components.percentEncodedQueryItems = query
        guard let uri = components.string else { throw VaultFailure.unavailable("The verification code couldn’t be converted.") }
        let parsed = try TOTP(uri: uri)
        guard parsed.secret == totp.secret, parsed.digits == totp.digits, parsed.period == totp.period, parsed.algorithm == algorithm else {
            throw VaultFailure.unavailable("The verification code couldn’t be converted.")
        }
        return uri
    }

    private static let p256AlgorithmIdentifier: [UInt8] = [0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]

    static func isP256PKCS8(_ key: Data) -> Bool {
        let bytes = [UInt8](key)
        guard bytes.count > 30, bytes.count < 512, bytes[0] == 0x30 else { return false }
        var index = 1
        if bytes[index] & 0x80 != 0 { index += Int(bytes[index] & 0x7F) }
        index += 1
        guard index + 3 + p256AlgorithmIdentifier.count <= bytes.count, bytes[index] == 0x02, bytes[index + 1] == 0x01, bytes[index + 2] == 0x00 else { return false }
        index += 3
        return Array(bytes[index..<(index + p256AlgorithmIdentifier.count)]) == p256AlgorithmIdentifier
    }
}

enum CredentialExchangeConverter {
    static func plan(_ export: CredentialExchangeSource.Export) -> CredentialExchangePlan {
        var records: [CredentialExchangeRecord] = []
        var excluded: [CredentialExchangeIssue] = []
        var notices: [CredentialExchangeIssue] = []
        var favorites = 0

        for item in export.items {
            let source = item.title.isEmpty ? (item.urls.lazy.compactMap(CredentialDomain.host).first ?? "Untitled item") : item.title
            let primaryIndex = item.urls.firstIndex { CredentialDomain.host($0) != nil }
            let primaryURL = primaryIndex.map { item.urls[$0] } ?? ""
            let extraURLs = item.urls.indices.filter { $0 != primaryIndex }.map { item.urls[$0] }
            let name = item.title.isEmpty ? (CredentialDomain.host(primaryURL) ?? "Imported login") : item.title
            if item.favorite { favorites += 1 }
            for metadata in item.unsupportedMetadata { notices.append(CredentialExchangeIssue(id: notices.count, source: source, message: metadata)) }

            var logins: [CredentialExchangeLogin] = []
            var totps: [CredentialExchangeSource.TOTP] = []
            var noteTexts: [String] = []
            var passkeys: [CredentialExchangePasskey] = []

            for credential in item.credentials {
                switch credential {
                case .login(let username, let password):
                    guard !username.isEmpty || !password.isEmpty else { continue }
                    logins.append(CredentialExchangeLogin(name: name, username: username, password: password, url: primaryURL))
                case .generatedPassword(let password):
                    guard !password.isEmpty else { continue }
                    logins.append(CredentialExchangeLogin(name: name, password: password, url: primaryURL))
                case .totp(let totp):
                    totps.append(totp)
                case .note(let text):
                    if !text.isEmpty { noteTexts.append(text) }
                case .passkey(let passkey):
                    if !passkey.extensions.isEmpty {
                        excluded.append(CredentialExchangeIssue(id: excluded.count, source: source, message: "Passkey for \(passkey.relyingParty) uses \(passkey.extensions.joined(separator: " and ")), which Deadbolt can’t keep. It wasn’t imported; keep it in Passwords."))
                    } else if passkey.relyingParty.isEmpty || passkey.credentialID.isEmpty || passkey.userHandle.isEmpty || passkey.userHandle.count > 64 {
                        excluded.append(CredentialExchangeIssue(id: excluded.count, source: source, message: "A passkey is missing its website or account identifiers. It wasn’t imported."))
                    } else if !CredentialExchangeFormat.isP256PKCS8(passkey.key) {
                        excluded.append(CredentialExchangeIssue(id: excluded.count, source: source, message: "Passkey for \(passkey.relyingParty) uses a key type Deadbolt doesn’t support. It wasn’t imported."))
                    } else {
                        passkeys.append(CredentialExchangePasskey(name: item.title.isEmpty ? passkey.relyingParty : item.title, relyingParty: passkey.relyingParty, username: passkey.username, displayName: passkey.displayName, credentialID: passkey.credentialID, userHandle: passkey.userHandle, privateKey: passkey.key))
                    }
                case .unsupported(let kind):
                    excluded.append(CredentialExchangeIssue(id: excluded.count, source: source, message: "\(kind) isn’t supported by Deadbolt and wasn’t imported."))
                }
            }

            for totp in totps {
                let uri: String
                do { uri = try CredentialExchangeFormat.otpURI(totp, fallbackIssuer: item.title.isEmpty ? (CredentialDomain.host(primaryURL) ?? "") : item.title) }
                catch {
                    excluded.append(CredentialExchangeIssue(id: excluded.count, source: source, message: "Verification code wasn’t imported: \(error.localizedDescription)"))
                    continue
                }
                let user = totp.username ?? ""
                if let index = logins.firstIndex(where: { $0.otp.isEmpty && !user.isEmpty && $0.username == user })
                    ?? logins.firstIndex(where: { $0.otp.isEmpty && (user.isEmpty || $0.username.isEmpty || logins.count == 1) }) {
                    logins[index].otp = uri
                } else {
                    logins.append(CredentialExchangeLogin(name: name, username: user, url: primaryURL, otp: uri))
                }
            }

            var extras: [String] = []
            if !extraURLs.isEmpty { extras.append("Additional websites:\n" + extraURLs.joined(separator: "\n")) }
            if !item.androidApps.isEmpty { extras.append("Android apps:\n" + item.androidApps.joined(separator: "\n")) }
            if !item.tags.isEmpty { extras.append("Tags: " + item.tags.joined(separator: ", ")) }
            let notes = (noteTexts + extras).joined(separator: "\n\n")

            if logins.isEmpty, !noteTexts.isEmpty {
                logins.append(CredentialExchangeLogin(name: name, url: primaryURL, notes: notes))
            } else if !logins.isEmpty {
                for index in logins.indices { logins[index].notes = notes }
            } else if !extras.isEmpty {
                notices.append(CredentialExchangeIssue(id: notices.count, source: source, message: "Websites, apps, or tags on this item weren’t kept because it has no login to attach them to."))
            }

            for login in logins { records.append(CredentialExchangeRecord(id: records.count, source: source, content: .login(login))) }
            for passkey in passkeys { records.append(CredentialExchangeRecord(id: records.count, source: source, content: .passkey(passkey))) }
        }

        if favorites > 0 { notices.append(CredentialExchangeIssue(id: notices.count, source: export.exporter, message: "Favorites (\(favorites)) aren’t marked in Deadbolt.")) }
        if export.collections > 0 { notices.append(CredentialExchangeIssue(id: notices.count, source: export.exporter, message: "Groups and folders (\(export.collections)) aren’t recreated. Their items are imported individually.")) }
        return CredentialExchangePlan(exporter: export.exporter, sourceItems: export.items.count, records: records, excluded: excluded, notices: notices)
    }
}
