import XCTest
@testable import MLXServerManager

final class BenchmarkTests: XCTestCase {
    func testJSONExtractorAcceptsFencedJSON() {
        let text = """
        ```json
        {"tool":"read_file","needs_tool":true,"reason":"inspect first"}
        ```
        """

        let object = BenchmarkJSONExtractor.object(from: text)

        XCTAssertEqual(object?["tool"] as? String, "read_file")
        XCTAssertEqual(object?["needs_tool"] as? Bool, true)
    }

    func testJSONExtractorAcceptsFencedJSONWithTrailingText() {
        let text = """
        ```json
        {"tool":"read_file","needs_tool":true,"reason":"inspect first"}
        ```
        done
        """

        let object = BenchmarkJSONExtractor.object(from: text)

        XCTAssertEqual(object?["tool"] as? String, "read_file")
        XCTAssertEqual(object?["needs_tool"] as? Bool, true)
    }

    func testJSONExtractorFindsValidObjectAfterInvalidBraces() {
        let text = """
        I considered {not valid json}.
        Final: {"answer":"blue","count":3}
        """

        let object = BenchmarkJSONExtractor.object(from: text)

        XCTAssertEqual(object?["answer"] as? String, "blue")
        XCTAssertEqual(object?["count"] as? Int, 3)
    }

    func testAgentProbeScorerValidatesExpectedToolChoice() {
        let output = #"{"tool":"edit_file","needs_tool":true,"reason":"apply the known change"}"#

        let score = BenchmarkAgentProbeScorer.score(output: output, kind: .toolSelectionEdit)

        XCTAssertTrue(score.jsonValid)
        XCTAssertTrue(score.instructionFollowed)
        XCTAssertTrue(score.toolSelectionPassed)
    }

    func testAgentProbeScorerRejectsWrongToolChoice() {
        let output = #"{"tool":"web_search","needs_tool":true,"reason":"look it up"}"#

        let score = BenchmarkAgentProbeScorer.score(output: output, kind: .toolSelectionNone)

        XCTAssertTrue(score.jsonValid)
        XCTAssertFalse(score.instructionFollowed)
        XCTAssertFalse(score.toolSelectionPassed)
    }

    func testScoreCalculatorKeepsStrongLocalRunHigh() {
        let speed = BenchmarkSpeedMetrics(
            readinessLatencyMS: 120,
            ttftMS: 900,
            totalLatencyMS: 6_000,
            outputTokensPerSecond: 28,
            outputTokenCount: 128,
            finishReason: "stop",
            httpStatusCode: 200,
            timedOut: false,
            errorMessage: nil,
            managedMemoryGigabytes: 28,
            availableMemoryGigabytes: 18
        )
        let agent = BenchmarkAgentReadiness(
            totalRuns: 5,
            successfulRuns: 5,
            jsonValidResponses: 5,
            instructionFollowingPasses: 5,
            toolSelectionPasses: 3,
            timeoutCount: 0,
            lengthFinishCount: 0,
            averageTTFTMS: 950,
            averageTotalLatencyMS: 3_000
        )

        let scores = BenchmarkScoreCalculator.scores(speed: speed, agent: agent)

        XCTAssertEqual(scores.first(where: { $0.useCase == .chat })?.score, 10)
        XCTAssertEqual(scores.first(where: { $0.useCase == .agent })?.score, 10)
    }

    func testScoreCalculatorPenalizesAgentInstability() {
        let speed = BenchmarkSpeedMetrics(
            readinessLatencyMS: 120,
            ttftMS: 5_500,
            totalLatencyMS: 22_000,
            outputTokensPerSecond: 7,
            outputTokenCount: 128,
            finishReason: "length",
            httpStatusCode: 200,
            timedOut: false,
            errorMessage: nil,
            managedMemoryGigabytes: 55,
            availableMemoryGigabytes: 3
        )
        let agent = BenchmarkAgentReadiness(
            totalRuns: 5,
            successfulRuns: 3,
            jsonValidResponses: 2,
            instructionFollowingPasses: 1,
            toolSelectionPasses: 1,
            timeoutCount: 1,
            lengthFinishCount: 2,
            averageTTFTMS: 6_500,
            averageTotalLatencyMS: 10_000
        )

        let scores = BenchmarkScoreCalculator.scores(speed: speed, agent: agent)

        XCTAssertLessThanOrEqual(scores.first(where: { $0.useCase == .agent })?.score ?? 10, 2)
        XCTAssertLessThan(scores.first(where: { $0.useCase == .coding })?.score ?? 10, 8)
    }

