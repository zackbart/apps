import XCTest
@testable import Deadbolt

final class RequestAdmissionTests: XCTestCase {
    func testCancelledQueuedRequestNeverStarts() {
        let request = RequestAdmission()
        request.cancel()
        XCTAssertFalse(request.begin())
    }

    func testStartedMutationCannotStartTwiceAfterCancellation() {
        let request = RequestAdmission()
        XCTAssertTrue(request.begin())
        request.cancel()
        XCTAssertFalse(request.begin())
    }

    func testSameNamedVaultsHaveDistinctPickerLabels() {
        let first = VaultSummary(id: "abcdef111111", name: "personal")
        let second = VaultSummary(id: "fedcba222222", name: "personal")
        let vaults = [first, second]
        XCTAssertNotEqual(VaultDisplay.name(first, among: vaults), VaultDisplay.name(second, among: vaults))
        XCTAssertEqual(VaultDisplay.name(first, among: [first]), "personal")
    }

    func testCredentialSearchMatchesTermsAcrossFieldsWithoutSearchingSecrets() {
        XCTAssertTrue(CredentialSearch.matches("alice example", values: ["Alice", "example.com"]))
        XCTAssertTrue(CredentialSearch.matches("cafe", values: ["Café account"]))
        XCTAssertFalse(CredentialSearch.matches("alice attacker", values: ["alice", "example.com"]))
        XCTAssertTrue(CredentialSearch.matches("  ", values: []))
    }
}
