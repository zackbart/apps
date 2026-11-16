import SwiftUI

@main
struct DeadboltApp: App {
    @StateObject private var session = VaultSession()
    @StateObject private var exchange = CredentialExchangeCoordinator()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            DeadboltRoot()
                .environmentObject(session)
                .environmentObject(exchange)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .overlay { if phase != .active { Theme.background.ignoresSafeArea().overlay { BoltMark() }.accessibilityLabel("Vault protected") } }
                .onChange(of: phase) { _, phase in
                    if phase == .background { session.lock(); exchange.protect() }
                    if phase == .active { session.scheduleSync() }
                }
                .onChange(of: session.isUnlocked) { _, unlocked in
                    if unlocked { exchange.resume(session: session) } else { exchange.protect() }
                }
                .onContinueUserActivity(CredentialExchangeCoordinator.activityType) { activity in
                    if let token = CredentialExchangeCoordinator.token(from: activity) { exchange.receive(token, session: session) }
                }
        }
    }
}

enum Theme {
    static let background = Color(red: 0.075, green: 0.085, blue: 0.083)
    static let surface = Color(red: 0.12, green: 0.135, blue: 0.13)
    static let accent = Color(red: 0.76, green: 0.84, blue: 0.55)
    static let ink = Color(red: 0.94, green: 0.93, blue: 0.87)
    static let secondary = Color(red: 0.64, green: 0.68, blue: 0.64)
}

struct BoltMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25).fill(Theme.surface)
            RoundedRectangle(cornerRadius: 14).stroke(Theme.secondary.opacity(0.35), lineWidth: 1).padding(12)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(Theme.accent).frame(width: 32, height: 13)
                RoundedRectangle(cornerRadius: 4).fill(Theme.ink).frame(width: 20, height: 34)
            }
        }.frame(width: 90, height: 90).accessibilityHidden(true)
    }
}

struct DeadboltRoot: View {
    @EnvironmentObject var session: VaultSession
    @EnvironmentObject var exchange: CredentialExchangeCoordinator
    var body: some View {
        Group {
            if session.isInitializing {
                VStack(spacing: 24) { BoltMark(); ProgressView("Opening Deadbolt…").tint(Theme.accent) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = session.initializationError {
                ContentUnavailableView { Label("Deadbolt couldn’t open", systemImage: "lock.trianglebadge.exclamationmark") } description: { Text(error + "\nClose and reopen the app to try again.") }
            } else if session.isUnlocked {
                if exchange.isPresenting { CredentialExchangeView() } else { MainView() }
            } else {
                UnlockView().safeAreaInset(edge: .top) { if exchange.phase == .waitingForVault { CredentialExchangeBanner() } }
            }
        }.foregroundStyle(Theme.ink)
            .background(Theme.background.ignoresSafeArea())
    }
}

struct UnlockView: View {
    @EnvironmentObject var session: VaultSession
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?
    @State private var working = false
    @State private var joining = false
    @FocusState private var focusedField: Field?
    private enum Field { case password, confirmation }
    @Environment(\.scenePhase) private var phase
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 36

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { BoltMark(); Spacer() }
                    .padding(.top, 45)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Deadbolt").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(session.isConfigured ? "Your vault.\nWithin reach." : "A place for\nyour private life.")
                        .font(.system(size: headlineSize, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    Text(session.isConfigured ? "Unlock your passwords on this device." : "Create an encrypted vault. Your master password is the key—keep it somewhere safe.")
                        .font(.body).foregroundStyle(Theme.secondary).padding(.top, 4)
                }
                VStack(spacing: 14) {
                    SecureField("Master password", text: $password)
                        .textContentType(session.isConfigured ? .password : .newPassword)
                        .accessibilityIdentifier("master-password").accessibilityLabel("Master password").privacySensitive()
                        .focused($focusedField, equals: .password)
                        .submitLabel(session.isConfigured ? .go : .next)
                        .onSubmit { if session.isConfigured { submit() } else { focusedField = .confirmation } }
                    if !session.isConfigured {
                        Divider()
                        SecureField("Confirm master password", text: $confirmation).textContentType(.newPassword)
                            .accessibilityIdentifier("confirm-password").accessibilityLabel("Confirm master password").privacySensitive()
                            .focused($focusedField, equals: .confirmation)
                            .submitLabel(.go).onSubmit(submit)
                    }
                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16)).disabled(working)
                if !session.isConfigured { Text("Use a long, unique password. Deadbolt can’t recover it for you.").font(.footnote).foregroundStyle(Theme.secondary) }
                if let error { Text(error).foregroundStyle(.orange).font(.callout) }
                Button(action: submit) {
                    HStack { Text(session.isConfigured ? "Unlock vault" : "Create vault"); Spacer(); if working { ProgressView() } else { Image(systemName: "arrow.right") } }
                        .fontWeight(.semibold).padding(18).foregroundStyle(Theme.background)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                }.disabled(working || session.isBusy || password.isEmpty)
                if session.isConfigured && DeviceKey.isEnrolled {
                    Button { run { try await session.unlockWithDeviceAuthentication() } } label: {
                        Label("Use device authentication", systemImage: "faceid").frame(maxWidth: .infinity).padding(10)
                    }.disabled(working || session.isBusy)
                }
                if !session.isConfigured { Button("Join an existing vault") { joining = true }.frame(maxWidth: .infinity).padding(8).disabled(working || session.isBusy) }
                Label("Encrypted here. Controlled by you.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(Theme.secondary).padding(.bottom, 24)
            }.padding(.horizontal, 28).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }
            .sheet(isPresented: $joining) { NavigationStack { JoinDeviceView() } }
            .onChange(of: phase) { _, phase in if phase == .background { password = ""; confirmation = "" } }
    }

    private func submit() {
        guard !working, !session.isBusy, !password.isEmpty else { return }
        focusedField = nil
        if !session.isConfigured && password != confirmation { error = "The passwords don’t match."; return }
        let masterPassword = password
        let configured = session.isConfigured
        run { if configured { try await session.unlock(password: masterPassword) } else { try await session.create(password: masterPassword) } }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        guard !working, !session.isBusy else { return }
        working = true
        error = nil
        Task {
            defer { working = false }
            do { try await action(); password = ""; confirmation = "" }
            catch { self.error = error.localizedDescription }
        }
    }
}