    func testChatCompletionRequestDisablesThinkingByDefaultPayloadShape() throws {
        let request = BenchmarkChatCompletionRequest(
            model: "local-model",
            messages: [BenchmarkChatMessage(role: "user", content: "ping")],
            stream: true,
            maxTokens: 64,
            temperature: 0,
            chatTemplateKwargs: BenchmarkChatTemplateKwargs(enableThinking: false),
            responseFormat: nil
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let kwargs = try XCTUnwrap(object["chat_template_kwargs"] as? [String: Any])

        XCTAssertEqual(kwargs["enable_thinking"] as? Bool, false)
        XCTAssertEqual(object["max_tokens"] as? Int, 64)
        XCTAssertNil(object["response_format"])
    }

    func testChatCompletionRequestCanRequestJSONObjectResponseFormat() throws {
        let request = BenchmarkChatCompletionRequest(
            model: "local-model",
            messages: [BenchmarkChatMessage(role: "user", content: "ping")],
            stream: true,
            maxTokens: 64,
            temperature: 0,
            chatTemplateKwargs: BenchmarkChatTemplateKwargs(enableThinking: false),
            responseFormat: BenchmarkResponseFormat(type: "json_object")
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let responseFormat = try XCTUnwrap(object["response_format"] as? [String: Any])

        XCTAssertEqual(responseFormat["type"] as? String, "json_object")
    }

    func testStreamingRequestCanAskForUsageWithoutChangingDefaultPayload() throws {
        let defaultRequest = BenchmarkChatCompletionRequest(
            model: "local-model",
            messages: [BenchmarkChatMessage(role: "user", content: "ping")],
            stream: true,
            maxTokens: 64,
            temperature: 0,
            chatTemplateKwargs: nil
        )
        let usageRequest = BenchmarkChatCompletionRequest(
            model: "local-model",
            messages: [BenchmarkChatMessage(role: "user", content: "ping")],
            stream: true,
            maxTokens: 64,
            temperature: 0,
            chatTemplateKwargs: nil,
            streamOptions: BenchmarkStreamOptions(includeUsage: true)
        )

        let defaultObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(defaultRequest)) as? [String: Any]
        )
        let usageObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(usageRequest)) as? [String: Any]
        )
        let streamOptions = try XCTUnwrap(usageObject["stream_options"] as? [String: Any])

        XCTAssertNil(defaultObject["stream_options"])
        XCTAssertEqual(streamOptions["include_usage"] as? Bool, true)
    }

    func testReportedCompletionTokenCountOverridesEstimator() {
        XCTAssertEqual(
            BenchmarkTokenCountResolver.outputTokenCount(reported: 42, output: "short"),
            42
        )
        XCTAssertGreaterThan(
            BenchmarkTokenCountResolver.outputTokenCount(reported: nil, output: "日本語の応答です。"),
            0
        )
    }

    func testOpenAICompatibleRetryPolicyOnlyRetriesMatchingUnsupportedFields() {
        XCTAssertTrue(
            OpenAICompatibleChatSupport.shouldRetryWithoutStreamOptions(
                statusCode: 422,
                message: "stream_options is not permitted"
            )
        )
        XCTAssertFalse(
            OpenAICompatibleChatSupport.shouldRetryWithoutThinkingControl(
                statusCode: 422,
                message: "model not found"
            )
        )
    }

    func testAgentProbePromptsUseExactJSONShape() {
        for kind in BenchmarkAgentProbeKind.allCases {
            XCTAssertTrue(kind.prompt.contains("Output only this exact JSON:"))
            XCTAssertTrue(kind.prompt.contains(kind.expectedJSON))
            XCTAssertTrue(kind.noThinkingRetryPrompt.contains("/no_think"))
            XCTAssertTrue(kind.noThinkingRetryPrompt.contains(kind.expectedJSON))
        }
    }

    func testStreamingChunkDecodesReasoningContentAndUsage() throws {
        let data = #"{"choices":[{"delta":{"reasoning_content":"thinking"},"finish_reason":null}],"usage":{"completion_tokens":17}}"#
            .data(using: .utf8)!

        let chunk = try JSONDecoder().decode(BenchmarkStreamingChatChunk.self, from: data)

        XCTAssertEqual(chunk.choices?.first?.delta?.reasoningContent, "thinking")
        XCTAssertEqual(chunk.usage?.completionTokens, 17)
    }

    func testCompletionDiagnosticsExplainsReasoningOnlyLengthFinish() {
        let message = BenchmarkCompletionDiagnostics.errorMessage(
            output: "",
            reasoning: "Thinking through the task.",
            finishReason: "length"
        )

        XCTAssertEqual(message, "Model produced reasoning but reached the token limit before final content.")
    }

    func testScoreCalculatorProducesLowUseCaseScoresForReasoningOnlyBenchmark() {
        let speed = BenchmarkSpeedMetrics(
            readinessLatencyMS: 120,
            ttftMS: nil,
            totalLatencyMS: 4_000,
            outputTokensPerSecond: nil,
            outputTokenCount: 0,
            finishReason: "length",
            httpStatusCode: 200,
            timedOut: false,
            errorMessage: "Model produced reasoning but reached the token limit before final content.",
            managedMemoryGigabytes: 19,
            availableMemoryGigabytes: 10
        )

        let scores = BenchmarkScoreCalculator.scores(speed: speed, agent: nil)

        XCTAssertEqual(scores.count, 3)
        XCTAssertEqual(scores.map(\.score), [1, 1, 1])
        XCTAssertEqual(scores.first?.reasons.first, "Model used the token budget on reasoning before final content.")
    }

    func testScoreCalculatorProducesLowUseCaseScoresForReasoningOnlyStopBenchmark() {
        let speed = BenchmarkSpeedMetrics(
            readinessLatencyMS: 120,
            ttftMS: nil,
            totalLatencyMS: 4_000,
            outputTokensPerSecond: nil,
            outputTokenCount: 0,
            finishReason: "stop",
            httpStatusCode: 200,
            timedOut: false,
            errorMessage: "Model produced reasoning-only output before final content.",
            managedMemoryGigabytes: 19,
            availableMemoryGigabytes: 10
        )

        let scores = BenchmarkScoreCalculator.scores(speed: speed, agent: nil)

        XCTAssertEqual(scores.count, 3)
        XCTAssertEqual(scores.map(\.score), [1, 1, 1])
        XCTAssertEqual(scores.first?.reasons.first, "Model returned reasoning without final content.")
    }

    func testTokenEstimatorHandlesJapaneseText() {
        let count = BenchmarkTokenEstimator.estimatedTokenCount("ローカルモデルは正常に応答しています。")

        XCTAssertGreaterThan(count, 1)
    }

    func testAgenticDetailedTextIncludesDiagnosticsForFailedTasksOnly() {
        let failedTask = AgenticBenchmarkTaskResult(
            id: "virtual_lookup",
            axis: "grounding",
            title: "Virtual File Lookup",
            passed: false,
            score: 0,
            checks: [AgenticBenchmarkCheck(title: "valid_json", passed: false)],
            notes: "failed: valid_json",
            turns: 1,
            toolCalls: 0,
            errorsSeen: 1,
            stopReason: "length",
            rawResponse: "raw model text",
            reasoningResponse: "internal reasoning text",
            errorMessage: "diagnostic error"
        )
        let passedTask = AgenticBenchmarkTaskResult(
            id: "missing_file",
            axis: "robustness",
            title: "Missing File Honesty",
            passed: true,
            score: 1,
            checks: [AgenticBenchmarkCheck(title: "valid_json", passed: true)],
            notes: "ok",
            turns: 1,
            toolCalls: 1,
            errorsSeen: 0,
            stopReason: "stop",
            rawResponse: "passed raw text",
            reasoningResponse: "passed reasoning text",
            errorMessage: nil
        )
        let result = AgenticBenchmarkResult(
            profileID: "profile",
            modelID: "model",
            baseURL: "http://127.0.0.1:8000/v1",
            selectedProfileName: "Local",
            phase: .failed,
            message: "failed",
            tasks: [failedTask, passedTask]
        )

        let text = result.detailedText

        XCTAssertTrue(text.contains("raw response:\n    raw model text"))
        XCTAssertTrue(text.contains("reasoning:\n    internal reasoning text"))
        XCTAssertTrue(text.contains("error:\n    diagnostic error"))
        XCTAssertFalse(text.contains("passed raw text"))
        XCTAssertFalse(text.contains("passed reasoning text"))
    }

    func testAgenticDetailedTextTruncatesLongDiagnostics() {
        let task = AgenticBenchmarkTaskResult(
            id: "path_planning",
            axis: "planning",
            title: "Path Planning",
            passed: false,
            score: 0,
            checks: [AgenticBenchmarkCheck(title: "valid_json", passed: false)],
            notes: "failed: valid_json",
            turns: 1,
            toolCalls: 0,
            errorsSeen: 0,
            stopReason: "response",
            rawResponse: String(repeating: "x", count: 1_240),
            reasoningResponse: "",
            errorMessage: nil
        )
        let result = AgenticBenchmarkResult(
            profileID: "profile",
            modelID: "model",
            baseURL: "http://127.0.0.1:8000/v1",
            selectedProfileName: "Local",
            phase: .failed,
            message: "failed",
            tasks: [task]
        )

        XCTAssertTrue(result.detailedText.contains("[truncated"))
    }

    func testAgenticTaskDiagnosticsSummarizeReasoningOnlyFailure() {
        let task = AgenticBenchmarkTaskResult(
            id: "path_planning",
            axis: "planning",
            title: "Path Planning",
            passed: false,
            score: 0,
            checks: [AgenticBenchmarkCheck(title: "valid_json", passed: false)],
            notes: "failed: valid_json",
            turns: 1,
            toolCalls: 0,
            errorsSeen: 1,
            stopReason: "length",
            rawResponse: "",
            reasoningResponse: "thinking without final JSON",
            errorMessage: nil
        )

        XCTAssertEqual(task.failedCheckTitles, ["valid_json"])
        XCTAssertEqual(task.diagnostics.first?.title, "Hint")
        XCTAssertEqual(task.diagnostics.first?.text, "Model returned reasoning without final JSON content.")
        XCTAssertTrue(task.diagnostics.contains { $0.title == "Reasoning" })
    }

    func testAgenticTaskDiagnosticsAreHiddenForPassedTasks() {
        let task = AgenticBenchmarkTaskResult(
            id: "missing_file",
            axis: "robustness",
            title: "Missing File Honesty",
            passed: true,
            score: 1,
            checks: [AgenticBenchmarkCheck(title: "valid_json", passed: true)],
            notes: "ok",
            turns: 1,
            toolCalls: 1,
            errorsSeen: 0,
            stopReason: "stop",
            rawResponse: "raw text",
            reasoningResponse: "reasoning text",
            errorMessage: nil
        )

        XCTAssertNil(task.diagnosticHint)
        XCTAssertTrue(task.diagnostics.isEmpty)
    }

    func testBenchmarkResultsSnapshotRoundTripsModelResults() throws {
        let benchmark = BenchmarkResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            timestamp: Date(timeIntervalSinceReferenceDate: 1_000),
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            phase: .success,
            readinessLatencyMS: 120,
            selectedProfileName: "Model A",
            message: "ok",
            useCaseScores: [
                BenchmarkUseCaseScore(useCase: .chat, score: 10, reasons: ["responsive"])
            ]
        )
        let readiness = AgenticBenchmarkResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            timestamp: Date(timeIntervalSinceReferenceDate: 2_000),
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            selectedProfileName: "Model A",
            phase: .success,
            message: "ok",
            tasks: [
                AgenticBenchmarkTaskResult(
                    id: "virtual_file_lookup",
                    axis: "tool_planning",
                    title: "Virtual File Lookup",
                    passed: true,
                    score: 1,
                    checks: [AgenticBenchmarkCheck(title: "valid_json", passed: true)],
                    notes: "ok",
                    turns: 1,
                    toolCalls: 3,
                    errorsSeen: 0,
                    stopReason: "stop",
                    rawResponse: #"{"actions":[],"final":"ok"}"#,
                    reasoningResponse: "",
                    errorMessage: nil
                )
            ]
        )
        let snapshot = BenchmarkResultsSnapshot(
            benchmarkResultsByProfileID: ["model-a": benchmark],
            agenticBenchmarkResultsByProfileID: ["model-a": readiness]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BenchmarkResultsSnapshot.self, from: data)

        XCTAssertEqual(decoded.benchmarkResultsByProfileID["model-a"]?.useCaseScores.first?.score, 10)
        XCTAssertEqual(decoded.agenticBenchmarkResultsByProfileID["model-a"]?.scoreText, "1/1")
    }

    func testBenchmarkUseCaseReasonsLocalizeForJapaneseUI() {
        let score = BenchmarkUseCaseScore(
            useCase: .chat,
            score: 10,
            reasons: ["TTFT is responsive."]
        )
        let result = BenchmarkResult(
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            phase: .success,
            readinessLatencyMS: 120,
            selectedProfileName: "Model A",
            message: "Speed 40.0 tok/s, TTFT 500 ms, Agent JSON 5/5",
            useCaseScores: [score]
        )

        XCTAssertEqual(score.localizedReasons(language: .japanese), ["TTFTは良好です。"])
        XCTAssertTrue(result.localizedSummary(language: .japanese).contains("成功: チャット: 10/10"))
        XCTAssertTrue(result.localizedSummary(language: .japanese).contains("速度 40.0 tok/s、TTFT 500 ms、Agent JSON 5/5"))
        XCTAssertEqual(score.localizedReasons(language: .english), ["TTFT is responsive."])
        XCTAssertEqual(score.localizedReasons(language: .system), score.localizedReasons(language: .system.resolved))
    }

    func testAgenticTaskResultLocalizesVisibleJapaneseLabels() {
        let task = AgenticBenchmarkTaskResult(
            id: "virtual_file_lookup",
            axis: "tool_planning",
            title: "Virtual File Lookup",
            passed: false,
            score: 0.5,
            checks: [
                AgenticBenchmarkCheck(title: "valid_json", passed: true),
                AgenticBenchmarkCheck(title: "read_secret", passed: false)
            ],
            notes: "failed: read_secret",
            turns: 1,
            toolCalls: 1,
            errorsSeen: 0,
            stopReason: "stop",
            rawResponse: #"{"actions":[],"final":""}"#,
            reasoningResponse: "",
            errorMessage: nil
        )
        let result = AgenticBenchmarkResult(
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            selectedProfileName: "Model A",
            phase: .failed,
            message: "Virtual readiness tasks passed 4/5.",
            tasks: [task]
        )

        XCTAssertEqual(task.localizedTitle(language: .japanese), "仮想ファイル参照")
        XCTAssertEqual(task.localizedScoreText(language: .japanese), "不合格")
        XCTAssertEqual(task.localizedNotes(language: .japanese), "失敗: 秘密ファイル参照")
        XCTAssertEqual(task.localizedTitle(language: .system), task.localizedTitle(language: .system.resolved))
        XCTAssertEqual(task.localizedScoreText(language: .system), task.localizedScoreText(language: .system.resolved))
        XCTAssertEqual(task.localizedNotes(language: .system), task.localizedNotes(language: .system.resolved))
        XCTAssertTrue(result.localizedSummary(language: .japanese).contains("成功") == false)
        XCTAssertTrue(result.localizedSummary(language: .japanese).contains("仮想Readinessタスク: 4/5 合格。"))
    }

    func testMLXLMVersionProviderNormalizesFirstNonEmptyLine() {
        let output = "\n\nmlx-lm 0.31.3\nextra detail\n"

        XCTAssertEqual(MLXLMVersionProvider.normalizedVersionOutput(output), "mlx-lm 0.31.3")
    }

    func testMLXLMVersionProviderRejectsUsageText() {
        let output = "usage: mlx_lm.server [-h] [--model MODEL] [--adapter-path ADAPTER_PATH]"

        XCTAssertNil(MLXLMVersionProvider.normalizedVersionOutput(output))
    }
}
