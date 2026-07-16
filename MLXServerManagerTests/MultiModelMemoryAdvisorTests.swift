import XCTest
@testable import MLXServerManager

final class MultiModelMemoryAdvisorTests: XCTestCase {
    func testSafeWhenProjectedAvailableMemoryExceedsReserve() {
        let assessment = MultiModelMemoryAdvisor.assess(
            environment: MultiModelMemoryEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: 40,
                managedMemoryGigabytes: 18,
                runningModelCount: 1,
                candidateModelGigabytes: 12,
                candidateCacheBytes: 1_073_741_824
            )
        )

        XCTAssertEqual(assessment.level, .safe)
        XCTAssertFalse(assessment.requiresConfirmation)
        XCTAssertEqual(assessment.candidateFootprintGigabytes ?? 0, 14.2, accuracy: 0.001)
        XCTAssertEqual(assessment.projectedAvailableMemoryGigabytes ?? 0, 25.8, accuracy: 0.001)
    }

    func testCautionWhenProjectedAvailableMemoryFallsBelowReserve() {
        let assessment = MultiModelMemoryAdvisor.assess(
            environment: MultiModelMemoryEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: 25,
                managedMemoryGigabytes: 19,
                runningModelCount: 1,
                candidateModelGigabytes: 14,
                candidateCacheBytes: 2_147_483_648
            )
        )

        XCTAssertEqual(assessment.level, .caution)
        XCTAssertFalse(assessment.requiresConfirmation)
        XCTAssertGreaterThan(assessment.projectedAvailableMemoryGigabytes ?? 0, 3.2)
        XCTAssertLessThan(assessment.projectedAvailableMemoryGigabytes ?? 0, 9.6)
    }

    func testCriticalWhenProjectedAvailableMemoryFallsBelowEmergencyFloor() {
        let assessment = MultiModelMemoryAdvisor.assess(
            environment: MultiModelMemoryEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: 18,
                managedMemoryGigabytes: 38,
                runningModelCount: 2,
                candidateModelGigabytes: 15,
                candidateCacheBytes: 2_147_483_648
            )
        )

        XCTAssertEqual(assessment.level, .critical)
        XCTAssertTrue(assessment.requiresConfirmation)
        XCTAssertLessThan(assessment.projectedAvailableMemoryGigabytes ?? 0, 3.2)
    }

    func testUnavailableDoesNotBlockWhenInputsCannotBeEstimated() {
        let assessment = MultiModelMemoryAdvisor.assess(
            environment: MultiModelMemoryEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: nil,
                managedMemoryGigabytes: 0,
                runningModelCount: 0,
                candidateModelGigabytes: nil,
                candidateCacheBytes: nil
            )
        )

        XCTAssertEqual(assessment.level, .unavailable)
        XCTAssertFalse(assessment.requiresConfirmation)
    }

    func testLocalizedDetailIncludesProjectedValues() {
        let assessment = MultiModelMemoryAdvisor.assess(
            environment: MultiModelMemoryEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: 40,
                managedMemoryGigabytes: 18,
                runningModelCount: 1,
                candidateModelGigabytes: 12,
                candidateCacheBytes: nil
            )
        )

        XCTAssertTrue(assessment.detail(language: .japanese).contains("起動後の空きメモリ推定"))
        XCTAssertTrue(assessment.detail(language: .english).contains("Projected available memory"))
    }
}

@MainActor
final class MultiModelMemoryStartFlowTests: XCTestCase {
    func testCriticalAssessmentRequiresExplicitConfirmationBeforeStart() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerMemoryStartTests-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = temporaryDirectory.appendingPathComponent("model", isDirectory: true)
        let weightsURL = modelDirectory.appendingPathComponent("weights.safetensors")
        let executableURL = temporaryDirectory.appendingPathComponent("mlx_lm.server")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: weightsURL.path, contents: Data())
        let weightsHandle = try FileHandle(forWritingTo: weightsURL)
        try weightsHandle.truncate(atOffset: 8 * 1_073_741_824)
        try weightsHandle.close()
        FileManager.default.createFile(atPath: executableURL.path, contents: Data("#!/bin/sh\nexit 0\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let model = ModelConfig(
            modelID: modelDirectory.path,
            displayName: "Memory Test Model",
            family: "Test",
            quantization: "4bit",
            localName: modelDirectory.path,
            host: "127.0.0.1",
            serverPort: 58997,
            enableThinking: false,
            notes: ""
        )
        let store = SettingsStore(appDirectoryName: "MLXServerManagerMemoryStartTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        try store.save(
            settings: AppSettings(
                mlxServerExecutablePath: executableURL.path,
                defaultHost: "127.0.0.1",
                defaultPort: 8080,
                apiKeyPlaceholder: "not-required-local",
                uiLanguage: .japanese,
                uiAppearance: "system"
            ),
            models: [model]
        )

        let viewModel = AppViewModel(
            settingsStore: store,
            systemMemorySnapshotProvider: {
                SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 8 * 1_073_741_824
                )
            }
        )

        viewModel.startRequested(for: model)

        XCTAssertTrue(viewModel.isMemoryRiskStartConfirmationPresented)
        XCTAssertEqual(viewModel.pendingMemoryRiskAssessment?.level, .critical)
        XCTAssertFalse(viewModel.isManagedProcessRunning)
        XCTAssertTrue(viewModel.memoryRiskConfirmationDetail.contains("起動後の空きメモリ推定"))

        viewModel.cancelMemoryRiskStart()
        XCTAssertFalse(viewModel.isMemoryRiskStartConfirmationPresented)
        XCTAssertNil(viewModel.pendingMemoryRiskAssessment)
    }
}
