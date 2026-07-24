import XCTest
@testable import MLXServerManager

final class HuggingFaceOutputBatchTests: XCTestCase {
    func testDrainPreservesOrderAndClearsPendingLines() {
        var batch = HuggingFaceOutputBatch()
        batch.append("first")
        batch.append("second")

        XCTAssertEqual(batch.drain(), ["first", "second"])
        XCTAssertTrue(batch.isEmpty)
        XCTAssertEqual(batch.drain(), [])
    }

    func testBoundedHistoryKeepsNewestLines() {
        let history = HuggingFaceOutputBatch.boundedHistory(
            existing: (1...20).map { "old-\($0)" },
            appending: (1...10).map { "new-\($0)" },
            maximumCount: 24
        )

        XCTAssertEqual(history.count, 24)
        XCTAssertEqual(history.first, "old-7")
        XCTAssertEqual(history.last, "new-10")
    }

    func testProgressDetectionUsesExistingDownloadParser() {
        var batch = HuggingFaceOutputBatch()
        batch.append("working")
        XCTAssertFalse(batch.containsProgress)

        batch.append("42%")
        XCTAssertTrue(batch.containsProgress)
    }

    func testImmediatePolicyPrioritizesErrorsWarningsAndTerminalLines() {
        XCTAssertTrue(HuggingFaceOutputLinePolicy.requiresImmediateFlush("[hf:stderr] fatal error"))
        XCTAssertTrue(HuggingFaceOutputLinePolicy.requiresImmediateFlush("WARNING: low disk space"))
        XCTAssertTrue(HuggingFaceOutputLinePolicy.requiresImmediateFlush("Download completed"))
        XCTAssertTrue(HuggingFaceOutputLinePolicy.requiresImmediateFlush("cancelled by user"))
        XCTAssertFalse(HuggingFaceOutputLinePolicy.requiresImmediateFlush("[hf:stderr] 42%"))
        XCTAssertFalse(HuggingFaceOutputLinePolicy.requiresImmediateFlush("fetching model metadata"))
    }
}
