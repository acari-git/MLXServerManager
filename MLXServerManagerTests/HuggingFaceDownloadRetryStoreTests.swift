import XCTest
@testable import MLXServerManager

@MainActor
final class HuggingFaceDownloadRetryStoreTests: XCTestCase {
    func testRetryPreservesOriginalDownloadSettingsAndUsesNewQueueID() throws {
        let originalID = UUID()
        let retryID = UUID()
        let original = makeJob(id: originalID)
        var store = HuggingFaceDownloadRetryStore()
        store.record(original)

        XCTAssertEqual(store.retryKind(queueEntryID: originalID), .download)

        let retried = try XCTUnwrap(
            store.consumeRetry(queueEntryID: originalID, newQueueEntryID: retryID)
        )

        XCTAssertEqual(retried.id, retryID)
        XCTAssertEqual(retried.reference, original.reference)
        XCTAssertEqual(retried.destinationPath, original.destinationPath)
        XCTAssertEqual(retried.displayName, original.displayName)
        XCTAssertEqual(retried.draft, original.draft)
        XCTAssertEqual(retried.expectedFiles, original.expectedFiles)
        XCTAssertEqual(retried.expectedBytes, original.expectedBytes)
        XCTAssertEqual(retried.includePatterns, original.includePatterns)
        XCTAssertEqual(retried.excludePatterns, original.excludePatterns)
        XCTAssertNil(store.consumeRetry(queueEntryID: originalID, newQueueEntryID: UUID()))
        XCTAssertNil(store.retryKind(queueEntryID: originalID))
    }

    func testProfileRegistrationRetryPreservesDownloadedJobWithoutBecomingDownloadRetry() throws {
        let originalID = UUID()
        let retryID = UUID()
        let original = makeJob(id: originalID)
        var store = HuggingFaceDownloadRetryStore()
        store.record(original, kind: .profileRegistration)

        XCTAssertEqual(store.retryKind(queueEntryID: originalID), .profileRegistration)
        XCTAssertTrue(store.isRetryable(makeEntry(id: originalID, phase: .failed)))

        let retried = try XCTUnwrap(
            store.consumeRetry(queueEntryID: originalID, newQueueEntryID: retryID)
        )

        XCTAssertEqual(retried.id, retryID)
        XCTAssertEqual(retried.destinationPath, original.destinationPath)
        XCTAssertEqual(retried.draft, original.draft)
        XCTAssertNil(store.retryKind(queueEntryID: originalID))
    }

    func testLatestRetryableEntryUsesQueueOrderAndConsumesOneSnapshotAtATime() throws {
        let olderID = UUID()
        let newerID = UUID()
        var store = HuggingFaceDownloadRetryStore()
        store.record(makeJob(id: olderID))
        store.record(makeJob(id: newerID))
        let entries = [
            makeEntry(id: newerID, phase: .cancelled),
            makeEntry(id: olderID, phase: .failed)
        ]

        XCTAssertEqual(store.latestRetryableEntry(in: entries)?.id, newerID)
        _ = try XCTUnwrap(store.consumeRetry(queueEntryID: newerID, newQueueEntryID: UUID()))
        XCTAssertEqual(store.latestRetryableEntry(in: entries)?.id, olderID)
    }

    func testSpecificEntryRetryDoesNotConsumeAnotherFailure() throws {
        let firstID = UUID()
        let secondID = UUID()
        var store = HuggingFaceDownloadRetryStore()
        store.record(makeJob(id: firstID))
        store.record(makeJob(id: secondID))
        let firstEntry = makeEntry(id: firstID, phase: .failed)
        let secondEntry = makeEntry(id: secondID, phase: .cancelled)

        XCTAssertTrue(store.isRetryable(firstEntry))
        XCTAssertTrue(store.isRetryable(secondEntry))

        _ = try XCTUnwrap(store.consumeRetry(queueEntryID: firstID, newQueueEntryID: UUID()))

        XCTAssertFalse(store.isRetryable(firstEntry))
        XCTAssertTrue(store.isRetryable(secondEntry))
    }

