import XCTest
@testable import MLXServerManager

@MainActor
final class HuggingFaceDownloadExecutionCoordinatorTests: XCTestCase {
    func testCompletionRemovesDownloadBeforeCallingHandler() async {
        let manager = ControlledHuggingFaceDownloadManager()
        let started = expectation(description: "Download started")
        let completed = expectation(description: "Download completed")
        manager.onStart = { started.fulfill() }
        let coordinator = makeCoordinator()
        let id = UUID()

        XCTAssertTrue(
            coordinator.start(
                id: id,
                manager: manager,
                request: makeRequest(destinationPath: "/tmp/model-a"),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { completion in
                    XCTAssertFalse(coordinator.isActive(id))
                    XCTAssertEqual(coordinator.activeCount, 0)
                    guard case let .succeeded(result) = completion.outcome else {
                        return XCTFail("Expected a successful result")
                    }
                    XCTAssertEqual(result.repositoryID, "owner/model")
                    XCTAssertFalse(completion.cancellationRequested)
                    completed.fulfill()
                }
            )
        )

        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(coordinator.isActive(id))
        manager.succeed(destinationPath: "/tmp/model-a")
        await fulfillment(of: [completed], timeout: 1)
    }

    func testCompletionIsDeliveredAfterAllOutputLines() async {
        let manager = ControlledHuggingFaceDownloadManager()
        let started = expectation(description: "Download started")
        let completed = expectation(description: "Download completed")
        manager.onStart = { started.fulfill() }
        let coordinator = makeCoordinator()
        var events: [String] = []

        XCTAssertTrue(
            coordinator.start(
                id: UUID(),
                manager: manager,
                request: makeRequest(destinationPath: "/tmp/model-a"),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { line in
                    events.append("output:\(line)")
                },
                progressHandler: { _ in },
                completionHandler: { _ in
                    events.append("completion")
                    completed.fulfill()
                }
            )
        )

        await fulfillment(of: [started], timeout: 1)
        manager.emit("[hf:stdout] first")
        manager.emit("[hf:stderr] final")
        manager.succeed(destinationPath: "/tmp/model-a")
        await fulfillment(of: [completed], timeout: 1)

        XCTAssertEqual(events, [
            "output:[hf:stdout] first",
            "output:[hf:stderr] final",
            "completion"
        ])
    }

    func testCancellationBeforeExecutionStartsDoesNotCallDownload() async {
        let manager = ControlledHuggingFaceDownloadManager()
        let completed = expectation(description: "Cancellation completed")
        let coordinator = makeCoordinator()
        let id = UUID()

        XCTAssertTrue(
            coordinator.start(
                id: id,
                manager: manager,
                request: makeRequest(destinationPath: "/tmp/model-a"),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { completion in
                    XCTAssertTrue(completion.cancellationRequested)
                    guard case .failed = completion.outcome else {
                        return XCTFail("Expected cancellation to fail the execution")
                    }
                    completed.fulfill()
                }
            )
        )

        XCTAssertTrue(coordinator.cancel(id))
        await fulfillment(of: [completed], timeout: 1)

        XCTAssertEqual(manager.downloadCallCount, 0)
        XCTAssertEqual(manager.cancelCallCount, 1)
        XCTAssertFalse(coordinator.isActive(id))
    }

    func testActiveCancellationKeepsSlotUntilManagerFinishes() async {
        let manager = ControlledHuggingFaceDownloadManager()
        let started = expectation(description: "Download started")
        let completed = expectation(description: "Cancellation completed")
        manager.onStart = { started.fulfill() }
        let coordinator = makeCoordinator()
        let id = UUID()

        XCTAssertTrue(
            coordinator.start(
                id: id,
                manager: manager,
                request: makeRequest(destinationPath: "/tmp/model-a"),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { completion in
                    XCTAssertTrue(completion.cancellationRequested)
                    completed.fulfill()
                }
            )
        )

        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(coordinator.cancel(id))
        XCTAssertFalse(coordinator.cancel(id))
        XCTAssertTrue(coordinator.isActive(id))
        XCTAssertEqual(manager.cancelCallCount, 1)

        manager.fail(with: .cancelled)
        await fulfillment(of: [completed], timeout: 1)
        XCTAssertFalse(coordinator.isActive(id))
    }

    func testConcurrentDownloadToSameDestinationIsRejected() async {
        let firstManager = ControlledHuggingFaceDownloadManager()
        let firstStarted = expectation(description: "First download started")
        let firstCompleted = expectation(description: "First download completed")
        firstManager.onStart = { firstStarted.fulfill() }
        let secondManager = ControlledHuggingFaceDownloadManager()
        let coordinator = makeCoordinator()
        let destinationPath = "/tmp/shared-model"

        XCTAssertTrue(
            coordinator.start(
                id: UUID(),
                manager: firstManager,
                request: makeRequest(destinationPath: destinationPath),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { _ in firstCompleted.fulfill() }
            )
        )
        XCTAssertTrue(coordinator.isDestinationActive(destinationPath))
        XCTAssertEqual(coordinator.activeDestinationPaths, [destinationPath])
        XCTAssertFalse(
            coordinator.start(
                id: UUID(),
                manager: secondManager,
                request: makeRequest(destinationPath: destinationPath),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { _ in XCTFail("Rejected download must not complete") }
            )
        )

        await fulfillment(of: [firstStarted], timeout: 1)
        XCTAssertEqual(secondManager.downloadCallCount, 0)
        firstManager.succeed(destinationPath: destinationPath)
        await fulfillment(of: [firstCompleted], timeout: 1)
        XCTAssertFalse(coordinator.isDestinationActive(destinationPath))
        XCTAssertTrue(coordinator.activeDestinationPaths.isEmpty)
    }

