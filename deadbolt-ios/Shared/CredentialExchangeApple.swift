import AuthenticationServices
import Foundation

@available(iOS 26.0, *)
extension CredentialExchangeSource.Export {
    init(_ data: ASExportedCredentialData) {
        self.init(exporter: data.exporterDisplayName.isEmpty ? "The exporting app" : data.exporterDisplayName,
                  items: data.accounts.flatMap { $0.items.map(CredentialExchangeSource.Item.init) },
                  collections: data.accounts.reduce(0) { $0 + Self.count($1.collections) })
    }

    private static func count(_ collections: [ASImportableCollection]) -> Int {
        collections.reduce(0) { $0 + 1 + count($1.subcollections) }
    }
}

@available(iOS 26.0, *)
extension CredentialExchangeSource.Item {
    init(_ item: ASImportableItem) {
        var metadata: [String] = []
        if #available(iOS 26.4, *), !item.extensions.isEmpty {
            metadata.append("Sharing settings on this item aren’t kept. Share it again from a Deadbolt vault if needed.")
        }
        self.init(title: item.title,
                  urls: item.scope?.urls.map(\.absoluteString) ?? [],
                  androidApps: item.scope?.androidApps.map { app in app.name.map { "\($0) (\(app.bundleID))" } ?? app.bundleID } ?? [],
                  tags: item.tags,
                  favorite: item.favorite,
                  unsupportedMetadata: metadata,
                  credentials: item.credentials.map(CredentialExchangeSource.Credential.init))
    }
}

@available(iOS 26.0, *)
extension CredentialExchangeSource.Credential {
    init(_ credential: ASImportableCredential) {
        switch credential {
        case .basicAuthentication(let login):
            self = .login(username: login.userName?.value ?? "", password: login.password?.value ?? "")
        case .generatedPassword(let generated):
            self = .generatedPassword(generated.password)
        case .passkey(let passkey):
            var extensions: [String] = []
            if #available(iOS 26.4, *), let fido2 = passkey.fido2Extensions {
                if fido2.hmacCredentials != nil { extensions.append("the PRF (hmac-secret) extension") }
                if fido2.largeBlob != nil { extensions.append("large blob storage") }
            }
            self = .passkey(CredentialExchangeSource.Passkey(credentialID: passkey.credentialID, relyingParty: passkey.relyingPartyIdentifier, username: passkey.userName, displayName: passkey.userDisplayName, userHandle: passkey.userHandle, key: passkey.key, extensions: extensions))
        case .totp(let totp):
            let algorithm: String
            switch totp.algorithm {
            case .sha1: algorithm = "SHA1"
            case .sha256: algorithm = "SHA256"
            case .sha512: algorithm = "SHA512"
            @unknown default: algorithm = totp.algorithm.rawValue
            }
            self = .totp(CredentialExchangeSource.TOTP(secret: totp.secret, period: Int(totp.period), digits: Int(totp.digits), algorithm: algorithm, username: totp.userName, issuer: totp.issuer))
        case .note(let note):
            self = .note(note.content.value)
        case .address: self = .unsupported("An address")
        case .apiKey: self = .unsupported("An API key")
        case .creditCard: self = .unsupported("A payment card")
        case .customFields: self = .unsupported("Custom fields")
        case .driversLicense: self = .unsupported("A driver’s license")
        case .identityDocument: self = .unsupported("An identity document")
        case .itemReference: self = .unsupported("A linked item reference")
        case .passport: self = .unsupported("A passport")
        case .personName: self = .unsupported("A name card")
        case .sshKey: self = .unsupported("An SSH key")
        case .wifi: self = .unsupported("A Wi-Fi network")
        @unknown default: self = .unsupported("An unrecognized credential type")
        }
    }
}
