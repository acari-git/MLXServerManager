import Foundation
import XCTest
@testable import MLXServerManager

final class MLXLMServerCapabilityProviderTests: XCTestCase {
    func testHelpOutputParsesSupportedFlagsAndReportsOnlyMissingOptions() throws {
        let capabilities = try XCTUnwrap(MLXLMServerCapabilities(
            helpOutput: """
            usage: mlx_lm.server [-h] [--model MODEL] [--host HOST] [--port PORT]
                                 [--temp TEMP] [--prompt-cache-size PROMPT_CACHE_SIZE]
            """
        ))

        XCTAssertEqual(
            capabilities.unsupportedFlags(
                from: ["--prompt-cache-bytes", "--temp", "--allowed-origins"]
            ),
            ["--allowed-origins", "--prompt-cache-bytes"]
        )
    }

    func testRequestedOptionalFlagsMatchGeneratedMLXLMArguments() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/bin/mlx_lm.server",
            modelID: "/tmp/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: true,
            advancedLaunchOptions: AdvancedLaunchOptions(
                rawExtraArgs: "--experimental-mode=fast",
                defaultTemperature: "0.2"
            )
        )

        XCTAssertEqual(
            MLXLMServerCapabilities.requestedOptionalFlags(for: request),
            ["--chat-template-args", "--experimental-mode", "--temp"]
        )
    }

    func testRapidMLXDoesNotUseMLXLMCapabilityValidation() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/local/bin/rapid-mlx",
            backend: .rapidMLX,
            modelID: "/tmp/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: false,
            advancedLaunchOptions: AdvancedLaunchOptions(defaultTemperature: "0.2")
        )

        XCTAssertEqual(MLXLMServerCapabilities.requestedOptionalFlags(for: request), [])
    }

    func testProviderCachesHelpResultForExecutablePath() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXLMCapabilityProvider-\(UUID().uuidString)", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server")
        let counterURL = root.appendingPathComponent("calls")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let script = """
        #!/bin/sh
        echo call >> "\(counterURL.path)"
        echo "usage: mlx_lm.server --model MODEL --host HOST --port PORT --temp TEMP"
        """
        try Data(script.utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let provider = MLXLMServerCapabilityProvider(timeout: 2)
        let first = await provider.capabilities(executablePath: executableURL.path)
        let second = await provider.capabilities(executablePath: executableURL.path)

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            try String(contentsOf: counterURL, encoding: .utf8)
                .split(separator: "\n")
                .count,
            1
        )
    }

    func testProviderReprobesWhenExecutableChangesAtSamePath() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXLMCapabilityProviderRefresh-\(UUID().uuidString)", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server")
        let counterURL = root.appendingPathComponent("calls")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func writeScript(flag: String, padding: String) throws {
            let script = """
            #!/bin/sh
            echo call >> "\(counterURL.path)"
            echo "usage: mlx_lm.server --model MODEL --host HOST --port PORT \(flag) VALUE"
            # \(padding)
            """
            try Data(script.utf8).write(to: executableURL)
            try FileManager.default.setAttributes(
                [
                    .posixPermissions: 0o755,
                    .modificationDate: Date().addingTimeInterval(Double(padding.count + 1))
                ],
                ofItemAtPath: executableURL.path
            )
        }

        try writeScript(flag: "--temp", padding: "first")
        let provider = MLXLMServerCapabilityProvider(timeout: 2)
        let first = await provider.capabilities(executablePath: executableURL.path)

        try writeScript(flag: "--allowed-origins", padding: "second-version")
        let second = await provider.capabilities(executablePath: executableURL.path)

        guard case let .available(firstCapabilities) = first,
              case let .available(secondCapabilities) = second else {
            return XCTFail("Expected both capability probes to succeed.")
        }
        XCTAssertTrue(firstCapabilities.supportedFlags.contains("--temp"))
        XCTAssertFalse(firstCapabilities.supportedFlags.contains("--allowed-origins"))
        XCTAssertTrue(secondCapabilities.supportedFlags.contains("--allowed-origins"))
        XCTAssertFalse(secondCapabilities.supportedFlags.contains("--temp"))
        XCTAssertEqual(
            try String(contentsOf: counterURL, encoding: .utf8)
                .split(separator: "\n")
                .count,
            2
        )
    }

    func testUnavailableProbeIsRetriedInsteadOfCached() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXLMCapabilityProviderRetry-\(UUID().uuidString)", isDirectory: true)
        let executableURL = root.appendingPathComponent("mlx_lm.server")
        let counterURL = root.appendingPathComponent("calls")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let script = """
        #!/bin/sh
        count=0
        if [ -f "\(counterURL.path)" ]; then
          count=$(cat "\(counterURL.path)")
        fi
        count=$((count + 1))
        echo "$count" > "\(counterURL.path)"
        if [ "$count" -gt 1 ]; then
          echo "usage: mlx_lm.server --model MODEL --host HOST --port PORT --temp TEMP"
        fi
        """
        try Data(script.utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let provider = MLXLMServerCapabilityProvider(timeout: 2)
        let first = await provider.capabilities(executablePath: executableURL.path)
        let second = await provider.capabilities(executablePath: executableURL.path)

        XCTAssertEqual(first, .unavailable)
        guard case let .available(capabilities) = second else {
            return XCTFail("Expected the second probe to retry and succeed.")
        }
        XCTAssertTrue(capabilities.supportedFlags.contains("--temp"))
        XCTAssertEqual(
            try String(contentsOf: counterURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            "2"
        )
    }

    func testUnsupportedOptionIssueExplainsHowToRecover() {
        let issue = ModelStartPreflightIssue.unsupportedLaunchOptions(
            backend: .mlxLM,
            flags: ["--allowed-origins"]
        )

        XCTAssertTrue(issue.launchMessage(language: .english).contains("update the runtime"))
        XCTAssertTrue(issue.launchMessage(language: .japanese).contains("ランタイムを更新"))
    }
}