    func testConcurrentDownloadToAliasedDestinationIsRejected() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerExecutionAlias-\(UUID().uuidString)", isDirectory: true)
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let aliasDirectory = root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasDirectory, withDestinationURL: realDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let realDestination = realDirectory.appendingPathComponent("model", isDirectory: true).path
        let aliasedDestination = aliasDirectory.appendingPathComponent("model", isDirectory: true).path
        let firstManager = ControlledHuggingFaceDownloadManager()
        let secondManager = ControlledHuggingFaceDownloadManager()
        let started = expectation(description: "First aliased download started")
        let completed = expectation(description: "First aliased download completed")
        firstManager.onStart = { started.fulfill() }
        let coordinator = makeCoordinator()

        XCTAssertTrue(
            coordinator.start(
                id: UUID(),
                manager: firstManager,
                request: makeRequest(destinationPath: realDestination),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { _ in completed.fulfill() }
            )
        )
        XCTAssertTrue(coordinator.isDestinationActive(aliasedDestination))
        XCTAssertFalse(
            coordinator.start(
                id: UUID(),
                manager: secondManager,
                request: makeRequest(destinationPath: aliasedDestination),
                expectedFiles: [],
                totalBytes: nil,
                outputHandler: { _ in },
                progressHandler: { _ in },
                completionHandler: { _ in XCTFail("Aliased destination must be rejected") }
            )
        )

        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(secondManager.downloadCallCount, 0)
        firstManager.succeed(destinationPath: realDestination)
        await fulfillment(of: [completed], timeout: 1)
    }

    func testProgressPollingStopsWhenExecutionCompletes() async {
        let manager = ControlledHuggingFaceDownloadManager()
        let started = expectation(description: "Download started")
        let progressReported = expectation(description: "Progress reported")
        let completed = expectation(description: "Download completed")
        manager.onStart = { started.fulfill() }
        var sleepContinuation: CheckedContinuation<Void, Error>?
        var progressCount = 0
        let coordinator = HuggingFaceDownloadExecutionCoordinator(
            progressIntervalNanoseconds: 1,
            progressSnapshotOperation: { _, _ in
                HuggingFaceDownloadProgressSnapshot(
                    downloadedBytes: 42,
                    completedFileCount: 1,
                    expectedFileCount: 1
                )
            },
            sleepOperation: { _ in
                try await withCheckedThrowingContinuation { continuation in
                    sleepContinuation = continuation
                }
            }
        )

        XCTAssertTrue(
            coordinator.start(
                id: UUID(),
                manager: manager,
                request: makeRequest(destinationPath: "/tmp/model-a"),
                expectedFiles: [],
                totalBytes: 100,
                outputHandler: { _ in },
                progressHandler: { progress in
                    progressCount += 1
                    XCTAssertEqual(progress.downloadedBytes, 42)
                    progressReported.fulfill()
                },
                completionHandler: { _ in completed.fulfill() }
            )
        )

        await fulfillment(of: [started, progressReported], timeout: 1)
        manager.succeed(destinationPath: "/tmp/model-a")
        await fulfillment(of: [completed], timeout: 1)

        sleepContinuation?.resume()
        await Task.yield()
        XCTAssertEqual(progressCount, 1)
    }

    private func makeCoordinator() -> HuggingFaceDownloadExecutionCoordinator {
        HuggingFaceDownloadExecutionCoordinator(
            progressIntervalNanoseconds: 60_000_000_000,
            progressSnapshotOperation: { _, _ in
                HuggingFaceDownloadProgressSnapshot(
                    downloadedBytes: 0,
                    completedFileCount: 0,
                    expectedFileCount: 0
                )
            }
        )
    }

    private func makeRequest(destinationPath: String) -> HuggingFaceDownloadRequest {
        HuggingFaceDownloadRequest(
            repositoryID: "owner/model",
            destinationPath: destinationPath,
            revision: "main",
            includePatterns: [],
            excludePatterns: [],
            authorizationValue: nil
        )
    }
}

@MainActor
private final class ControlledHuggingFaceDownloadManager: HuggingFaceModelDownloading {
    var onStart: (() -> Void)?
    private(set) var downloadCallCount = 0
    private(set) var cancelCallCount = 0
    private var continuation: CheckedContinuation<HuggingFaceDownloadResult, Error>?
    private var outputHandler: (@Sendable (String) -> Void)?

    func download(
        request: HuggingFaceDownloadRequest,
        outputHandler: @escaping @Sendable (String) -> Void
    ) async throws -> HuggingFaceDownloadResult {
        downloadCallCount += 1
        self.outputHandler = outputHandler
        onStart?()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {
        cancelCallCount += 1
    }

    func emit(_ line: String) {
        outputHandler?(line)
    }

    func succeed(destinationPath: String) {
        continuation?.resume(
            returning: HuggingFaceDownloadResult(
                repositoryID: "owner/model",
                destinationPath: destinationPath,
                terminationStatus: 0
            )
        )
        continuation = nil
        outputHandler = nil
    }

    func fail(with error: HuggingFaceDownloadError) {
        continuation?.resume(throwing: error)
        continuation = nil
        outputHandler = nil
    }
}
