import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class MLXLMServerCapabilityFlowTests: XCTestCase {
    func testKnownUnsupportedExplicitOptionBlocksLaunch() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let processManager = CapabilityCapturingProcessManager()
        let capabilityProvider = StubRuntimeOptionCapabilityProvider(
            result: .available(flags: ["--model", "--host", "--port"])
        )
        let viewModel = makeViewModel(
            fixture: fixture,
            processManager: processManager,
            capabilityProvider: capabilityProvider
        )

        viewModel.startRequested(for: fixture.model)

        for _ in 0..<200 where !viewModel.logText.contains("Unsupported mlx-lm options") {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertNil(processManager.capturedRequest)
        XCTAssertTrue(viewModel.logText.contains("--temp"))
        XCTAssertTrue(viewModel.logText.contains("update the runtime"))
        let requestCount = await capabilityProvider.requestCount()
        XCTAssertEqual(requestCount, 1)
    }

    func testUnavailableCapabilityProbeDoesNotBlockExplicitOption() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let processManager = CapabilityCapturingProcessManager()
        let capabilityProvider = StubRuntimeOptionCapabilityProvider(result: .unavailable)
        let viewModel = makeViewModel(
            fixture: fixture,
            processManager: processManager,
            capabilityProvider: capabilityProvider
        )

        viewModel.startRequested(for: fixture.model)

        for _ in 0..<200 where processManager.capturedRequest == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(
            processManager.capturedRequest?.advancedLaunchOptions?.defaultTemperature,
            "0.2"
        )
        XCTAssertTrue(viewModel.logText.contains("capability check was unavailable"))
        let requestCount = await capabilityProvider.requestCount()
        XCTAssertEqual(requestCount, 1)

        viewModel.stopRequested(for: fixture.model)
        try await Task.sleep(for: .milliseconds(20))
    }

    private func makeViewModel(
        fixture: CapabilityFlowFixture,
        processManager: CapabilityCapturingProcessManager,
        capabilityProvider: StubRuntimeOptionCapabilityProvider
    ) -> AppViewModel {
        AppViewModel(
            settingsStore: fixture.store,
            processManager: processManager,
            modelStorageEstimateOperation: { _ in 1 },
            systemMemorySnapshotProvider: {
                SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 48 * 1_073_741_824
                )
            },
            localModelIntegrityChecker: CapabilityAlwaysReadyIntegrityChecker(),
            runtimeOptionCapabilityProvider: capabilityProvider
        )
    }

    private func makeFixture() throws -> CapabilityFlowFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXLMCapabilityFlow-\(UUID().uuidString)", isDirectory: true)
        let modelDirectory = root.appendingPathComponent("model", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        var options = AdvancedLaunchOptions.empty
        options.defaultTemperature = "0.2"
        let model = ModelConfig(
            modelID: modelDirectory.path,
            displayName: "Capability Flow Model",
            family: "Test",
            quantization: "4bit",
            localName: modelDirectory.path,
            host: "127.0.0.1",
            serverPort: try availablePort(),
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: options
        )
        let settings = AppSettings(
            mlxServerExecutablePath: executableURL.path,
            defaultHost: "127.0.0.1",
            defaultPort: model.serverPort,
            apiKeyPlaceholder: "not-required-local",
            uiLanguage: .english,
            uiAppearance: "system"
        )
        let store = SettingsStore(
            appDirectoryName: "MLXLMCapabilityFlowStore-\(UUID().uuidString)"
        )
        try store.save(settings: settings, models: [model])
        return CapabilityFlowFixture(root: root, store: store, model: model)
    }

    private func availablePort() throws -> Int {
        let checker = PortChecker()
        for port in 56_000...57_999 {
            if case .available = checker.check(host: "127.0.0.1", port: port) {
                return port
            }
        }
        throw NSError(
            domain: "MLXLMServerCapabilityFlowTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No available test port was found."]
        )
    }
}

private struct CapabilityFlowFixture {
    let root: URL
    let store: SettingsStore
    let model: ModelConfig

    func remove() {
        try? FileManager.default.removeItem(at: root)
        if let settingsDirectory = try? store.settingsDirectoryURL {
            try? FileManager.default.removeItem(at: settingsDirectory)
        }
    }
}

private actor StubRuntimeOptionCapabilityProvider: RuntimeOptionCapabilityProviding {
    private let result: RuntimeOptionCapabilityProbeResult
    private var count = 0

    init(result: RuntimeOptionCapabilityProbeResult) {
        self.result = result
    }

    func capabilities(executablePath: String) async -> RuntimeOptionCapabilityProbeResult {
        count += 1
        return result
    }

    func requestCount() -> Int {
        count
    }
}

private struct CapabilityAlwaysReadyIntegrityChecker: LocalModelIntegrityChecking {
    func check(path: String) -> LocalModelIntegrityCheckResult {
        .ready
    }
}

private final class CapabilityCapturingProcessManager: ModelProcessManaging {
    private(set) var managedProcessIdentifier: Int32?
    private(set) var capturedRequest: ModelLaunchRequest?

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        capturedRequest = request
        managedProcessIdentifier = 43_434
        return ModelLaunchResult(
            processIdentifier: 43_434,
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
