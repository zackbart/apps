import SwiftUI
import Security
import AuthenticationServices

struct PasswordFactory {
    static func make(length: Int, symbols: Bool) -> String {
        let alphabet = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789" + (symbols ? "!@#$%&*+-=?" : ""))
        var result = ""
        while result.count < length {
            var value: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &value) == errSecSuccess else { return "" }
            let limit = 256 - 256 % alphabet.count
            if Int(value) < limit { result.append(alphabet[Int(value) % alphabet.count]) }
        }
        return result
    }
}

struct GeneratorView: View {
    @State private var length = 24.0
    @State private var symbols = true
    @State private var password = PasswordFactory.make(length: 24, symbols: true)
    @State private var copied = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Text("Hard to guess.\nEasy to keep.").font(.system(.largeTitle, design: .serif, weight: .medium)).padding(.top, 28)
                    Text(password.isEmpty ? "Password unavailable" : password).font(.system(.title2, design: .monospaced, weight: .medium)).lineSpacing(8).privacySensitive().fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading).padding(24).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    VStack(spacing: 24) {
                        HStack { Text("Length"); Spacer(); Text("\(Int(length)) characters").foregroundStyle(Theme.secondary).monospacedDigit() }
                        Slider(value: $length, in: 12...64, step: 1).accessibilityLabel("Password length").accessibilityValue("\(Int(length)) characters").onChange(of: length) { _, _ in generate() }
                        Toggle("Allow symbols", isOn: $symbols).onChange(of: symbols) { _, _ in generate() }
                    }
                    Button { generate() } label: { Label("Generate again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity).padding(12) }.buttonStyle(.bordered)
                    Button {
                        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: password]], options: [.expirationDate: Date().addingTimeInterval(45), .localOnly: true]); copied = true
                    } label: { Label(copied ? "Copied for 45 seconds" : "Copy password", systemImage: copied ? "checkmark" : "doc.on.doc").frame(maxWidth: .infinity).padding(12) }.buttonStyle(.borderedProminent).foregroundStyle(Theme.background).disabled(password.isEmpty)
                    if let error { Text(error).font(.callout).foregroundStyle(.orange) }
                    Text("Created using your device’s secure random generator. Clipboard copies expire after 45 seconds.").font(.footnote).foregroundStyle(Theme.secondary)
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(Theme.background).navigationTitle("Generator").navigationBarTitleDisplayMode(.inline)
                .task(id: copied) {
                    guard copied else { return }
                    do { try await Task.sleep(for: .seconds(45)); copied = false } catch { }
                }
        }
    }
    private func generate() {
        let generated = PasswordFactory.make(length: Int(length), symbols: symbols)
        guard !generated.isEmpty else { error = "Your device couldn’t generate a secure password. Try again."; return }
        password = generated
        copied = false
        error = nil
    }
}

struct SettingsView: View {
    @EnvironmentObject var session: VaultSession
    @State private var message: String?
    @State private var importing = false
    @State private var transferGuide = false
    @State private var enrolled = DeviceKey.isEnrolled
    @State private var authenticationWorking = false
    @State private var disabling = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 20) { BoltMark(); VStack(alignment: .leading, spacing: 6) { Text("Deadbolt").font(.title2.weight(.semibold)); Text("A vault of your own.").foregroundStyle(Theme.secondary) } }.padding(.vertical, 12)
                }.listRowBackground(Theme.background)
                Section("Unlocking") {
                    Button {
                        authenticationWorking = true
                        Task {
                            defer { authenticationWorking = false }
                            do { try await session.enableDeviceAuthentication(); enrolled = DeviceKey.isEnrolled; message = "Device unlock is enabled. Use your device authentication to unlock this vault." }
                            catch { message = error.localizedDescription }
                        }
                    } label: { Label(enrolled ? "Reconfigure device unlock" : "Enable device unlock", systemImage: "faceid") }.disabled(authenticationWorking)
                    if enrolled { Button("Disable device unlock", role: .destructive) { disabling = true }.disabled(authenticationWorking) }
                    if authenticationWorking { ProgressView("Updating device unlock…") }
                    Label("Locks when you leave the app", systemImage: "lock.fill").foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.surface)
                Section("Passwords & passkeys") {
                    Text("Use saved passwords and create passkeys in Safari and other apps.")
                    Button("Open AutoFill settings") {
                        ASSettingsHelper.openCredentialProviderAppSettings { error in
                            if let error { Task { @MainActor in message = "AutoFill settings couldn’t open: \(error.localizedDescription)" } }
                        }
                    }
                    Text("Turn on Deadbolt under Settings → General → AutoFill & Passwords, including passkey creation. Device unlock must be enabled before filling.").font(.footnote).foregroundStyle(Theme.secondary)
                }.listRowBackground(Theme.surface)
                Section("Your data") {
                    if #available(iOS 26.0, *) {
                        Button { transferGuide = true } label: { Label("Transfer from Apple Passwords", systemImage: "key.viewfinder") }
                            .accessibilityIdentifier("passwords-transfer")
                    }
                    Button { importing = true } label: { Label("Import passwords from CSV", systemImage: "square.and.arrow.down") }.disabled(session.vaults.isEmpty)
                    if session.vaults.isEmpty { Text("Create or join a vault in the Vault tab before importing passwords.").font(.footnote).foregroundStyle(Theme.secondary) }
                }.listRowBackground(Theme.surface)
                Section("Security") {
                    Label("Encrypted vault on this device", systemImage: "externaldrive.badge.checkmark")
                    Label("Clipboard expires in 45 seconds", systemImage: "doc.on.clipboard")
                    Button("Lock vault now") { session.lock() }.disabled(authenticationWorking)
                }.listRowBackground(Theme.surface)
                Section { Text("Keep your master password safe. Deadbolt cannot recover it for you.").font(.footnote).foregroundStyle(Theme.secondary) }.listRowBackground(Theme.background)
            }.scrollContentBackground(.hidden).background(Theme.background).navigationTitle("Settings")
                .sheet(isPresented: $importing) { ImportView() }
                .sheet(isPresented: $transferGuide) { PasswordsTransferGuide() }
                .onAppear { enrolled = DeviceKey.isEnrolled }
                .confirmationDialog("Disable device unlock?", isPresented: $disabling, titleVisibility: .visible) {
                    Button("Disable device unlock", role: .destructive) {
                        authenticationWorking = true
                        Task {
                            defer { authenticationWorking = false }
                            do { try await session.disableDeviceAuthentication(); enrolled = DeviceKey.isEnrolled; message = "Device unlock disabled." }
                            catch { message = error.localizedDescription }
                        }
                    }
                } message: { Text("You’ll need your master password to unlock. AutoFill will be unavailable until device unlock is enabled again.") }
                .alert("Deadbolt", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
        }
    }
}
