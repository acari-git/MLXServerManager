import XCTest
@testable import MLXServerManager

final class HuggingFaceDownloadViewStateTests: XCTestCase {
    func testMeasuredProgressUpdatesQueueAndAggregateStatusTogether() {
        let entryID = UUID()
        var state = HuggingFaceDownloadViewState.waiting
        state.insert(
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .preparing,
                message: "Preparing",
                fileCount: 10,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: 1_000,
                speedBytesPerSecond: nil
            )
        )

        XCTAssertTrue(
            state.updateMeasuredProgress(
                queueEntryID: entryID,
                downloadedBytes: 400,
                downloadedFileCount: 3,
                totalBytes: 1_000,
                speedBytesPerSecond: 200
            )
        )
        let primaryID = state.refreshAggregateStatus(
            primaryID: entryID,
            outputLinesByID: [entryID: ["progress"]]
        )

        XCTAssertEqual(primaryID, entryID)
        XCTAssertEqual(state.entries.first?.phase, .downloading)
        XCTAssertEqual(state.entries.first?.downloadedBytes, 400)
        XCTAssertEqual(state.entries.first?.downloadedFileCount, 3)
        XCTAssertEqual(state.entries.first?.speedBytesPerSecond, 200)
        XCTAssertEqual(state.status.phase, .downloading)
        XCTAssertEqual(state.status.progress ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(state.status.message, "Downloading... 40%")
        XCTAssertEqual(state.status.outputLines, ["progress"])
    }

    func testMeasuredProgressClampsValuesAndPreservesKnownFileLimit() {
        let entryID = UUID()
        var state = HuggingFaceDownloadViewState.waiting
        state.insert(
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .waiting,
                message: "Waiting",
                fileCount: 4,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: 1_000,
                speedBytesPerSecond: nil
            )
        )

        XCTAssertTrue(
            state.updateMeasuredProgress(
                queueEntryID: entryID,
                downloadedBytes: 2_000,
                downloadedFileCount: 9,
                totalBytes: 1_000,
                speedBytesPerSecond: nil
            )
        )

        XCTAssertEqual(state.entries.first?.downloadedBytes, 1_000)
        XCTAssertEqual(state.entries.first?.downloadedFileCount, 4)
        XCTAssertEqual(state.entries.first?.message, "Downloading... 100%")
    }

    func testMeasuredProgressIgnoresTerminalAndUnknownEntries() {
        let entryID = UUID()
        var state = HuggingFaceDownloadViewState.waiting
        state.insert(
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .completed,
                message: "Completed",
                fileCount: 1,
                downloadedFileCount: 1,
                downloadedBytes: 100,
                totalBytes: 100,
                speedBytesPerSecond: nil
            )
        )
        let originalState = state

        XCTAssertFalse(
            state.updateMeasuredProgress(
                queueEntryID: entryID,
                downloadedBytes: 50,
                downloadedFileCount: 0,
                totalBytes: 100,
                speedBytesPerSecond: 10
            )
        )
        XCTAssertFalse(
            state.updateMeasuredProgress(
                queueEntryID: UUID(),
                downloadedBytes: 50,
                downloadedFileCount: 0,
                totalBytes: 100,
                speedBytesPerSecond: 10
            )
        )
        XCTAssertEqual(state, originalState)
    }

    func testMeasuredProgressAndQueueSummaryUseRequestedLanguage() {
        let entryID = UUID()
        var state = HuggingFaceDownloadViewState.waiting
        state.insert(
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .preparing,
                message: "準備中",
                fileCount: 10,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: 1_000,
                speedBytesPerSecond: nil
            )
        )

        XCTAssertTrue(
            state.updateMeasuredProgress(
                queueEntryID: entryID,
                downloadedBytes: 400,
                downloadedFileCount: 3,
                totalBytes: 1_000,
                speedBytesPerSecond: 200,
                language: .japanese
            )
        )

        guard let entry = state.entries.first else {
            return XCTFail("Expected a download queue entry.")
        }
        XCTAssertEqual(entry.message, "ダウンロード中... 40%")
        XCTAssertTrue(entry.localizedProgressText(language: .japanese).contains("ファイル"))
        XCTAssertFalse(entry.localizedProgressText(language: .japanese).contains("files"))
    }

    func testAggregateStatusFallsBackToActiveEntryWhenPrimaryIsTerminal() {
        let completedID = UUID()
        let activeID = UUID()
        var state = HuggingFaceDownloadViewState.waiting
        state.insert(
            HuggingFaceDownloadQueueEntry(
                id: completedID,
                repositoryID: "owner/completed",
                destinationPath: "/tmp/completed",
                phase: .completed,
                message: "Completed",
                fileCount: 1,
                downloadedFileCount: 1,
                downloadedBytes: 100,
                totalBytes: 100,
                speedBytesPerSecond: nil
            )
        )
        state.insert(
            HuggingFaceDownloadQueueEntry(
                id: activeID,
                repositoryID: "owner/active",
                destinationPath: "/tmp/active",
                phase: .downloading,
                message: "Downloading",
                fileCount: nil,
                downloadedFileCount: nil,
                downloadedBytes: 50,
                totalBytes: 100,
                speedBytesPerSecond: nil
            )
        )

        let resolvedPrimaryID = state.refreshAggregateStatus(
            primaryID: completedID,
            outputLinesByID: [:]
        )

        XCTAssertEqual(resolvedPrimaryID, activeID)
        XCTAssertEqual(state.status.repositoryID, "owner/active")
        XCTAssertEqual(state.status.phase, .downloading)
    }
}
