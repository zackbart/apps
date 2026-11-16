import SwiftUI

struct CredentialExchangeView: View {
    @EnvironmentObject var session: VaultSession
    @EnvironmentObject var exchange: CredentialExchangeCoordinator
    @State private var creatingVault = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Move in from Passwords.").font(.system(.title, design: .serif, weight: .medium))
                    Text("Your passwords, verification codes, and passkeys are received on this device and encrypted in the vault you choose. Nothing is saved until you import.").foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.background)
                content
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Transfer").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if exchange.phase != .importing, !isComplete { Button("Cancel") { exchange.cancel(session: session) } }
                }
            }
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $creatingVault) { CreateVaultView { exchange.destinationID = $0.id } }
        }
    }

    private var isComplete: Bool {
        switch exchange.phase {
        case .finished, .failed: true
        default: false
        }
    }

    @ViewBuilder private var content: some View {
        switch exchange.phase {
        case .idle, .waitingForVault, .loading:
            Section { ProgressView("Receiving your transfer…").tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 12) }.listRowBackground(Theme.surface)
        case .importing:
            Section {
                ProgressView("Importing…").tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 12)
                Text("Keep Deadbolt open while your items are encrypted.").font(.footnote).foregroundStyle(Theme.secondary)
            }.listRowBackground(Theme.surface)
        case .finished(let summary):
            Section {
                Label(summary.imported == 0 ? "These items are already in your vault" : "Imported \(count(summary.imported, "item"))", systemImage: "checkmark.circle").foregroundStyle(Theme.accent)
                if summary.skipped > 0 { Text("Skipped \(count(summary.skipped, "matching item")) already in this vault.").font(.callout).foregroundStyle(Theme.secondary) }
                Text("Your items stay in Passwords too. Remove them there once you’ve confirmed everything works in Deadbolt.").font(.footnote).foregroundStyle(Theme.secondary)
                Button("Done") { exchange.close(session: session) }.accessibilityIdentifier("transfer-done")
            }.listRowBackground(Theme.surface)
        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                Button("Done") { exchange.close(session: session) }
            }.listRowBackground(Theme.surface)
        case .review:
            if let plan = exchange.plan { review(plan) }
        }
    }

    @ViewBuilder private func review(_ plan: CredentialExchangePlan) -> some View {
        Section("From \(plan.exporter)") {
            LabeledContent("Items received", value: "\(plan.sourceItems)")
            LabeledContent("Logins ready", value: "\(plan.loginCount)")
            LabeledContent("Passkeys ready", value: "\(plan.passkeyCount)")
            if !plan.excluded.isEmpty { LabeledContent("Can’t be imported", value: "\(plan.excluded.count)").foregroundStyle(.orange) }
        }.listRowBackground(Theme.surface)

        Section("Destination") {
            Picker("Save in", selection: $exchange.destinationID) {
                Text("Choose a vault").tag("")
                ForEach(session.vaults) { vault in Text(VaultDisplay.name(vault, among: session.vaults)).tag(vault.id) }
            }.accessibilityIdentifier("transfer-vault")
            Button { creatingVault = true } label: { Label("Create a vault", systemImage: "plus") }
            if session.vaults.isEmpty { Text("Create a vault to hold these items.").font(.callout).foregroundStyle(.orange) }
        }.listRowBackground(Theme.surface)

        if !plan.excluded.isEmpty {
            Section {
                ForEach(plan.excluded) { issue in issueRow(issue, symbol: "xmark.octagon", tint: .orange) }
                Toggle("I understand these stay in Passwords and won’t be imported", isOn: $exchange.acknowledgedExclusions).accessibilityIdentifier("transfer-acknowledge")
            } header: { Text("Won’t be imported") }
            .listRowBackground(Theme.surface)
        }

        if !plan.notices.isEmpty {
            Section("Kept differently") {
                ForEach(plan.notices) { issue in issueRow(issue, symbol: "info.circle", tint: Theme.secondary) }
            }.listRowBackground(Theme.surface)
        }

        if !plan.records.isEmpty {
            Section {
                HStack {
                    Button("Select all") { exchange.selectAll(true) }.disabled(exchange.selection.count == plan.records.count)
                    Spacer()
                    Button("Select none") { exchange.selectAll(false) }.disabled(exchange.selection.isEmpty)
                }.buttonStyle(.borderless)
                ForEach(plan.records) { record in recordRow(record) }
            } header: { Text("\(exchange.selection.count) of \(plan.records.count) selected") }
            .listRowBackground(Theme.surface)
        }

        Section {
            if let error = exchange.error { Text(error).foregroundStyle(.orange).accessibilityIdentifier("transfer-error") }
            Button { exchange.importSelected(session: session) } label: {
                Text("Import \(count(exchange.selection.count, "item"))").frame(maxWidth: .infinity).padding(.vertical, 6)
            }
                .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.background)
                .fontWeight(.semibold)
                .disabled(!exchange.canImport(into: session.vaults))
                .accessibilityIdentifier("transfer-import")
            Text("Matching items already in this vault are skipped. If anything can’t be saved, nothing from this transfer is saved.").font(.footnote).foregroundStyle(Theme.secondary)
        }.listRowBackground(Theme.surface)
    }

    private func recordRow(_ record: CredentialExchangeRecord) -> some View {
        Toggle(isOn: Binding(get: { exchange.selection.contains(record.id) }, set: { selected in
            if selected { exchange.selection.insert(record.id) } else { exchange.selection.remove(record.id) }
        })) {
            HStack(spacing: 14) {
                Image(systemName: record.isPasskey ? "person.badge.key.fill" : "key.horizontal").foregroundStyle(Theme.accent).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title).foregroundStyle(Theme.ink)
                    if !record.subtitle.isEmpty { Text(record.subtitle).font(.caption).foregroundStyle(Theme.secondary).lineLimit(1).privacySensitive() }
                    Text(record.contents.joined(separator: " · ")).font(.caption2).foregroundStyle(Theme.secondary)
                }
            }
        }
        .accessibilityLabel("\(record.title), \(record.isPasskey ? "passkey" : "login")")
        .accessibilityValue(record.contents.joined(separator: ", "))
    }

    private func issueRow(_ issue: CredentialExchangeIssue, symbol: String, tint: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(issue.source).foregroundStyle(Theme.ink)
                Text(issue.message).font(.caption).foregroundStyle(Theme.secondary)
            }
        } icon: { Image(systemName: symbol).foregroundStyle(tint) }
        .accessibilityElement(children: .combine)
    }

    private func count(_ value: Int, _ noun: String) -> String { "\(value) \(noun)\(value == 1 ? "" : "s")" }
}

