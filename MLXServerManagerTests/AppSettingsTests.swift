import XCTest
@testable import MLXServerManager

final class AppSettingsTests: XCTestCase {
    func testDefaultsIncludeSavedChromePreferences() {
        let settings = AppSettings.defaults

        XCTAssertEqual(settings.uiLanguage, .system)
        XCTAssertEqual(settings.uiAppearance, "system")
        XCTAssertEqual(settings.hermesConfigPath, "~/.hermes/config.yaml")
        XCTAssertEqual(settings.benchmarkPreset, .standard)
        XCTAssertEqual(settings.rapidMLXExecutablePath, "")
    }

    func testDecodingLegacySettingsFillsChromePreferences() throws {
        let json = """
        {
          "mlxServerExecutablePath": "",
          "defaultHost": "127.0.0.1",
          "defaultPort": 8080,
          "apiKeyPlaceholder": "not-required-local"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.uiLanguage, .system)
        XCTAssertEqual(settings.uiAppearance, "system")
        XCTAssertEqual(settings.hermesConfigPath, "~/.hermes/config.yaml")
        XCTAssertEqual(settings.benchmarkPreset, .standard)
        XCTAssertEqual(settings.rapidMLXExecutablePath, "")
    }

    func testEncodingRoundTripsChromePreferences() throws {
        let original = AppSettings(
            mlxServerExecutablePath: "/tmp/mlx_lm.server",
            rapidMLXExecutablePath: "/tmp/rapid-mlx",
            defaultHost: "127.0.0.1",
            defaultPort: 9999,
            apiKeyPlaceholder: "local-only",
            hermesConfigPath: "/tmp/hermes/config.yaml",
            benchmarkPreset: .detailed,
            uiLanguage: .english,
            uiAppearance: "dark"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.uiLanguage, .english)
        XCTAssertEqual(decoded.uiAppearance, "dark")
        XCTAssertEqual(decoded.hermesConfigPath, "/tmp/hermes/config.yaml")
        XCTAssertEqual(decoded.benchmarkPreset, .detailed)
        XCTAssertEqual(decoded.rapidMLXExecutablePath, "/tmp/rapid-mlx")
        XCTAssertEqual(decoded.executablePath(for: .mlxLM), "/tmp/mlx_lm.server")
        XCTAssertEqual(decoded.executablePath(for: .rapidMLX), "/tmp/rapid-mlx")
    }

    func testEncodingOmitsRetiredDownloadBehaviorKeys() throws {
        let data = try JSONEncoder().encode(AppSettings.defaults)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(text.contains("downloadAutoAddToModelList"))
        XCTAssertFalse(text.contains("downloadAutoSelectAfterAdd"))
        XCTAssertFalse(text.contains("confirmFilesBeforeDownload"))
    }

    func testAutoUnloadSettingsRoundTripAndClampMinutes() throws {
        let original = AppSettings(
            mlxServerExecutablePath: "",
            defaultHost: "127.0.0.1",
            defaultPort: 8080,
            apiKeyPlaceholder: "not-required-local",
            autoUnloadEnabledByModelID: ["model-a": true],
            autoUnloadMinutesByModelID: ["model-a": 45, "model-b": 0]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.autoUnloadEnabledByModelID["model-a"], true)
        XCTAssertEqual(decoded.autoUnloadMinutesByModelID["model-a"], 45)
        XCTAssertEqual(decoded.autoUnloadMinutesByModelID["model-b"], 1)
    }

    func testSettingsStoreLoadsAuthoritativeCombinedSnapshot() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var authoritativeSettings = AppSettings.defaults
        authoritativeSettings.defaultPort = 8123
        let authoritativeModel = ModelConfig.defaults[0]
        try store.save(settings: authoritativeSettings, models: [authoritativeModel])

        var staleSettings = AppSettings.defaults
        staleSettings.defaultPort = 9999
        let staleModel = ModelConfig(
            modelID: "stale/model",
            displayName: "Stale",
            family: "Stale",
            quantization: "Unknown",
            localName: "stale-model",
            host: "127.0.0.1",
            serverPort: 9999,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
        try JSONEncoder().encode(staleSettings).write(to: store.settingsFileURL, options: [.atomic])
        try JSONEncoder().encode([staleModel]).write(to: store.modelsFileURL, options: [.atomic])

        let loaded = try store.load()
        XCTAssertEqual(loaded.settings.defaultPort, 8123)
        XCTAssertEqual(loaded.models.map(\.modelID), [authoritativeModel.modelID])
    }

    func testModelsOnlySavePreservesSettingsInCombinedSnapshot() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var settings = AppSettings.defaults
        settings.defaultPort = 8777
        try store.save(settings: settings, models: ModelConfig.defaults)

        let replacement = ModelConfig(
            modelID: "owner/replacement",
            displayName: "Replacement",
            family: "Custom",
            quantization: "4-bit",
            localName: "replacement",
            host: "127.0.0.1",
            serverPort: 8778,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
        try store.save(models: [replacement])

        let loaded = try store.load()
        XCTAssertEqual(loaded.settings.defaultPort, 8777)
        XCTAssertEqual(loaded.models.map(\.modelID), [replacement.modelID])
    }

    func testCorruptedCombinedSnapshotRecoversFromAuthoritativeBackupInsteadOfLegacyFiles() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var settings = AppSettings.defaults
        settings.defaultPort = 8444
        try store.save(settings: settings, models: ModelConfig.defaults)

        var staleSettings = AppSettings.defaults
        staleSettings.defaultPort = 9_999
        try JSONEncoder().encode(staleSettings).write(to: store.settingsFileURL, options: [.atomic])
        try Data("not-json".utf8).write(to: store.stateSnapshotFileURL, options: [.atomic])

        let loaded = try store.load()
        XCTAssertEqual(loaded.settings.defaultPort, 8444)
        XCTAssertEqual(loaded.models.map(\.modelID), ModelConfig.defaults.map(\.modelID))
        XCTAssertNotNil(loaded.recoveryNotice)

        let repaired = try store.load()
        XCTAssertEqual(repaired.settings.defaultPort, 8444)
        XCTAssertNil(repaired.recoveryNotice)
    }

    func testCorruptedAuthoritativeStateWithoutBackupDoesNotLoadStaleLegacyMirrors() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let model = ModelConfig(
            modelID: "owner/recoverable-model",
            displayName: "Recoverable",
            family: "Test",
            quantization: "4bit",
            localName: "recoverable-model",
            host: "127.0.0.1",
            serverPort: 8_444,
            enableThinking: false,
            notes: ""
        )
        try store.save(settings: .defaults, models: [model])
        try Data("not-json".utf8).write(to: store.stateSnapshotFileURL, options: [.atomic])
        try FileManager.default.removeItem(at: store.stateSnapshotBackupFileURL)

        XCTAssertThrowsError(try store.load()) { error in
            guard case SettingsStoreError.authoritativeStateCorrupted = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCorruptedAuthoritativeStateAndBackupDoesNotLoadLegacyMirrors() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var settings = AppSettings.defaults
        settings.defaultPort = 8_555
        try store.save(settings: settings, models: ModelConfig.defaults)
        try Data("not-json".utf8).write(to: store.stateSnapshotFileURL, options: [.atomic])
        try Data("also-not-json".utf8).write(to: store.stateSnapshotBackupFileURL, options: [.atomic])

        XCTAssertThrowsError(try store.load()) { error in
            guard case SettingsStoreError.authoritativeStateCorrupted = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testFailedLoadBlocksLaterSaveWithoutChangingAuthoritativeFiles() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try store.save(settings: .defaults, models: ModelConfig.defaults)
        let corruptState = Data("not-json".utf8)
        let corruptBackup = Data("also-not-json".utf8)
        try corruptState.write(to: store.stateSnapshotFileURL, options: [.atomic])
        try corruptBackup.write(to: store.stateSnapshotBackupFileURL, options: [.atomic])

        XCTAssertThrowsError(try store.load())

        var replacementSettings = AppSettings.defaults
        replacementSettings.defaultPort = 9_999
        XCTAssertThrowsError(
            try store.save(settings: replacementSettings, models: [])
        ) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(try Data(contentsOf: store.stateSnapshotFileURL), corruptState)
        XCTAssertEqual(try Data(contentsOf: store.stateSnapshotBackupFileURL), corruptBackup)
    }

    func testWriteBlockRemainsLatchedAcrossStoreInstancesAfterFilesAreExternallyRepaired() throws {
        let appDirectoryName = "MLXServerManagerTests-\(UUID().uuidString)"
        let store = SettingsStore(appDirectoryName: appDirectoryName)
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var originalSettings = AppSettings.defaults
        originalSettings.defaultPort = 8_123
        try store.save(settings: originalSettings, models: ModelConfig.defaults)
        let validState = try Data(contentsOf: store.stateSnapshotFileURL)
        let validBackup = try Data(contentsOf: store.stateSnapshotBackupFileURL)
        try Data("not-json".utf8).write(to: store.stateSnapshotFileURL, options: [.atomic])
        try Data("also-not-json".utf8).write(to: store.stateSnapshotBackupFileURL, options: [.atomic])
        XCTAssertThrowsError(try store.load())

        try validState.write(to: store.stateSnapshotFileURL, options: [.atomic])
        try validBackup.write(to: store.stateSnapshotBackupFileURL, options: [.atomic])
        XCTAssertEqual(try store.load().settings.defaultPort, 8_123)
        XCTAssertThrowsError(try store.save(settings: .defaults, models: [])) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let secondStore = SettingsStore(appDirectoryName: appDirectoryName)
        XCTAssertEqual(try secondStore.load().settings.defaultPort, 8_123)
        XCTAssertThrowsError(try secondStore.save(settings: .defaults, models: [])) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCorruptedLegacySettingsBlocksSaveAndPreservesLegacyFiles() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try FileManager.default.createDirectory(
            at: store.settingsDirectoryURL,
            withIntermediateDirectories: true
        )
        let corruptSettings = Data("not-json".utf8)
        let validModels = try JSONEncoder().encode(ModelConfig.defaults)
        try corruptSettings.write(to: store.settingsFileURL)
        try validModels.write(to: store.modelsFileURL)

        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(settings: .defaults, models: [])) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: store.settingsFileURL), corruptSettings)
        XCTAssertEqual(try Data(contentsOf: store.modelsFileURL), validModels)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try store.stateSnapshotFileURL.path))
    }

    func testCorruptedLegacyModelsBlocksSaveAndPreservesLegacyFiles() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try FileManager.default.createDirectory(
            at: store.settingsDirectoryURL,
            withIntermediateDirectories: true
        )
        let validSettings = try JSONEncoder().encode(AppSettings.defaults)
        let corruptModels = Data("not-json".utf8)
        try validSettings.write(to: store.settingsFileURL)
        try corruptModels.write(to: store.modelsFileURL)

        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(settings: .defaults, models: [])) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: store.settingsFileURL), validSettings)
        XCTAssertEqual(try Data(contentsOf: store.modelsFileURL), corruptModels)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try store.stateSnapshotFileURL.path))
    }

    func testSettingsTransactionsSerializeSaveAndFailedLoad() throws {
        let coordinator = SettingsStoreTransactionCoordinator()
        let saveStarted = DispatchSemaphore(value: 0)
        let allowSaveToFinish = DispatchSemaphore(value: 0)
        let loadStarted = DispatchSemaphore(value: 0)
        let saveFinished = expectation(description: "save finished")
        let loadFinished = expectation(description: "load finished")

        DispatchQueue.global().async {
            _ = try? coordinator.performSave {
                saveStarted.signal()
                allowSaveToFinish.wait()
            }
            saveFinished.fulfill()
        }
        XCTAssertEqual(saveStarted.wait(timeout: .now() + 2), .success)

        DispatchQueue.global().async {
            do {
                let _: Void = try coordinator.performLoad {
                    loadStarted.signal()
                    throw NSError(domain: "AppSettingsTests", code: 1)
                }
            } catch {
                // The failed read is the state transition under test.
            }
            loadFinished.fulfill()
        }
        XCTAssertEqual(loadStarted.wait(timeout: .now() + 0.05), .timedOut)
        allowSaveToFinish.signal()
        wait(for: [saveFinished, loadFinished], timeout: 2)
        XCTAssertEqual(loadStarted.wait(timeout: .now()), .success)

        XCTAssertThrowsError(try coordinator.performSave {}) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testLegacyMirrorsLoadWhenNoAuthoritativeStateExists() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try FileManager.default.createDirectory(
            at: store.settingsDirectoryURL,
            withIntermediateDirectories: true
        )
        var settings = AppSettings.defaults
        settings.defaultPort = 8_555
        let model = ModelConfig(
            modelID: "owner/legacy-model",
            displayName: "Legacy",
            family: "Test",
            quantization: "4bit",
            localName: "legacy-model",
            host: "127.0.0.1",
            serverPort: 8_555,
            enableThinking: false,
            notes: ""
        )
        try JSONEncoder().encode(settings).write(to: store.settingsFileURL, options: [.atomic])
        try JSONEncoder().encode([model]).write(to: store.modelsFileURL, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded.settings.defaultPort, 8_555)
        XCTAssertEqual(loaded.models.map(\.modelID), [model.modelID])
        XCTAssertFalse(loaded.usedDefaults)
        XCTAssertNil(loaded.recoveryNotice)
    }

    func testMissingPrimarySnapshotRecoversFromBackup() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var settings = AppSettings.defaults
        settings.defaultPort = 8_777
        try store.save(settings: settings, models: ModelConfig.defaults)
        try FileManager.default.removeItem(at: store.stateSnapshotFileURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded.settings.defaultPort, 8_777)
        XCTAssertNotNil(loaded.recoveryNotice)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.stateSnapshotFileURL.path))
    }

    func testMirrorWriteFailureIsNonfatalAfterAuthoritativeSnapshotIsSaved() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try FileManager.default.createDirectory(
            at: store.settingsFileURL,
            withIntermediateDirectories: true
        )
        var settings = AppSettings.defaults
        settings.defaultPort = 8_666

        let outcome = try store.save(settings: settings, models: ModelConfig.defaults)
        let loaded = try store.load()

        XCTAssertTrue(outcome.hasWarnings)
        XCTAssertEqual(outcome.mirrorWarnings.count, 1)
        XCTAssertTrue(outcome.mirrorWarnings[0].hasPrefix("settings.json:"))
        XCTAssertEqual(loaded.settings.defaultPort, 8_666)
        XCTAssertEqual(loaded.models, ModelConfig.defaults)
    }

    func testBackupWriteFailureIsReportedWithoutInvalidatingPrimarySnapshot() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try FileManager.default.createDirectory(
            at: store.stateSnapshotBackupFileURL,
            withIntermediateDirectories: true
        )
        var settings = AppSettings.defaults
        settings.defaultPort = 8_888

        let outcome = try store.save(settings: settings, models: ModelConfig.defaults)
        let loaded = try store.load()

        XCTAssertTrue(outcome.hasWarnings)
        XCTAssertEqual(outcome.recoveryWarnings.count, 1)
        XCTAssertTrue(outcome.recoveryWarnings[0].hasPrefix("settings-state.backup.json:"))
        XCTAssertEqual(loaded.settings.defaultPort, 8_888)
    }

    func testUnsupportedAuthoritativeSchemaDoesNotFallBackOrOverwriteState() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try store.save(settings: .defaults, models: ModelConfig.defaults)
        var json = String(decoding: try Data(contentsOf: store.stateSnapshotFileURL), as: UTF8.self)
        json = json.replacingOccurrences(of: "\"schemaVersion\" : 2", with: "\"schemaVersion\" : 999")
        try Data(json.utf8).write(to: store.stateSnapshotFileURL, options: [.atomic])

        XCTAssertThrowsError(try store.load()) { error in
            guard case SettingsStoreError.unsupportedStateSchemaVersion(999) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let futureState = try Data(contentsOf: store.stateSnapshotFileURL)
        XCTAssertTrue(String(decoding: futureState, as: UTF8.self).contains("999"))
        XCTAssertThrowsError(try store.save(settings: .defaults, models: [])) { error in
            guard case SettingsStoreError.saveBlockedAfterLoadFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: store.stateSnapshotFileURL), futureState)
    }

    func testSettingsStoreMigratesAuthoritativeSchemaOneToSchemaTwo() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var settings = AppSettings.defaults
        settings.defaultPort = 8_123
        try store.save(settings: settings, models: ModelConfig.defaults)
        var stateText = String(
            decoding: try Data(contentsOf: store.stateSnapshotFileURL),
            as: UTF8.self
        )
        stateText = stateText.replacingOccurrences(
            of: "\"schemaVersion\" : 2",
            with: "\"schemaVersion\" : 1"
        )
        try Data(stateText.utf8).write(to: store.stateSnapshotFileURL, options: [.atomic])
        try Data(stateText.utf8).write(to: store.stateSnapshotBackupFileURL, options: [.atomic])

        let loaded = try store.load()
        let migratedState = String(
            decoding: try Data(contentsOf: store.stateSnapshotFileURL),
            as: UTF8.self
        )
        let migratedBackup = String(
            decoding: try Data(contentsOf: store.stateSnapshotBackupFileURL),
            as: UTF8.self
        )

        XCTAssertEqual(loaded.settings.defaultPort, 8_123)
        XCTAssertTrue(loaded.recoveryNotice?.contains("Migrated") == true)
        XCTAssertTrue(migratedState.contains("\"schemaVersion\" : 2"))
        XCTAssertTrue(migratedBackup.contains("\"schemaVersion\" : 2"))
    }

    func testSettingsStorePersistsBenchmarkResultsSeparately() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let result = BenchmarkResult(
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            phase: .success,
            readinessLatencyMS: 100,
            selectedProfileName: "Model A",
            message: "ok"
        )
        let snapshot = BenchmarkResultsSnapshot(
            benchmarkResultsByProfileID: ["model-a": result],
            agenticBenchmarkResultsByProfileID: [:]
        )

        try store.save(benchmarkResults: snapshot)
        let loaded = try store.loadBenchmarkResults()

        XCTAssertFalse(loaded.usedDefault)
        XCTAssertEqual(loaded.value.benchmarkResultsByProfileID["model-a"]?.modelID, "local/model-a")
    }
}
