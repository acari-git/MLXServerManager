import Combine
import XCTest
@testable import MLXServerManager

@MainActor
final class MonitoringPublicationTests: XCTestCase {
    func testSystemUsageSamplePublishesOneCoherentUpdate() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerMonitoringPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.applySystemUsageSample(
            SystemUsageMonitorSample(
                cpuPercent: 42,
                gpuPercent: nil,
                systemMemorySnapshot: SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 40 * 1_073_741_824
                )
            )
        )

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.cpuUsagePercent, 42)
        XCTAssertNil(viewModel.gpuUsagePercent)
        XCTAssertEqual(viewModel.systemMemorySnapshot?.availableBytes, 40 * 1_073_741_824)
        XCTAssertEqual(viewModel.memoryHistory.count, 1)
        XCTAssertEqual(viewModel.systemUsageHistory.count, 1)
        withExtendedLifetime(cancellable) {}
    }

    func testHuggingFaceSearchPublishesOneCoherentUpdatePerPhase() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerSearchPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let result = HuggingFaceSearchResult(
            id: "owner/model",
            downloads: 10,
            likes: 2,
            lastModified: nil,
            tags: ["mlx"]
        )
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.updateHuggingFaceSearchViewState { state in
            state.beginSearch(message: "Searching")
        }
        viewModel.updateHuggingFaceSearchViewState { state in
            state.beginSearch(message: "Searching")
        }

        XCTAssertEqual(publicationCount, 1)
        XCTAssertTrue(viewModel.isHuggingFaceSearching)
        XCTAssertEqual(viewModel.huggingFaceSearchMessage, "Searching")

        viewModel.updateHuggingFaceSearchViewState { state in
            state.completeSearch(
                results: [result],
                selectedResult: result,
                message: "Selected"
            )
        }
        viewModel.updateHuggingFaceSearchViewState { state in
            state.completeSearch(
                results: [result],
                selectedResult: result,
                message: "Selected"
            )
        }

        XCTAssertEqual(publicationCount, 2)
        XCTAssertFalse(viewModel.isHuggingFaceSearching)
        XCTAssertEqual(viewModel.huggingFaceSearchResults, [result])
        XCTAssertEqual(viewModel.selectedHuggingFaceSearchResult, result)
        XCTAssertEqual(viewModel.huggingFaceSearchMessage, "Selected")
        withExtendedLifetime(cancellable) {}
    }

    func testHuggingFaceFilePreviewPublishesOneCoherentUpdatePerPhase() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerFilePreviewPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let identity = HuggingFaceFilePreviewIdentity(
            repositoryID: "owner/model",
            revision: "main"
        )
        let files = [
            HuggingFaceDownloadPreviewFile(path: "model.safetensors", size: 100),
            HuggingFaceDownloadPreviewFile(path: "config.json", size: 20)
        ]
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.updateHuggingFaceFilePreviewViewState { state in
            state.begin(identity: identity, message: "Fetching")
        }
        viewModel.updateHuggingFaceFilePreviewViewState { state in
            state.begin(identity: identity, message: "Fetching")
        }

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.huggingFaceFilePreviewIdentity, identity)
        XCTAssertTrue(viewModel.huggingFaceFilePreview.isLoading)
        XCTAssertTrue(viewModel.selectedHuggingFacePreviewFileIDs.isEmpty)

        viewModel.updateHuggingFaceFilePreviewViewState { state in
            state.complete(files: files, message: "Ready")
        }
        viewModel.updateHuggingFaceFilePreviewViewState { state in
            state.complete(files: files, message: "Ready")
        }

        XCTAssertEqual(publicationCount, 2)
        XCTAssertFalse(viewModel.huggingFaceFilePreview.isLoading)
        XCTAssertEqual(viewModel.huggingFaceFilePreview.message, "Ready")
        XCTAssertEqual(viewModel.huggingFaceFilePreview.files, files)
        XCTAssertEqual(viewModel.selectedHuggingFacePreviewFileIDs, Set(files.map(\.id)))

        viewModel.toggleHuggingFacePreviewFile(files[0])
        XCTAssertEqual(publicationCount, 3)
        XCTAssertEqual(viewModel.selectedHuggingFacePreviewFileIDs, [files[1].id])
        withExtendedLifetime(cancellable) {}
    }

    func testRuntimeStatePublishesOneCoherentUpdate() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerRuntimePublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let modelID = try XCTUnwrap(viewModel.selectedModelID)
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        let state = ModelRuntimeState.checkingReady(host: "127.0.0.1", port: 8080)
        viewModel.setRuntimeState(state, for: modelID)
        viewModel.setRuntimeState(state, for: modelID)

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.runtimeState, state)
        XCTAssertEqual(viewModel.runtimeStatesByModelID[modelID], state)
        withExtendedLifetime(cancellable) {}
    }

    func testMeasuredDownloadProgressPublishesOneCoherentUpdate() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerDownloadPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.settings.uiLanguage = .english
        let entryID = UUID()
        viewModel.replaceHuggingFaceDownloadQueue([
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
        ])
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.updateMeasuredHuggingFaceProgress(
            queueEntryID: entryID,
            downloadedBytes: 400,
            downloadedFileCount: 3,
            totalBytes: 1_000,
            speedBytesPerSecond: 200
        )

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.huggingFaceDownloadQueue.first?.phase, .downloading)
        XCTAssertEqual(viewModel.huggingFaceDownloadQueue.first?.downloadedBytes, 400)
        XCTAssertEqual(viewModel.huggingFaceDownloadQueue.first?.downloadedFileCount, 3)
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.progress ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.message, "Downloading... 40%")
        withExtendedLifetime(cancellable) {}
    }

    func testHuggingFaceOutputBurstPublishesOncePerStateAfterManualFlush() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerOutputBatchPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let entryID = UUID()
        viewModel.replaceHuggingFaceDownloadQueue([
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .preparing,
                message: "Preparing",
                fileCount: nil,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: nil,
                speedBytesPerSecond: nil
            )
        ])
        let initialLogCount = viewModel.logEntries.count
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.appendHuggingFaceOutputLine("[hf:stdout] metadata", queueEntryID: entryID)
        viewModel.appendHuggingFaceOutputLine("[hf:stderr] 21%", queueEntryID: entryID)
        viewModel.appendHuggingFaceOutputLine("[hf:stderr] 42%", queueEntryID: entryID)

        XCTAssertEqual(publicationCount, 0)
        viewModel.flushPendingHuggingFaceOutput(queueEntryID: entryID)

        XCTAssertEqual(publicationCount, 2)
        XCTAssertEqual(viewModel.huggingFaceDownloadQueue.first?.phase, .downloading)
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.outputLines, [
            "[hf:stdout] metadata",
            "[hf:stderr] 21%",
            "[hf:stderr] 42%"
        ])
        XCTAssertEqual(viewModel.logEntries.count, initialLogCount + 3)

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(publicationCount, 2)
        withExtendedLifetime(cancellable) {}
    }

    func testScheduledHuggingFaceOutputFlushPublishesOneBatchPerState() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerScheduledOutputPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let entryID = UUID()
        viewModel.replaceHuggingFaceDownloadQueue([
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .preparing,
                message: "Preparing",
                fileCount: nil,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: nil,
                speedBytesPerSecond: nil
            )
        ])
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.appendHuggingFaceOutputLine("[hf:stdout] first", queueEntryID: entryID)
        viewModel.appendHuggingFaceOutputLine("[hf:stdout] second", queueEntryID: entryID)
        XCTAssertEqual(publicationCount, 0)

        for _ in 0..<40 where viewModel.huggingFaceDownloadStatus.outputLines.count < 2 {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(publicationCount, 2)
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.outputLines, [
            "[hf:stdout] first",
            "[hf:stdout] second"
        ])
        try await Task.sleep(nanoseconds: 160_000_000)
        XCTAssertEqual(publicationCount, 2)
        withExtendedLifetime(cancellable) {}
    }

    func testUrgentHuggingFaceOutputFlushesPendingLinesImmediately() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerUrgentOutputPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let entryID = UUID()
        viewModel.replaceHuggingFaceDownloadQueue([
            HuggingFaceDownloadQueueEntry(
                id: entryID,
                repositoryID: "owner/model",
                destinationPath: "/tmp/model",
                phase: .preparing,
                message: "Preparing",
                fileCount: nil,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: nil,
                speedBytesPerSecond: nil
            )
        ])
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.appendHuggingFaceOutputLine("[hf:stdout] preparing", queueEntryID: entryID)
        viewModel.appendHuggingFaceOutputLine("[hf:stderr] fatal error", queueEntryID: entryID)

        XCTAssertEqual(publicationCount, 2)
        XCTAssertEqual(viewModel.huggingFaceDownloadStatus.outputLines, [
            "[hf:stdout] preparing",
            "[hf:stderr] fatal error"
        ])
        XCTAssertEqual(viewModel.logEntries.suffix(2).map(\.line), [
            "[hf:stdout] preparing",
            "[hf:stderr] fatal error"
        ])
        withExtendedLifetime(cancellable) {}
    }

    func testMiniChatLifecyclePublishesOneCoherentUpdatePerPhase() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerMiniChatPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.miniChatPrompt = "hello"
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.applyMiniChatRequestStart(
            prompt: "hello",
            status: "Sending"
        )

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.miniChatPrompt, "")
        XCTAssertEqual(viewModel.miniChatMessages.map(\.content), ["hello"])
        XCTAssertTrue(viewModel.isMiniChatRunning)
        XCTAssertEqual(viewModel.miniChatStatus, "Sending")
        XCTAssertEqual(viewModel.miniChatHTTPStatusText, "-")
        XCTAssertEqual(viewModel.miniChatDurationText, "-")
        XCTAssertEqual(viewModel.miniChatResponse, "")

        publicationCount = 0
        viewModel.applyMiniChatRequestCompletion(
            response: "world",
            sender: .assistant,
            status: "Received",
            httpStatusText: "HTTP 200",
            durationText: "12 ms"
        )

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.miniChatMessages.map(\.content), ["hello", "world"])
        XCTAssertEqual(viewModel.miniChatResponse, "world")
        XCTAssertEqual(viewModel.miniChatStatus, "Received")
        XCTAssertEqual(viewModel.miniChatHTTPStatusText, "HTTP 200")
        XCTAssertEqual(viewModel.miniChatDurationText, "12 ms")
        XCTAssertFalse(viewModel.isMiniChatRunning)
        withExtendedLifetime(cancellable) {}
    }

    func testDiagnosticsPublishesOneCoherentUpdatePerPhase() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerDiagnosticsPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let result = DiagnosticsResult(
            check: .hostConfigured,
            status: .pass,
            message: "Host is configured."
        )
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.updateDiagnosticsViewState { state in
            state.beginRun()
        }
        viewModel.updateDiagnosticsViewState { state in
            state.beginRun()
        }

        XCTAssertEqual(publicationCount, 1)
        XCTAssertTrue(viewModel.isDiagnosticsRunning)
        XCTAssertFalse(viewModel.diagnosticsDidRun)
        XCTAssertTrue(viewModel.diagnosticsResults.isEmpty)

        viewModel.updateDiagnosticsViewState { state in
            state.completeRun(with: [result])
        }
        viewModel.updateDiagnosticsViewState { state in
            state.completeRun(with: [result])
        }

        XCTAssertEqual(publicationCount, 2)
        XCTAssertFalse(viewModel.isDiagnosticsRunning)
        XCTAssertTrue(viewModel.diagnosticsDidRun)
        XCTAssertEqual(viewModel.diagnosticsResults, [result])
        withExtendedLifetime(cancellable) {}
    }

    func testProfileEditorFormPublishesOneCoherentUpdatePerMutation() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerProfileEditorPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let draft = ModelProfileDraft(model: viewModel.models[0])
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.updateProfileEditorViewState { state in
            state.present(
                draft: draft,
                message: "message",
                portSuggestionMessage: "suggestion"
            )
        }
        viewModel.updateProfileEditorViewState { state in
            state.present(
                draft: draft,
                message: "message",
                portSuggestionMessage: "suggestion"
            )
        }

        XCTAssertEqual(publicationCount, 1)
        XCTAssertTrue(viewModel.isProfileEditorPresented)
        XCTAssertEqual(viewModel.profileEditorDraft, draft)
        XCTAssertEqual(viewModel.profileEditorMessage, "message")
        XCTAssertEqual(viewModel.profileEditorPortSuggestionMessage, "suggestion")

        viewModel.profileEditorDraft.serverPortText = "8002"

        XCTAssertEqual(publicationCount, 2)
        XCTAssertEqual(viewModel.profileEditorDraft.serverPortText, "8002")
        XCTAssertEqual(viewModel.profileEditorPortSuggestionMessage, "suggestion")

        viewModel.updateProfileEditorViewState { state in
            state.applyPortSuggestion(portText: "8003", message: "Port 8003 is available.")
        }
        viewModel.updateProfileEditorViewState { state in
            state.applyPortSuggestion(portText: "8003", message: "Port 8003 is available.")
        }

        XCTAssertEqual(publicationCount, 3)
        XCTAssertEqual(viewModel.profileEditorDraft.serverPortText, "8003")
        XCTAssertEqual(viewModel.profileEditorPortSuggestionMessage, "Port 8003 is available.")

        viewModel.updateProfileEditorViewState { $0.dismiss() }

        XCTAssertEqual(publicationCount, 4)
        XCTAssertFalse(viewModel.isProfileEditorPresented)
        XCTAssertEqual(viewModel.profileEditorDraft, .empty)
        XCTAssertNil(viewModel.profileEditorMessage)
        XCTAssertNil(viewModel.profileEditorPortSuggestionMessage)
        withExtendedLifetime(cancellable) {}
    }

    func testAddProfileFormPublishesDraftAndMessagesTogether() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerAddProfilePublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8000)
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.updateAddProfileViewState { state in
            state.present(
                draft: draft,
                portSuggestionMessage: "Port 8000 is available."
            )
        }

        XCTAssertEqual(publicationCount, 1)
        XCTAssertTrue(viewModel.isAddProfilePresented)
        XCTAssertEqual(viewModel.addProfileDraft, draft)
        XCTAssertEqual(viewModel.addProfilePortSuggestionMessage, "Port 8000 is available.")

        viewModel.addProfileDraft.displayName = "New Name"

        XCTAssertEqual(publicationCount, 2)
        XCTAssertEqual(viewModel.addProfileDraft.displayName, "New Name")
        XCTAssertEqual(viewModel.addProfilePortSuggestionMessage, "Port 8000 is available.")

        viewModel.updateAddProfileViewState { state in
            state.setMessage("Invalid model ID")
        }

        XCTAssertEqual(publicationCount, 3)
        XCTAssertEqual(viewModel.addProfileMessage, "Invalid model ID")
        XCTAssertTrue(viewModel.isAddProfilePresented)
        withExtendedLifetime(cancellable) {}
    }

    func testAddProfileLifecyclePublishesOneFormAndOneLogUpdatePerPhase() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerAddProfileLifecyclePublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.addProfileRequested()

        XCTAssertEqual(publicationCount, 2)
        XCTAssertTrue(viewModel.isAddProfilePresented)
        XCTAssertFalse(viewModel.addProfileDraft.serverPortText.isEmpty)
        XCTAssertNotNil(viewModel.addProfilePortSuggestionMessage)

        publicationCount = 0
        viewModel.cancelAddProfile()

        XCTAssertEqual(publicationCount, 2)
        XCTAssertFalse(viewModel.isAddProfilePresented)
        XCTAssertEqual(viewModel.addProfileDraft, .empty)
        XCTAssertNil(viewModel.addProfileMessage)
        XCTAssertNil(viewModel.addProfilePortSuggestionMessage)
        withExtendedLifetime(cancellable) {}
    }

    func testClearingLogsPublishesOneCoherentUpdate() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerLogPublicationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        var publicationCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publicationCount += 1
        }

        viewModel.clearLogsRequested()

        XCTAssertEqual(publicationCount, 1)
        XCTAssertEqual(viewModel.logEntries.count, 1)
        XCTAssertTrue(viewModel.logText.contains("[info] logs cleared"))
        withExtendedLifetime(cancellable) {}
    }
}

