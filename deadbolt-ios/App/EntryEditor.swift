import SwiftUI

struct EntryEditor: View {
    @EnvironmentObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    @State private var original: VaultEntry?
    @State private var title: String
    @State private var username: String
    @State private var password: String
    @State private var url: String
    @State private var notes: String
    @State private var totp: String
    @State private var vaultID: String
    @State private var error: String?
    @State private var working = false
    @State private var reveal = false
    @State private var discarding = false
    @State private var replacingPassword = false
    @State private var previousPassword: String?
    @FocusState private var focus: Field?
    private enum Field: Hashable { case title, username, password, url, totp, notes }

    init(entry: VaultEntry? = nil, vaultID: String? = nil) {
        _original = State(initialValue: entry)
        _title = State(initialValue: entry?.title ?? "")
        _username = State(initialValue: entry?.username ?? "")
        _password = State(initialValue: entry?.password ?? "")
        _url = State(initialValue: entry?.url ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _totp = State(initialValue: entry?.totp ?? "")
        _vaultID = State(initialValue: entry?.vaultID ?? vaultID ?? "")
    }

    private var isDirty: Bool {
        title != (original?.title ?? "") || username != (original?.username ?? "") || password != (original?.password ?? "") || url != (original?.url ?? "") || notes != (original?.notes ?? "") || totp != (original?.totp ?? "")
    }
    private var latest: VaultEntry? { original.flatMap { item in session.entries.first { $0.id == item.id && $0.vaultID == item.vaultID } } }
    private var canSave: Bool { !working && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && session.vaults.contains(where: { $0.id == vaultID }) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vault") {
                    if original == nil {
                        Picker("Save in", selection: $vaultID) {
                            Text("Choose a vault").tag("")
                            ForEach(session.vaults) { vault in Text(VaultDisplay.name(vault, among: session.vaults)).tag(vault.id) }
                        }.accessibilityIdentifier("entry-vault")
                    } else {
                        LabeledContent("Saved in", value: session.vaults.first { $0.id == vaultID }.map { VaultDisplay.name($0, among: session.vaults) } ?? "Unavailable vault")
                    }
                }.listRowBackground(Theme.surface)
                Section("Login") {
                    TextField("Name", text: $title).accessibilityIdentifier("entry-title").accessibilityLabel("Name")
                        .focused($focus, equals: .title).submitLabel(.next).onSubmit { focus = .username }
                    TextField("Username or email", text: $username).accessibilityLabel("Username or email").accessibilityIdentifier("entry-username")
                        .textContentType(nil).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .username).submitLabel(.next).onSubmit { focus = .password }
                    HStack {
                        Group {
                            if reveal { TextField("Password", text: $password) }
                            else { SecureField("Password", text: $password) }
                        }.accessibilityLabel("Password").accessibilityIdentifier("entry-password").privacySensitive()
                            .textContentType(nil).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: .password).submitLabel(.next).onSubmit { focus = .url }
                        Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel(reveal ? "Hide password" : "Show password").buttonStyle(.borderless)
                    }
                    Button {
                        if password.isEmpty { generatePassword() } else { replacingPassword = true }
                    } label: { Label("Generate strong password", systemImage: "arrow.clockwise") }
                    if previousPassword != nil {
                        Button("Undo generated password") { if let previousPassword { password = previousPassword }; previousPassword = nil }
                    }
                }.listRowBackground(Theme.surface)
                Section("Website") {
                    TextField("https://example.com", text: $url).accessibilityLabel("Website").accessibilityIdentifier("entry-url")
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .url).submitLabel(.next).onSubmit { focus = .totp }
                }.listRowBackground(Theme.surface)
                Section("Verification code") {
                    TextField("otpauth://totp/…", text: $totp).accessibilityLabel("TOTP setup link").privacySensitive()
                        .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focus, equals: .totp)
                        .submitLabel(.next).onSubmit { focus = .notes }
                    Text("Paste the setup link from your account’s two-factor authentication settings.").font(.footnote).foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.surface)
                Section("Notes") {
                    TextField("Anything else to keep safe", text: $notes, axis: .vertical).accessibilityLabel("Notes").lineLimit(4...8).focused($focus, equals: .notes)
                }.listRowBackground(Theme.surface)
            }.disabled(working).scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle(original == nil ? "New login" : "Edit login").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(isDirty || working)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { if isDirty { discarding = true } else { dismiss() } }.disabled(working)
                    }
                    ToolbarItem(placement: .confirmationAction) { Button(working ? "Saving…" : "Save", action: save).disabled(!canSave) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = nil } }
                }
                .confirmationDialog("Discard your changes?", isPresented: $discarding, titleVisibility: .visible) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                }
                .confirmationDialog("Replace this password?", isPresented: $replacingPassword, titleVisibility: .visible) {
                    Button("Generate password", action: generatePassword)
                    Button("Cancel", role: .cancel) { }
                } message: { Text("The saved password changes only when you save this login.") }
                .alert("Couldn’t save login", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("Keep editing", role: .cancel) { error = nil }
                    if let latest, latest != original { Button("Load latest version", role: .destructive) { load(latest); error = nil } }
                } message: { Text(error ?? "") }
                .onAppear {
                    if vaultID.isEmpty, session.vaults.count == 1 { vaultID = session.vaults[0].id }
                    focus = original == nil ? .title : nil
                }
        }
    }

    private func generatePassword() {
        let generated = PasswordFactory.make(length: 24, symbols: true)
        guard !generated.isEmpty else { error = "Your device couldn’t generate a secure password. Try again."; return }
        previousPassword = password
        password = generated
    }

    private func save() {
        guard canSave else { return }
        focus = nil
        let website = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard website.isEmpty || CredentialDomain.host(website) != nil else { error = "Enter a valid website, such as https://example.com, or leave the website blank."; return }
        let setupLink = totp.trimmingCharacters(in: .whitespacesAndNewlines)
        do { if !setupLink.isEmpty { _ = try TOTP(uri: setupLink) } }
        catch { self.error = error.localizedDescription; return }
        let entry = VaultEntry(id: original?.id ?? UUID().uuidString, title: title.trimmingCharacters(in: .whitespacesAndNewlines), username: username, password: password, url: website.isEmpty || website.contains("://") ? website : "https://" + website, notes: notes, vaultID: vaultID, totp: setupLink)
        working = true
        Task {
            defer { working = false }
            do { try await session.save(entry: entry, original: original); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }

    private func load(_ entry: VaultEntry) {
        original = entry
        title = entry.title
        username = entry.username
        password = entry.password
        url = entry.url
        notes = entry.notes
        totp = entry.totp
        vaultID = entry.vaultID ?? ""
        previousPassword = nil
        reveal = false
    }
}
