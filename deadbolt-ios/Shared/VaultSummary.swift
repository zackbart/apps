import Foundation

struct VaultSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init?(_ object: [String: Any]) {
        guard let id = object["id"] as? String, let name = object["name"] as? String else { return nil }
        self.init(id: id, name: name)
    }
}

protocol VaultEngineAccess: Sendable {
    func perform(_ operation: String, _ arguments: [String: Any]) async throws -> Any
    func entries() async throws -> [VaultEntry]
    func publishIdentities(_ entries: [VaultEntry]) async throws
    func enqueueLock()
}

extension VaultEngineAccess {
    func perform(_ operation: String) async throws -> Any { try await perform(operation, [:]) }
}

struct VaultImportSummary: Equatable, Sendable {
    let imported: Int
    let skipped: Int
    var total: Int { imported + skipped }
}
