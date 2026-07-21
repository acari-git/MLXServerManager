import XCTest
@testable import MLXServerManager

@MainActor
final class RuntimeMemoryEmergencyGuardFlowTests: XCTestCase {
    func testThreeCriticalSamplesBlockStartWhileTransientCriticalDoesNot() throws {
        let model = Self.model(id: "/tmp/runtime-memory-emergency-start", port: 58_201)
        let store = Self.store()
        defer { Self.removeStoreDirectory(store) }
        try store.save(settings: .defaults, models: [model])
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.settings.uiLanguage = .english

        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))
        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))

        XCTAssertFalse(viewModel.isRuntimeMemoryEmergencyActive)
        XCTAssertNotEqual(viewModel.runtimeMemoryProtectionState.level, .emergency)

        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))

        XCTAssertTrue(viewModel.isRuntimeMemoryEmergencyActive)
        XCTAssertEqual(viewModel.runtimeMemoryProtectionState.level, .emergency)
        XCTAssertTrue(viewModel.selectedBlockingStartIssue?.contains("memory") == true)

        viewModel.startRequested(for: model)
        viewModel.restartRequested()
        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))
        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))

        XCTAssertTrue(viewModel.logText.contains("[start] blocked by runtime memory emergency"))
        XCTAssertTrue(viewModel.logText.contains("[restart] blocked by runtime memory emergency"))
        XCTAssertFalse(viewModel.logText.contains("[restart] requested for"))
        XCTAssertTrue(viewModel.restartDisabledReason.contains("memory"))
        XCTAssertTrue(viewModel.runtimeMemoryProtectionActionText?.contains("not stopped automatically") == true)
        viewModel.settings.uiLanguage = .japanese
        XCTAssertTrue(viewModel.runtimeMemoryProtectionActionText?.contains("自動停止しません") == true)
        XCTAssertEqual(
            viewModel.logText.components(separatedBy: "runtime memory emergency engaged").count - 1,
            1
        )
        XCTAssertFalse(viewModel.isNetworkExposureStartConfirmationPresented)
        XCTAssertFalse(viewModel.isMemoryRiskStartConfirmationPresented)
    }

    func testEmergencyProtectionRequiresThreeNormalSamplesToRecover() throws {
        let model = Self.model(id: "/tmp/runtime-memory-emergency-recovery", port: 58_202)
        let store = Self.store()
        defer { Self.removeStoreDirectory(store) }
        try store.save(settings: .defaults, models: [model])
        let viewModel = AppViewModel(settingsStore: store)

        for _ in 0..<3 {
            viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))
        }
        XCTAssertTrue(viewModel.isRuntimeMemoryEmergencyActive)

        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 20))
        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 20))
        XCTAssertTrue(viewModel.isRuntimeMemoryEmergencyActive)

        viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 20))

        XCTAssertFalse(viewModel.isRuntimeMemoryEmergencyActive)
        XCTAssertEqual(viewModel.runtimeMemoryProtectionState.level, .normal)
        XCTAssertTrue(viewModel.logText.contains("runtime memory emergency cleared"))
    }

    func testEmergencyEngagedDuringNetworkConfirmationBlocksConfirmedStart() throws {
        var model = Self.model(id: "/tmp/runtime-memory-emergency-network-confirmation", port: 58_203)
        model.host = "0.0.0.0"
        let store = Self.store()
        defer { Self.removeStoreDirectory(store) }
        try store.save(settings: .defaults, models: [model])
        let viewModel = AppViewModel(settingsStore: store)

        viewModel.startRequested(for: model)
        XCTAssertTrue(viewModel.isNetworkExposureStartConfirmationPresented)

        for _ in 0..<3 {
            viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))
        }
        viewModel.confirmNetworkExposureStart()

        XCTAssertFalse(viewModel.isNetworkExposureStartConfirmationPresented)
        XCTAssertTrue(viewModel.logText.contains("[start] blocked by runtime memory emergency"))
        XCTAssertFalse(viewModel.isMemoryRiskStartConfirmationPresented)
        XCTAssertFalse(viewModel.isManagedProcessRunning)
    }

    func testEmergencyEngagedDuringStorageEstimationBlocksCompletionPath() async throws {
        let estimationStarted = expectation(description: "Storage estimation started")
        let releaseEstimation = DispatchSemaphore(value: 0)
        let model = Self.model(id: "/tmp/runtime-memory-emergency-storage-estimation", port: 58_204)
        let store = Self.store()
        defer {
            releaseEstimation.signal()
            Self.removeStoreDirectory(store)
        }
        try store.save(settings: .defaults, models: [model])
        let viewModel = AppViewModel(
            settingsStore: store,
            modelStorageEstimateOperation: { _ in
                estimationStarted.fulfill()
                releaseEstimation.wait()
                return 8
            }
        )

        viewModel.startRequested(for: model)
        await fulfillment(of: [estimationStarted], timeout: 1)
        for _ in 0..<3 {
            viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))
        }
        releaseEstimation.signal()

        for _ in 0..<100 where !viewModel.logText.contains("[start] blocked by runtime memory emergency") {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertTrue(viewModel.logText.contains("[start] blocked by runtime memory emergency"))
        XCTAssertFalse(viewModel.isMemoryRiskStartConfirmationPresented)
        XCTAssertFalse(viewModel.isManagedProcessRunning)
    }

    func testEmergencyEngagedDuringMemoryConfirmationBlocksConfirmedStart() async throws {
        let model = Self.model(id: "/tmp/runtime-memory-emergency-confirmation", port: 58_203)
        let store = Self.store()
        defer { Self.removeStoreDirectory(store) }
        try store.save(settings: .defaults, models: [model])
        let viewModel = AppViewModel(
            settingsStore: store,
            modelStorageEstimateOperation: { _ in 60 },
            systemMemorySnapshotProvider: {
                SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 8 * 1_073_741_824
                )
            }
        )

        viewModel.startRequested(for: model)
        for _ in 0..<100 where !viewModel.isMemoryRiskStartConfirmationPresented {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(viewModel.isMemoryRiskStartConfirmationPresented)

        for _ in 0..<3 {
            viewModel.applySystemUsageSample(Self.sample(availableGigabytes: 2))
        }
        viewModel.confirmMemoryRiskStart()

        XCTAssertFalse(viewModel.isMemoryRiskStartConfirmationPresented)
        XCTAssertTrue(viewModel.logText.contains("[start] blocked by runtime memory emergency"))
        XCTAssertFalse(viewModel.isManagedProcessRunning)
    }

    private static func sample(availableGigabytes: UInt64) -> SystemUsageMonitorSample {
        SystemUsageMonitorSample(
            cpuPercent: 10,
            gpuPercent: nil,
            systemMemorySnapshot: SystemMemorySnapshot(
                totalBytes: 64 * 1_073_741_824,
                availableBytes: availableGigabytes * 1_073_741_824
            )
        )
    }

    private static func model(id: String, port: Int) -> ModelConfig {
        ModelConfig(
            modelID: id,
            displayName: "Runtime Memory Emergency Model",
            family: "Test",
            quantization: "4bit",
            localName: id,
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: false,
            notes: ""
        )
    }

    private static func store() -> SettingsStore {
        SettingsStore(appDirectoryName: "MLXServerManagerRuntimeMemoryEmergencyTests-\(UUID().uuidString)")
    }

    private static func removeStoreDirectory(_ store: SettingsStore) {
        if let directory = try? store.settingsDirectoryURL {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
