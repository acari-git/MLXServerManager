import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class DownloadAndReadyInternalTests: XCTestCase {
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
