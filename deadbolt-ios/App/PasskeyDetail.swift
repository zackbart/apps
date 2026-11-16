import SwiftUI

struct PasskeyDetail: View {
    @EnvironmentObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    let id: String
    private let relyingParty: String
    init(passkey: VaultPasskey) { id = passkey.id; relyingParty = passkey.relyingParty }
    private var passkey: VaultPasskey? { session.passkeys.first { $0.id == id } }
    @State private var deleting = false
    @State private var error: String?
    @State private var removing = false
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "person.badge.key.fill").font(.largeTitle).foregroundStyle(Theme.accent)
                    Text(passkey?.relyingParty ?? relyingParty).font(.system(.largeTitle, design: .serif, weight: .medium))
                    Text("Passkey").foregroundStyle(Theme.secondary)
                    if let vault = session.vaults.first(where: { $0.id == passkey?.vaultID }) { Label(VaultDisplay.name(vault, among: session.vaults), systemImage: "tray").font(.caption).foregroundStyle(Theme.secondary) }
                }.padding(.vertical, 16)
            }.listRowBackground(Theme.background)
            Section("Account") { LabeledContent("Username", value: passkey?.username ?? "Unavailable") }.listRowBackground(Theme.surface)
            Section {
                Text("This passkey signs you in without sharing a password. Choose Deadbolt when this website or app asks for a passkey.").foregroundStyle(Theme.secondary)
            }.listRowBackground(Theme.background)
            Section { Button(removing ? "Deleting…" : "Delete passkey", role: .destructive) { deleting = true }.disabled(removing || passkey == nil) }.listRowBackground(Theme.surface)
            if let error { Text(error).foregroundStyle(.orange) }
        }.scrollContentBackground(.hidden).background(Theme.background).navigationTitle("Passkey").navigationBarTitleDisplayMode(.inline)
            .onChange(of: session.passkeys) { _, passkeys in if !passkeys.contains(where: { $0.id == id }) { dismiss() } }
            .alert("Couldn’t delete passkey", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
            .confirmationDialog("Delete this passkey?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete passkey", role: .destructive) {
                    guard !removing, let passkey else { return }
                    removing = true
                    Task {
                        defer { removing = false }
                        do { try await session.deletePasskey(passkey); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            } message: { Text("Make sure you have another way to sign in to \(relyingParty) before deleting this passkey.") }
    }
}
