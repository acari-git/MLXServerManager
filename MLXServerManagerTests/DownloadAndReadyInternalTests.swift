import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class DownloadAndReadyInternalTests: XCTestCase {
    func testSelectingSearchResultUpdatesDownloadTargetAndDisplayName() {
        let viewModel = AppViewModel()
        let result = HuggingFaceSearchResult(
            id: "owner/selected-model",
            downloads: 10,
            likes: 2,
            lastModified: nil,
            tags: ["mlx"]
        )

        viewModel.selectHuggingFaceSearchResult(result)

        XCTAssertEqual(viewModel.selectedHuggingFaceSearchResult, result)
        XCTAssertEqual(viewModel.huggingFaceDownloadDraft.source, "owner/selected-model")
        XCTAssertEqual(viewModel.huggingFaceDownloadDraft.displayName, "selected-model")
        XCTAssertTrue(viewModel.huggingFaceSearchMessage.contains("MLX"))
    }

    func testSearchIgnoresStaleCompletionFromOlderRequest() async throws {
        let service = DelayedSearchService()
        let viewModel = AppViewModel(huggingFaceSearchService: service)

        viewModel.huggingFaceDownloadDraft.source = "owner/old-model"
        viewModel.huggingFaceSearchQuery = "owner/old-model"
        viewModel.performHuggingFaceSearchRequested()

        try await Task.sleep(nanoseconds: 20_000_000)

        viewModel.huggingFaceDownloadDraft.source = "owner/new-model"
        viewModel.huggingFaceSearchQuery = "owner/new-model"
        viewModel.performHuggingFaceSearchRequested()

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(viewModel.huggingFaceSearchResults.map(\.id), ["owner/new-model"])
        XCTAssertEqual(viewModel.selectedHuggingFaceSearchResult?.id, "owner/new-model")
        XCTAssertEqual(viewModel.huggingFaceDownloadDraft.source, "owner/new-model")
    }

    func testSearchDoesNotOverwriteSourceEditedWhileRequestIsRunning() async throws {
        let service = DelayedSearchService()
        let viewModel = AppViewModel(huggingFaceSearchService: service)

        viewModel.huggingFaceDownloadDraft.source = "owner/old-model"
        viewModel.huggingFaceSearchQuery = "owner/old-model"
        viewModel.performHuggingFaceSearchRequested()

        try await Task.sleep(nanoseconds: 20_000_000)
        viewModel.huggingFaceDownloadDraft.source = "owner/user-edited-model"

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(viewModel.huggingFaceDownloadDraft.source, "owner/user-edited-model")
        XCTAssertTrue(viewModel.huggingFaceSearchResults.isEmpty)
        XCTAssertNil(viewModel.selectedHuggingFaceSearchResult)
        XCTAssertFalse(viewModel.isHuggingFaceSearching)
    }

    func testFilePreviewIgnoresFilesFromPreviouslySelectedModel() async throws {
        let service = DelayedRepositoryFileService()
        let viewModel = AppViewModel(huggingFaceRepositoryFileService: service)

        viewModel.huggingFaceDownloadDraft.source = "owner/old-model"
        viewModel.previewHuggingFaceFilesRequested()

        try await Task.sleep(nanoseconds: 20_000_000)

        viewModel.huggingFaceDownloadDraft.source = "owner/new-model"
        viewModel.previewHuggingFaceFilesRequested()

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(
            viewModel.huggingFaceFilePreviewIdentity,
            HuggingFaceFilePreviewIdentity(repositoryID: "owner/new-model", revision: "main")
        )
        XCTAssertEqual(viewModel.huggingFaceFilePreview.files.map(\.path), ["new.safetensors"])
        XCTAssertEqual(viewModel.selectedHuggingFacePreviewFileIDs, ["new.safetensors"])
    }

    func testFilePreviewIsCancelledWhenDraftIdentityChanges() async throws {
        let service = DelayedRepositoryFileService()
        let viewModel = AppViewModel(huggingFaceRepositoryFileService: service)

        viewModel.huggingFaceDownloadDraft.source = "owner/old-model"
        viewModel.previewHuggingFaceFilesRequested()

        try await Task.sleep(nanoseconds: 20_000_000)
        viewModel.huggingFaceDownloadDraft.source = "owner/user-edited-model"
        viewModel.huggingFaceDownloadIdentityChanged()

        XCTAssertNil(viewModel.huggingFaceFilePreviewIdentity)
        XCTAssertFalse(viewModel.huggingFaceFilePreview.isLoading)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(viewModel.huggingFaceFilePreview.files.isEmpty)
        XCTAssertTrue(viewModel.selectedHuggingFacePreviewFileIDs.isEmpty)
    }

    func testAutoUnloadSettingsPersistAcrossViewModelReload() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerAutoUnloadTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let firstViewModel = AppViewModel(settingsStore: store)
        guard let model = firstViewModel.models.first else {
            return XCTFail("Expected a default model")
        }
        firstViewModel.setAutoUnloadEnabled(true, for: model)
        firstViewModel.setAutoUnloadMinutes(45, for: model)

        let reloadedViewModel = AppViewModel(settingsStore: store)
        guard let reloadedModel = reloadedViewModel.models.first else {
            return XCTFail("Expected the saved model")
        }

        XCTAssertTrue(reloadedViewModel.isAutoUnloadEnabled(for: reloadedModel))
        XCTAssertEqual(reloadedViewModel.autoUnloadMinutes(for: reloadedModel), 45)
    }

    func testSavingSettingsPreservesSelectedPreviewFileMode() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerDownloadDraftTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let viewModel = AppViewModel(settingsStore: store)
        viewModel.huggingFaceDownloadDraft.useSelectedPreviewFiles = true

        viewModel.saveSettingsRequested()

        XCTAssertTrue(viewModel.huggingFaceDownloadDraft.useSelectedPreviewFiles)
    }

    func testSaveSettingsRequestedReportsAuthoritativeSnapshotFailure() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerSaveFailureTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let viewModel = AppViewModel(settingsStore: store)
        try FileManager.default.createDirectory(
            at: store.stateSnapshotFileURL,
            withIntermediateDirectories: true
        )

        let originalSettings = viewModel.settings
        var candidate = originalSettings
        candidate.defaultPort = 9_999

        XCTAssertFalse(viewModel.saveSettingsRequested(candidate))
        XCTAssertEqual(viewModel.settings, originalSettings)
        XCTAssertTrue(viewModel.logText.contains("[settings] Failed to save settings:"))
    }

    func testFilePreviewUsesCredentialStoreToken() async throws {
        let service = DelayedRepositoryFileService()
        let credentialStore = StaticCredentialStore(value: "hf_test_token")
        let viewModel = AppViewModel(
            huggingFaceCredentialStore: credentialStore,
            huggingFaceRepositoryFileService: service
        )

        viewModel.huggingFaceDownloadDraft.source = "owner/private-model"
        viewModel.previewHuggingFaceFilesRequested()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(service.lastToken, "hf_test_token")
    }

    func testDownloadStorageAssessmentUsesPartialFileAtResolvedDestination() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = root
            .appendingPathComponent("owner", isDirectory: true)
            .appendingPathComponent("new-model", isDirectory: true)
        try HuggingFaceDownloadProvenanceStore().prepare(
            destinationURL: destination,
            repositoryID: "owner/new-model",
            revision: "main"
        )
        try Data(repeating: 1, count: 7).write(
            to: destination.appendingPathComponent("new.safetensors")
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let viewModel = AppViewModel(
            huggingFaceRepositoryFileService: DelayedRepositoryFileService(),
            downloadStorageCapacityProvider: InternalTestDownloadStorageCapacityProvider(capacity: 2)
        )
        viewModel.selectHuggingFaceSearchResult(
            HuggingFaceSearchResult(
                id: "owner/new-model",
                downloads: 1,
                likes: 1,
                lastModified: nil,
                tags: ["mlx"]
            )
        )
        viewModel.huggingFaceDownloadDraft.saveDirectory = root.path
        viewModel.previewHuggingFaceFilesRequested()

        try await Task.sleep(nanoseconds: 100_000_000)

        let assessment = try XCTUnwrap(viewModel.huggingFaceDownloadStorageAssessment)
        XCTAssertEqual(assessment.kind, .insufficient)
        XCTAssertEqual(assessment.requirement.knownRemainingBytes, 3)
        XCTAssertEqual(assessment.availableCapacityBytes, 2)
        XCTAssertTrue(assessment.blocksDownload)
    }

    func testProgressMeasurerCountsOnlyExpectedCompletedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 1, count: 3).write(to: root.appendingPathComponent("a.safetensors"))
        try Data(repeating: 2, count: 100).write(to: root.appendingPathComponent("unrelated.log"))
        try Data(repeating: 3, count: 2).write(to: root.appendingPathComponent("b.json"))

        let expectedFiles = [
            HuggingFaceDownloadPreviewFile(path: "a.safetensors", size: 3),
            HuggingFaceDownloadPreviewFile(path: "b.json", size: 4)
        ]
        let snapshot = HuggingFaceDownloadProgressMeasurer.snapshot(
            destinationPath: root.path,
            expectedFiles: expectedFiles
        )

        XCTAssertEqual(snapshot.downloadedBytes, 5)
        XCTAssertEqual(snapshot.completedFileCount, 1)
        XCTAssertEqual(snapshot.expectedFileCount, 2)
    }

    func testQueueSchedulerHonorsConcurrencyAndFIFOOrder() {
        let oldestID = UUID()
        let middleID = UUID()
        let newestID = UUID()
        let entries = [
            makeQueueEntry(id: newestID, phase: .waiting),
            makeQueueEntry(id: middleID, phase: .waiting),
            makeQueueEntry(id: oldestID, phase: .waiting)
        ]
        let queuedIDs = Set([oldestID, middleID, newestID])

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [],
                maximumConcurrentDownloads: 2
            ),
            [oldestID, middleID]
        )

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [oldestID],
                maximumConcurrentDownloads: 2
            ),
            [middleID]
        )

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [oldestID, middleID],
                maximumConcurrentDownloads: 2
            ),
            []
        )
    }

    func testQueueSchedulerPromotesWaitingEntryAfterSlotOpens() {
        let activeID = UUID()
        let waitingID = UUID()
        let entries = [
            makeQueueEntry(id: waitingID, phase: .waiting),
            makeQueueEntry(id: activeID, phase: .downloading)
        ]
        let queuedIDs = Set([activeID, waitingID])

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [activeID],
                maximumConcurrentDownloads: 1
            ),
            []
        )
        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [],
                maximumConcurrentDownloads: 1
            ),
            [waitingID]
        )
    }

    func testQueueSchedulerSerializesSharedDestinationsWithoutBlockingOtherJobs() {
        let activeID = UUID()
        let oldestSharedID = UUID()
        let newestSharedID = UUID()
        let otherID = UUID()
        let sharedDestination = "/tmp/shared-model"
        let entries = [
            makeQueueEntry(id: newestSharedID, phase: .waiting, destinationPath: sharedDestination),
            makeQueueEntry(id: otherID, phase: .waiting, destinationPath: "/tmp/other-model"),
            makeQueueEntry(id: oldestSharedID, phase: .waiting, destinationPath: sharedDestination),
            makeQueueEntry(id: activeID, phase: .downloading, destinationPath: "/tmp/active-model")
        ]
        let queuedIDs = Set([oldestSharedID, newestSharedID, otherID])

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [activeID],
                activeDestinationPaths: ["/tmp/active-model"],
                maximumConcurrentDownloads: 3
            ),
            [oldestSharedID, otherID]
        )

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: queuedIDs,
                activeIDs: [activeID],
                activeDestinationPaths: [sharedDestination],
                maximumConcurrentDownloads: 3
            ),
            [otherID]
        )
    }

    func testQueueSchedulerSerializesAliasedDestinationPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerQueueAlias-\(UUID().uuidString)", isDirectory: true)
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let aliasDirectory = root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasDirectory, withDestinationURL: realDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let oldestID = UUID()
        let newestID = UUID()
        let realDestination = realDirectory.appendingPathComponent("model", isDirectory: true).path
        let aliasedDestination = aliasDirectory.appendingPathComponent("model", isDirectory: true).path
        let entries = [
            makeQueueEntry(id: newestID, phase: .waiting, destinationPath: aliasedDestination),
            makeQueueEntry(id: oldestID, phase: .waiting, destinationPath: realDestination)
        ]

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: [oldestID, newestID],
                activeIDs: [],
                maximumConcurrentDownloads: 2
            ),
            [oldestID]
        )
        XCTAssertTrue(
            HuggingFaceDownloadQueueScheduler.startableIDs(
                entries: entries,
                queuedIDs: [newestID],
                activeIDs: [],
                activeDestinationPaths: [realDestination],
                maximumConcurrentDownloads: 2
            ).isEmpty
        )
    }

    func testQueueSchedulerSupportsIndividualCancellation() {
        let waitingID = UUID()
        let activeID = UUID()
        let completedID = UUID()
        let entries = [
            makeQueueEntry(id: completedID, phase: .completed),
            makeQueueEntry(id: activeID, phase: .downloading),
            makeQueueEntry(id: waitingID, phase: .waiting)
        ]

        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.cancellableIDs(
                entries: entries,
                requestedID: waitingID
            ),
            [waitingID]
        )
        XCTAssertEqual(
            HuggingFaceDownloadQueueScheduler.cancellableIDs(entries: entries),
            Set([waitingID, activeID])
        )
        XCTAssertTrue(
            HuggingFaceDownloadQueueScheduler.cancellableIDs(
                entries: entries,
                requestedID: completedID
            ).isEmpty
        )
    }

    func testQueueHistoryPruningKeepsAllActiveAndNewestTerminalEntries() {
        let activeID = UUID()
        let newestTerminalID = UUID()
        let secondTerminalID = UUID()
        let removedTerminalID = UUID()
        let entries = [
            makeQueueEntry(id: activeID, phase: .downloading),
            makeQueueEntry(id: newestTerminalID, phase: .failed),
            makeQueueEntry(id: secondTerminalID, phase: .completed),
            makeQueueEntry(id: removedTerminalID, phase: .cancelled)
        ]

        let result = HuggingFaceDownloadQueueScheduler.pruningTerminalHistory(
            entries: entries,
            maximumTerminalEntries: 2
        )

        XCTAssertEqual(result.entries.map(\.id), [activeID, newestTerminalID, secondTerminalID])
        XCTAssertEqual(result.removedIDs, [removedTerminalID])
    }

    func testQueueFileProgressDoesNotInventCurrentFile() {
        var entry = HuggingFaceDownloadQueueEntry(
            id: UUID(),
            repositoryID: "owner/model",
            destinationPath: "/tmp/model",
            phase: .downloading,
            message: "Downloading",
            fileCount: 2,
            downloadedFileCount: 0,
            downloadedBytes: 0,
            totalBytes: 10,
            speedBytesPerSecond: 0
        )

        XCTAssertEqual(entry.fileProgressText, "0 / 2")
        entry.downloadedFileCount = 1
        XCTAssertEqual(entry.fileProgressText, "1 / 2")
        entry.phase = .completed
        XCTAssertEqual(entry.fileProgressText, "2 / 2")
    }

    func testReadyCheckerValidatesModelsPayloadAndExpectedModel() async {
        let session = makeSession()
        let checker = ReadyChecker(timeout: 1, session: session)

        MockReadyURLProtocol.response = .init(
            statusCode: 200,
            body: #"{"object":"list","data":[{"id":"/Models/example-model"}]}"#
        )
        let ready = await checker.check(
            host: "127.0.0.1",
            port: 8080,
            expectedModelID: "/Users/example/Models/example-model"
        )
        guard case .ready = ready else {
            return XCTFail("Expected valid OpenAI-compatible models payload to be ready: \(ready)")
        }

        MockReadyURLProtocol.response = .init(statusCode: 200, body: "<html>ok</html>")
        let invalidPayload = await checker.check(host: "127.0.0.1", port: 8080)
        guard case let .failed(_, message) = invalidPayload else {
            return XCTFail("Expected invalid HTTP 200 payload to fail: \(invalidPayload)")
        }
        XCTAssertTrue(message.contains("OpenAI-compatible"))

        MockReadyURLProtocol.response = .init(
            statusCode: 200,
            body: #"{"object":"list","data":[{"id":"different-model"}]}"#
        )
        let wrongModel = await checker.check(
            host: "127.0.0.1",
            port: 8080,
            expectedModelID: "expected-model"
        )
        guard case let .failed(_, message) = wrongModel else {
            return XCTFail("Expected mismatched model to fail: \(wrongModel)")
        }
        XCTAssertTrue(message.contains("expected model"))
    }

    func testManualReadyCheckResultStaysWithOriginalModelAfterSelectionChanges() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerReadyGenerationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelayedReadyURLProtocol.self]
        let checker = ReadyChecker(timeout: 1, session: URLSession(configuration: configuration))
        let viewModel = AppViewModel(settingsStore: store, readyChecker: checker)
        var firstModel = ModelConfig.defaults[0]
        firstModel.modelID = "owner/first-model"
        firstModel.displayName = "First"
        firstModel.serverPort = 18080
        var secondModel = ModelConfig.defaults[0]
        secondModel.modelID = "owner/second-model"
        secondModel.displayName = "Second"
        secondModel.serverPort = 18081
        viewModel.models = [firstModel, secondModel]
        viewModel.selectedModelID = firstModel.id
        DelayedReadyURLProtocol.response = .init(
            delay: 0.15,
            statusCode: 200,
            body: #"{"object":"list","data":[{"id":"owner/first-model"}]}"#
        )

        viewModel.checkReadyRequested()
        viewModel.selectedModelID = secondModel.id
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .ready = viewModel.runtimeState(for: firstModel) else {
            return XCTFail("Expected the first model to receive its ready result.")
        }
        XCTAssertEqual(viewModel.runtimeState(for: secondModel), .stopped)
        XCTAssertEqual(viewModel.selectedModelID, secondModel.id)
    }

    private func makeQueueEntry(
        id: UUID,
        phase: HuggingFaceDownloadPhase,
        destinationPath: String? = nil
    ) -> HuggingFaceDownloadQueueEntry {
        HuggingFaceDownloadQueueEntry(
            id: id,
            repositoryID: "owner/model-\(id.uuidString)",
            destinationPath: destinationPath ?? "/tmp/model-\(id.uuidString)",
            phase: phase,
            message: "test",
            fileCount: nil,
            downloadedFileCount: nil,
            downloadedBytes: nil,
            totalBytes: nil,
            speedBytesPerSecond: nil
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockReadyURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class DelayedSearchService: HuggingFaceModelSearching {
    func search(query: String, limit: Int) async throws -> [HuggingFaceSearchResult] {
        let delay: UInt64 = query.contains("old") ? 200_000_000 : 20_000_000
        try? await Task.sleep(nanoseconds: delay)
        return [
            HuggingFaceSearchResult(
                id: query,
                downloads: 1,
                likes: 1,
                lastModified: nil,
                tags: ["mlx"]
            )
        ]
    }
}

private final class DelayedRepositoryFileService: HuggingFaceRepositoryFileListing {
    private(set) var lastToken: String?

    func fetchFiles(
        repositoryID: String,
        revision: String,
        token: String?
    ) async throws -> [HuggingFaceDownloadPreviewFile] {
        lastToken = token
        let isOld = repositoryID.contains("old")
        try? await Task.sleep(nanoseconds: isOld ? 200_000_000 : 20_000_000)
        return [
            HuggingFaceDownloadPreviewFile(
                path: isOld ? "old.safetensors" : "new.safetensors",
                size: 10
            )
        ]
    }
}

private final class StaticCredentialStore: HuggingFaceCredentialStoring {
    private let value: String?

    init(value: String?) {
        self.value = value
    }

    func readValue() -> String? { value }
    func saveValue(_ value: String) {}
    func deleteValue() {}
}

private struct InternalTestDownloadStorageCapacityProvider: DownloadStorageCapacityProviding {
    let capacity: Int64?

    func availableCapacityForImportantUsage(at destinationDirectoryURL: URL) -> Int64? {
        capacity
    }
}

private final class MockReadyURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: String
    }

    nonisolated(unsafe) static var response = Response(statusCode: 500, body: "")

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = Self.response
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class DelayedReadyURLProtocol: URLProtocol {
    struct Response {
        let delay: TimeInterval
        let statusCode: Int
        let body: String
    }

    nonisolated(unsafe) static var response = Response(delay: 0, statusCode: 500, body: "")
    private var pendingWorkItem: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = Self.response
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingWorkItem?.isCancelled == false else { return }
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(response.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        pendingWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + response.delay, execute: workItem)
    }

    override func stopLoading() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }
}
