import XCTest
@testable import MLXServerManager

@MainActor
final class ModelOperationsSafetyTests: XCTestCase {
    func testFailedAuthoritativeSaveDoesNotPublishModelOrSettingsMutations() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        guard let model = viewModel.models.first else {
            return XCTFail("Expected a default model")
        }
        let originalReasoning = model.enableThinking
        let originalSettings = viewModel.settings

        try FileManager.default.createDirectory(
            at: store.stateSnapshotFileURL,
            withIntermediateDirectories: true
        )

        viewModel.toggleReasoning(for: model, isEnabled: !originalReasoning)
        viewModel.setAutoUnloadEnabled(true, for: model)
        viewModel.setBenchmarkPreset(.detailed)

        XCTAssertEqual(viewModel.models.first(where: { $0.id == model.id })?.enableThinking, originalReasoning)
        XCTAssertEqual(viewModel.settings, originalSettings)
        XCTAssertFalse(viewModel.isAutoUnloadEnabled(for: model))
    }

    func testDuplicateProfileWarningDetectsDuplicateEndpoint() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        let first = ModelConfig(
            modelID: "owner/model-a",
            displayName: "A",
            family: "Test",
            quantization: "4bit",
            localName: "model-a",
            host: "127.0.0.1",
            serverPort: 54321,
            enableThinking: false,
            notes: ""
        )
        let second = ModelConfig(
            modelID: "owner/model-b",
            displayName: "B",
            family: "Test",
            quantization: "4bit",
            localName: "model-b",
            host: "127.0.0.1",
            serverPort: 54321,
            enableThinking: false,
            notes: ""
        )
        try store.save(settings: .defaults, models: [first, second])

        let viewModel = AppViewModel(settingsStore: store)
        viewModel.settings.uiLanguage = .english

        XCTAssertEqual(viewModel.duplicateProfileWarning(for: first), "Shared endpoint")
        XCTAssertEqual(viewModel.duplicateProfileWarning(for: second), "Shared endpoint")
    }

    func testSafetySummaryIncludesImplementedRowsOnly() {
        let viewModel = AppViewModel(settingsStore: SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)"))
        let keys = viewModel.selectedModelSafetyRows.map(\.0)

        XCTAssertTrue(keys.contains("Executable"))
        XCTAssertTrue(keys.contains("Model"))
        XCTAssertTrue(keys.contains("Server port"))
        XCTAssertTrue(keys.contains("Duplicate"))
        XCTAssertTrue(keys.contains("Runtime edit"))
        XCTAssertTrue(viewModel.copyableSafetySummary.contains("Model Operations Safety"))
    }

    func testRecoveryIssueDefaultsToNoRecoveryNeeded() {
        let viewModel = AppViewModel(settingsStore: SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)"))

        XCTAssertEqual(viewModel.currentRecoveryIssue.category, .none)
        XCTAssertEqual(viewModel.currentRecoveryIssue.severity, .ok)
        XCTAssertTrue(viewModel.currentRecoveryIssue.actions.isEmpty)
    }

    func testTroubleshootingSummaryIncludesRecoveryAndSafety() {
        let viewModel = AppViewModel(settingsStore: SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)"))

        XCTAssertTrue(viewModel.copyableTroubleshootingSummary.contains("MLX Server Manager Troubleshooting Summary"))
        XCTAssertTrue(viewModel.copyableTroubleshootingSummary.contains("Recovery:"))
        XCTAssertTrue(viewModel.copyableTroubleshootingSummary.contains("Safety:"))
    }

    func testCanStartModelUsesActualStateNotLocalizedDisplayText() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerTests-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = temporaryDirectory.appendingPathComponent("model", isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent("mlx_lm.server")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: executableURL.path, contents: Data("#!/bin/sh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let model = ModelConfig(
            modelID: modelDirectory.path,
            displayName: "Local Model",
            family: "Test",
            quantization: "4bit",
            localName: modelDirectory.path,
            host: "127.0.0.1",
            serverPort: 58999,
            enableThinking: false,
            notes: ""
        )
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        let settings = AppSettings(
            mlxServerExecutablePath: executableURL.path,
            defaultHost: "127.0.0.1",
            defaultPort: 8080,
            apiKeyPlaceholder: "not-required-local",
            uiLanguage: .english,
            uiAppearance: "system"
        )
        try store.save(settings: settings, models: [model])

        let viewModel = AppViewModel(settingsStore: store)
        viewModel.settings.uiLanguage = .english

        XCTAssertTrue(viewModel.canStartModel(model))
    }

    func testProfileDeletionCanBeUndoneWithOrderAndSettingsRestored() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerUndoTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let first = ModelConfig(
            modelID: "owner/model-a",
            displayName: "Model A",
            family: "Test",
            quantization: "4bit",
            localName: "model-a",
            host: "127.0.0.1",
            serverPort: 8101,
            enableThinking: false,
            notes: ""
        )
        let second = ModelConfig(
            modelID: "owner/model-b",
            displayName: "Model B",
            family: "Test",
            quantization: "4bit",
            localName: "model-b",
            host: "127.0.0.1",
            serverPort: 8102,
            enableThinking: false,
            notes: ""
        )
        var settings = AppSettings.defaults
        settings.autoUnloadEnabledByModelID[first.id] = true
        settings.autoUnloadMinutesByModelID[first.id] = 45
        try store.save(settings: settings, models: [first, second])

        let viewModel = AppViewModel(settingsStore: store)
        viewModel.deleteProfileRequested(for: first)
        viewModel.confirmDeleteProfile()

        XCTAssertEqual(viewModel.models.map(\.id), [second.id])
        XCTAssertEqual(viewModel.profileDeletionUndoState?.modelID, first.id)
        XCTAssertNil(viewModel.settings.autoUnloadEnabledByModelID[first.id])

        viewModel.undoProfileDeletionRequested()

        XCTAssertEqual(viewModel.models.map(\.id), [first.id, second.id])
        XCTAssertEqual(viewModel.selectedModelID, first.id)
        XCTAssertEqual(viewModel.settings.autoUnloadEnabledByModelID[first.id], true)
        XCTAssertEqual(viewModel.settings.autoUnloadMinutesByModelID[first.id], 45)
        XCTAssertNil(viewModel.profileDeletionUndoState)

        let reloaded = AppViewModel(settingsStore: store)
        XCTAssertEqual(reloaded.models.map(\.id), [first.id, second.id])
        XCTAssertEqual(reloaded.settings.autoUnloadMinutesByModelID[first.id], 45)
    }

    func testCacheDeletionDoesNotOfferUndo() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerPermanentDeleteTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let first = ModelConfig(
            modelID: "/tmp/non-hugging-face-model",
            displayName: "Local Model",
            family: "Test",
            quantization: "4bit",
            localName: "local-model",
            host: "127.0.0.1",
            serverPort: 8201,
            enableThinking: false,
            notes: ""
        )
        let second = ModelConfig(
            modelID: "owner/model-b",
            displayName: "Model B",
            family: "Test",
            quantization: "4bit",
            localName: "model-b",
            host: "127.0.0.1",
            serverPort: 8202,
            enableThinking: false,
            notes: ""
        )
        try store.save(settings: .defaults, models: [first, second])

        let viewModel = AppViewModel(settingsStore: store)
        viewModel.deleteProfileRequested(for: first)
        viewModel.confirmDeleteProfile(deleteHuggingFaceCache: true)

        XCTAssertEqual(viewModel.models.map(\.id), [second.id])
        XCTAssertNil(viewModel.profileDeletionUndoState)
        XCTAssertNotNil(viewModel.profileDeletionMessage)

        viewModel.dismissProfileDeletionMessage()

        XCTAssertNil(viewModel.profileDeletionMessage)
    }

    func testCacheDeletionPublishesProfileChangeBeforeBackgroundDeletionCompletes() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerAsyncCacheDeleteTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let first = reorderModel(id: "owner/model-a", port: 8_221)
        let second = reorderModel(id: "owner/model-b", port: 8_222)
        try store.save(settings: .defaults, models: [first, second])
        let viewModel = AppViewModel(
            settingsStore: store,
            huggingFaceCacheDeletionService: DelayedCacheDeletionService(
                delayNanoseconds: 80_000_000,
                outcome: .deleted
            )
        )
        viewModel.settings.uiLanguage = .english

        viewModel.deleteProfileRequested(for: first)
        viewModel.confirmDeleteProfile(deleteHuggingFaceCache: true)

        XCTAssertEqual(viewModel.models.map(\.id), [second.id])
        XCTAssertNil(viewModel.profileDeletionUndoState)
        XCTAssertTrue(viewModel.profileDeletionMessage?.contains("Deleting") == true)

        let completedMessage = "Profile and matching Hugging Face cache were deleted."
        for _ in 0..<100 where viewModel.profileDeletionMessage != completedMessage {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(viewModel.profileDeletionMessage, completedMessage)
    }

    func testModelReorderMovesUpDownAndPersistsOrder() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerReorderTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let models = [
            reorderModel(id: "owner/a", port: 8_301),
            reorderModel(id: "owner/b", port: 8_302),
            reorderModel(id: "owner/c", port: 8_303)
        ]
        try store.save(settings: .defaults, models: models)
        let viewModel = AppViewModel(settingsStore: store)

        XCTAssertFalse(viewModel.canMoveModelUp(withID: models[0].id))
        XCTAssertFalse(viewModel.canMoveModelDown(withID: models[2].id))

        viewModel.moveModelDown(withID: models[0].id)
        XCTAssertEqual(viewModel.models.map(\.id), [models[1].id, models[0].id, models[2].id])

        viewModel.moveModelUp(withID: models[2].id)
        XCTAssertEqual(viewModel.models.map(\.id), [models[1].id, models[2].id, models[0].id])

        let reloaded = AppViewModel(settingsStore: store)
        XCTAssertEqual(reloaded.models.map(\.id), [models[1].id, models[2].id, models[0].id])
    }

    func testModelReorderDoesNotChangeMemoryOrderWhenPersistenceFails() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerReorderFailureTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let models = [
            reorderModel(id: "owner/a", port: 8_311),
            reorderModel(id: "owner/b", port: 8_312)
        ]
        try store.save(settings: .defaults, models: models)
        let viewModel = AppViewModel(settingsStore: store)
        try FileManager.default.removeItem(at: store.stateSnapshotFileURL)
        try FileManager.default.createDirectory(
            at: store.stateSnapshotFileURL,
            withIntermediateDirectories: true
        )

        viewModel.moveModelDown(withID: models[0].id)

        XCTAssertEqual(viewModel.models.map(\.id), models.map(\.id))
        XCTAssertTrue(viewModel.logText.contains("failed to save model order"))
    }

    private func reorderModel(id: String, port: Int) -> ModelConfig {
        ModelConfig(
            modelID: id,
            displayName: id,
            family: "Test",
            quantization: "4bit",
            localName: id,
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: false,
            notes: ""
        )
    }

    func testModelTableSortValuesReflectDisplayedColumns() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerTests-\(UUID().uuidString)", isDirectory: true)
        let smallModelDirectory = temporaryDirectory.appendingPathComponent("small-model", isDirectory: true)
        let largeModelDirectory = temporaryDirectory.appendingPathComponent("large-model", isDirectory: true)
        try FileManager.default.createDirectory(at: smallModelDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: largeModelDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: smallModelDirectory.appendingPathComponent("weights.safetensors").path,
            contents: Data(repeating: 1, count: 128)
        )
        FileManager.default.createFile(
            atPath: largeModelDirectory.appendingPathComponent("weights.safetensors").path,
            contents: Data(repeating: 1, count: 512)
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let smallModel = ModelConfig(
            modelID: smallModelDirectory.path,
            displayName: "Small",
            family: "Test",
            quantization: "4bit",
            localName: "small-model",
            host: "127.0.0.1",
            serverPort: 9000,
            enableThinking: false,
            notes: ""
        )
        let largeModel = ModelConfig(
            modelID: largeModelDirectory.path,
            displayName: "Large",
            family: "Test",
            quantization: "4bit",
            localName: "large-model",
            host: "127.0.0.1",
            serverPort: 8080,
            enableThinking: true,
            notes: ""
        )
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        try store.save(settings: .defaults, models: [smallModel, largeModel])

        let viewModel = AppViewModel(settingsStore: store)
        viewModel.setAutoUnloadEnabled(true, for: smallModel)
        viewModel.setAutoUnloadMinutes(45, for: smallModel)

        _ = viewModel.modelSizeSortValue(for: smallModel)
        _ = viewModel.modelSizeSortValue(for: largeModel)
        for _ in 0..<100 where viewModel.modelSizeSortValue(for: smallModel) < 0
            || viewModel.modelSizeSortValue(for: largeModel) < 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertLessThan(viewModel.modelSizeSortValue(for: smallModel), viewModel.modelSizeSortValue(for: largeModel))
        XCTAssertLessThan(viewModel.endpointSortValue(for: largeModel), viewModel.endpointSortValue(for: smallModel))
        XCTAssertEqual(viewModel.integratedMemorySortValue(for: smallModel), -1)
        XCTAssertEqual(viewModel.autoUnloadTableSortValue(for: smallModel), 45)
        XCTAssertEqual(viewModel.autoUnloadTableSortValue(for: largeModel), Int.max)
        XCTAssertEqual(viewModel.reasoningSortValue(for: smallModel), 0)
        XCTAssertEqual(viewModel.reasoningSortValue(for: largeModel), 1)

        let rowStates = viewModel.modelListRowStates(from: [smallModel, largeModel])
        XCTAssertEqual(rowStates.map(\.id), [smallModel.id, largeModel.id])
        XCTAssertEqual(rowStates[0].sizeSortValue, viewModel.modelSizeSortValue(for: smallModel))
        XCTAssertEqual(rowStates[1].sizeSortValue, viewModel.modelSizeSortValue(for: largeModel))
        XCTAssertEqual(rowStates[0].endpointSortValue, viewModel.endpointSortValue(for: smallModel))
        XCTAssertEqual(rowStates[1].endpointSortValue, viewModel.endpointSortValue(for: largeModel))
        XCTAssertEqual(rowStates[0].autoUnloadSortValue, 45)
        XCTAssertEqual(rowStates[1].autoUnloadSortValue, Int.max)
        XCTAssertEqual(rowStates[0].reasoningSortValue, 0)
        XCTAssertEqual(rowStates[1].reasoningSortValue, 1)
        XCTAssertEqual(rowStates[0].memoryText, "-")
        XCTAssertEqual(rowStates[1].memoryText, "-")
        XCTAssertFalse(rowStates[0].isTransitioning)
        XCTAssertFalse(rowStates[1].isTransitioning)
    }
}

private struct DelayedCacheDeletionService: HuggingFaceCacheDeleting {
    let delayNanoseconds: UInt64
    let outcome: HuggingFaceCacheDeletionOutcome

    func deleteCache(at cacheURL: URL) async -> HuggingFaceCacheDeletionOutcome {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return outcome
    }
}
