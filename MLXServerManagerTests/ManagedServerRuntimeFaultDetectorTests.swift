import Foundation
import XCTest
@testable import MLXServerManager

final class ManagedServerRuntimeFaultDetectorTests: XCTestCase {
    private let detector = ManagedServerRuntimeFaultDetector()

    func testDetectsMLXLMGenerationThreadTermination() {
        let fault = detector.detect(
            line: "[process:stderr] Exception in thread Thread-1 (_generate):",
            backend: .mlxLM
        )

        XCTAssertEqual(fault?.kind, .generationWorkerTerminated)
    }

    func testDetectsNamedGenerationWorkerTermination() {
        let fault = detector.detect(
            line: "[process:stderr] Exception in thread Thread-2 (generation_worker):",
            backend: .mlxLM
        )

        XCTAssertEqual(fault?.kind, .generationWorkerTerminated)
    }

    func testDetectsExplicitGenerationWorkerCrashMessage() {
        let fault = detector.detect(
            line: "[process:stderr] generation worker exited unexpectedly after an uncaught error",
            backend: .mlxLM
        )

        XCTAssertEqual(fault?.kind, .generationWorkerTerminated)
    }

    func testIgnoresNonTerminalGenerationWorkerWarnings() {
        XCTAssertNil(detector.detect(
            line: "[process:stderr] generation worker retry scheduled after a transient warning",
            backend: .mlxLM
        ))
    }

    func testIgnoresStdoutAndUnrelatedExceptions() {
        XCTAssertNil(detector.detect(
            line: "[process:stdout] Exception in thread Thread-1 (_generate):",
            backend: .mlxLM
        ))
        XCTAssertNil(detector.detect(
            line: "[process:stderr] Exception in thread Thread-2 (telemetry):",
            backend: .mlxLM
        ))
    }

    func testIgnoresOtherBackends() {
        XCTAssertNil(detector.detect(
            line: "[process:stderr] Exception in thread Thread-1 (_generate):",
            backend: .rapidMLX
        ))
    }
}

@MainActor
final class ManagedServerRuntimeHealthFlowTests: XCTestCase {
    func testGenerationWorkerTerminationMarksManagedModelDegradedWithoutStoppingProcess() async throws {
        let fixture = try RuntimeHealthFixture.make()
        defer { fixture.remove() }

        let processManager = RuntimeHealthProcessManager()
        RuntimeHealthReadyURLProtocol.responseDelay = 0
        defer { RuntimeHealthReadyURLProtocol.responseDelay = 0 }
        RuntimeHealthReadyURLProtocol.modelID = fixture.model.modelID
        let viewModel = AppViewModel(
            settingsStore: fixture.store,
            readyChecker: ReadyChecker(
                timeout: 1,
                session: RuntimeHealthReadyURLProtocol.makeSession()
            ),
            processManager: processManager,
            localModelIntegrityChecker: RuntimeHealthReadyIntegrityChecker()
        )

        viewModel.startRequested(for: fixture.model)
        try await waitUntil {
            if case .ready = viewModel.runtimeState(for: fixture.model) {
                return true
            }
            return false
        }

        RuntimeHealthReadyURLProtocol.responseDelay = 0.1
        viewModel.checkReadyRequested()
        processManager.emit(
            "[process:stderr] Exception in thread Thread-1 (_generate):"
        )
        try await waitUntil {
            viewModel.runtimeState(for: fixture.model).isDegraded
        }
        try await Task.sleep(for: .milliseconds(150))

        guard case let .degraded(host, port, processIdentifier, _) =
            viewModel.runtimeState(for: fixture.model) else {
            return XCTFail("Expected the managed model to remain visible as degraded.")
        }
        XCTAssertEqual(host, fixture.model.host)
        XCTAssertEqual(port, fixture.model.serverPort)
        XCTAssertEqual(processIdentifier, RuntimeHealthProcessManager.processIdentifier)
        XCTAssertEqual(processManager.managedProcessIdentifier, RuntimeHealthProcessManager.processIdentifier)
        XCTAssertTrue(viewModel.isModelRunning(fixture.model))
        XCTAssertFalse(viewModel.isModelLoaded(fixture.model))
        XCTAssertTrue(viewModel.isModelDegraded(fixture.model))
        XCTAssertTrue(viewModel.canStopManagedServer)
        XCTAssertTrue(viewModel.logText.contains("[runtime-health]"))
        XCTAssertFalse(viewModel.connectionTargetSummary.isActiveTarget)
        XCTAssertFalse(viewModel.canRunSpeedTest)
        XCTAssertFalse(viewModel.canRunAgenticBenchmark)
        viewModel.miniChatPrompt = "test"
        XCTAssertFalse(viewModel.canSendMiniChat)

        viewModel.checkPortRequested()
        XCTAssertTrue(viewModel.runtimeState(for: fixture.model).isDegraded)

        let row = try XCTUnwrap(
            viewModel.modelListRowStates(from: [fixture.model]).first
        )
        XCTAssertTrue(row.isDegraded)
        XCTAssertFalse(row.isLoaded)
        XCTAssertEqual(row.normalStatusText, "Degraded")
        XCTAssertEqual(row.hoveredStatusText, "Unload")

        viewModel.stopRequested(for: fixture.model)
        try await waitUntil {
            processManager.managedProcessIdentifier == nil
        }
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<300 {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met before timeout.")
    }
}

private struct RuntimeHealthFixture {
    let root: URL
    let store: SettingsStore
    let model: ModelConfig

