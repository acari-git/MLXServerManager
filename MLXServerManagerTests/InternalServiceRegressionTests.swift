import Foundation
import XCTest
@testable import MLXServerManager

final class InternalServiceRegressionTests: XCTestCase {
    func testShellArgumentParserPreservesQuotedJSONAndPaths() throws {
        let arguments = try ShellArgumentParser.parse(
            #"--chat-template-args '{"mode":"reasoning with spaces"}' --path "/tmp/model folder" --flag"#
        )

        XCTAssertEqual(
            arguments,
            [
                "--chat-template-args",
                #"{"mode":"reasoning with spaces"}"#,
                "--path",
                "/tmp/model folder",
                "--flag"
            ]
        )
    }

    func testShellArgumentParserRejectsUnterminatedQuote() {
        XCTAssertThrowsError(try ShellArgumentParser.parse(#"--path "/tmp/model folder"#)) { error in
            XCTAssertEqual(error as? ShellArgumentParserError, .unterminatedDoubleQuote)
        }
    }

    func testLineStreamBufferPreservesPartialLinesAcrossChunks() {
        let buffer = LineStreamBuffer()

        XCTAssertEqual(buffer.consume("hello wor", label: "stdout"), [])
        XCTAssertEqual(buffer.consume("ld\nnext", label: "stdout"), ["hello world"])
        XCTAssertEqual(buffer.flush(label: "stdout"), ["next"])
    }

    func testLineStreamBufferFlushHonorsMaximumLineCount() {
        let buffer = LineStreamBuffer(maximumLinesPerLabel: 1)

        XCTAssertEqual(buffer.consume("first\nsecond", label: "stdout"), ["first"])
        XCTAssertEqual(buffer.flush(label: "stdout"), [])
    }

    func testLineStreamBufferBoundsAnUnterminatedLine() {
        let buffer = LineStreamBuffer(maximumCharactersPerLine: 8)

        XCTAssertEqual(buffer.consume("0123456789", label: "stdout"), [])
        let lines = buffer.flush(label: "stdout")

        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("2 characters omitted"))
        XCTAssertTrue(lines[0].hasSuffix("23456789"))
    }

