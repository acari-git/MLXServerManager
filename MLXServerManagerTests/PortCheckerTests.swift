import Darwin
import XCTest
@testable import MLXServerManager

final class PortCheckerTests: XCTestCase {
    func testReuseAddressFailureIsReportedAsCheckFailure() {
        let result = PortChecker().resultForSocketOptionFailure(
            host: "127.0.0.1",
            port: 8_000,
            errorCode: EINVAL
        )

        guard case let .failed(host, port, message) = result else {
            return XCTFail("Expected a socket option error to be reported as failed: \(result)")
        }
        XCTAssertEqual(host, "127.0.0.1")
        XCTAssertEqual(port, 8_000)
        XCTAssertTrue(message.contains("setsockopt SO_REUSEADDR failed"))
        XCTAssertTrue(message.contains(String(cString: strerror(EINVAL))))
    }

    func testAddressInUseBindFailureIsReportedAsBusy() {
        XCTAssertEqual(
            PortChecker().resultForBindFailure(
                host: "127.0.0.1",
                port: 8_000,
                errorCode: EADDRINUSE
            ),
            .busy(host: "127.0.0.1", port: 8_000, pid: nil)
        )
    }

    func testNonConflictBindFailureIsReportedAsCheckFailure() {
        let result = PortChecker().resultForBindFailure(
            host: "127.0.0.1",
            port: 8_000,
            errorCode: EACCES
        )

        guard case let .failed(host, port, message) = result else {
            return XCTFail("Expected a non-conflict bind error to be reported as failed: \(result)")
        }
        XCTAssertEqual(host, "127.0.0.1")
        XCTAssertEqual(port, 8_000)
        XCTAssertTrue(message.contains("bind failed"))
        XCTAssertTrue(message.contains(String(cString: strerror(EACCES))))
    }
}