struct CredentialExchangeBanner: View {
    @EnvironmentObject var session: VaultSession
    @EnvironmentObject var exchange: CredentialExchangeCoordinator

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square").foregroundStyle(Theme.accent).accessibilityHidden(true)
            Text(session.isConfigured ? "Unlock your vault to receive your transfer from Passwords." : "Create your vault to receive your transfer from Passwords.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Cancel") { exchange.cancel(session: session) }.font(.callout.weight(.semibold))
        }
        .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16).padding(.top, 8)
        .accessibilityElement(children: .contain)
    }
}

struct PasswordsTransferGuide: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Bring everything from Passwords.").font(.system(.title, design: .serif, weight: .medium))
                    Text("Apple Passwords can hand your passwords, verification codes, and passkeys directly to Deadbolt. No file is created along the way.").foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.background)
                Section("In the Passwords app") {
                    step(1, "Open Passwords and tap the More button (•••).")
                    step(2, "Choose Export Data to Another App.")
                    step(3, "Select the items to move, then tap Continue.")
                    step(4, "Choose Deadbolt. Deadbolt opens and asks you to unlock first.")
                    step(5, "Pick a vault, review what will be imported, then tap Import.")
                }.listRowBackground(Theme.surface)
                Section {
                    Label("Set up your Deadbolt vault before starting a transfer. After choosing Deadbolt, unlock promptly and keep it open until the review appears.", systemImage: "lock.open")
                    Label("If Deadbolt isn’t listed, turn it on in Settings → General → AutoFill & Passwords.", systemImage: "info.circle")
                    Label("Anything Deadbolt can’t store, such as passkeys that use extensions, payment cards, or Wi-Fi networks, is listed before you import and stays in Passwords.", systemImage: "exclamationmark.triangle")
                    Label("Your items aren’t removed from Passwords.", systemImage: "checkmark.shield")
                }.font(.callout).foregroundStyle(Theme.secondary).listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Transfer from Passwords").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)").font(.system(.headline, design: .rounded).monospacedDigit()).foregroundStyle(Theme.accent).accessibilityHidden(true)
            Text(text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}
