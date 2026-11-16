import Foundation

enum CredentialCSV {
    static func parse(_ text: String) throws -> [VaultEntry] {
        guard text.utf8.count <= 10_000_000 else { throw VaultFailure.unavailable("Import is limited to 10 MB.") }
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var closed = false
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(character) }
            } else if character == "," {
                row.append(field); field = ""; closed = false
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                row.append(field); rows.append(row); row = []; field = ""; closed = false
            } else if character == "\"", field.isEmpty, !closed { quoted = true }
            else {
                guard !closed, character != "\"" else { throw VaultFailure.unavailable("Malformed CSV quoting.") }
                field.append(character)
            }
            index += 1
        }
        guard !quoted else { throw VaultFailure.unavailable("Unclosed CSV field.") }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        guard let first = rows.first else { return [] }
        let headers = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "\u{feff}", with: "") }
        guard Set(headers).count == headers.count else { throw VaultFailure.unavailable("Duplicate CSV headers.") }
        func column(_ names: [String]) -> Int? { names.compactMap { headers.firstIndex(of: $0) }.first }
        guard let passwordIndex = column(["password", "login_password"]), let userIndex = column(["username", "login_username", "user"]) else { throw VaultFailure.unavailable("CSV requires username and password columns.") }
        let titleIndex = column(["name", "title"])
        let urlIndex = column(["url", "website", "login_uri"])
        let notesIndex = column(["notes", "note"])
        let otpIndex = column(["otpauth", "totp", "login_totp"])
        return try rows.dropFirst().filter { !$0.allSatisfy(\.isEmpty) }.map { cells in
            guard cells.count == headers.count else { throw VaultFailure.unavailable("CSV rows have inconsistent columns.") }
            func value(_ index: Int?) -> String { index.map { cells[$0] } ?? "" }
            let title = value(titleIndex).isEmpty ? (CredentialDomain.host(value(urlIndex)) ?? (cells[userIndex].isEmpty ? "Imported login" : cells[userIndex])) : value(titleIndex)
            return VaultEntry(title: title, username: cells[userIndex], password: cells[passwordIndex], url: value(urlIndex), notes: value(notesIndex), totp: value(otpIndex))
        }
    }
}
