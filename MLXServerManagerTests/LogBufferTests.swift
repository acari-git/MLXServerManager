import XCTest
@testable import MLXServerManager

final class LogBufferTests: XCTestCase {
    func testBatchAppendPreservesIndividualEntriesAndJoinedText() {
        var buffer = LogBuffer(maximumCount: 5, initialLines: ["initial"])

        buffer.append(contentsOf: ["first", "second"])

        XCTAssertEqual(buffer.entries.map(\.line), ["initial", "first", "second"])
        XCTAssertEqual(buffer.text, "initial\nfirst\nsecond")
    }

    func testBatchAppendTrimsOnceToNewestMaximumEntries() {
        var buffer = LogBuffer(maximumCount: 3, initialLines: ["old-1", "old-2"])

        buffer.append(contentsOf: ["new-1", "new-2"])

        XCTAssertEqual(buffer.entries.map(\.line), ["old-2", "new-1", "new-2"])
        XCTAssertEqual(buffer.text, "old-2\nnew-1\nnew-2")
    }

    func testEmptyBatchDoesNotChangeBuffer() {
        var buffer = LogBuffer(maximumCount: 3, initialLines: ["initial"])
        let originalEntries = buffer.entries
        let originalText = buffer.text

        buffer.append(contentsOf: [])

        XCTAssertEqual(buffer.entries, originalEntries)
        XCTAssertEqual(buffer.text, originalText)
    }
}
