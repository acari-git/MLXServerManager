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

        XCTAssertEqual(viewModel.duplicateProfileWarning(for: first), "Duplicate endpoint")
        XCTAssertEqual(viewModel.duplicateProfileWarning(for: second), "Duplicate endpoint")
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
}