    func testSnapshotIsNotRetryableUntilEntryIsTerminal() {
        let id = UUID()
        var store = HuggingFaceDownloadRetryStore()
        store.record(makeJob(id: id))

        XCTAssertFalse(store.isRetryable(makeEntry(id: id, phase: .waiting)))
        XCTAssertFalse(store.isRetryable(makeEntry(id: id, phase: .downloading)))
        XCTAssertFalse(store.isRetryable(makeEntry(id: id, phase: .completed)))
        XCTAssertTrue(store.isRetryable(makeEntry(id: id, phase: .failed)))
        XCTAssertTrue(store.isRetryable(makeEntry(id: id, phase: .cancelled)))
    }

    func testCompletedAndDiscardedSnapshotsAreNotRetryable() {
        let completedID = UUID()
        let discardedID = UUID()
        var store = HuggingFaceDownloadRetryStore()
        store.record(makeJob(id: completedID))
        store.record(makeJob(id: discardedID))
        store.discard(queueEntryID: discardedID)

        let entries = [
            makeEntry(id: discardedID, phase: .failed),
            makeEntry(id: completedID, phase: .completed)
        ]

        XCTAssertNil(store.latestRetryableEntry(in: entries))
    }

    func testRetainDiscardsSnapshotsRemovedFromQueueHistory() {
        let retainedID = UUID()
        let removedID = UUID()
        var store = HuggingFaceDownloadRetryStore()
        store.record(makeJob(id: retainedID))
        store.record(makeJob(id: removedID))

        store.retain(queueEntryIDs: [retainedID])

        XCTAssertNotNil(store.consumeRetry(queueEntryID: retainedID, newQueueEntryID: UUID()))
        XCTAssertNil(store.consumeRetry(queueEntryID: removedID, newQueueEntryID: UUID()))
    }

    func testPersistenceSnapshotRoundTripsRetryableEntriesInQueueOrder() {
        let firstID = UUID()
        let secondID = UUID()
        let firstJob = makeJob(id: firstID)
        let secondJob = makeJob(id: secondID)
        let firstEntry = makeEntry(id: firstID, phase: .failed)
        let secondEntry = makeEntry(id: secondID, phase: .cancelled)
        var source = HuggingFaceDownloadRetryStore()
        source.record(firstJob, kind: .profileRegistration)
        source.record(secondJob, kind: .download)

        let snapshot = source.persistenceSnapshot(entries: [secondEntry, firstEntry])
        var restored = HuggingFaceDownloadRetryStore()
        let restoredEntries = restored.restore(from: snapshot)

        XCTAssertEqual(restoredEntries, [secondEntry, firstEntry])
        XCTAssertEqual(restored.retryKind(queueEntryID: secondID), .download)
        XCTAssertEqual(restored.retryKind(queueEntryID: firstID), .profileRegistration)
        XCTAssertTrue(restored.isRetryable(secondEntry))
        XCTAssertTrue(restored.isRetryable(firstEntry))
    }

    func testPersistenceSnapshotRestoresUnfinishedDownloadAsRetryableInterruption() throws {
        let id = UUID()
        let job = makeJob(id: id)
        var activeEntry = makeEntry(id: id, phase: .downloading)
        activeEntry.message = "Downloading... 42%"
        activeEntry.downloadedBytes = 42
        activeEntry.totalBytes = 100
        activeEntry.speedBytesPerSecond = 12
        var source = HuggingFaceDownloadRetryStore()
        source.record(job)

        let snapshot = source.persistenceSnapshot(entries: [activeEntry])
        var restored = HuggingFaceDownloadRetryStore()
        let restoredEntry = try XCTUnwrap(restored.restore(from: snapshot).first)

        XCTAssertEqual(snapshot.records.map(\.entry.id), [id])
        XCTAssertEqual(restoredEntry.phase, .cancelled)
        XCTAssertEqual(restoredEntry.downloadedBytes, 42)
        XCTAssertEqual(restoredEntry.totalBytes, 100)
        XCTAssertNil(restoredEntry.speedBytesPerSecond)
        XCTAssertTrue(restoredEntry.message.contains("interrupted"))
        XCTAssertTrue(restored.isRetryable(restoredEntry))
        XCTAssertEqual(restored.retryKind(queueEntryID: id), .download)
    }

