import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var session: VaultSession
    @State private var devices: [[String: Any]] = []
    @State private var code = ""
    @State private var vaultID = ""
    @State private var message: String?
    @State private var busy = false
    @State private var loading = true
    @State private var cancellingSync = false
    @State private var revoking: String?
    @State private var joining = false
    @FocusState private var enteringCode: Bool

    private var normalizedCode: String { code.lowercased().split { $0.isWhitespace || $0 == "-" }.joined(separator: "-") }
    private var validCode: Bool {
        let words = normalizedCode.split(separator: "-")
        return words.count == 5 && words.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isLetter } }
    }
    private var syncDescription: String {
        if let error = session.syncError { return error }
        switch session.syncState {
        case "running": return "Syncing with your devices…"
        case "complete": return "Last sync completed."
        case "failed": return session.syncError ?? "Sync couldn’t finish. Your local vault is available."
        default: return "Your local vault is available offline."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "laptopcomputer.and.iphone").font(.largeTitle).foregroundStyle(Theme.accent).accessibilityHidden(true)
                        Text("Your vault,\non your devices.").font(.system(.largeTitle, design: .serif, weight: .medium))
                        Text("Pair devices using a one-time code. Approve only devices you recognize.").foregroundStyle(Theme.secondary)
                    }.padding(.vertical, 20)
                }.listRowBackground(Theme.background)
                Section("Paired devices") {
                    if loading { ProgressView("Loading devices…") }
                    else if devices.isEmpty { Text("No paired devices yet.").foregroundStyle(Theme.secondary) }
                    ForEach(Array(devices.enumerated()), id: \.offset) { _, device in
                        HStack {
                            Image(systemName: device["this"] as? Bool == true ? "iphone" : "laptopcomputer").foregroundStyle(Theme.accent).frame(width: 28).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device["name"] as? String ?? "Paired device")
                                Text(device["this"] as? Bool == true ? "This device" : (device["connected"] as? Bool == true ? "Connected" : "Offline")).font(.caption).foregroundStyle(Theme.secondary)
                            }
                        }.padding(.vertical, 4).accessibilityElement(children: .combine)
                            .swipeActions {
                                if device["this"] as? Bool != true, let id = device["id"] as? String {
                                    Button("Revoke", role: .destructive) { revoking = id }.disabled(busy)
                                }
                            }
                    }
                    Button {
                        Task { do { try await session.syncNow() } catch { message = error.localizedDescription } }
                    } label: {
                        Label(session.syncState == "running" ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath")
                    }.disabled(busy || session.syncState == "running" || session.vaults.isEmpty)
                    Text(syncDescription).font(.footnote).foregroundStyle(session.syncState == "failed" || session.syncError != nil ? .orange : Theme.secondary)
                    if session.syncState == "running" {
                        Button(cancellingSync ? "Cancelling…" : "Cancel sync") {
                            cancellingSync = true
                            Task {
                                defer { cancellingSync = false }
                                do { try await session.cancelSync() } catch { message = error.localizedDescription }
                            }
                        }.disabled(cancellingSync)
                    }
                }.listRowBackground(Theme.surface)
                Section { Button("Join another vault") { joining = true }.disabled(busy) }.listRowBackground(Theme.surface)
                if !session.vaults.isEmpty {
                    Section("Approve a new device") {
                        Text("On the new device, choose “Join an existing vault.” Enter its code and select the vault to share.").font(.callout).foregroundStyle(Theme.secondary)
                        Picker("Share vault", selection: $vaultID) {
                            Text("Choose a vault").tag("")
                            ForEach(session.vaults) { vault in Text(VaultDisplay.name(vault, among: session.vaults)).tag(vault.id) }
                        }.disabled(busy).accessibilityIdentifier("approval-vault")
                        TextField("Five-word pairing code", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.asciiCapable).focused($enteringCode).submitLabel(.go).onSubmit(approve)
                            .disabled(busy).accessibilityIdentifier("approval-code")
                        if !code.isEmpty && !validCode { Text("Enter all five words, separated by hyphens or spaces.").font(.footnote).foregroundStyle(Theme.secondary) }
                        Button(busy ? "Approving…" : "Approve device", action: approve).disabled(busy || !validCode || vaultID.isEmpty)
                    }.listRowBackground(Theme.surface)
                }
                if busy { ProgressView("Connecting…").listRowBackground(Theme.background) }
                if let message { Text(message).font(.callout).foregroundStyle(Theme.secondary).listRowBackground(Theme.background).accessibilityIdentifier("device-result") }
            }.scrollContentBackground(.hidden).background(Theme.background).navigationTitle("Devices")
                .sheet(isPresented: $joining, onDismiss: { Task { await load() } }) { NavigationStack { JoinDeviceView() } }
                .confirmationDialog("Revoke this device?", isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }), titleVisibility: .visible) {
                    Button("Revoke device", role: .destructive) {
                        if let id = revoking { perform { _ = try await session.operation("remove_device", arguments: ["id": id]); message = "Device access revoked." } }
                        revoking = nil
                    }
                } message: { Text("It will lose access to future updates from all your vaults. Data already stored on that device cannot be erased remotely.") }
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { enteringCode = false } } }
                .task { selectOnlyVault(); await load() }
                .onChange(of: session.vaults) { _, _ in selectOnlyVault() }
                .refreshable { await load() }
        }
    }

    private func selectOnlyVault() {
        if !session.vaults.contains(where: { $0.id == vaultID }) { vaultID = session.vaults.count == 1 ? session.vaults[0].id : "" }
    }
    private func approve() {
        guard !busy, validCode, !vaultID.isEmpty else { return }
        enteringCode = false
        let pairingCode = normalizedCode
        let selectedVault = vaultID
        perform {
            _ = try await session.operation("approve", arguments: ["code": pairingCode, "vault_id": selectedVault])
            code = ""
            message = "Device approved. Keep both devices open until the vault finishes transferring."
        }
    }
    private func load() async {
        defer { loading = false }
        do { devices = try await session.operation("devices") as? [[String: Any]] ?? [] }
        catch { message = "Devices couldn’t load: \(error.localizedDescription)" }
    }
    private func perform(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do { try await action(); await load() }
            catch { message = error.localizedDescription }
        }
    }
}

