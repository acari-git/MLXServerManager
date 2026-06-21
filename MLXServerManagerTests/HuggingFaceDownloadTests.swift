import XCTest
@testable import MLXServerManager

final class HuggingFaceDownloadTests: XCTestCase {
    func testRepositoryIDParsesOwnerAndModelName() throws {
        let reference = try success(HuggingFaceModelReference.parse("mlx-community/example-mlx"))

        XCTAssertEqual(reference.repositoryID, "mlx-community/example-mlx")
        XCTAssertEqual(reference.owner, "mlx-community")
        XCTAssertEqual(reference.name, "example-mlx")
    }

    func testModelURLParsesRepositoryIDAndIgnoresSubpath() throws {
        let reference = try success(
            HuggingFaceModelReference.parse("https://huggingface.co/mlx-community/example-mlx/tree/main")
        )

        XCTAssertEqual(reference.repositoryID, "mlx-community/example-mlx")
        XCTAssertEqual(reference.name, "example-mlx")
    }

    func testInvalidRepositoryIDIsRejected() {
        let result = HuggingFaceModelReference.parse("just-a-model-name")

        XCTAssertEqual(result.failure, .invalidRepositoryID)
    }

    func testPreviewBuildsDestinationFromDefaultBaseDirectory() {
        let draft = HuggingFaceDownloadDraft(
            source: "mlx-community/example-mlx",
            saveDirectory: "~/Models/mlx",
            displayName: "",
            host: "127.0.0.1",
            serverPortText: "8080",
            enableThinking: false,
            autoAddToModelList: true,
            autoSelectAfterAdd: true
        )

        let preview = HuggingFaceDownloadPreview.make(draft: draft)

        XCTAssertEqual(preview.reference?.repositoryID, "mlx-community/example-mlx")
        XCTAssertEqual(preview.displayName, "example-mlx")
        XCTAssertEqual(preview.compactDestinationPath, "~/Models/mlx/example-mlx")
        XCTAssertTrue(preview.canDownload)
    }

    func testProgressFractionParsesPercentOutput() {
        XCTAssertEqual(HuggingFaceDownloadPlanner.progressFraction(from: "42%"), 0.42)
        XCTAssertEqual(HuggingFaceDownloadPlanner.progressFraction(from: "100% complete"), 1.0)
        XCTAssertNil(HuggingFaceDownloadPlanner.progressFraction(from: "working"))
    }

    func testDestinationStateDistinguishesNewFolderDirectoryAndFile() throws {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let newPath = baseURL.appendingPathComponent("new-model", isDirectory: true).path
        let directoryURL = baseURL.appendingPathComponent("existing-model", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent("existing-file", isDirectory: false)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try "not a directory".write(to: fileURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: baseURL)
        }

        XCTAssertTrue(HuggingFaceDownloadPlanner.destinationState(path: newPath).canUse)
        XCTAssertTrue(HuggingFaceDownloadPlanner.destinationState(path: directoryURL.path).canUse)
        XCTAssertFalse(HuggingFaceDownloadPlanner.destinationState(path: fileURL.path).canUse)
    }

    func testCandidateExecutablePathsIncludeUserLocalAndHomebrewPaths() {
        let candidates = HuggingFaceDownloadManager.candidateExecutablePaths(
            environment: [
                "HOME": "/Users/example",
                "PATH": "/custom/bin:/usr/bin"
            ]
        )

        XCTAssertEqual(candidates.first, "/Users/example/.local/bin/hf")
        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/hf"))
        XCTAssertTrue(candidates.contains("/usr/local/bin/hf"))
        XCTAssertTrue(candidates.contains("/custom/bin/hf"))
    }

    private func success(_ result: Result<HuggingFaceModelReference, HuggingFaceModelReferenceError>) throws -> HuggingFaceModelReference {
        switch result {
        case let .success(reference):
            return reference
        case let .failure(error):
            throw error
        }
    }
}

private extension Result where Failure == HuggingFaceModelReferenceError {
    var failure: HuggingFaceModelReferenceError? {
        guard case let .failure(error) = self else {
            return nil
        }

        return error
    }
}
