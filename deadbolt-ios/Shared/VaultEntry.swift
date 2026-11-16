import Foundation

struct VaultEntry: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var username: String
    var password: String
    var url: String
    var notes: String
    var vaultID: String?
    var totp: String
    var extraFields: [String: [String: String]] = [:]

    init(id: String = UUID().uuidString, title: String, username: String, password: String, url: String, notes: String, vaultID: String? = nil, totp: String = "") {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.vaultID = vaultID
        self.totp = totp
    }
}

enum CredentialDomain {
    static func host(_ value: String) -> String? {
        let input = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !input.contains("\\"),
              input.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        let candidate = input.contains("://") ? input : "https://" + input
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
              components.user == nil, components.password == nil,
              var host = components.url?.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasSuffix(".") { host.removeLast() }
        guard !host.isEmpty, !host.hasSuffix("."), !host.contains(".."),
              host.unicodeScalars.allSatisfy({ $0.isASCII && !CharacterSet.whitespacesAndNewlines.contains($0) }),
              !host.contains("%") else { return nil }
        return host
    }

    static func matches(_ credentialURL: String, service: String) -> Bool {
        guard let left = host(credentialURL), let right = host(service) else { return false }
        return left == right
    }
}
