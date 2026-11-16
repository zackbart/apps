import SwiftUI
import UIKit

struct MainView: View {
    var body: some View {
        TabView {
            VaultView().tabItem { Label("Vault", systemImage: "square.stack.3d.up") }
            GeneratorView().tabItem { Label("Generator", systemImage: "key.horizontal") }
            DevicesView().tabItem { Label("Devices", systemImage: "laptopcomputer.and.iphone") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct VaultView: View {
    @EnvironmentObject var session: VaultSession
    @State private var search = ""
    @State private var adding = false
    @State private var creatingVault = false
    @State private var joining = false
    @State private var selectedVaultID = ""
    private var selectedVaultName: String { session.vaults.first { $0.id == selectedVaultID }.map { VaultDisplay.name($0, among: session.vaults) } ?? "All vaults" }
    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    var filteredPasskeys: [VaultPasskey] { session.passkeys.filter { (selectedVaultID.isEmpty || $0.vaultID == selectedVaultID) && (query.isEmpty || "\($0.relyingParty) \($0.username)".localizedCaseInsensitiveContains(query)) } }
    var filtered: [VaultEntry] {
        session.entries.filter { (selectedVaultID.isEmpty || $0.vaultID == selectedVaultID) && (query.isEmpty || "\($0.title) \($0.username) \($0.url)".localizedCaseInsensitiveContains(query)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.vaults.count > 1 ? "Your vaults" : "Your vault").font(.system(.largeTitle, design: .serif, weight: .medium))
                        Spacer()
                        Text("\(filtered.count + filteredPasskeys.count)").accessibilityLabel("\(filtered.count + filteredPasskeys.count) saved items").font(.title3.monospacedDigit()).foregroundStyle(Theme.secondary)
                    }.padding(.top, 12)
                    if !session.vaults.isEmpty {
                        Menu {
                            Button("All vaults") { selectedVaultID = "" }
                            ForEach(session.vaults) { vault in Button(VaultDisplay.name(vault, among: session.vaults)) { selectedVaultID = vault.id } }
                            Divider()
                            Button("Create a vault") { creatingVault = true }
                            Button("Join an existing vault") { joining = true }
                        } label: { Label(selectedVaultName, systemImage: "tray.2").font(.subheadline.weight(.medium)).padding(.vertical, 8) }
                        .accessibilityLabel("Vault filter: \(selectedVaultName)")
                    }
                    if session.vaults.isEmpty {
                        ContentUnavailableView {
                            Label("Finish setting up", systemImage: "tray")
                        } description: {
                            Text("Join a vault from another device, or create one here before adding logins.")
                        } actions: {
                            Button("Join an existing vault") { joining = true }.buttonStyle(.borderedProminent).foregroundStyle(Theme.background).controlSize(.large)
                            Button("Create a vault") { creatingVault = true }.buttonStyle(.bordered).controlSize(.large)
                        }.padding(.top, 24)
                    } else if !filteredPasskeys.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Passkeys").font(.headline).foregroundStyle(Theme.secondary).padding(.bottom, 8)
                            ForEach(filteredPasskeys) { passkey in
                                NavigationLink { PasskeyDetail(passkey: passkey) } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "person.badge.key.fill").font(.title3).foregroundStyle(Theme.accent).frame(width: 48, height: 48).background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                                        VStack(alignment: .leading, spacing: 5) { Text(passkey.relyingParty).font(.headline).foregroundStyle(Theme.ink); Text(passkey.username).font(.subheadline).foregroundStyle(Theme.secondary)
                                            if session.vaults.count > 1, selectedVaultID.isEmpty, let vault = session.vaults.first(where: { $0.id == passkey.vaultID }) { Text(VaultDisplay.name(vault, among: session.vaults)).font(.caption).foregroundStyle(Theme.secondary) }
                                        }
                                        Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
                                    }.padding(.vertical, 15)
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    if !session.vaults.isEmpty && filtered.isEmpty && filteredPasskeys.isEmpty {
                        ContentUnavailableView {
                            Label(query.isEmpty ? "Make yourself at home" : "No matching items", systemImage: query.isEmpty ? "key.horizontal" : "magnifyingglass")
                        } description: {
                            Text(query.isEmpty ? "Add your first login. Your passwords stay encrypted in your vault." : "Try a different name, username, or website.")
                        } actions: {
                            if query.isEmpty { Button("Add a login") { adding = true }.buttonStyle(.borderedProminent).foregroundStyle(Theme.background).controlSize(.large) }
                        }.padding(.top, 50)
                    } else if !filtered.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { entry in
                                NavigationLink { EntryDetail(entry: entry) } label: {
                                    HStack(spacing: 16) {
                                        Text(String(entry.title.prefix(1)).uppercased()).font(.system(.title3, design: .rounded, weight: .semibold))
                                            .foregroundStyle(Theme.accent).frame(width: 48, height: 48).background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(entry.title).font(.headline).foregroundStyle(Theme.ink)
                                            Text(entry.username.isEmpty ? entry.url : entry.username).font(.subheadline).foregroundStyle(Theme.secondary).lineLimit(1)
                                            if session.vaults.count > 1, selectedVaultID.isEmpty, let vault = session.vaults.first(where: { $0.id == entry.vaultID }) { Text(VaultDisplay.name(vault, among: session.vaults)).font(.caption).foregroundStyle(Theme.secondary) }
                                        }
                                        Spacer(minLength: 4)
                                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                                    }.padding(.vertical, 15).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Divider().overlay(Theme.secondary.opacity(0.15))
                            }
                        }
                    }
                }.padding(.horizontal, 24).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background(Theme.background)
                .navigationTitle("Deadbolt").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search your vault")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button { session.lock() } label: { Image(systemName: "lock") }.accessibilityLabel("Lock vault") }
                    ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add login").disabled(session.vaults.isEmpty) }
                }
                .sheet(isPresented: $adding) { EntryEditor(vaultID: selectedVaultID.isEmpty ? nil : selectedVaultID) }
                .sheet(isPresented: $creatingVault) { CreateVaultView { selectedVaultID = $0.id } }
                .sheet(isPresented: $joining) { NavigationStack { JoinDeviceView() } }
                .onChange(of: session.vaults) { previous, vaults in
                    let added = vaults.filter { vault in !previous.contains(where: { $0.id == vault.id }) }
                    if !selectedVaultID.isEmpty && (!vaults.contains(where: { $0.id == selectedVaultID }) || (!added.isEmpty && !added.contains(where: { $0.id == selectedVaultID }))) { selectedVaultID = "" }
                }
        }
    }
}

