import Foundation
import XCTest
@testable import MLXServerManager

final class RuntimeReadinessTests: XCTestCase {
    func testViewStateTransitionsRemainCoherent() {
        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = "/tmp/mlx_lm.server"
        settings.rapidMLXExecutablePath = "/tmp/rapid-mlx"
        var state = RuntimeReadinessViewState.initial(settings: settings)

        XCTAssertFalse(state.isChecking)
        XCTAssertEqual(state.report(for: .mlxLM).issue, .notChecked)

        state.begin(settings: settings)
        XCTAssertTrue(state.isChecking)
        XCTAssertEqual(state.report(for: .mlxLM).issue, .checking)
        XCTAssertEqual(state.report(for: .rapidMLX).issue, .checking)

        state.complete([
            RuntimeReadinessReport(
                backend: .mlxLM,
                executablePath: settings.mlxServerExecutablePath,
                issue: .ready(supportedFlagCount: 12),
                checkedAt: Date()
            ),
            RuntimeReadinessReport(
                backend: .rapidMLX,
                executablePath: settings.rapidMLXExecutablePath,
                issue: .notExecutable,
                checkedAt: Date()
            )
        ])

        XCTAssertFalse(state.isChecking)
        XCTAssertEqual(state.report(for: .mlxLM).status, .ready)
        XCTAssertEqual(state.report(for: .rapidMLX).status, .unavailable)
    }

    func testServiceDistinguishesMissingAndUnconfiguredPaths() async throws {
        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = ""
        settings.rapidMLXExecutablePath = "/path/that/does/not/exist"
        let service = RuntimeReadinessService(
            mlxLMCapabilityProvider: StubRuntimeCapabilityProvider(result: .unavailable)
        )

        let reports = await service.assess(settings: settings)

        XCTAssertEqual(report(.mlxLM, in: reports).issue, .pathNotConfigured)
        XCTAssertEqual(report(.rapidMLX, in: reports).issue, .fileMissing)
    }

    func testServiceReportsExecutableCapabilityAndRapidMLXReadiness() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let mlxPath = try makeExecutable(named: "mlx_lm.server", in: directory)
        let rapidPath = try makeExecutable(named: "rapid-mlx", in: directory)
        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = mlxPath.path
        settings.rapidMLXExecutablePath = rapidPath.path
        let capabilities = MLXLMServerCapabilities(
            supportedFlags: ["--model", "--host", "--port", "--prompt-cache-size"]
        )
        let service = RuntimeReadinessService(
            mlxLMCapabilityProvider: StubRuntimeCapabilityProvider(result: .available(capabilities))
        )

        let reports = await service.assess(settings: settings)

        XCTAssertEqual(report(.mlxLM, in: reports).issue, .ready(supportedFlagCount: 4))
        XCTAssertEqual(report(.rapidMLX, in: reports).issue, .ready(supportedFlagCount: nil))
    }

    func testServiceKeepsExecutableAvailableWhenCapabilityProbeCannotFinish() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = try makeExecutable(named: "mlx_lm.server", in: directory)
        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = executable.path
        let service = RuntimeReadinessService(
            mlxLMCapabilityProvider: StubRuntimeCapabilityProvider(result: .unavailable)
        )

        let reports = await service.assess(settings: settings)

        XCTAssertEqual(report(.mlxLM, in: reports).issue, .capabilityProbeUnavailable)
        XCTAssertEqual(report(.mlxLM, in: reports).status, .warning)
    }

    func testServiceRejectsNonExecutableFiles() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("rapid-mlx")
        try Data("placeholder".utf8).write(to: path)
        var settings = AppSettings.defaults
        settings.rapidMLXExecutablePath = path.path
        let service = RuntimeReadinessService(
            mlxLMCapabilityProvider: StubRuntimeCapabilityProvider(result: .unavailable)
        )

        let reports = await service.assess(settings: settings)

        XCTAssertEqual(report(.rapidMLX, in: reports).issue, .notExecutable)
    }

    private func report(
        _ backend: InferenceBackend,
        in reports: [RuntimeReadinessReport]
    ) -> RuntimeReadinessReport {
        guard let report = reports.first(where: { $0.backend == backend }) else {
            XCTFail("Missing report for \(backend.rawValue)")
            return RuntimeReadinessReport.initial(backend: backend, executablePath: "")
        }
        return report
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuntimeReadinessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeExecutable(named name: String, in directory: URL) throws -> URL {
        let path = directory.appendingPathComponent(name)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: path)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: path.path
        )
        return path
    }
}

private actor StubRuntimeCapabilityProvider: MLXLMServerCapabilityProviding {
    let result: MLXLMServerCapabilityProbeResult

    init(result: MLXLMServerCapabilityProbeResult) {
        self.result = result
    }

    func capabilities(executablePath: String) async -> MLXLMServerCapabilityProbeResult {
        result
    }
}
