import XCTest
@testable import Deadbolt

final class CredentialDomainTests: XCTestCase {
    func testRejectsInvalidHostsAndEmbeddedControls() {
        XCTAssertNil(CredentialDomain.host("https://example..com"))
        XCTAssertNil(CredentialDomain.host("https://example.com.."))
        XCTAssertNil(CredentialDomain.host("https://exa\tmple.com"))
        XCTAssertNil(CredentialDomain.host("https://example.com%00.attacker.test"))
        XCTAssertTrue(CredentialDomain.matches("https://example.com/path?email=alice@example.com", service: "example.com"))
    }

    func testIDNAEquivalentHostsMatch() {
        XCTAssertTrue(CredentialDomain.matches("https://bücher.example", service: "xn--bcher-kva.example"))
    }

    func testExactHostMatching() {
        XCTAssertTrue(CredentialDomain.matches("https://EXAMPLE.com/login", service: "example.com"))
        XCTAssertTrue(CredentialDomain.matches("example.com.", service: "https://example.com"))
        XCTAssertFalse(CredentialDomain.matches("https://example.com", service: "example.com.attacker.test"))
        XCTAssertFalse(CredentialDomain.matches("https://example.com", service: "login.example.com"))
        XCTAssertFalse(CredentialDomain.matches("https://example.com@attacker.test", service: "attacker.test"))
        XCTAssertFalse(CredentialDomain.matches("javascript://example.com", service: "example.com"))
        XCTAssertFalse(CredentialDomain.matches("", service: ""))
        XCTAssertFalse(CredentialDomain.matches("https://example.com\\@evil.test", service: "example.com"))
    }
}