final class MonitoringViewStateTests: XCTestCase {
    func testModelMemoryAggregationTracksMultipleProfilesWithoutDuplicatingHistory() {
        let now = Date(timeIntervalSince1970: 1_000)
        let system = SystemMemorySnapshot(
            totalBytes: 64 * 1_073_741_824,
            availableBytes: 40 * 1_073_741_824
        )
        let first = MemoryBreakdownSnapshot(
            processIdentifier: 101,
            rssKilobytes: 2 * 1_048_576,
            system: system,
            modelEstimateGigabytes: 1.5,
            modelEstimateSource: "first",
            updatedAt: now
        )
        let second = MemoryBreakdownSnapshot(
            processIdentifier: 202,
            rssKilobytes: 3 * 1_048_576,
            system: system,
            modelEstimateGigabytes: 2.5,
            modelEstimateSource: "second",
            updatedAt: now.addingTimeInterval(1)
        )
        var state = MonitoringViewState.empty

        state.setModelMemory(first, for: "first")
        state.setModelMemory(second, for: "second")

        XCTAssertEqual(state.memoryUsageGB ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(state.memoryBreakdown?.managedProcessGigabytes ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(state.memoryBreakdown?.processIdentifier, 0)
        XCTAssertEqual(state.memoryBreakdown?.modelEstimateGigabytes ?? 0, 4, accuracy: 0.001)
        XCTAssertTrue(state.memoryHistory.isEmpty)

        state.setModelMemory(nil, for: "first")

        XCTAssertEqual(state.memoryUsageGB ?? 0, 3, accuracy: 0.001)
        XCTAssertEqual(state.memoryBreakdown?.processIdentifier, 202)
        XCTAssertEqual(state.memoryBreakdownByModelID.count, 1)
    }

    func testSystemUsageHistoryIsBoundedAndUsesAggregateManagedMemory() {
        let totalBytes = UInt64(64) * 1_073_741_824
        let availableBytes = UInt64(32) * 1_073_741_824
        let system = SystemMemorySnapshot(totalBytes: totalBytes, availableBytes: availableBytes)
        let snapshot = MemoryBreakdownSnapshot(
            processIdentifier: 101,
            rssKilobytes: 8 * 1_048_576,
            system: system,
            modelEstimateGigabytes: 6,
            modelEstimateSource: "model",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        var state = MonitoringViewState.empty
        state.setModelMemory(snapshot, for: "model")

        for index in 0..<75 {
            state.applySystemUsage(
                SystemUsageMonitorSample(
                    cpuPercent: Double(index),
                    gpuPercent: nil,
                    systemMemorySnapshot: system
                ),
                protectionState: .normal,
                timestamp: Date(timeIntervalSince1970: Double(index))
            )
        }

        XCTAssertEqual(state.memoryHistory.count, 60)
        XCTAssertEqual(state.systemUsageHistory.count, 60)
        XCTAssertEqual(state.memoryHistory.first?.timestamp, Date(timeIntervalSince1970: 15))
        XCTAssertEqual(state.systemUsageHistory.first?.timestamp, Date(timeIntervalSince1970: 15))
        XCTAssertEqual(state.memoryHistory.last?.managedProcessFraction ?? 0, 0.125, accuracy: 0.001)
    }
}