struct EntryDetail: View {
    @EnvironmentObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    let id: String
    init(entry: VaultEntry) { id = entry.id }
    @State private var reveal = false
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?
    @State private var copied: String?
    @State private var removing = false
    var current: VaultEntry { session.entries.first { $0.id == id } ?? VaultEntry(id: id, title: "Login unavailable", username: "", password: "", url: "", notes: "") }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(current.title).font(.system(.largeTitle, design: .serif, weight: .medium))
                    if !current.url.isEmpty { Text(current.url).foregroundStyle(Theme.secondary).textSelection(.enabled) }
                    if let vault = session.vaults.first(where: { $0.id == current.vaultID }) { Label(VaultDisplay.name(vault, among: session.vaults), systemImage: "tray").font(.caption).foregroundStyle(Theme.secondary) }
                }.padding(.vertical, 15)
            }.listRowBackground(Theme.background)
            Section {
                field("Username", value: current.username)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Password").font(.caption).foregroundStyle(Theme.secondary)
                        Spacer()
                        Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel(reveal ? "Hide password" : "Show password")
                    }
                    HStack {
                        Text(reveal ? current.password : "••••••••••••").font(.body.monospaced()).privacySensitive().fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button { copy(current.password, label: "Password") } label: { Image(systemName: "doc.on.doc").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Copy password")
                    }
                }.padding(.vertical, 8)
            }.listRowBackground(Theme.surface)
            if !current.totp.isEmpty {
                Section("Verification code") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let generator = try? TOTP(uri: current.totp), let code = try? generator.code(at: context.date) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(code).font(.system(.title, design: .monospaced, weight: .semibold)).foregroundStyle(Theme.accent)
                                    Text("Refreshes in \(generator.period - Int(context.date.timeIntervalSince1970) % generator.period)s").font(.caption).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Button { copy(code, label: "Code") } label: { Image(systemName: "doc.on.doc").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Copy verification code")
                            }.padding(.vertical, 8)
                        } else { Text("This verification setup is invalid. Edit the login to replace its setup link.").font(.callout).foregroundStyle(.orange) }
                    }
                }.listRowBackground(Theme.surface)
            }
            if !current.notes.isEmpty { Section("Notes") { Text(current.notes); Button("Copy notes") { copy(current.notes, label: "Notes") } }.listRowBackground(Theme.surface) }
            if let copied { Section { Label("\(copied) copied", systemImage: "checkmark").foregroundStyle(Theme.accent) }.listRowBackground(Theme.background) }
            if let error { Text(error).foregroundStyle(.orange) }
            Section { Button(removing ? "Deleting…" : "Delete login", role: .destructive) { deleting = true }.disabled(removing) }.listRowBackground(Theme.surface)
        }.buttonStyle(.borderless).scrollContentBackground(.hidden).background(Theme.background).navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Edit") { editing = true }.disabled(removing || !session.entries.contains(where: { $0.id == id })) }
            .sheet(isPresented: $editing) { EntryEditor(entry: current) }
            .onChange(of: session.entries) { _, entries in if !entries.contains(where: { $0.id == id }) { dismiss() } }
            .alert("Couldn’t delete login", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
            .confirmationDialog("Delete this login?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete login", role: .destructive) {
                    guard !removing else { return }
                    removing = true
                    Task {
                        defer { removing = false }
                        do { try await session.delete(id: id); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            } message: { Text("This removes it from your vault and synced devices.") }
    }
    private func field(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.caption).foregroundStyle(Theme.secondary)
            HStack { Text(value.isEmpty ? "Not set" : value); Spacer(); Button { copy(value, label: label) } label: { Image(systemName: "doc.on.doc").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Copy \(label.lowercased())").disabled(value.isEmpty) }
        }.padding(.vertical, 8)
    }
    private func copy(_ value: String, label: String) {
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: value]], options: [.expirationDate: Date().addingTimeInterval(45), .localOnly: true])
        copied = label
    }
}
