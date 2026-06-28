import XCTest
@testable import MLXServerManager

@MainActor
final class ModelOperationsSafetyTests: XCTestCase {
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

    func testModelTableSortValuesReflectDisplayedColumns() throws {
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

        XCTAssertLessThan(viewModel.modelSizeSortValue(for: smallModel), viewModel.modelSizeSortValue(for: largeModel))
        XCTAssertLessThan(viewModel.endpointSortValue(for: largeModel), viewModel.endpointSortValue(for: smallModel))
        XCTAssertEqual(viewModel.integratedMemorySortValue(for: smallModel), -1)
        XCTAssertEqual(viewModel.autoUnloadTableSortValue(for: smallModel), 45)
        XCTAssertEqual(viewModel.autoUnloadTableSortValue(for: largeModel), Int.max)
        XCTAssertEqual(viewModel.reasoningSortValue(for: smallModel), 0)
        XCTAssertEqual(viewModel.reasoningSortValue(for: largeModel), 1)
    }
}