struct JoinDeviceView: View {
    @EnvironmentObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var code: String?
    @State private var message: String?
    @State private var state = "idle"
    @State private var working = false
    @State private var password = ""
    @State private var confirmation = ""
    @State private var prepared = false
    @State private var attempt = UUID()
    @State private var startTask: Task<Void, Never>?
    @FocusState private var focus: Field?
    private enum Field { case password, confirmation }
    private var needsPassword: Bool { !session.isUnlocked && !prepared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                BoltMark().padding(.top, 30)
                Text("Bring your\nvault along.").font(.system(.largeTitle, design: .serif, weight: .medium))
                Text("Keep your other device open and unlocked. In its Devices screen, approve this iPhone using the code below.").foregroundStyle(Theme.secondary)
                if let code {
                    Text(code).font(.system(.title2, design: .monospaced, weight: .medium)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(24).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityIdentifier("pairing-code")
                    Label(state == "failed" ? "Pairing ended" : state == "complete" ? "Finishing setup…" : "Waiting for approval", systemImage: state == "failed" ? "exclamationmark.circle" : state == "complete" ? "checkmark.circle" : "antenna.radiowaves.left.and.right")
                        .foregroundStyle(state == "failed" ? .orange : Theme.accent)
                } else if needsPassword {
                    Text("First, choose a long, unique master password for this device. It can differ from your other devices.").font(.callout).foregroundStyle(Theme.secondary)
                    VStack(spacing: 16) {
                        SecureField("Master password", text: $password).textContentType(.newPassword).accessibilityIdentifier("join-password")
                            .focused($focus, equals: .password).submitLabel(.next).onSubmit { focus = .confirmation }
                        Divider()
                        SecureField("Confirm master password", text: $confirmation).textContentType(.newPassword).accessibilityIdentifier("join-confirmation")
                            .focused($focus, equals: .confirmation).submitLabel(.go).onSubmit(start)
                    }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16)).disabled(working)
                    if !confirmation.isEmpty && password != confirmation { Text("The passwords don’t match.").font(.footnote).foregroundStyle(.orange) }
                }
                if code == nil || state == "failed" {
                    Button(working ? "Connecting…" : state == "failed" ? "Try a new code" : "Get pairing code", action: start)
                        .buttonStyle(.borderedProminent).foregroundStyle(Theme.background).controlSize(.large).disabled(working || (needsPassword && (password.isEmpty || password != confirmation)))
                }
                if working || state == "complete" { ProgressView(state == "complete" ? "Opening your vault…" : "Connecting securely…") }
                if let message { Text(message).foregroundStyle(.orange).font(.callout).accessibilityIdentifier("pairing-error") }
                Text("A pairing code grants access to your vault. Share it only between devices you control.").font(.footnote).foregroundStyle(Theme.secondary)
            }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).background(Theme.background).navigationTitle("Join a vault").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityLabel("Cancel pairing") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = nil } }
            }
            .onDisappear(perform: cancel)
            .onChange(of: phase) { _, phase in if phase == .background { password = ""; confirmation = ""; dismiss() } }

    }

    private func start() {
        guard !working, !needsPassword || (!password.isEmpty && password == confirmation) else { return }
        focus = nil
        working = true
        message = nil
        code = nil
        state = "idle"
        attempt = UUID()
        let currentAttempt = attempt
        let masterPassword = password
        let preparing = needsPassword
        startTask = Task {
            defer { if attempt == currentAttempt { working = false } }
            do {
                guard !Task.isCancelled, attempt == currentAttempt else { return }
                if preparing {
                    try await session.prepareToJoin(password: masterPassword)
                    prepared = true
                    password = ""
                    confirmation = ""
                }
                guard !Task.isCancelled, attempt == currentAttempt else { return }
                let result = try await session.operation("join_start") as? [String: Any] ?? [:]
                guard !Task.isCancelled, attempt == currentAttempt else { return }
                guard let value = result["code"] as? String else { throw VaultFailure.unavailable("A pairing code couldn’t be created. Try again.") }
                state = result["state"] as? String ?? "waiting"
                code = value
                working = false
                try await monitor(currentAttempt)
            } catch {
                guard !Task.isCancelled, attempt == currentAttempt else { return }
                state = "failed"
                message = error.localizedDescription
            }
        }
    }

    private func monitor(_ currentAttempt: UUID) async throws {
        while !Task.isCancelled && state == "waiting" {
            try await Task.sleep(for: .seconds(2))
            let result = try await session.operation("pairing_status") as? [String: Any] ?? [:]
            guard !Task.isCancelled, attempt == currentAttempt else { return }
            state = result["state"] as? String ?? "failed"
            message = result["error"] as? String
            if state == "complete" { try await session.finishJoin(); dismiss(); return }
            if state != "waiting" { state = "failed"; message = message ?? "Pairing ended. Request a new code and try again." }
        }
    }

    private func cancel() {
        startTask?.cancel()
        attempt = UUID()
        password = ""
        confirmation = ""
        guard state != "complete" else { return }
        let shouldLock = !session.isUnlocked
        Task { _ = try? await session.operation("pair_cancel"); if shouldLock { session.lock() } }
    }
}
