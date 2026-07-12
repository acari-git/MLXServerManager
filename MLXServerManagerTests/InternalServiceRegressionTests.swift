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
