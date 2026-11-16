import AuthenticationServices
import UIKit

final class CredentialProviderViewController: ASCredentialProviderViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private var engine: VaultEngine?
    private var entries: [VaultEntry] = []
    private var allEntries: [VaultEntry] = []
    private let showAll = UIButton(type: .system)
    private let unlockButton = UIButton(type: .system)
    private let searchBar = UISearchBar()
    private let registerButton = UIButton(type: .system)
    private var registrationVaults: [VaultSummary] = []
    private var registrationVaultID: String?
    private var searchText = ""
    private var visiblePasswords: [VaultEntry] = []
    private var visiblePasskeys: [VaultPasskey] = []
    private var services: [ASCredentialServiceIdentifier] = []
    private var vaultNames: [String: String] = [:]
    private var requestedServices: [String] {
        if !services.isEmpty { return services.map(\.identifier) }
        return passkeyParameters.map { [$0.relyingPartyIdentifier] } ?? []
    }
    private var identity: ASPasswordCredentialIdentity?
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let message = UILabel()
    private var unlocking = false
    private var generation = 0
    private var completed = false
    private var configuring = false
    private var passkeyRequest: ASPasskeyCredentialRequest?
    private var passkeyParameters: ASPasskeyCredentialRequestParameters?
    private var registeringPasskey = false
    private var passkeys: [VaultPasskey] = []
    private var expiryTask: Task<Void, Never>?
    private var signing = false
    private var authentication: DeviceAuthentication?

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(red: 0.075, green: 0.085, blue: 0.083, alpha: 1)
        view.tintColor = UIColor(red: 0.76, green: 0.84, blue: 0.55, alpha: 1)
        table.backgroundColor = view.backgroundColor
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(cancelRequest), for: .touchUpInside)
        unlockButton.setTitle("Unlock Deadbolt", for: .normal)
        unlockButton.addTarget(self, action: #selector(unlockVault), for: .touchUpInside)
        searchBar.placeholder = "Search accounts or websites"
        searchBar.delegate = self
        searchBar.isHidden = true
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.searchBarStyle = .minimal
        registerButton.setTitle("Create passkey", for: .normal)
        registerButton.addTarget(self, action: #selector(registerSelectedPasskey), for: .touchUpInside)
        registerButton.isHidden = true
        registerButton.isEnabled = false
        showAll.setTitle("Choose another login", for: .normal)
        showAll.addTarget(self, action: #selector(showAllLogins), for: .touchUpInside)
        showAll.isHidden = true
        message.text = "Authenticate to fill a password. Enable device unlock in Deadbolt first."
        for button in [cancel, unlockButton, showAll, registerButton] {
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0
        message.textAlignment = .center
        message.textColor = .secondaryLabel
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        table.register(UITableViewCell.self, forCellReuseIdentifier: "credential")
        let stack = UIStackView(arrangedSubviews: [cancel, message, unlockButton, showAll, searchBar, registerButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let header = UIView()
        header.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16), stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16), stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 16), stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16)])
        table.tableHeaderView = header
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([table.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), table.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor), table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), table.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)])
        NotificationCenter.default.addObserver(self, selector: #selector(cancelRequest), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = table.tableHeaderView else { return }
        let width = table.bounds.width
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        if header.frame.width != width || abs(header.frame.height - height) > 0.5 {
            header.frame = CGRect(x: 0, y: 0, width: width, height: height)
            table.tableHeaderView = header
        }
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        services = serviceIdentifiers
        loadViewIfNeeded()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.Code.userInteractionRequired.rawValue))
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        identity = credentialIdentity
        loadViewIfNeeded()
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.Code.userInteractionRequired.rawValue))
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        if let password = credentialRequest as? ASPasswordCredentialRequest { identity = password.credentialIdentity as? ASPasswordCredentialIdentity }
        else if let passkey = credentialRequest as? ASPasskeyCredentialRequest { passkeyRequest = passkey }
        else { cancelRequest(); return }
        loadViewIfNeeded()
    }

    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        guard let passkey = registrationRequest as? ASPasskeyCredentialRequest else { cancelRequest(); return }
        passkeyRequest = passkey
        registeringPasskey = true
        loadViewIfNeeded()
        let identity = passkey.credentialIdentity as? ASPasskeyCredentialIdentity
        message.text = "Create a passkey for \(identity?.userName ?? "your account") at \(identity?.relyingPartyIdentifier ?? "this website"). Authenticate to continue."
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier], requestParameters: ASPasskeyCredentialRequestParameters) {
        services = serviceIdentifiers
        passkeyParameters = requestParameters
        loadViewIfNeeded()
    }

    override func prepareInterfaceForExtensionConfiguration() {
        configuring = true
        loadViewIfNeeded()
        message.text = "Enable device unlock in Deadbolt, then select Deadbolt in Settings → General → AutoFill & Passwords."
    }

    @objc private func unlockVault() {
        guard !unlocking else { return }
        unlocking = true
        unlockButton.isEnabled = false
        unlockButton.setTitle("Authenticating…", for: .normal)
        let current = generation
        Task { @MainActor in
            defer {
                unlocking = false
                unlockButton.isEnabled = true
                unlockButton.setTitle("Unlock Deadbolt", for: .normal)
            }
            do {
                let authentication = DeviceAuthentication()
                self.authentication = authentication
                let key = try await Task.detached { try authentication.read() }.value
                self.authentication = nil
                guard current == generation, !completed else { return }
                let engine = try VaultEngine()
                self.engine = engine
                try await unlock(engine, key: key, generation: current)
                guard current == generation, !completed else { engine.enqueueLock(); return }
                if let status = try await engine.perform("status") as? [String: Any] {
                    guard current == generation, !completed else { engine.enqueueLock(); return }
                    let vaults = (status["vaults"] as? [[String: Any]] ?? []).compactMap(VaultSummary.init)
                    vaultNames = Dictionary(vaults.map { ($0.id, VaultDisplay.name($0, among: vaults)) }, uniquingKeysWith: { first, _ in first })
                }
                unlockButton.isHidden = true
                searchBar.isHidden = false
                expiryTask?.cancel()
                expiryTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(90)) } catch { return }
                    self?.cancelRequest()
                }
                if configuring {
                    completed = true
                    clear()
                    extensionContext.completeExtensionConfigurationRequest()
                    return
                }
                if passkeyRequest != nil || passkeyParameters != nil {
                    try await handlePasskeys(engine, generation: current)
                    return
                }
                let all = try await engine.entries()
                guard current == generation, !completed else { engine.enqueueLock(); return }
                if let identity {
                    guard let entry = all.first(where: { $0.id == identity.recordIdentifier && $0.username == identity.user && CredentialDomain.matches($0.url, service: identity.serviceIdentifier.identifier) }) else {
                        throw VaultFailure.unavailable("This credential has changed. Open Deadbolt and try again.")
                    }
                    complete(entry)
                } else {
                    allEntries = CredentialSearch.sorted(all)
                    showAll.isHidden = false
                    entries = allEntries.filter { entry in services.isEmpty || services.contains { CredentialDomain.matches(entry.url, service: $0.identifier) } }
                    message.text = entries.isEmpty ? "No matching logins. Choose another login to fill a different website." : "Select a login for this website."
                    reloadPicker()
        view.setNeedsLayout()
                }
            } catch {
                guard current == generation, !completed else { return }
                clear()
                message.text = error.localizedDescription
            }
        }
    }

    private func unlock(_ engine: VaultEngine, key: String, generation current: Int) async throws {
        for attempt in 0..<4 {
            guard current == generation, !completed else { throw CancellationError() }
            do {
                _ = try await engine.perform("unlock_key", ["key": key])
                return
            } catch {
                let detail = error.localizedDescription.lowercased()
                guard attempt < 3, detail.contains("already open") || detail.contains("in use") || detail.contains("locked by") else { throw error }
                try await Task.sleep(for: .milliseconds(150 * (attempt + 1)))
            }
        }
    }

    private func reloadPicker() {
        visiblePasswords = entries.filter { CredentialSearch.matches(searchText, values: [$0.title, $0.username, $0.url]) }
        visiblePasskeys = passkeys.filter { CredentialSearch.matches(searchText, values: [$0.username, $0.relyingParty]) }
        table.reloadData()
        view.setNeedsLayout()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        reloadPicker()
        view.setNeedsLayout()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { registrationVaults.isEmpty ? visiblePasskeys.count + visiblePasswords.count : registrationVaults.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "credential", for: indexPath)
        var content = cell.defaultContentConfiguration()
        cell.accessoryType = .none
        if !registrationVaults.isEmpty {
            guard registrationVaults.indices.contains(indexPath.row) else { return cell }
            let vault = registrationVaults[indexPath.row]
            content.text = VaultDisplay.name(vault, among: registrationVaults)
            content.secondaryText = "Save passkey in this vault"
            cell.accessoryType = registrationVaultID == vault.id ? .checkmark : .none
            cell.contentConfiguration = content
            return cell
        }
        let passkeys = visiblePasskeys
        if indexPath.row < passkeys.count {
            let passkey = passkeys[indexPath.row]
            content.text = passkey.username
            content.secondaryText = ["Passkey", passkey.relyingParty, vaultNames.count > 1 ? vaultNames[passkey.vaultID] : nil].compactMap { $0 }.joined(separator: " · ")
            cell.contentConfiguration = content
            return cell
        }
        let passwords = visiblePasswords
        guard passwords.indices.contains(indexPath.row - passkeys.count) else { return cell }
        let entry = passwords[indexPath.row - passkeys.count]
        content.text = entry.title
        content.secondaryText = [entry.username, vaultNames.count > 1 ? entry.vaultID.flatMap { vaultNames[$0] } : nil].compactMap { $0 }.joined(separator: " · ")
        cell.contentConfiguration = content
        return cell
    }

    @objc private func showAllLogins() {
        entries = allEntries
        message.text = "Choose a login. Different websites require confirmation."
        reloadPicker()
        view.setNeedsLayout()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !signing, !completed else { return }
        if !registrationVaults.isEmpty {
            guard registrationVaults.indices.contains(indexPath.row) else { return }
            registrationVaultID = registrationVaults[indexPath.row].id
            registerButton.isEnabled = true
            reloadPicker()
        view.setNeedsLayout()
            return
        }
        let passkeys = visiblePasskeys
        if indexPath.row < passkeys.count {
            let passkey = passkeys[indexPath.row]
            let current = generation
            Task { @MainActor in
                do { try await assertPasskey(passkey) }
                catch {
                    guard current == generation, !completed else { return }
                    message.text = error.localizedDescription
                    view.setNeedsLayout()
                }
            }
            return
        }
        let passwords = visiblePasswords
        guard passwords.indices.contains(indexPath.row - passkeys.count) else { return }
        let entry = passwords[indexPath.row - passkeys.count]
        if requestedServices.isEmpty || requestedServices.contains(where: { CredentialDomain.matches(entry.url, service: $0) }) { complete(entry); return }
        let target = requestedServices.joined(separator: ", ")
        let alert = UIAlertController(title: "Fill on a different website?", message: "This login belongs to \(CredentialDomain.host(entry.url) ?? entry.title). The requesting service is \(target).", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Fill password", style: .destructive) { [weak self] _ in self?.complete(entry) })
        present(alert, animated: true)
    }

    private func complete(_ entry: VaultEntry) {
        guard !completed else { return }
        completed = true
        let credential = ASPasswordCredential(user: entry.username, password: entry.password)
        clear()
        extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }

    private func clear() {
        authentication?.cancel()
        authentication = nil
        expiryTask?.cancel()
        expiryTask = nil
        generation += 1
        entries.removeAll(keepingCapacity: false)
        allEntries.removeAll(keepingCapacity: false)
        vaultNames.removeAll(keepingCapacity: false)
        passkeys.removeAll(keepingCapacity: false)
        registrationVaults.removeAll(keepingCapacity: false)
        registrationVaultID = nil
        registerButton.isHidden = true
        registerButton.isEnabled = false
        showAll.isHidden = true
        searchBar.isHidden = true
        searchBar.text = nil
        searchText = ""
        searchBar.resignFirstResponder()
        unlockButton.isHidden = false
        engine?.enqueueLock()
        engine = nil
        reloadPicker()
        view.setNeedsLayout()
    }

    @objc private func cancelRequest() {
        guard !completed else { return }
        completed = true
        clear()
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.Code.userCanceled.rawValue))
    }
}

