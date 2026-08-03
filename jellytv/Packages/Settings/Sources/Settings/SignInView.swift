import SwiftUI
import JellyfinAPI

fileprivate enum FocusField: Hashable {
    case serverURL, username, password
}

public struct SignInView: View {
    @State private var model: SignInModel

    public init(model: SignInModel) {
        self._model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            switch model.state {
            case .enteringServerURL, .validatingServer, .failed:
                ServerURLEntryView(model: model)
            case .chooseMode(let serverName):
                ChooseModeView(serverName: serverName, model: model)
            case .quickConnectStarting:
                ProgressView("Starting Quick Connect\u{2026}")
            case .quickConnect(let code, _):
                QuickConnectCodeView(code: code, model: model)
            case .enteringPassword, .authenticating:
                PasswordSignInView(model: model)
            case .signedIn(let user):
                SignedInPlaceholderView(user: user)
            }
        }
        .padding(80)
    }
}

// MARK: - ServerURLEntryView

private struct ServerURLEntryView: View {
    @Bindable var model: SignInModel
    @FocusState private var focus: FocusField?

    var body: some View {
        VStack(spacing: 40) {
            Text("Connect to your Jellyfin server")
                .font(.title)
                .multilineTextAlignment(.center)

            TextField("http://192.168.1.50:8096", text: $model.serverURLInput)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .focused($focus, equals: .serverURL)
                .onSubmit {
                    Task { await model.connectToServer() }
                }

            if case .failed(let err) = model.state {
                Text(err.message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Connect") {
                Task { await model.connectToServer() }
            }
            .disabled(model.state == .validatingServer)
        }
        .task { focus = .serverURL }
    }
}

// MARK: - ChooseModeView

private struct ChooseModeView: View {
    let serverName: String
    let model: SignInModel

    @Namespace private var ns

    var body: some View {
        VStack(spacing: 40) {
            Text("Sign in to \(serverName)")
                .font(.title)

            Button("Use Quick Connect") {
                Task { await model.chooseQuickConnect() }
            }
            .prefersDefaultFocus(in: ns)

            Button("Sign in with username & password") {
                model.choosePassword()
            }
        }
        .focusScope(ns)
    }
}

// MARK: - QuickConnectCodeView

private struct QuickConnectCodeView: View {
    let code: String
    let model: SignInModel

    var body: some View {
        VStack(spacing: 32) {
            Text(code)
                .font(.system(size: 96, weight: .bold, design: .monospaced))

            Text("Open Jellyfin in your browser, go to your profile, and enter this code.")
                .multilineTextAlignment(.center)
                .font(.body)

            ProgressView()

            Button("Cancel") {
                model.cancelQuickConnect()
            }
        }
    }
}

// MARK: - PasswordSignInView

private struct PasswordSignInView: View {
    @Bindable var model: SignInModel
    @FocusState private var focus: FocusField?

    var body: some View {
        VStack(spacing: 32) {
            Text("Sign in")
                .font(.title)

            TextField("Username", text: $model.username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .focused($focus, equals: .username)
                .onSubmit { focus = .password }

            SecureField("Password", text: $model.password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .onSubmit {
                    Task { await model.signInWithPassword() }
                }

            if case .failed(let err) = model.state {
                Text(err.message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Sign In") {
                Task { await model.signInWithPassword() }
            }
            .disabled(model.state == .authenticating)
        }
        .task { focus = .username }
    }
}

// MARK: - SignedInPlaceholderView

struct SignedInPlaceholderView: View {
    let user: UserDto

    var body: some View {
        VStack(spacing: 24) {
            Text("Signed in as \(user.name)")
                .font(.title)
            Text("Phase 1.5 wires this to a real Sign Out button.")
                .foregroundStyle(.secondary)
        }
    }
}
