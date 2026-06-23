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

        XCTAssertEqual(viewModel.duplicateProfileWarning(for: first), "Duplicate endpoint")
        XCTAssertEqual(viewModel.duplicateProfileWarning(for: second), "Duplicate endpoint")
    }

    func testSafetySummaryIncludesExecutableAndModelRows() {
        let viewModel = AppViewModel(settingsStore: SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)"))
        let keys = viewModel.selectedModelSafetyRows.map(\.0)

        XCTAssertTrue(keys.contains("Executable"))
        XCTAssertTrue(keys.contains("Model"))
        XCTAssertTrue(keys.contains("Server port"))
        XCTAssertTrue(keys.contains("Proxy port"))
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
}