    func testPersistenceSnapshotExcludesCompletedAndNonterminalProfileRegistrationEntries() {
        let completedID = UUID()
        let profileID = UUID()
        var store = HuggingFaceDownloadRetryStore()
        store.record(makeJob(id: completedID))
        store.record(makeJob(id: profileID), kind: .profileRegistration)

        let snapshot = store.persistenceSnapshot(entries: [
            makeEntry(id: completedID, phase: .completed),
            makeEntry(id: profileID, phase: .finalizing)
        ])

        XCTAssertTrue(snapshot.records.isEmpty)
    }

    func testRestoreAcceptsNonterminalDownloadAndRejectsInvalidRecords() {
        let validID = UUID()
        let nonterminalID = UUID()
        let mismatchedID = UUID()
        let validJob = makeJob(id: validID)
        let records = [
            HuggingFaceDownloadRetryRecord(
                entry: makeEntry(id: validID, phase: .failed),
                job: validJob,
                kind: .download
            ),
            HuggingFaceDownloadRetryRecord(
                entry: makeEntry(id: nonterminalID, phase: .downloading),
                job: makeJob(id: nonterminalID),
                kind: .download
            ),
            HuggingFaceDownloadRetryRecord(
                entry: makeEntry(id: mismatchedID, phase: .failed),
                job: validJob,
                kind: .profileRegistration
            )
        ]
        var store = HuggingFaceDownloadRetryStore()

        let restoredEntries = store.restore(
            from: HuggingFaceDownloadRetrySnapshot(records: records)
        )

        XCTAssertEqual(restoredEntries.map(\.id), [validID, nonterminalID])
        XCTAssertEqual(restoredEntries.last?.phase, .cancelled)
        XCTAssertEqual(store.retryKind(queueEntryID: validID), .download)
        XCTAssertEqual(store.retryKind(queueEntryID: nonterminalID), .download)
        XCTAssertNil(store.retryKind(queueEntryID: mismatchedID))
    }

    func testSettingsStorePersistsRetrySnapshotWithoutCredentialFields() throws {
        let settingsStore = SettingsStore(
            appDirectoryName: "MLXServerManagerRetryPersistenceTests-\(UUID().uuidString)"
        )
        defer { removeSettingsStore(settingsStore) }
        let id = UUID()
        var retryStore = HuggingFaceDownloadRetryStore()
        retryStore.record(makeJob(id: id), kind: .profileRegistration)
        let snapshot = retryStore.persistenceSnapshot(
            entries: [makeEntry(id: id, phase: .failed)]
        )

        try settingsStore.save(huggingFaceDownloadRetries: snapshot)
        let loaded = try settingsStore.loadHuggingFaceDownloadRetries()
        let persistedText = try String(
            contentsOf: settingsStore.huggingFaceDownloadRetriesFileURL,
            encoding: .utf8
        )

        XCTAssertFalse(loaded.usedDefault)
        XCTAssertEqual(loaded.value, snapshot)
        XCTAssertFalse(persistedText.localizedCaseInsensitiveContains("authorizationValue"))
        XCTAssertFalse(persistedText.localizedCaseInsensitiveContains("credential"))
    }

