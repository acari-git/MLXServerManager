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
        XCTAssertEqual(preview.compactDestinationPath, "~/Models/mlx/mlx-community/example-mlx")
        XCTAssertTrue(preview.canDownload)
    }

    func testPreviewSeparatesSameNamedRepositoriesByOwner() {
        var firstDraft = makeDownloadDraft(includePatterns: "", excludePatterns: "")
        firstDraft.source = "owner-a/shared-model"
        var secondDraft = firstDraft
        secondDraft.source = "owner-b/shared-model"

        let firstPreview = HuggingFaceDownloadPreview.make(draft: firstDraft)
        let secondPreview = HuggingFaceDownloadPreview.make(draft: secondDraft)

        XCTAssertEqual(firstPreview.compactDestinationPath, "~/Models/mlx/owner-a/shared-model")
        XCTAssertEqual(secondPreview.compactDestinationPath, "~/Models/mlx/owner-b/shared-model")
        XCTAssertNotEqual(firstPreview.destinationPath, secondPreview.destinationPath)
    }

    func testPlannerRestoresNamespacedAndLegacyBaseDirectories() {
        XCTAssertEqual(
            HuggingFaceDownloadPlanner.baseDirectory(
                forDestinationPath: "/tmp/models/owner/model",
                repositoryID: "owner/model"
            ),
            "/tmp/models"
        )
        XCTAssertEqual(
            HuggingFaceDownloadPlanner.baseDirectory(
                forDestinationPath: "/tmp/models/model",
                repositoryID: "owner/model"
            ),
            "/tmp/models"
        )
    }

    func testProgressFractionParsesPercentOutput() {
        XCTAssertEqual(HuggingFaceDownloadPlanner.progressFraction(from: "42%"), 0.42)
        XCTAssertEqual(HuggingFaceDownloadPlanner.progressFraction(from: "100% complete"), 1.0)
        XCTAssertNil(HuggingFaceDownloadPlanner.progressFraction(from: "working"))
    }

    func testOutputSanitizerRedactsExplicitBearerAndHuggingFaceTokens() {
        let explicitToken = "private-value-without-hf-prefix"
        let line = "token=\(explicitToken) Authorization: Bearer hf_abcdefghijklmnopqrstuvwxyz123456"

        let sanitized = HuggingFaceDownloadPlanner.sanitizedOutputLine(
            line,
            sensitiveValues: [explicitToken]
        )

        XCTAssertEqual(sanitized, "token=[REDACTED] Authorization: Bearer [REDACTED]")
        XCTAssertFalse(sanitized.contains(explicitToken))
        XCTAssertFalse(sanitized.contains("hf_"))
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

    func testSelectedFileModeMarksEmptySelectionInvalid() {
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
        XCTAssertFalse(selection.hasValidExplicitSelection)
    }

    func testFilteredModeDoesNotRequireExplicitSelection() {
        let draft = makeDownloadDraft(
            includePatterns: "*.json",
            excludePatterns: "",
            useSelectedPreviewFiles: false
        )

        let selection = HuggingFaceDownloadFileSelectionPlanner.make(
            files: [HuggingFaceDownloadPreviewFile(path: "config.json", size: 4)],
            draft: draft,
            selectedFileIDs: []
        )

        XCTAssertTrue(selection.hasValidExplicitSelection)
        XCTAssertEqual(selection.downloadFiles.map(\.path), ["config.json"])
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

    func testProvenanceBlocksUntrackedExistingContentWithoutChangingIt() throws {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFUntracked-\(UUID().uuidString)", isDirectory: true)
        let sentinelURL = destinationURL.appendingPathComponent("existing.bin", isDirectory: false)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try Data("original".utf8).write(to: sentinelURL)
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        let store = HuggingFaceDownloadProvenanceStore()
        let inspection = store.inspect(
            destinationURL: destinationURL,
            repositoryID: "owner/model",
            revision: "main"
        )

        XCTAssertEqual(inspection, .blocked(.destinationContainsUntrackedFiles))
        XCTAssertThrowsError(
            try store.prepare(
                destinationURL: destinationURL,
                repositoryID: "owner/model",
                revision: "main"
            )
        )
        XCTAssertEqual(try Data(contentsOf: sentinelURL), Data("original".utf8))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationURL
                    .appendingPathComponent(HuggingFaceDownloadProvenanceStore.metadataFileName)
                    .path
            )
        )
    }

    func testProvenanceAllowsOnlyMatchingRepositoryAndRevision() throws {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFProvenance-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: destinationURL) }
        let store = HuggingFaceDownloadProvenanceStore()

        try store.prepare(
            destinationURL: destinationURL,
            repositoryID: "owner/model",
            revision: "main"
        )

        XCTAssertEqual(
            store.inspect(
                destinationURL: destinationURL,
                repositoryID: "owner/model",
                revision: "main"
            ),
            .matchingSource
        )
        XCTAssertEqual(
            store.inspect(
                destinationURL: destinationURL,
                repositoryID: "other/model",
                revision: "main"
            ),
            .blocked(.sourceMismatch(existingRepositoryID: "owner/model", existingRevision: "main"))
        )
        XCTAssertEqual(
            store.inspect(
                destinationURL: destinationURL,
                repositoryID: "owner/model",
                revision: "v2"
            ),
            .blocked(.sourceMismatch(existingRepositoryID: "owner/model", existingRevision: "main"))
        )
    }

    func testDestinationIdentityResolvesSymlinkedAncestorForMissingModelFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerDestinationIdentity-\(UUID().uuidString)", isDirectory: true)
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let aliasDirectory = root.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: aliasDirectory, withDestinationURL: realDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let realDestination = realDirectory.appendingPathComponent("new-model", isDirectory: true).path
        let aliasedDestination = aliasDirectory.appendingPathComponent("new-model", isDirectory: true).path

        XCTAssertFalse(FileManager.default.fileExists(atPath: realDestination))
        XCTAssertEqual(
            HuggingFaceDownloadPlanner.destinationIdentity(path: aliasedDestination),
            HuggingFaceDownloadPlanner.destinationIdentity(path: realDestination)
        )
        XCTAssertTrue(HuggingFaceDownloadPlanner.destinationsMatch(aliasedDestination, realDestination))
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
    func testManagerRejectsMismatchedProvenanceBeforeLaunchingCLI() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFProvenanceManager-\(UUID().uuidString)", isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent(".local/bin/hf")
        let destinationURL = temporaryDirectory.appendingPathComponent("shared-model", isDirectory: true)
        let launchMarkerURL = temporaryDirectory.appendingPathComponent("launched")
        let sentinelURL = destinationURL.appendingPathComponent("existing.safetensors")
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let script = """
        #!/bin/sh
        touch "\(launchMarkerURL.path)"
        exit 0
        """
        try Data(script.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )
        try HuggingFaceDownloadProvenanceStore().prepare(
            destinationURL: destinationURL,
            repositoryID: "owner-a/shared-model",
            revision: "main"
        )
        try Data("original".utf8).write(to: sentinelURL)

        let manager = HuggingFaceDownloadManager(
            environment: ["HOME": temporaryDirectory.path, "PATH": ""]
        )
        let request = HuggingFaceDownloadRequest(
            repositoryID: "owner-b/shared-model",
            destinationPath: destinationURL.path,
            revision: "main",
            includePatterns: [],
            excludePatterns: [],
            authorizationValue: nil
        )

        do {
            _ = try await manager.download(request: request, outputHandler: { _ in })
            XCTFail("Expected mismatched provenance to be rejected.")
        } catch let HuggingFaceDownloadError.destinationPreparationFailed(message) {
            XCTAssertTrue(message.contains("owner-a/shared-model"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: launchMarkerURL.path))
        XCTAssertEqual(try Data(contentsOf: sentinelURL), Data("original".utf8))
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

    @MainActor
    func testAlreadyCancelledTaskDoesNotLaunchDownloadProcess() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFPreflightCancellationTests-\(UUID().uuidString)", isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent(".local/bin/hf")
        let destinationURL = temporaryDirectory.appendingPathComponent("model", isDirectory: true)
        let launchMarkerURL = temporaryDirectory.appendingPathComponent("launched")
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let script = """
        #!/bin/sh
        touch "\(launchMarkerURL.path)"
        exit 0
        """
        try Data(script.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let manager = HuggingFaceDownloadManager(
            environment: ["HOME": temporaryDirectory.path, "PATH": ""]
        )
        let request = HuggingFaceDownloadRequest(
            repositoryID: "owner/model",
            destinationPath: destinationURL.path,
            revision: "main",
            includePatterns: [],
            excludePatterns: [],
            authorizationValue: nil
        )

        let downloadTask = Task { @MainActor in
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return try await manager.download(request: request, outputHandler: { _ in })
        }

        do {
            _ = try await downloadTask.value
            XCTFail("Expected the pre-cancelled download to throw.")
        } catch {
            XCTAssertEqual(error as? HuggingFaceDownloadError, .cancelled)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: launchMarkerURL.path))
    }

    @MainActor
    func testManagerRedactsTokenFromChildProcessOutput() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFRedactionTests-\(UUID().uuidString)", isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent(".local/bin/hf")
        let destinationURL = temporaryDirectory.appendingPathComponent("model", isDirectory: true)
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let script = """
        #!/bin/sh
        echo "token=$HF_TOKEN"
        echo "Authorization: Bearer $HF_TOKEN" >&2
        exit 0
        """
        try Data(script.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let token = "hf_abcdefghijklmnopqrstuvwxyz123456"
        let collector = ThreadSafeStringCollector()
        let manager = HuggingFaceDownloadManager(
            environment: ["HOME": temporaryDirectory.path, "PATH": ""]
        )
        let request = HuggingFaceDownloadRequest(
            repositoryID: "owner/model",
            destinationPath: destinationURL.path,
            revision: "main",
            includePatterns: [],
            excludePatterns: [],
            authorizationValue: token
        )

        _ = try await manager.download(request: request) { line in
            collector.append(line)
        }

        let output = collector.values.joined(separator: "\n")
        XCTAssertTrue(output.contains("token=[REDACTED]"))
        XCTAssertTrue(output.contains("Authorization: Bearer [REDACTED]"))
        XCTAssertFalse(output.contains(token))
    }

    @MainActor
    func testCompletionWaitsForStdoutAndStderrEOF() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerHFOutputDrainTests-\(UUID().uuidString)", isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent(".local/bin/hf")
        let destinationURL = temporaryDirectory.appendingPathComponent("model", isDirectory: true)
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let script = """
        #!/bin/sh
        printf 'final-stdout-without-newline'
        printf 'final-stderr-without-newline' >&2
        exit 0
        """
        try Data(script.utf8).write(to: executableURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let collector = ThreadSafeStringCollector()
        let manager = HuggingFaceDownloadManager(
            environment: ["HOME": temporaryDirectory.path, "PATH": ""]
        )
        let request = HuggingFaceDownloadRequest(
            repositoryID: "owner/model",
            destinationPath: destinationURL.path,
            revision: "main",
            includePatterns: [],
            excludePatterns: [],
            authorizationValue: nil
        )

        _ = try await manager.download(request: request) { line in
            collector.append(line)
        }

        XCTAssertTrue(collector.values.contains("[hf:stdout] final-stdout-without-newline"))
        XCTAssertTrue(collector.values.contains("[hf:stderr] final-stderr-without-newline"))
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

private final class ThreadSafeStringCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.withLock { storage }
    }

    func append(_ value: String) {
        lock.withLock {
            storage.append(value)
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
