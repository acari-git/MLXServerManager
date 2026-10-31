import XCTest
@testable import MLXServerManager

/// Rapid-MLX launches as `rapid-mlx serve <model> ...`, and serve-only flags such as
/// `--no-thinking` are listed by `rapid-mlx serve --help`, not by top-level `--help`.
/// These tests run a fake executable that behaves the same way, so they exercise the real
/// process-probing path without needing Rapid-MLX installed.
@MainActor
final class RapidMLXServeHelpProbeTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rapid-mlx-help-probe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    // MARK: - Capability provider (Start preflight)

    func testRapidMLXProbeIncludesServeOnlyFlags() async throws {
        let runtime = try makeFakeRuntime()
        let provider = RuntimeOptionCapabilityProvider(timeout: 5)

        let result = await provider.capabilities(executablePath: runtime.executablePath, backend: .rapidMLX)

        guard case let .available(flags) = result else {
            return XCTFail("Expected flags to be detected, got \(result)")
        }
        XCTAssertTrue(flags.contains("--no-thinking"), "serve-only flag must be detected")
        XCTAssertTrue(flags.contains("--host"))
        XCTAssertTrue(flags.contains("--version"), "top-level help flags must still be merged in")
        XCTAssertEqual(runtime.invocations(), ["--help", "serve --help"])
    }

    func testMLXLMProbeOnlyRunsTopLevelHelp() async throws {
        let runtime = try makeFakeRuntime()
        let provider = RuntimeOptionCapabilityProvider(timeout: 5)

        let result = await provider.capabilities(executablePath: runtime.executablePath, backend: .mlxLM)

        guard case let .available(flags) = result else {
            return XCTFail("Expected flags to be detected, got \(result)")
        }
        XCTAssertFalse(flags.contains("--no-thinking"))
        XCTAssertEqual(runtime.invocations(), ["--help"], "mlx-lm must not be probed with `serve --help`")
    }

    func testRapidMLXProbeKeepsTopLevelFlagsWhenServeHelpFails() async throws {
        let runtime = try makeFakeRuntime(serveHelpSucceeds: false)
        let provider = RuntimeOptionCapabilityProvider(timeout: 5)

        let result = await provider.capabilities(executablePath: runtime.executablePath, backend: .rapidMLX)

        guard case let .available(flags) = result else {
            return XCTFail("A failing `serve --help` must not discard top-level flags, got \(result)")
        }
        XCTAssertTrue(flags.contains("--version"))
        XCTAssertFalse(flags.contains("--no-thinking"))
        XCTAssertEqual(runtime.invocations(), ["--help", "serve --help"])
    }

    func testProbeResultsAreCachedPerBackend() async throws {
        let runtime = try makeFakeRuntime()
        let provider = RuntimeOptionCapabilityProvider(timeout: 5)

        let mlxLM = await provider.capabilities(executablePath: runtime.executablePath, backend: .mlxLM)
        let rapid = await provider.capabilities(executablePath: runtime.executablePath, backend: .rapidMLX)
        let rapidAgain = await provider.capabilities(executablePath: runtime.executablePath, backend: .rapidMLX)

        guard case let .available(mlxLMFlags) = mlxLM,
              case let .available(rapidFlags) = rapid else {
            return XCTFail("Expected both probes to detect flags")
        }
        XCTAssertFalse(mlxLMFlags.contains("--no-thinking"))
        XCTAssertTrue(
            rapidFlags.contains("--no-thinking"),
            "A cached mlx-lm result must not be reused for the same path with the Rapid-MLX backend"
        )
        XCTAssertEqual(rapidAgain, rapid)
        XCTAssertEqual(
            runtime.invocations(),
            ["--help", "--help", "serve --help"],
            "The repeated Rapid-MLX probe should be served from the cache"
        )
    }

    func testMissingExecutableIsUnavailable() async {
        let provider = RuntimeOptionCapabilityProvider(timeout: 5)
        let missing = temporaryDirectory.appendingPathComponent("does-not-exist").path

        let result = await provider.capabilities(executablePath: missing, backend: .rapidMLX)

        XCTAssertEqual(result, .unavailable)
    }

    // MARK: - Runtime Compatibility Matrix

    func testCompatibilityMatrixDetectsReasoningControlFromServeHelp() async throws {
        let runtime = try makeFakeRuntime()
        var settings = AppSettings.defaults
        settings.rapidMLXExecutablePath = runtime.executablePath
        let service = RuntimeCompatibilityService(timeout: 5)

        let reports = await service.assess(settings: settings)

        let report = try XCTUnwrap(reports.first { $0.backend == .rapidMLX })
        let supportedFlags = try XCTUnwrap(report.supportedFlags)
        XCTAssertTrue(supportedFlags.contains("--no-thinking"))
        let reasoning = try XCTUnwrap(report.features.first { $0.feature == .reasoningControl })
        XCTAssertEqual(reasoning.support, .supported)
        XCTAssertEqual(reasoning.detectedFlags, ["--no-thinking"])
    }

    // MARK: - Fake runtime

    private struct FakeRuntime {
        let executablePath: String
        let invocationLogPath: String

        /// Arguments of every invocation, in order (e.g. `["--help", "serve --help"]`).
        func invocations() -> [String] {
            guard let contents = try? String(contentsOfFile: invocationLogPath, encoding: .utf8) else {
                return []
            }
            return contents.split(separator: "\n").map(String.init)
        }
    }

    /// A shell script that mimics Rapid-MLX's help layout: `--no-thinking` is only listed
    /// under `serve --help`.
    private func makeFakeRuntime(serveHelpSucceeds: Bool = true) throws -> FakeRuntime {
        let executablePath = temporaryDirectory.appendingPathComponent("rapid-mlx").path
        let logPath = temporaryDirectory.appendingPathComponent("invocations.log").path
        let serveHelp = serveHelpSucceeds
            ? "echo \"usage: rapid-mlx serve [--host HOST] [--port PORT] [--no-thinking]\""
            : "echo \"serve help unavailable\" >&2; exit 2"

        let script = """
        #!/bin/sh
        echo "$*" >> '\(logPath)'
        case "$1" in
        --version)
          echo "rapid-mlx 0.16.10"
          ;;
        --help)
          echo "usage: rapid-mlx [--version] [--help] {serve,chat}"
          ;;
        serve)
          if [ "$2" = "--help" ]; then
            \(serveHelp)
          fi
          ;;
        esac

        """
        try script.write(toFile: executablePath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath)
        return FakeRuntime(executablePath: executablePath, invocationLogPath: logPath)
    }
}