    func testAppViewModelRestoresRetryableDownloadAfterRestart() throws {
        let settingsStore = SettingsStore(
            appDirectoryName: "MLXServerManagerRetryRestoreTests-\(UUID().uuidString)"
        )
        defer { removeSettingsStore(settingsStore) }
        let id = UUID()
        var retryStore = HuggingFaceDownloadRetryStore()
        retryStore.record(makeJob(id: id), kind: .profileRegistration)
        try settingsStore.save(
            huggingFaceDownloadRetries: retryStore.persistenceSnapshot(
                entries: [makeEntry(id: id, phase: .failed)]
            )
        )

        let viewModel = AppViewModel(settingsStore: settingsStore)

        XCTAssertEqual(viewModel.huggingFaceDownloadQueue.map(\.id), [id])
        XCTAssertTrue(viewModel.canRetryHuggingFaceDownload(id: id))
        XCTAssertEqual(viewModel.currentRecoveryIssue.category, .profileRegistration)
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.phase, .failed)
    }

    func testAppViewModelRestoresInterruptedDownloadAfterRestart() throws {
        let settingsStore = SettingsStore(
            appDirectoryName: "MLXServerManagerInterruptedDownloadTests-\(UUID().uuidString)"
        )
        defer { removeSettingsStore(settingsStore) }
        let id = UUID()
        var retryStore = HuggingFaceDownloadRetryStore()
        retryStore.record(makeJob(id: id))
        try settingsStore.save(
            huggingFaceDownloadRetries: retryStore.persistenceSnapshot(
                entries: [makeEntry(id: id, phase: .downloading)]
            )
        )

        let viewModel = AppViewModel(settingsStore: settingsStore)
        let restoredEntry = try XCTUnwrap(viewModel.huggingFaceDownloadQueue.first)

        XCTAssertEqual(restoredEntry.id, id)
        XCTAssertEqual(restoredEntry.phase, .cancelled)
        XCTAssertTrue(restoredEntry.message.contains("interrupted"))
        XCTAssertTrue(viewModel.canRetryHuggingFaceDownload(id: id))
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.phase, .cancelled)
    }

    func testProfileRegistrationRetryReclassifiesIncompleteModelAsDownloadRetry() throws {
        let settingsStore = SettingsStore(
            appDirectoryName: "MLXServerManagerIncompleteProfileRetryTests-\(UUID().uuidString)"
        )
        defer { removeSettingsStore(settingsStore) }
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: modelURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: modelURL) }
        try Data(#"{"model_type":"test"}"#.utf8).write(
            to: modelURL.appendingPathComponent("config.json")
        )

        let id = UUID()
        var retryStore = HuggingFaceDownloadRetryStore()
        retryStore.record(
            makeJob(id: id, destinationPath: modelURL.path, autoAddToModelList: true),
            kind: .profileRegistration
        )
        try settingsStore.save(
            huggingFaceDownloadRetries: retryStore.persistenceSnapshot(
                entries: [makeEntry(id: id, phase: .failed, destinationPath: modelURL.path)]
            )
        )

        let viewModel = AppViewModel(settingsStore: settingsStore)
        viewModel.retryHuggingFaceDownload(id: id)

        let retryEntry = try XCTUnwrap(viewModel.huggingFaceDownloadQueue.first)
        XCTAssertNotEqual(retryEntry.id, id)
        XCTAssertEqual(retryEntry.phase, .failed)
        XCTAssertTrue(viewModel.canRetryHuggingFaceDownload(id: retryEntry.id))
        XCTAssertTrue(
            viewModel.currentRecoveryIssue.actions.contains { $0.kind == .retryDownload }
        )
        XCTAssertFalse(
            viewModel.currentRecoveryIssue.actions.contains { $0.kind == .retryProfileRegistration }
        )
        XCTAssertFalse(viewModel.models.contains { $0.modelID == modelURL.path })
    }

    func testProfileRegistrationRetryAddsCompleteModelWithoutDownloadingAgain() throws {
        let settingsStore = SettingsStore(
            appDirectoryName: "MLXServerManagerCompleteProfileRetryTests-\(UUID().uuidString)"
        )
        defer { removeSettingsStore(settingsStore) }
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: modelURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: modelURL) }
        try Data(#"{"model_type":"test"}"#.utf8).write(
            to: modelURL.appendingPathComponent("config.json")
        )
        try Data(#"{"version":"1.0"}"#.utf8).write(
            to: modelURL.appendingPathComponent("tokenizer.json")
        )
        try Data([1]).write(to: modelURL.appendingPathComponent("model.safetensors"))

        let id = UUID()
        var retryStore = HuggingFaceDownloadRetryStore()
        retryStore.record(
            makeJob(id: id, destinationPath: modelURL.path, autoAddToModelList: true),
            kind: .profileRegistration
        )
        try settingsStore.save(
            huggingFaceDownloadRetries: retryStore.persistenceSnapshot(
                entries: [makeEntry(id: id, phase: .failed, destinationPath: modelURL.path)]
            )
        )

        let viewModel = AppViewModel(settingsStore: settingsStore)
        viewModel.retryHuggingFaceDownload(id: id)

        let retryEntry = try XCTUnwrap(viewModel.huggingFaceDownloadQueue.first)
        XCTAssertEqual(retryEntry.phase, .completed)
        XCTAssertFalse(viewModel.canRetryHuggingFaceDownload(id: retryEntry.id))
        XCTAssertTrue(viewModel.models.contains { $0.modelID == modelURL.path })
    }

    func testAppViewModelIgnoresCorruptPersistedRetryState() throws {
        let settingsStore = SettingsStore(
            appDirectoryName: "MLXServerManagerRetryCorruptionTests-\(UUID().uuidString)"
        )
        defer { removeSettingsStore(settingsStore) }
        try FileManager.default.createDirectory(
            at: settingsStore.settingsDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data("{not-valid-json".utf8).write(
            to: settingsStore.huggingFaceDownloadRetriesFileURL
        )

        let viewModel = AppViewModel(settingsStore: settingsStore)

        XCTAssertTrue(viewModel.huggingFaceDownloadQueue.isEmpty)
        XCTAssertFalse(viewModel.canRetryHuggingFaceDownload)
    }

    private func makeJob(
        id: UUID,
        destinationPath: String = "/tmp/models/original-model",
        autoAddToModelList: Bool = false
    ) -> HuggingFaceDownloadJob {
        var draft = HuggingFaceDownloadDraft.defaults(defaultHost: "127.0.0.1", defaultPort: 8080)
        draft.source = "owner/original-model"
        draft.revision = "refs/pr/42"
        draft.includePatterns = "*.safetensors, tokenizer.json"
        draft.excludePatterns = "*.bin"
        draft.useSelectedPreviewFiles = true
        draft.saveDirectory = URL(fileURLWithPath: destinationPath).deletingLastPathComponent().path
        draft.displayName = "Original display name"
        draft.host = "localhost"
        draft.serverPortText = "9000"
        draft.enableThinking = true
        draft.autoAddToModelList = autoAddToModelList
        draft.autoSelectAfterAdd = false

        return HuggingFaceDownloadJob(
            id: id,
            reference: HuggingFaceModelReference(
                repositoryID: "owner/original-model",
                owner: "owner",
                name: "original-model"
            ),
            destinationPath: destinationPath,
            displayName: "Original display name",
            draft: draft,
            expectedFiles: [
                HuggingFaceDownloadPreviewFile(path: "weights/model.safetensors", size: 123),
                HuggingFaceDownloadPreviewFile(path: "tokenizer.json", size: 45)
            ],
            expectedBytes: 168,
            includePatterns: ["weights/model.safetensors", "tokenizer.json"],
            excludePatterns: ["*.bin"]
        )
    }

    private func makeEntry(
        id: UUID,
        phase: HuggingFaceDownloadPhase,
        destinationPath: String = "/tmp/models/original-model"
    ) -> HuggingFaceDownloadQueueEntry {
        HuggingFaceDownloadQueueEntry(
            id: id,
            repositoryID: "owner/original-model",
            destinationPath: destinationPath,
            phase: phase,
            message: "test",
            fileCount: nil,
            downloadedFileCount: nil,
            downloadedBytes: nil,
            totalBytes: nil,
            speedBytesPerSecond: nil
        )
    }

    private func removeSettingsStore(_ store: SettingsStore) {
        guard let directory = try? store.settingsDirectoryURL else {
            return
        }
        try? FileManager.default.removeItem(at: directory)
    }
}
