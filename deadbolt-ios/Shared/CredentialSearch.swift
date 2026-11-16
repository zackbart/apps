import Foundation

enum CredentialSearch {
    static func matches(_ query: String, values: [String]) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        return terms.allSatisfy { term in
            values.contains { $0.range(of: String(term), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    static func sorted(_ entries: [VaultEntry]) -> [VaultEntry] {
        entries.sorted {
            let title = $0.title.localizedStandardCompare($1.title)
            if title != .orderedSame { return title == .orderedAscending }
            let username = $0.username.localizedStandardCompare($1.username)
            return username == .orderedSame ? $0.id < $1.id : username == .orderedAscending
        }
    }
}
