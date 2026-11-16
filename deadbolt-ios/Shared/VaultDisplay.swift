import Foundation

enum VaultDisplay {
    static func name(_ vault: VaultSummary, among vaults: [VaultSummary]) -> String {
        vaults.filter { $0.name == vault.name }.count > 1 ? "\(vault.name) (\(vault.id.prefix(6)))" : vault.name
    }
}