extension CredentialProviderViewController {
    private func handlePasskeys(_ engine: VaultEngine, generation current: Int) async throws {
        if registeringPasskey {
            guard let status = try await engine.perform("status") as? [String: Any] else { throw VaultFailure.unavailable("The vault list is unavailable.") }
            guard current == generation, !completed else { return }
            registrationVaults = (status["vaults"] as? [[String: Any]] ?? []).compactMap(VaultSummary.init)
            guard !registrationVaults.isEmpty else { throw VaultFailure.unavailable("Create a vault in Deadbolt before saving a passkey.") }
            searchBar.isHidden = true
            registerButton.isHidden = false
            registerButton.isEnabled = false
            let identity = passkeyRequest?.credentialIdentity as? ASPasskeyCredentialIdentity
            message.text = "Choose a vault for \(identity?.userName ?? "your account") at \(identity?.relyingPartyIdentifier ?? "this website"), then create the passkey."
            reloadPicker()
            view.setNeedsLayout()
            return
        }
        guard let rows = try await engine.perform("passkey_list") as? [[String: Any]] else { throw VaultFailure.unavailable("Passkeys are unavailable.") }
        guard current == generation, !completed else { return }
        let records = rows.compactMap(VaultPasskey.init)
        if let request = passkeyRequest, let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity {
            guard let passkey = records.first(where: { $0.relyingParty == identity.relyingPartyIdentifier && $0.credentialID == identity.credentialID && $0.userHandle == identity.userHandle }) else { throw VaultFailure.unavailable("This passkey no longer exists.") }
            try await assertPasskey(passkey)
        } else if let parameters = passkeyParameters {
            passkeys = records.filter { $0.relyingParty == parameters.relyingPartyIdentifier && (parameters.allowedCredentials.isEmpty || parameters.allowedCredentials.contains($0.credentialID)) }
            allEntries = CredentialSearch.sorted(try await engine.entries())
            guard current == generation, !completed else { return }
            entries = allEntries.filter { CredentialDomain.matches($0.url, service: parameters.relyingPartyIdentifier) }
            showAll.isHidden = allEntries.isEmpty
            message.text = passkeys.isEmpty && entries.isEmpty ? "No matching credentials for this website." : "Select a passkey or password to sign in."
            reloadPicker()
            view.setNeedsLayout()
        }
    }

