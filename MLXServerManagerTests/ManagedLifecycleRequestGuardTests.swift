import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class ManagedLifecycleRequestGuardTests: XCTestCase {
    func testRepeatedStartRequestCreatesOnlyOneManagedLaunch() async throws {
        let fixture = try LifecycleGuardFixture.make(includeOptionalFlag: false)
        defer { fixture.remove() }
        let processManager = CountingFailingProcessManager()
        let viewModel = fixture.makeViewModel(processManager: processManager)

        XCTAssertTrue(viewModel.canStartSelectedModel)
        viewModel.startRequested(for: fixture.model)
        viewModel.startRequested(for: fixture.model)

        for _ in 0..<200 where processManager.startCallCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(processManager.startCallCount, 1)
        XCTAssertTrue(viewModel.logText.contains("ignored duplicate or unavailable start request"))
    }

    func testStopCancelsManagedStartBeforeProcessLaunch() async throws {
        let fixture = try LifecycleGuardFixture.make(includeOptionalFlag: true)
        defer { fixture.remove() }
        let processManager = CountingFailingProcessManager()
        let capabilityProvider = DelayedCapabilityProvider()
        let viewModel = fixture.makeViewModel(
            processManager: processManager,
            capabilityProvider: capabilityProvider
        )

        viewModel.startRequested(for: fixture.model)
        for _ in 0..<200 where !viewModel.runtimeState(for: fixture.model).isTransitioningForTest {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(viewModel.canStartSelectedModel)
        viewModel.stopRequested(for: fixture.model)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(processManager.startCallCount, 0)
        XCTAssertFalse(viewModel.isManagedProcessRunning)
        XCTAssertFalse(viewModel.runtimeState(for: fixture.model).isTransitioningForTest)
    }
}

private struct LifecycleGuardFixture {
    let root: URL
    let store: SettingsStore
    let model: ModelConfig

    static func make(includeOptionalFlag: Bool) throws -> LifecycleGuardFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerLifecycleGuard-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent("model", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        var options = AdvancedLaunchOptions.empty
        if includeOptionalFlag {
            options.defaultTemperature = "0.2"
        }
        let model = ModelConfig(
            modelID: modelDirectory.path,
            displayName: "Lifecycle Guard Model",
            family: "Test",
            quantization: "4bit",
            localName: modelDirectory.path,
            host: "127.0.0.1",
            serverPort: try availablePort(),
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: options.normalized()
        )
        let settings = AppSettings(
            mlxServerExecutablePath: executableURL.path,
            defaultHost: model.host,
            defaultPort: model.serverPort,
            apiKeyPlaceholder: "not-required-local",
            uiLanguage: .english,
            uiAppearance: "system"
        )
        let store = SettingsStore(appDirectoryName: "MLXServerManagerLifecycleGuardStore-\(UUID().uuidString)")
        try store.save(settings: settings, models: [model])
        return LifecycleGuardFixture(root: root, store: store, model: model)
    }

    @MainActor
    func makeViewModel(
        processManager: CountingFailingProcessManager,
        capabilityProvider: (any MLXLMServerCapabilityProviding)? = nil
    ) -> AppViewModel {
        AppViewModel(
            settingsStore: store,
            processManager: processManager,
            modelStorageEstimateOperation: { _ in 1 },
            systemMemorySnapshotProvider: {
                SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 48 * 1_073_741_824
                )
            },
            localModelIntegrityChecker: LifecycleReadyIntegrityChecker(),
            mlxLMServerCapabilityProvider: capabilityProvider
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
        if let directory = try? store.settingsDirectoryURL {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func availablePort() throws -> Int {
        let checker = PortChecker()
        for port in 57_000...58_999 {
            if case .available = checker.check(host: "127.0.0.1", port: port) {
                return port
            }
        }
        throw NSError(
            domain: "LifecycleGuardFixture",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No available test port was found."]
        )
    }
}

private struct LifecycleReadyIntegrityChecker: LocalModelIntegrityChecking {
    func check(path: String) -> LocalModelIntegrityCheckResult {
        .ready
    }
}

@MainActor
private final class CountingFailingProcessManager: ModelProcessManaging {
    private(set) var startCallCount = 0
    var managedProcessIdentifier: Int32? { nil }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        startCallCount += 1
        throw NSError(
            domain: "CountingFailingProcessManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Intentional launch failure"]
        )
    }

    func stop(
        gracefulTimeout: TimeInterval,
        interruptTimeout: TimeInterval
    ) async -> ModelStopResult {
        .notRunning
    }
}

private actor DelayedCapabilityProvider: MLXLMServerCapabilityProviding {
    func capabilities(executablePath: String) async -> MLXLMServerCapabilityProbeResult {
        try? await Task.sleep(for: .seconds(5))
        return .available(
            MLXLMServerCapabilities(
                supportedFlags: ["--model", "--host", "--port", "--temp"]
            )
        )
    }
}

private extension ModelRuntimeState {
    var isTransitioningForTest: Bool {
        switch self {
        case .starting, .loading, .stopping, .checkingPort, .checkingReady:
            return true
        default:
            return false
        }
    }
}
