import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var entries: [VaultEntry] = []
    @State private var error: String?
    @State private var vaultID = ""
    @State private var fileName: String?
    @State private var working = false
    @State private var parsing = false
    @State private var summary: VaultImportSummary?
    @State private var operationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Bring your logins with you.").font(.system(.title, design: .serif, weight: .medium))
                    Text("Choose a CSV exported from your password manager. Deadbolt reads it on this device and encrypts the logins in your selected vault.").foregroundStyle(Theme.secondary)
                    Text("Exports contain plain-text passwords. Delete the CSV from Files and Recently Deleted after importing.").font(.callout).foregroundStyle(Theme.accent)
                }.listRowBackground(Theme.background)
                if let summary {
                    Section {
                        Label(summary.imported == 0 ? "These logins are already in your vault" : "Imported \(summary.imported) \(summary.imported == 1 ? "login" : "logins")", systemImage: "checkmark.circle")
                        if summary.skipped > 0 { Text("Skipped \(summary.skipped) \(summary.skipped == 1 ? "matching login" : "matching logins") already in this vault.").font(.callout).foregroundStyle(Theme.secondary) }
                        Button("Done") { dismiss() }
                    }.listRowBackground(Theme.surface)
                } else {
                    Section("Destination") {
                        Picker("Save in", selection: $vaultID) {
                            Text("Choose a vault").tag("")
                            ForEach(session.vaults) { vault in Text(VaultDisplay.name(vault, among: session.vaults)).tag(vault.id) }
                        }.disabled(working || parsing).accessibilityIdentifier("import-vault")
                        if session.vaults.isEmpty { Text("Create or join a vault before importing passwords.").font(.callout).foregroundStyle(.orange) }
                    }.listRowBackground(Theme.surface)
                    if parsing {
                        Section { ProgressView("Reading CSV…") }.listRowBackground(Theme.surface)
                    } else if entries.isEmpty {
                        Section { Button("Choose CSV file") { picking = true }.disabled(session.vaults.isEmpty) }.listRowBackground(Theme.surface)
                    } else {
                        Section("\(entries.count) \(entries.count == 1 ? "login" : "logins") in \(fileName ?? "CSV")") {
                            ForEach(entries.prefix(20)) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                    Text(entry.username).font(.caption).foregroundStyle(Theme.secondary)
                                }
                            }
                            if entries.count > 20 { Text("And \(entries.count - 20) more…").foregroundStyle(Theme.secondary) }
                        }.listRowBackground(Theme.surface)
                        Section {
                            if working {
                                ProgressView("Importing…")
                                Text("Keep Deadbolt open while your logins are encrypted.").font(.footnote).foregroundStyle(Theme.secondary)
                            } else {
                                Button("Import \(entries.count) \(entries.count == 1 ? "login" : "logins")", action: save)
                                    .disabled(vaultID.isEmpty || !session.vaults.contains(where: { $0.id == vaultID }))
                                Button("Choose another file") { picking = true }
                            }
                            Text("Matching logins already in this vault are skipped. Your existing logins stay in place.").font(.footnote).foregroundStyle(Theme.secondary)
                        }.listRowBackground(Theme.surface)
                    }
                }
                if let error { Text(error).foregroundStyle(.orange).listRowBackground(Theme.background).accessibilityIdentifier("import-error") }
            }.scrollContentBackground(.hidden).background(Theme.background).navigationTitle("Import passwords").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(working || parsing) } }
                .interactiveDismissDisabled(working || parsing)
                .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false, onCompletion: read)
                .onAppear { if session.vaults.count == 1 { vaultID = session.vaults[0].id } }
                .onDisappear { operationTask?.cancel(); entries = [] }
        }
    }

    private func read(_ result: Result<[URL], Error>) {
        let url: URL
        do { guard let selected = try result.get().first else { return }; url = selected }
        catch {
            let failure = error as NSError
            if failure.domain != NSCocoaErrorDomain || failure.code != NSUserCancelledError { self.error = error.localizedDescription }
            return
        }
        entries = []
        fileName = nil
        summary = nil
        error = nil
        parsing = true
        operationTask = Task {
            defer { parsing = false }
            do {
                let rows = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? 0) <= 10_000_000 else { throw VaultFailure.unavailable("Choose a CSV smaller than 10 MB.") }
                    return try CredentialCSV.parse(String(contentsOf: url, encoding: .utf8))
                }.value
                try Task.checkCancellation()
                guard !rows.isEmpty else { throw VaultFailure.unavailable("This CSV doesn’t contain any logins to import.") }
                entries = rows
                fileName = url.lastPathComponent
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }

    private func save() {
        guard !working, !vaultID.isEmpty else { return }
        working = true
        error = nil
        let target = vaultID
        let rows = entries
        operationTask = Task {
            defer { working = false }
            do {
                let result = try await session.importEntries(rows, vaultID: target)
                guard !Task.isCancelled else { return }
                summary = result
                entries = []
            } catch is CancellationError { }
            catch { self.error = "\(error.localizedDescription) You can safely retry this file; matching logins are skipped." }
        }
    }
}
