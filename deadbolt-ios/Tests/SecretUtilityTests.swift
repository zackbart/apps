import XCTest
@testable import Deadbolt

final class SecretUtilityTests: XCTestCase {
    func testRFC6238SHA1() throws {
        let totp = try TOTP(uri: "otpauth://totp/Test?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&digits=8")
        for (time, code) in [(59.0, "94287082"), (1111111109, "07081804"), (1111111111, "14050471"), (1234567890, "89005924"), (2000000000, "69279037"), (20000000000, "65353130")] {
            XCTAssertEqual(try totp.code(at: Date(timeIntervalSince1970: time)), code)
        }
    }

    func testRFC6238SHA256AndSHA512() throws {
        let sha256 = try TOTP(uri: "otpauth://totp/Test?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA====&digits=8&algorithm=SHA256")
        let sha512 = try TOTP(uri: "otpauth://totp/Test?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA=&digits=8&algorithm=SHA512")
        XCTAssertEqual(try sha256.code(at: Date(timeIntervalSince1970: 59)), "46119246")
        XCTAssertEqual(try sha512.code(at: Date(timeIntervalSince1970: 59)), "90693936")
    }

    func testBase32RejectsNoncanonicalEncoding() throws {
        XCTAssertEqual(TOTP.base32("MY======"), Data([102]))
        XCTAssertEqual(TOTP.base32("MY"), Data([102]))
        for input in ["MY=", "MY=======", "MY======A", "AAA", "AAAAAA", "MZ", "ß"] {
            XCTAssertNil(TOTP.base32(input), input)
        }
        let totp = try TOTP(uri: "MY")
        XCTAssertThrowsError(try totp.code(at: Date(timeIntervalSince1970: -1)))
        XCTAssertThrowsError(try totp.code(at: Date(timeIntervalSince1970: 1e30)))
    }

    func testCSVPreservesQuotedCarriageReturnsAndUnicode() throws {
        let csv = "username,password,notes\r\nzoë,\"a\r\nb\",\"雪\r\nline\"\r\n"
        let entry = try XCTUnwrap(CredentialCSV.parse(csv).first)
        XCTAssertEqual(entry.username, "zoë")
        XCTAssertEqual(entry.password, "a\r\nb")
        XCTAssertEqual(entry.notes, "雪\r\nline")
    }

    func testRejectsMalformedTOTP() {
        for uri in ["otpauth://hotp/test?secret=ABC", "otpauth://totp/test?secret=ABC&secret=DEF", "otpauth://totp/test?secret=A!", "otpauth://totp/test?secret=MY&digits=10", "otpauth://totp/test?secret=MY&period=0"] {
            XCTAssertThrowsError(try TOTP(uri: uri))
        }
    }

    func testCSVQuotedSecrets() throws {
        let entries = try CredentialCSV.parse("name,url,username,password,notes\r\n\"A, B\",https://example.com,me,\"p\"\"ass\",\"line1\nline2\"\r\n")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "A, B")
        XCTAssertEqual(entries[0].password, "p\"ass")
        XCTAssertEqual(entries[0].notes, "line1\nline2")
    }

    func testCommonPasswordExports() throws {
        let bitwarden = try CredentialCSV.parse("name,login_uri,login_username,login_password,login_totp,notes\nExample,https://example.com,alice,secret,JBSWY3DPEHPK3PXP,note")
        XCTAssertEqual(bitwarden[0].totp, "JBSWY3DPEHPK3PXP")
        let apple = try CredentialCSV.parse("Title,URL,Username,Password,Notes,OTPAuth\n,https://example.com,alice,secret,note,JBSWY3DPEHPK3PXP")
        XCTAssertEqual(apple[0].title, "example.com")
        XCTAssertEqual(apple[0].password, "secret")
    }

    func testPasswordOnlyCSVHasUsableTitle() throws {
        let entry = try XCTUnwrap(CredentialCSV.parse("username,password\n,secret").first)
        XCTAssertEqual(entry.title, "Imported login")
    }

    func testRejectsMalformedCSV() {
        XCTAssertThrowsError(try CredentialCSV.parse("username,password\na,\"unclosed"))
        XCTAssertThrowsError(try CredentialCSV.parse("username,password\na,b,c"))
        XCTAssertThrowsError(try CredentialCSV.parse("username,password,password\na,b,c"))
    }
}
