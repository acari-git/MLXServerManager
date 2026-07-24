import XCTest
@testable import MLXServerManager

@MainActor
final class EnglishModeVisibleTextTests: XCTestCase {
    func testEnglishModeViewModelVisibleTextUsesEnglishOnly() {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.settings.uiLanguage = .english

        var values: [String] = []
        values += viewModel.systemInfoRows.flatMap { [$0.0, $0.1] }
        values += viewModel.selectedModelSafetyRows.flatMap { [$0.0, $0.1] }
        values += [
            viewModel.selectedModelSafetySummary,
            viewModel.failedStartRecoverySummary,
            viewModel.selectedServerPortSafetyText,
            viewModel.selectedModelIdentifier,
            viewModel.selectedModelIdentityDetailText,
            viewModel.memoryUsageText,
            viewModel.memoryTotalText,
            viewModel.memoryAvailableText,
            viewModel.memoryMLXProcessText,
            viewModel.memoryOtherProcessesText,
            viewModel.memoryBreakdownUpdateText,
            viewModel.memoryBreakdownAccuracyText,
            viewModel.integratedCPUUsageText,
            viewModel.integratedGPUUsageText,
            viewModel.integratedUptimeText,
            viewModel.huggingFaceDownloadProgressText,
            viewModel.huggingFaceDownloadQueueSummary,
            viewModel.runningModelText,
            viewModel.diagnosticsSummaryText
        ]

        if let model = viewModel.models.first {
            values += [
                viewModel.autoUnloadText(for: model),
                viewModel.integratedStatusText(for: model),
                viewModel.interactiveStatusText(for: model, isHovered: true),
                viewModel.integratedStopModeText(for: model),
                viewModel.runtimeEditingSafetyText(for: model),
                viewModel.duplicateProfileWarning(for: model) ?? "No duplicate issue"
            ]
        }

        let invalid = values.filter(Self.hasCJK)
        XCTAssertTrue(invalid.isEmpty, invalid.joined(separator: "\n"))
    }

    func testJapaneseModeUsesLocalizedSafetyRuntimeAndDownloadText() {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerJapaneseTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        var settings = viewModel.settings
        settings.uiLanguage = .japanese
        XCTAssertTrue(viewModel.saveSettingsRequested(settings))

        XCTAssertTrue(viewModel.selectedModelSafetyRows.allSatisfy { Self.hasCJK($0.0) })
        XCTAssertTrue(Self.hasCJK(viewModel.selectedModelSafetySummary))
        XCTAssertTrue(Self.hasCJK(viewModel.startActionReason))
        XCTAssertTrue(Self.hasCJK(viewModel.stopDisabledReason))
        XCTAssertTrue(Self.hasCJK(viewModel.restartDisabledReason))
        XCTAssertTrue(Self.hasCJK(viewModel.menuBarTitle))
        XCTAssertTrue(Self.hasCJK(viewModel.huggingFaceDownloadStatus.message))
        XCTAssertFalse(viewModel.huggingFaceDownloadStatus.message.contains("Paste a Hugging Face"))
    }

    private static func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(Int(scalar.value)) || (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }
}
