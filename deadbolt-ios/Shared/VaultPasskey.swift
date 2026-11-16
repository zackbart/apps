import Foundation

struct VaultPasskey: Identifiable, Equatable, Sendable {
    let id: String
    let vaultID: String
    let relyingParty: String
    let username: String
    let credentialID: Data
    let userHandle: Data

    init?(_ record: [String: Any]) {
        guard let id = record["id"] as? String, let vault = record["vault_id"] as? String,
              let rp = record["rp_id"] as? String, let username = record["username"] as? String,
              let credential = record["credential_id"] as? String, let credentialID = Data(base64Encoded: credential),
              let handle = record["user_handle"] as? String, let userHandle = Data(base64Encoded: handle) else { return nil }
        self.id = id
        vaultID = vault
        relyingParty = rp
        self.username = username
        self.credentialID = credentialID
        self.userHandle = userHandle
    }
}