    func testLaunchArgumentsUseQuotedRawExtraArgumentParsing() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/bin/mlx_lm.server",
            modelID: "/tmp/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: false,
            advancedLaunchOptions: AdvancedLaunchOptions(
                rawExtraArgs: #"--custom-json '{"key":"value with spaces"}'"#,
                chatTemplateArgs: nil,
                defaultTemperature: nil,
                defaultTopP: nil,
                defaultTopK: nil,
                defaultMinP: nil,
                defaultMaxTokens: nil,
                allowedOrigins: nil,
                logLevel: nil,
                decodeConcurrency: nil,
                promptConcurrency: nil,
                prefillStepSize: nil,
                promptCacheSize: nil,
                promptCacheBytes: nil
            )
        )

        let arguments = ModelProcessManager.launchArguments(for: request)
        XCTAssertEqual(Array(arguments.suffix(2)), ["--custom-json", #"{"key":"value with spaces"}"#])
    }

    func testMLXLMLaunchArgumentsDiscardManagedRawOverrides() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/bin/mlx_lm.server",
            modelID: "/tmp/managed-model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: false,
            advancedLaunchOptions: AdvancedLaunchOptions(
                rawExtraArgs: "--model other/model --host=0.0.0.0 --port 9000 --safe-flag value"
            )
        )

        XCTAssertEqual(
            ModelProcessManager.launchArguments(for: request),
            [
                "--model", "/tmp/managed-model", "--host", "127.0.0.1", "--port", "8080",
                "--safe-flag", "value"
            ]
        )
    }

    func testRapidMLXLaunchArgumentsDiscardManagedRawOverridesButPreserveOtherArguments() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/local/bin/rapid-mlx",
            backend: .rapidMLX,
            modelID: "/tmp/managed-model",
            host: "127.0.0.1",
            port: 8088,
            enableThinking: true,
            advancedLaunchOptions: AdvancedLaunchOptions(
                rawExtraArgs: "--host 0.0.0.0 --port=9000 --model alternate-model --safe-flag"
            )
        )

        XCTAssertEqual(
            ModelProcessManager.launchArguments(for: request),
            [
                "serve", "/tmp/managed-model", "--host", "127.0.0.1", "--port", "8088",
                "--model", "alternate-model", "--safe-flag"
            ]
        )
    }

    func testMLXLMLaunchArgumentsUseSupportedTemperatureFlag() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/bin/mlx_lm.server",
            modelID: "/tmp/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: true,
            advancedLaunchOptions: AdvancedLaunchOptions(defaultTemperature: "0.2")
        )

        let arguments = ModelProcessManager.launchArguments(for: request)

        XCTAssertEqual(
            arguments,
            [
                "--model", "/tmp/model", "--host", "127.0.0.1", "--port", "8080",
                "--chat-template-args", #"{"enable_thinking":true}"#,
                "--temp", "0.2"
            ]
        )
    }

    func testRapidMLXLaunchArgumentsMapSupportedOptions() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/local/bin/rapid-mlx",
            backend: .rapidMLX,
            modelID: "/tmp/model folder",
            host: "127.0.0.1",
            port: 8088,
            enableThinking: false,
            advancedLaunchOptions: AdvancedLaunchOptions(
                rawExtraArgs: #"--extra-flag "value with spaces""#,
                defaultTemperature: "0.2",
                defaultTopP: "0.9",
                defaultTopK: "40",
                defaultMinP: "0.05",
                defaultMaxTokens: "4096",
                allowedOrigins: #""http://localhost:3000" "https://example.com""#,
                logLevel: "debug",
                decodeConcurrency: "4",
                promptConcurrency: "8",
                prefillStepSize: "2048",
                promptCacheSize: "16",
                promptCacheBytes: "1048577"
            )
        )

        XCTAssertEqual(
            ModelProcessManager.launchArguments(for: request),
            [
                "serve", "/tmp/model folder", "--host", "127.0.0.1", "--port", "8088", "--no-thinking",
                "--default-temperature", "0.2", "--default-top-p", "0.9", "--default-top-k", "40",
                "--default-min-p", "0.05", "--max-tokens", "4096",
                "--cors-origins", "http://localhost:3000", "https://example.com",
                "--log-level", "DEBUG", "--max-num-seqs", "4", "--max-concurrent-requests", "8",
                "--prefill-step-size", "2048", "--prefix-cache-size", "16", "--cache-memory-mb", "2",
                "--extra-flag", "value with spaces"
            ]
        )
    }

    func testRapidMLXCORSOriginsAcceptCommaSeparatedValues() {
        let request = ModelLaunchRequest(
            executablePath: "/usr/local/bin/rapid-mlx",
            backend: .rapidMLX,
            modelID: "local/model",
            host: "127.0.0.1",
            port: 8088,
            enableThinking: true,
            advancedLaunchOptions: AdvancedLaunchOptions(
                allowedOrigins: "http://localhost:3000, https://example.com"
            )
        )

        XCTAssertEqual(
            ModelProcessManager.launchArguments(for: request),
            [
                "serve", "local/model", "--host", "127.0.0.1", "--port", "8088",
                "--cors-origins", "http://localhost:3000", "https://example.com"
            ]
        )
    }

    func testLegacyModelProfileDefaultsToMLXLMBackend() throws {
        let data = Data(#"{"modelID":"local/model","displayName":"Model","family":"Local","quantization":"4bit","localName":"model","host":"127.0.0.1","serverPort":8000,"enableThinking":false,"notes":""}"#.utf8)

        let model = try JSONDecoder().decode(ModelConfig.self, from: data)

        XCTAssertNil(model.backend)
        XCTAssertEqual(model.resolvedBackend, .mlxLM)
    }

    func testRapidMLXModelProfileRoundTripsBackend() throws {
        var model = ModelConfig.defaults[0]
        model.backend = .rapidMLX

        let decoded = try JSONDecoder().decode(ModelConfig.self, from: JSONEncoder().encode(model))

        XCTAssertEqual(decoded.resolvedBackend, .rapidMLX)
    }

    func testLegacyBenchmarkSnapshotDecodesWithoutSchemaVersion() throws {
        let data = Data(
            #"{"benchmarkResultsByProfileID":{},"agenticBenchmarkResultsByProfileID":{}}"#.utf8
        )
        let snapshot = try JSONDecoder().decode(BenchmarkResultsSnapshot.self, from: data)

        XCTAssertEqual(snapshot.schemaVersion, 0)
        XCTAssertTrue(snapshot.benchmarkResultsByProfileID.isEmpty)
        XCTAssertTrue(snapshot.agenticBenchmarkResultsByProfileID.isEmpty)
    }

    func testLegacyAgentReadinessDerivesToolProbeCount() throws {
        let data = Data(
            #"{"totalRuns":5,"successfulRuns":5,"jsonValidResponses":5,"instructionFollowingPasses":5,"toolSelectionPasses":3,"timeoutCount":0,"lengthFinishCount":0,"averageTTFTMS":10,"averageTotalLatencyMS":20}"#.utf8
        )
        let readiness = try JSONDecoder().decode(BenchmarkAgentReadiness.self, from: data)

        XCTAssertEqual(readiness.toolSelectionProbeCount, 3)
        XCTAssertEqual(readiness.toolSelectionText, "3/3")
    }
}
