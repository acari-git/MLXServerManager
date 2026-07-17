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
            revision: "main",
            includePatterns: "*.safetensors, *.json, tokenizer.*, *.model, *.txt",
            excludePatterns: "*.h5, *.onnx, *.msgpack, *.bin",
            useSelectedPreviewFiles: false,
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

    func testFileSelectionParsesPatternsOnceAndFiltersByPathOrBasename() {
        let draft = makeDownloadDraft(
            includePatterns: " *.safetensors, config/*.json, tokenizer.? ",
            excludePatterns: " *draft* "
        )
        let files = [
            HuggingFaceDownloadPreviewFile(path: "weights/model.safetensors", size: 10),
            HuggingFaceDownloadPreviewFile(path: "config/model.json", size: 20),
            HuggingFaceDownloadPreviewFile(path: "nested/tokenizer.a", size: 30),
            HuggingFaceDownloadPreviewFile(path: "weights/model-draft.safetensors", size: 40),
            HuggingFaceDownloadPreviewFile(path: "README.md", size: 50)
        ]

        let selection = HuggingFaceDownloadFileSelectionPlanner.make(
            files: files,
            draft: draft,
            selectedFileIDs: Set(files.map(\.id))
        )

        XCTAssertEqual(
            selection.filteredFiles.map(\.path),
            ["weights/model.safetensors", "config/model.json", "nested/tokenizer.a"]
        )
        XCTAssertEqual(selection.downloadIncludePatterns, ["*.safetensors", "config/*.json", "tokenizer.?"])
        XCTAssertEqual(selection.downloadExcludePatterns, ["*draft*"])
        XCTAssertEqual(selection.totalDownloadBytes, 60)
    }

    func testSelectedFileModeUsesOnlyFilteredSelectedFilesAndExactPaths() {
        let draft = makeDownloadDraft(
            includePatterns: "*.safetensors, *.json",
            excludePatterns: "*.bin",
            useSelectedPreviewFiles: true
        )
        let files = [
            HuggingFaceDownloadPreviewFile(path: "a.safetensors", size: 3),
            HuggingFaceDownloadPreviewFile(path: "b.json", size: 4),
            HuggingFaceDownloadPreviewFile(path: "c.bin", size: 5)
        ]

        let selection = HuggingFaceDownloadFileSelectionPlanner.make(
            files: files,
            draft: draft,
            selectedFileIDs: ["b.json", "c.bin"]
        )

        XCTAssertEqual(selection.selectedFiles.map(\.path), ["b.json"])
        XCTAssertEqual(selection.downloadFiles.map(\.path), ["b.json"])
        XCTAssertEqual(selection.downloadIncludePatterns, ["b.json"])
        XCTAssertEqual(selection.downloadExcludePatterns, ["*.bin"])
        XCTAssertEqual(selection.totalDownloadBytes, 4)
    }

    func testSelectedFileModePreservesEmptySelectionBehavior() {
        let draft = makeDownloadDraft(
            includePatterns: "*.json",
            excludePatterns: "",
            useSelectedPreviewFiles: true
        )

        let selection = HuggingFaceDownloadFileSelectionPlanner.make(
            files: [HuggingFaceDownloadPreviewFile(path: "config.json", size: 4)],
            draft: draft,
            selectedFileIDs: []
        )

        XCTAssertTrue(selection.downloadFiles.isEmpty)
        XCTAssertEqual(selection.downloadIncludePatterns, ["*.json"])
        XCTAssertNil(selection.totalDownloadBytes)
    }

    func testFileSelectionReportsUnknownTotalWithoutDiscardingKnownBytes() {
        let draft = makeDownloadDraft(includePatterns: "", excludePatterns: "")

        let selection = HuggingFaceDownloadFileSelectionPlanner.make(
            files: [
                HuggingFaceDownloadPreviewFile(path: "known.json", size: 7),
                HuggingFaceDownloadPreviewFile(path: "unknown.safetensors", size: nil)
            ],
            draft: draft,
            selectedFileIDs: []
        )

        XCTAssertEqual(selection.knownDownloadByteCount, 7)
        XCTAssertTrue(selection.hasUnknownDownloadSize)
        XCTAssertNil(selection.totalDownloadBytes)
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

    @MainActor
    func testCancellationCompletesAndManagerCanBeReused() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFTests-\(UUID().uuidString)", isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent(".local/bin/hf")
        let destinationURL = temporaryDirectory.appendingPathComponent("model", isDirectory: true)
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let blockingScript = """
        #!/bin/sh
        trap '' TERM INT
        while true; do sleep 0.05; done
        """
        try Data(blockingScript.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let manager = HuggingFaceDownloadManager(
            environment: ["HOME": temporaryDirectory.path, "PATH": ""],
            cancellationGracePeriod: 0.05,
            cancellationInterruptPeriod: 0.05
        )
        let request = HuggingFaceDownloadRequest(
            repositoryID: "owner/model",
            destinationPath: destinationURL.path,
            revision: "main",
            includePatterns: [],
            excludePatterns: [],
            authorizationValue: nil
        )

        let downloadTask = Task {
            try await manager.download(request: request, outputHandler: { _ in })
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        manager.cancel()

        do {
            _ = try await downloadTask.value
            XCTFail("Expected the cancelled download to throw.")
        } catch {
            XCTAssertEqual(error as? HuggingFaceDownloadError, .cancelled)
        }

        let successfulScript = """
        #!/bin/sh
        exit 0
        """
        try Data(successfulScript.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let result = try await manager.download(request: request, outputHandler: { _ in })
        XCTAssertEqual(result.terminationStatus, 0)
    }

    private func success(_ result: Result<HuggingFaceModelReference, HuggingFaceModelReferenceError>) throws -> HuggingFaceModelReference {
        switch result {
        case let .success(reference):
            return reference
        case let .failure(error):
            throw error
        }
    }

    private func makeDownloadDraft(
        includePatterns: String,
        excludePatterns: String,
        useSelectedPreviewFiles: Bool = false
    ) -> HuggingFaceDownloadDraft {
        HuggingFaceDownloadDraft(
            source: "owner/model",
            revision: "main",
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            useSelectedPreviewFiles: useSelectedPreviewFiles,
            saveDirectory: "~/Models/mlx",
            displayName: "",
            host: "127.0.0.1",
            serverPortText: "8000",
            enableThinking: false,
            autoAddToModelList: true,
            autoSelectAfterAdd: true
        )
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
