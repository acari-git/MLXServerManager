import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class KVCacheSafeModeFlowTests: XCTestCase {
    func testManagedStartLeavesMissingCacheLimitsAtServerDefaults() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let processManager = CapturingKVCacheProcessManager()
        let memorySnapshot = SystemMemorySnapshot(
            totalBytes: 64 * 1_073_741_824,
            availableBytes: 40 * 1_073_741_824
        )
        let viewModel = AppViewModel(
            settingsStore: fixture.store,
            processManager: processManager,
            modelStorageEstimateOperation: { _ in 19 },
            systemMemorySnapshotProvider: { memorySnapshot },
            localModelIntegrityChecker: AlwaysReadyIntegrityChecker()
        )

        viewModel.startRequested(for: fixture.model)

        for _ in 0..<200 where processManager.capturedRequest == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let request = try XCTUnwrap(processManager.capturedRequest)
        XCTAssertNil(request.advancedLaunchOptions)
        XCTAssertNil(viewModel.models.first?.advancedLaunchOptions)
        XCTAssertNil(try fixture.store.load().models.first?.advancedLaunchOptions)
        XCTAssertFalse(viewModel.logText.contains("[cache-safe]"))

        viewModel.stopRequested(for: fixture.model)
        try await Task.sleep(for: .milliseconds(20))
    }

    func testMemorySafetyAssessmentUsesCappedRuntimeCacheInsteadOfOversizedProfileValue() async throws {
        var fixture = try makeFixture()
        defer { fixture.remove() }
        var options = AdvancedLaunchOptions.empty
        options.promptCacheSize = "999"
        options.promptCacheBytes = String(16 * 1_073_741_824 as UInt64)
        fixture.model.advancedLaunchOptions = options
        try fixture.store.save(settings: fixture.settings, models: [fixture.model])

        let viewModel = AppViewModel(
            settingsStore: fixture.store,
            modelStorageEstimateOperation: { _ in 10 },
            systemMemorySnapshotProvider: {
                SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 30 * 1_073_741_824
                )
            },
            localModelIntegrityChecker: AlwaysReadyIntegrityChecker()
        )

        var assessment = viewModel.memorySafetyAssessment(for: fixture.model)
        for _ in 0..<200 where assessment.level == .unavailable {
            try await Task.sleep(for: .milliseconds(10))
            assessment = viewModel.memorySafetyAssessment(for: fixture.model)
        }

        let recommendation = KVCacheAdvisor.recommendedConfiguration(
            environment: KVCacheEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: 30,
                modelStorageGigabytes: 10,
                isModelLoaded: false
            )
        )
        let expectedFootprint = 10 * 1.10
            + Double(recommendation.byteLimit) / Double(1_073_741_824)
        XCTAssertEqual(
            assessment.candidateFootprintGigabytes ?? 0,
            expectedFootprint,
            accuracy: 0.001
        )
        XCTAssertFalse(assessment.requiresConfirmation)
    }

    private func makeFixture() throws -> KVCacheFlowFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerKVCacheFlow-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent("model", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server", isDirectory: false)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: executableURL.path,
            contents: Data("#!/bin/sh\nexit 0\n".utf8)
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let port = try availablePort()
        let model = ModelConfig(
            modelID: modelDirectory.path,
            displayName: "KV Cache Flow Model",
            family: "Test",
            quantization: "4bit",
            localName: modelDirectory.path,
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: false,
            notes: ""
        )
        let settings = AppSettings(
            mlxServerExecutablePath: executableURL.path,
            defaultHost: "127.0.0.1",
            defaultPort: port,
            apiKeyPlaceholder: "not-required-local",
            uiLanguage: .english,
            uiAppearance: "system"
        )
        let store = SettingsStore(
            appDirectoryName: "MLXServerManagerKVCacheFlowStore-\(UUID().uuidString)"
        )
        try store.save(settings: settings, models: [model])
        return KVCacheFlowFixture(
            root: root,
            store: store,
            settings: settings,
            model: model
        )
    }

    private func availablePort() throws -> Int {
        let checker = PortChecker()
        for port in 58_000...59_999 {
            if case .available = checker.check(host: "127.0.0.1", port: port) {
                return port
            }
        }
        throw NSError(
            domain: "KVCacheSafeModeFlowTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No available test port was found."]
        )
    }
}

private struct KVCacheFlowFixture {
    let root: URL
    let store: SettingsStore
    let settings: AppSettings
    var model: ModelConfig

    func remove() {
        try? FileManager.default.removeItem(at: root)
        if let settingsDirectory = try? store.settingsDirectoryURL {
            try? FileManager.default.removeItem(at: settingsDirectory)
        }
    }
}

private struct AlwaysReadyIntegrityChecker: LocalModelIntegrityChecking {
    func check(path: String) -> LocalModelIntegrityCheckResult {
        .ready
    }
}

private final class CapturingKVCacheProcessManager: ModelProcessManaging {
    private(set) var managedProcessIdentifier: Int32?
    private(set) var capturedRequest: ModelLaunchRequest?

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        capturedRequest = request
        managedProcessIdentifier = 42_424
        return ModelLaunchResult(
            processIdentifier: 42_424,
            commandSummary: ModelProcessManager.commandPreview(
                for: request,
                executablePath: request.executablePath
            )
        )
    }

    func stop(
        gracefulTimeout: TimeInterval,
        interruptTimeout: TimeInterval
    ) async -> ModelStopResult {
        guard let managedProcessIdentifier else {
            return .notRunning
        }
        self.managedProcessIdentifier = nil
        return .stopped(
            processIdentifier: managedProcessIdentifier,
            terminationStatus: 0,
            stopMethod: .terminate
        )
    }
}