    @objc private func registerSelectedPasskey() {
        guard !signing, let engine, let vaultID = registrationVaultID else { return }
        signing = true
        table.isUserInteractionEnabled = false
        registerButton.isEnabled = false
        let current = generation
        Task { @MainActor in
            defer { signing = false; table.isUserInteractionEnabled = true; registerButton.isEnabled = registrationVaultID != nil }
            do { try await registerPasskey(engine, vaultID: vaultID, generation: current) }
            catch {
                guard current == generation, !completed else { return }
                message.text = error.localizedDescription
                view.setNeedsLayout()
            }
        }
    }

    private func registerPasskey(_ engine: VaultEngine, vaultID: String, generation current: Int) async throws {
        if let request = passkeyRequest, let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity {
            guard CredentialDomain.host(identity.relyingPartyIdentifier) == identity.relyingPartyIdentifier.lowercased(), request.clientDataHash.count == 32 else { throw VaultFailure.unavailable("Invalid passkey relying party or challenge.") }
            let algorithms = request.supportedAlgorithms.map { $0.rawValue }
            guard algorithms.contains(-7) else { throw VaultFailure.unavailable("This website requires an unsupported passkey algorithm.") }
            var arguments: [String: Any] = ["rp_id": identity.relyingPartyIdentifier, "username": identity.userName, "user_handle": identity.userHandle.base64EncodedString(), "client_data_hash": request.clientDataHash.base64EncodedString(), "algorithms": algorithms, "verified": true, "vault_id": vaultID]
            if #available(iOS 18.0, *) {
                let excluded = (request.excludedCredentials ?? []).map(\.credentialID)
                arguments["exclude"] = excluded.map { $0.base64EncodedString() }
                if !excluded.isEmpty {
                    let rows = try await engine.perform("passkey_list") as? [[String: Any]] ?? []
                    guard current == generation, !completed else { return }
                    if rows.compactMap(VaultPasskey.init).contains(where: { $0.relyingParty == identity.relyingPartyIdentifier && excluded.contains($0.credentialID) }) {
                        completed = true
                        clear()
                        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.Code.matchedExcludedCredential.rawValue))
                        return
                    }
                }
            }
            guard let result = try await engine.perform("passkey_register", arguments) as? [String: Any],
                  let id = result["credential_id"] as? String, let credentialID = Data(base64Encoded: id),
                  let attestation = result["attestation_object"] as? String, let object = Data(base64Encoded: attestation) else { throw VaultFailure.unavailable("The passkey registration failed.") }
            guard current == generation, !completed else { engine.enqueueLock(); return }
            let suggestion = ASPasskeyCredentialIdentity(relyingPartyIdentifier: identity.relyingPartyIdentifier, userName: identity.userName, credentialID: credentialID, userHandle: identity.userHandle, recordIdentifier: result["id"] as? String)
            Task { try? await ASCredentialIdentityStore.shared.saveCredentialIdentities([suggestion]) }
            let credential = ASPasskeyRegistrationCredential(relyingParty: identity.relyingPartyIdentifier, clientDataHash: request.clientDataHash, credentialID: credentialID, attestationObject: object)
            completed = true
            clear()
            extensionContext.completeRegistrationRequest(using: credential, completionHandler: nil)
            return
        }
    }

    private func assertPasskey(_ passkey: VaultPasskey) async throws {
        guard let engine, !completed, !signing else { return }
        signing = true
        table.isUserInteractionEnabled = false
        defer { signing = false; table.isUserInteractionEnabled = true }
        let current = generation
        let hash = passkeyRequest?.clientDataHash ?? passkeyParameters?.clientDataHash
        guard let hash, hash.count == 32 else { throw VaultFailure.unavailable("Invalid passkey challenge.") }
        guard let result = try await engine.perform("passkey_assert", ["rp_id": passkey.relyingParty, "credential_id": passkey.credentialID.base64EncodedString(), "client_data_hash": hash.base64EncodedString(), "verified": true]) as? [String: Any],
              let rawSignature = result["signature"] as? String, let signature = Data(base64Encoded: rawSignature),
              let rawAuthenticator = result["authenticator_data"] as? String, let authenticator = Data(base64Encoded: rawAuthenticator) else { throw VaultFailure.unavailable("Passkey signing failed.") }
        guard current == generation, !completed else { engine.enqueueLock(); return }
        let credential = ASPasskeyAssertionCredential(userHandle: passkey.userHandle, relyingParty: passkey.relyingParty, signature: signature, clientDataHash: hash, authenticatorData: authenticator, credentialID: passkey.credentialID)
        completed = true
        clear()
        extensionContext.completeAssertionRequest(using: credential, completionHandler: nil)
    }
}