    static func make() throws -> RuntimeHealthFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "MLXServerManagerRuntimeHealth-\(UUID().uuidString)",
                isDirectory: true
            )
        let modelDirectory = root.appendingPathComponent("model", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server")
        try FileManager.default.createDirectory(
            at: modelDirectory,
            withIntermediateDirectories: true
        )
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
            displayName: "Runtime Health Model",
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
            defaultHost: model.host,
            defaultPort: model.serverPort,
            apiKeyPlaceholder: "not-required-local",
            uiLanguage: .english,
            uiAppearance: "system"
        )
        let store = SettingsStore(
            appDirectoryName: "MLXServerManagerRuntimeHealthStore-\(UUID().uuidString)"
        )
        try store.save(settings: settings, models: [model])
        return RuntimeHealthFixture(root: root, store: store, model: model)
    }

    private static func availablePort() throws -> Int {
        let checker = PortChecker()
        for port in 59_000...59_999 {
            if case .available = checker.check(host: "127.0.0.1", port: port) {
                return port
            }
        }
        throw NSError(
            domain: "RuntimeHealthFixture",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No available test port was found."]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
        if let settingsDirectory = try? store.settingsDirectoryURL {
            try? FileManager.default.removeItem(at: settingsDirectory)
        }
    }
}

private struct RuntimeHealthReadyIntegrityChecker: LocalModelIntegrityChecking {
    func check(path: String) -> LocalModelIntegrityCheckResult {
        .ready
    }
}

private final class RuntimeHealthProcessManager: ModelProcessManaging {
    static let processIdentifier: Int32 = 45_678

    private(set) var managedProcessIdentifier: Int32?
    private var outputHandler: (@Sendable (String) -> Void)?

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        self.outputHandler = outputHandler
        managedProcessIdentifier = Self.processIdentifier
        return ModelLaunchResult(
            processIdentifier: Self.processIdentifier,
            commandSummary: "runtime-health-test"
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
        outputHandler = nil
        return .stopped(
            processIdentifier: managedProcessIdentifier,
            terminationStatus: 0,
            stopMethod: .terminate
        )
    }

    func emit(_ line: String) {
        outputHandler?(line)
    }
}

private final class RuntimeHealthReadyURLProtocol: URLProtocol {
    nonisolated(unsafe) static var modelID = ""
    nonisolated(unsafe) static var responseDelay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if Self.responseDelay > 0 {
            Thread.sleep(forTimeInterval: Self.responseDelay)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = #"{"object":"list","data":[{"id":"\#(Self.modelID)"}]}"#
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RuntimeHealthReadyURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
