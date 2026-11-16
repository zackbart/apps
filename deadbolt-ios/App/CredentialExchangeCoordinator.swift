import AuthenticationServices
import Foundation

@MainActor
final class CredentialExchangeCoordinator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForVault
        case loading
        case review
        case importing
        case finished(VaultImportSummary)
        case failed(String)
    }

    static var activityType: String {
        if #available(iOS 26.0, *) { return ASCredentialExchangeActivity }
        return "ASCredentialExchangeActivity"
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var plan: CredentialExchangePlan?
    @Published var selection: Set<Int> = []
    @Published var destinationID = ""
    @Published var acknowledgedExclusions = false
    @Published var error: String?
    private var token: UUID?
    private var queued: UUID?
    private var generation = 0
    private var task: Task<Void, Never>?
    private let fetch: @Sendable (UUID) async throws -> CredentialExchangePlan

    init(fetch: @escaping @Sendable (UUID) async throws -> CredentialExchangePlan = { try await CredentialExchangeCoordinator.liveFetch($0) }) {
        self.fetch = fetch
    }

    nonisolated static func liveFetch(_ token: UUID) async throws -> CredentialExchangePlan {
        guard #available(iOS 26.0, *) else { throw VaultFailure.unavailable("Transfers from Passwords need iOS 26 or later.") }
        let data = try await ASCredentialImportManager().importCredentials(token: token)
        return await Task.detached(priority: .userInitiated) { CredentialExchangeConverter.plan(CredentialExchangeSource.Export(data)) }.value
    }

    nonisolated static func token(from activity: NSUserActivity) -> UUID? {
        guard #available(iOS 26.0, *), activity.activityType == ASCredentialExchangeActivity else { return nil }
        let value = activity.userInfo?[ASCredentialImportToken]
        return value as? UUID ?? (value as? String).flatMap(UUID.init(uuidString:))
    }

    var isPresenting: Bool { phase != .idle }

    var selectedRecords: [CredentialExchangeRecord] { plan?.records.filter { selection.contains($0.id) } ?? [] }

    func canImport(into vaults: [VaultSummary]) -> Bool {
        guard phase == .review, let plan, !selection.isEmpty, vaults.contains(where: { $0.id == destinationID }) else { return false }
        return plan.excluded.isEmpty || acknowledgedExclusions
    }

    func receive(_ token: UUID, session: VaultSession) {
        if phase == .importing { queued = token; return }
        reset()
        self.token = token
        phase = .waitingForVault
        resume(session: session)
    }

    func resume(session: VaultSession) {
        guard phase == .waitingForVault, session.isUnlocked, let token else { return }
        self.token = nil
        phase = .loading
        let current = generation
        let fetch = fetch
        task = Task {
            do {
                let plan = try await fetch(token)
                guard current == generation, phase == .loading, session.isUnlocked else { return }
                present(plan, vaults: session.vaults)
            } catch {
                guard current == generation, phase == .loading else { return }
                task = nil
                phase = .failed("The transfer couldn’t finish. Start it again from Passwords, then keep Deadbolt open while you unlock. Your items are still in Passwords.")
            }
        }
    }

    private func present(_ plan: CredentialExchangePlan, vaults: [VaultSummary]) {
        task = nil
        self.plan = plan
        selection = Set(plan.records.map(\.id))
        destinationID = vaults.count == 1 ? vaults[0].id : ""
        acknowledgedExclusions = false
        error = nil
        phase = .review
    }

    func selectAll(_ selected: Bool) {
        selection = selected ? Set(plan?.records.map(\.id) ?? []) : []
    }

    func importSelected(session: VaultSession) {
        guard canImport(into: session.vaults) else { return }
        let records = selectedRecords
        let vaultID = destinationID
        let current = generation
        error = nil
        phase = .importing
        task = Task {
            do {
                let summary = try await session.importCredentialExchange(records, vaultID: vaultID)
                guard current == generation else { return }
                clear()
                phase = .finished(summary)
            } catch {
                guard current == generation, phase == .importing else { return }
                task = nil
                self.error = error is CancellationError ? "The import was interrupted. Try again; items already saved will be skipped." : "\(error.localizedDescription) Review your selection and try again; items already saved will be skipped."
                phase = .review
            }
        }
    }

    func cancel(session: VaultSession) {
        guard phase != .importing else { return }
        close(session: session)
    }

    func close(session: VaultSession) {
        reset()
        phase = .idle
        if let next = queued {
            queued = nil
            receive(next, session: session)
        }
    }

    func protect() {
        switch phase {
        case .loading, .review:
            reset()
            phase = .failed("Deadbolt locked, so the transfer was cleared. Nothing was imported. Start it again from Passwords.")
        case .importing:
            reset()
            phase = .failed("Deadbolt locked while importing. Start the transfer again from Passwords; items that were already saved will be skipped.")
        case .idle, .waitingForVault, .finished, .failed:
            break
        }
        if let next = queued {
            queued = nil
            reset()
            token = next
            phase = .waitingForVault
        }
    }

    private func clear() {
        task = nil
        plan = nil
        selection = []
        destinationID = ""
        acknowledgedExclusions = false
        error = nil
    }

    private func reset() {
        generation += 1
        task?.cancel()
        token = nil
        clear()
    }
}
