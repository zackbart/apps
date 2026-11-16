import SwiftUI

struct CreateVaultView: View {
    @EnvironmentObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    var created: (VaultSummary) -> Void = { _ in }
    @State private var name = ""
    @State private var working = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Give your vault a name.").font(.system(.title2, design: .serif, weight: .medium))
                    Text("Keep separate vaults for the things you share with different devices.").foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.background)
                Section("Vault name") {
                    TextField("personal", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("vault-name").focused($focused).submitLabel(.done).onSubmit(save)
                    Text("Start with a lowercase letter. Use up to 64 lowercase letters, numbers, hyphens, or underscores.").font(.footnote).foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.surface)
                if let error { Text(error).foregroundStyle(.orange).listRowBackground(Theme.background) }
            }.disabled(working).scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle("Create a vault").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(working)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) }
                    ToolbarItem(placement: .confirmationAction) { Button(working ? "Creating…" : "Create", action: save).disabled(working || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }.onAppear { focused = true }
        }
    }

    private func save() {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working, !value.isEmpty else { return }
        let bytes = Array(value.utf8)
        guard (1...64).contains(bytes.count), let first = bytes.first, (97...122).contains(first), bytes.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { error = "Use a vault name such as personal or work-passwords."; return }
        focused = false
        working = true
        Task {
            defer { working = false }
            do { let vault = try await session.createVault(name: value); created(vault); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}
