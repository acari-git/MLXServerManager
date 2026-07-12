import Foundation

struct BenchmarkRunConfiguration: Equatable {
    let host: String
    let port: Int
    let baseURL: String
    let profileID: String
    let modelID: String
    let selectedProfileName: String
    let runningProfileID: String?
    let managedProcessID: Int32?
    let chipName: String
    let memoryText: String
    let mlxServerExecutablePath: String
}

struct BenchmarkService {
    private let readyChecker: ReadyChecker
    private let memoryMonitor: MemoryMonitor
    private let mlxLMVersionProvider: MLXLMVersionProvider
    private let session: URLSession

    init(
        readyChecker: ReadyChecker = ReadyChecker(timeout: 5),
        memoryMonitor: MemoryMonitor = MemoryMonitor(),
        mlxLMVersionProvider: MLXLMVersionProvider = MLXLMVersionProvider(),
        session: URLSession = .shared
    ) {
        self.readyChecker = readyChecker
        self.memoryMonitor = memoryMonitor
        self.mlxLMVersionProvider = mlxLMVersionProvider
        self.session = session
    }

    func run(configuration: BenchmarkRunConfiguration) async -> BenchmarkResult {
        let mlxLMVersion = await mlxLMVersionProvider.version(executablePath: configuration.mlxServerExecutablePath)
        let hostSnapshot = BenchmarkHostSnapshot(
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            chipName: configuration.chipName,
            memoryText: configuration.memoryText,
            mlxLMVersion: mlxLMVersion ?? "Unavailable"
        )

        let readyStartedAt = Date()
        let readyResult = await readyChecker.check(
            host: configuration.host,
            port: configuration.port,
            expectedModelID: configuration.modelID
        )
        let readinessLatencyMS = Date().timeIntervalSince(readyStartedAt) * 1000

        guard case let .ready(_, statusCode) = readyResult else {
            let message = readyFailureMessage(from: readyResult)
            let metrics = BenchmarkSpeedMetrics(
                readinessLatencyMS: readinessLatencyMS,
                ttftMS: nil,
                totalLatencyMS: nil,
                outputTokensPerSecond: nil,
                outputTokenCount: 0,
                finishReason: nil,
                httpStatusCode: readyStatusCode(from: readyResult),
                timedOut: isTimeout(readyResult),
                errorMessage: message,
                managedMemoryGigabytes: nil,
                availableMemoryGigabytes: memoryMonitor.currentSystemSnapshot().availableGigabytes
            )
            let scores = BenchmarkScoreCalculator.scores(speed: metrics, agent: nil)
            return BenchmarkResult(
                profileID: configuration.profileID,
                modelID: configuration.modelID,
                baseURL: configuration.baseURL,
                phase: .failed,
                readinessLatencyMS: readinessLatencyMS,
                statusCode: readyStatusCode(from: readyResult),
                selectedProfileName: configuration.selectedProfileName,
                runningProfileID: configuration.runningProfileID,
                message: message,
                hostSnapshot: hostSnapshot,
                speedMetrics: metrics,
                agentReadiness: nil,
                useCaseScores: scores
            )
        }

        var speedMeasurement = await measuredChatCompletion(
            baseURL: configuration.baseURL,
            modelID: configuration.modelID,
            prompt: Self.speedProbePrompt,
            maxTokens: 96,
            timeout: 90
        )
        if speedMeasurement.isReasoningOnly {
            let fallbackMeasurement = await measuredChatCompletion(
                baseURL: configuration.baseURL,
                modelID: configuration.modelID,
                prompt: Self.speedProbeFallbackPrompt,
                maxTokens: 64,
                timeout: 90
            )
            if fallbackMeasurement.hasContent {
                speedMeasurement = fallbackMeasurement
            }
        }

        let memory = await memorySnapshot(processIdentifier: configuration.managedProcessID)
        let systemMemory = memoryMonitor.currentSystemSnapshot()
        let speedMetrics = makeSpeedMetrics(
            readinessLatencyMS: readinessLatencyMS,
            statusCode: statusCode,
            measurement: speedMeasurement,
            managedMemoryGigabytes: memory,
            availableMemoryGigabytes: systemMemory.availableGigabytes
        )

        if speedMeasurement.isReasoningOnly {
            let message = reasoningOnlyBenchmarkMessage(finishReason: speedMeasurement.finishReason)
            let scores = BenchmarkScoreCalculator.scores(speed: speedMetrics, agent: nil)
            return BenchmarkResult(
                profileID: configuration.profileID,
                modelID: configuration.modelID,
                baseURL: configuration.baseURL,
                phase: .failed,
                readinessLatencyMS: readinessLatencyMS,
                statusCode: speedMetrics.httpStatusCode,
                selectedProfileName: configuration.selectedProfileName,
                runningProfileID: configuration.runningProfileID,
                message: message,
                hostSnapshot: resolvedHostSnapshot(
                    base: hostSnapshot,
                    mlxLMVersion: mlxLMVersion,
                    systemFingerprint: speedMeasurement.systemFingerprint
                ),
                speedMetrics: speedMetrics,
                agentReadiness: nil,
                useCaseScores: scores
            )
        }

        let agentMeasurements = await runAgentReadiness(baseURL: configuration.baseURL, modelID: configuration.modelID)
        let agentReadiness = makeAgentReadiness(from: agentMeasurements)
        let scores = BenchmarkScoreCalculator.scores(speed: speedMetrics, agent: agentReadiness)
        let phase: BenchmarkPhase = speedMetrics.errorMessage == nil && !speedMetrics.timedOut ? .success : .failed
        let message = resultMessage(speedMetrics: speedMetrics, agentReadiness: agentReadiness)
        let resolvedHostSnapshot = resolvedHostSnapshot(
            base: hostSnapshot,
            mlxLMVersion: mlxLMVersion,
            systemFingerprint: speedMeasurement.systemFingerprint
        )

        return BenchmarkResult(
            profileID: configuration.profileID,
            modelID: configuration.modelID,
            baseURL: configuration.baseURL,
            phase: phase,
            readinessLatencyMS: readinessLatencyMS,
            statusCode: speedMetrics.httpStatusCode,
            selectedProfileName: configuration.selectedProfileName,
            runningProfileID: configuration.runningProfileID,
            message: message,
            hostSnapshot: resolvedHostSnapshot,
            speedMetrics: speedMetrics,
            agentReadiness: agentReadiness,
            useCaseScores: scores
        )
    }

    private func runAgentReadiness(baseURL: String, modelID: String) async -> [(BenchmarkAgentProbeKind, BenchmarkCompletionMeasurement)] {
        var measurements: [(BenchmarkAgentProbeKind, BenchmarkCompletionMeasurement)] = []
        for kind in BenchmarkAgentProbeKind.allCases {
            if Task.isCancelled {
                break
            }
            var measurement = await measuredChatCompletion(
                baseURL: baseURL,
                modelID: modelID,
                prompt: kind.prompt,
                maxTokens: 256,
                timeout: 90,
                requiresJSON: true
            )
            if shouldRetryAgentProbe(measurement, kind: kind) {
                let retryMeasurement = await measuredChatCompletion(
                    baseURL: baseURL,
                    modelID: modelID,
                    prompt: kind.noThinkingRetryPrompt,
                    maxTokens: 128,
                    timeout: 90,
                    requiresJSON: true
                )
                if agentProbeQuality(retryMeasurement, kind: kind) > agentProbeQuality(measurement, kind: kind) {
                    measurement = retryMeasurement
                }
            }
            measurements.append((kind, measurement))
        }
        return measurements
    }

    private func shouldRetryAgentProbe(_ measurement: BenchmarkCompletionMeasurement, kind: BenchmarkAgentProbeKind) -> Bool {
        let score = BenchmarkAgentProbeScorer.score(output: measurement.outputText, kind: kind)
        return !score.instructionFollowed
    }

    private func agentProbeQuality(_ measurement: BenchmarkCompletionMeasurement, kind: BenchmarkAgentProbeKind) -> Int {
        let score = BenchmarkAgentProbeScorer.score(output: measurement.outputText, kind: kind)
        var quality = 0
        if measurement.errorMessage == nil, !measurement.timedOut {
            quality += 1
        }
        if measurement.hasContent {
            quality += 1
        }
        if score.jsonValid {
            quality += 2
        }
        if score.instructionFollowed {
            quality += 3
        }
        if score.toolSelectionPassed {
            quality += 1
        }
        if measurement.finishReason == "length" {
            quality -= 1
        }
        return quality
    }

    private func makeAgentReadiness(
        from measurements: [(BenchmarkAgentProbeKind, BenchmarkCompletionMeasurement)]
    ) -> BenchmarkAgentReadiness {
        var jsonValidResponses = 0
        var instructionPasses = 0
        var toolPasses = 0
        var timeoutCount = 0
        var lengthFinishCount = 0
        var successfulRuns = 0
        var ttftValues: [Double] = []
        var totalLatencyValues: [Double] = []

        for (kind, measurement) in measurements {
            if measurement.timedOut {
                timeoutCount += 1
            }
            if measurement.finishReason == "length" {
                lengthFinishCount += 1
            }
            if measurement.errorMessage == nil, !measurement.timedOut {
                successfulRuns += 1
            }
            if let ttftMS = measurement.ttftMS {
                ttftValues.append(ttftMS)
            }
            if let totalLatencyMS = measurement.totalLatencyMS {
                totalLatencyValues.append(totalLatencyMS)
            }

            let probeScore = BenchmarkAgentProbeScorer.score(output: measurement.outputText, kind: kind)
            if probeScore.jsonValid {
                jsonValidResponses += 1
            }
            if probeScore.instructionFollowed {
                instructionPasses += 1
            }
            if probeScore.toolSelectionPassed {
                toolPasses += 1
            }
        }

        return BenchmarkAgentReadiness(
            totalRuns: measurements.count,
            successfulRuns: successfulRuns,
            jsonValidResponses: jsonValidResponses,
            instructionFollowingPasses: instructionPasses,
            toolSelectionPasses: toolPasses,
            toolSelectionProbeCount: measurements.filter { $0.0.expectedTool != nil }.count,
            timeoutCount: timeoutCount,
            lengthFinishCount: lengthFinishCount,
            averageTTFTMS: average(ttftValues),
            averageTotalLatencyMS: average(totalLatencyValues)
        )
    }

    private func makeSpeedMetrics(
        readinessLatencyMS: Double,
        statusCode: Int,
        measurement: BenchmarkCompletionMeasurement,
        managedMemoryGigabytes: Double?,
        availableMemoryGigabytes: Double?
    ) -> BenchmarkSpeedMetrics {
        BenchmarkSpeedMetrics(
            readinessLatencyMS: readinessLatencyMS,
            ttftMS: measurement.ttftMS,
            totalLatencyMS: measurement.totalLatencyMS,
            outputTokensPerSecond: measurement.outputTokensPerSecond,
            outputTokenCount: measurement.outputTokenCount,
            finishReason: measurement.finishReason,
            httpStatusCode: measurement.httpStatusCode ?? statusCode,
            timedOut: measurement.timedOut,
            errorMessage: measurement.errorMessage,
            managedMemoryGigabytes: managedMemoryGigabytes,
            availableMemoryGigabytes: availableMemoryGigabytes
        )
    }

    private func measuredChatCompletion(
        baseURL: String,
        modelID: String,
        prompt: String,
        maxTokens: Int,
        timeout: TimeInterval,
        requiresJSON: Bool = false
    ) async -> BenchmarkCompletionMeasurement {
        let responseFormat = requiresJSON ? BenchmarkResponseFormat(type: "json_object") : nil
        let measurement = await performChatCompletion(
            baseURL: baseURL,
            modelID: modelID,
            prompt: prompt,
            maxTokens: maxTokens,
            timeout: timeout,
            disablesThinking: true,
            responseFormat: responseFormat
        )
        if shouldRetryWithoutResponseFormat(measurement), responseFormat != nil {
            let fallbackMeasurement = await performChatCompletion(
                baseURL: baseURL,
                modelID: modelID,
                prompt: prompt,
                maxTokens: maxTokens,
                timeout: timeout,
                disablesThinking: true,
                responseFormat: nil
            )
            guard shouldRetryWithoutThinkingControl(fallbackMeasurement) else {
                return fallbackMeasurement
            }
            return await performChatCompletion(
                baseURL: baseURL,
                modelID: modelID,
                prompt: prompt,
                maxTokens: maxTokens,
                timeout: timeout,
                disablesThinking: false,
                responseFormat: nil
            )
        }
        guard shouldRetryWithoutThinkingControl(measurement) else {
            return measurement
        }
        return await performChatCompletion(
            baseURL: baseURL,
            modelID: modelID,
            prompt: prompt,
            maxTokens: maxTokens,
            timeout: timeout,
            disablesThinking: false,
            responseFormat: responseFormat
        )
    }

    private func performChatCompletion(
        baseURL: String,
        modelID: String,
        prompt: String,
        maxTokens: Int,
        timeout: TimeInterval,
        disablesThinking: Bool,
        responseFormat: BenchmarkResponseFormat?
    ) async -> BenchmarkCompletionMeasurement {
        guard let url = chatCompletionsURL(from: baseURL) else {
            return BenchmarkCompletionMeasurement.invalid(message: "Invalid /chat/completions URL.")
        }

        let startedAt = Date()
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload = BenchmarkChatCompletionRequest(
                model: modelID,
                messages: [
                    BenchmarkChatMessage(role: "user", content: prompt)
                ],
                stream: true,
                maxTokens: maxTokens,
                temperature: 0,
                chatTemplateKwargs: disablesThinking ? BenchmarkChatTemplateKwargs(enableThinking: false) : nil,
                responseFormat: responseFormat
            )
            request.httpBody = try JSONEncoder().encode(payload)

            let (bytes, response) = try await session.bytes(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            guard let statusCode, (200..<300).contains(statusCode) else {
                return BenchmarkCompletionMeasurement(
                    httpStatusCode: statusCode,
                    ttftMS: nil,
                    totalLatencyMS: Date().timeIntervalSince(startedAt) * 1000,
                    outputText: "",
                    reasoningText: "",
                    outputTokenCount: 0,
                    outputTokensPerSecond: nil,
                    finishReason: nil,
                    systemFingerprint: nil,
                    timedOut: false,
                    errorMessage: "HTTP \(statusCode.map(String.init) ?? "-") from /chat/completions"
                )
            }

            var firstContentAt: Date?
            var output = ""
            var reasoningOutput = ""
            var finishReason: String?
            var systemFingerprint: String?

            for try await rawLine in bytes.lines {
                if Task.isCancelled {
                    throw CancellationError()
                }

                guard rawLine.hasPrefix("data:") else {
                    continue
                }

                let payloadText = rawLine
                    .dropFirst("data:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if payloadText == "[DONE]" {
                    break
                }
                guard let payloadData = payloadText.data(using: .utf8),
                      let chunk = try? JSONDecoder().decode(BenchmarkStreamingChatChunk.self, from: payloadData) else {
                    continue
                }

                if let fingerprint = chunk.systemFingerprint, !fingerprint.isEmpty {
                    systemFingerprint = fingerprint
                }

                if let errorMessage = chunk.error?.message, !errorMessage.isEmpty {
                    return BenchmarkCompletionMeasurement(
                        httpStatusCode: statusCode,
                        ttftMS: firstContentAt.map { $0.timeIntervalSince(startedAt) * 1000 },
                        totalLatencyMS: Date().timeIntervalSince(startedAt) * 1000,
                        outputText: output,
                        reasoningText: reasoningOutput,
                        outputTokenCount: BenchmarkTokenEstimator.estimatedTokenCount(output),
                        outputTokensPerSecond: nil,
                        finishReason: finishReason,
                        systemFingerprint: systemFingerprint,
                        timedOut: false,
                        errorMessage: errorMessage
                    )
                }

                for choice in chunk.choices ?? [] {
                    if let reason = choice.finishReason, !reason.isEmpty {
                        finishReason = reason
                    }
                    let reasoning = [choice.delta?.reasoning, choice.delta?.reasoningContent]
                        .compactMap { $0 }
                        .joined()
                    if !reasoning.isEmpty {
                        reasoningOutput += reasoning
                    }
                    if let content = choice.delta?.content, !content.isEmpty {
                        if firstContentAt == nil {
                            firstContentAt = Date()
                        }
                        output += content
                    }
                }
            }

            let totalLatencyMS = Date().timeIntervalSince(startedAt) * 1000
            let outputTokenCount = BenchmarkTokenEstimator.estimatedTokenCount(output)
            let generationSeconds: Double
            if let firstContentAt {
                generationSeconds = max(Date().timeIntervalSince(firstContentAt), 0.001)
            } else {
                generationSeconds = max(totalLatencyMS / 1000, 0.001)
            }
            let tokensPerSecond = outputTokenCount > 0 && firstContentAt != nil
                ? Double(outputTokenCount) / generationSeconds
                : nil

            return BenchmarkCompletionMeasurement(
                httpStatusCode: statusCode,
                ttftMS: firstContentAt.map { $0.timeIntervalSince(startedAt) * 1000 },
                totalLatencyMS: totalLatencyMS,
                outputText: output,
                reasoningText: reasoningOutput,
                outputTokenCount: outputTokenCount,
                outputTokensPerSecond: tokensPerSecond,
                finishReason: finishReason,
                systemFingerprint: systemFingerprint,
                timedOut: false,
                errorMessage: BenchmarkCompletionDiagnostics.errorMessage(
                    output: output,
                    reasoning: reasoningOutput,
                    finishReason: finishReason
                )
            )
        } catch is CancellationError {
            return BenchmarkCompletionMeasurement.cancelled()
        } catch {
            let isTimedOut = (error as? URLError)?.code == .timedOut
            return BenchmarkCompletionMeasurement(
                httpStatusCode: nil,
                ttftMS: nil,
                totalLatencyMS: Date().timeIntervalSince(startedAt) * 1000,
                outputText: "",
                reasoningText: "",
                outputTokenCount: 0,
                outputTokensPerSecond: nil,
                finishReason: nil,
                systemFingerprint: nil,
                timedOut: isTimedOut,
                errorMessage: isTimedOut ? "Request timed out" : error.localizedDescription
            )
        }
    }

    private func shouldRetryWithoutThinkingControl(_ measurement: BenchmarkCompletionMeasurement) -> Bool {
        if measurement.httpStatusCode == 400 || measurement.httpStatusCode == 422 {
            return true
        }
        let message = measurement.errorMessage?.lowercased() ?? ""
        return message.contains("chat_template_kwargs")
            || message.contains("chat template kwargs")
            || message.contains("enable_thinking")
            || message.contains("extra_forbidden")
    }

    private func shouldRetryWithoutResponseFormat(_ measurement: BenchmarkCompletionMeasurement) -> Bool {
        guard measurement.httpStatusCode == 400 || measurement.httpStatusCode == 422 else {
            return false
        }
        let message = measurement.errorMessage?.lowercased() ?? ""
        return message.contains("response_format")
            || message.contains("response format")
    }

    private func memorySnapshot(processIdentifier: Int32?) async -> Double? {
        guard let processIdentifier else {
            return nil
        }

        switch await memoryMonitor.currentUsage(processIdentifier: processIdentifier) {
        case let .usage(snapshot):
            return snapshot.gigabytes
        default:
            return nil
        }
    }

    private func resultMessage(speedMetrics: BenchmarkSpeedMetrics, agentReadiness: BenchmarkAgentReadiness) -> String {
        if let errorMessage = speedMetrics.errorMessage {
            return errorMessage
        }
        return "Speed \(speedMetrics.outputSpeedText), TTFT \(speedMetrics.ttftText), Agent JSON \(agentReadiness.jsonValidityText)"
    }

    private func reasoningOnlyBenchmarkMessage(finishReason: String?) -> String {
        if finishReason == "length" {
            return "Benchmark assigned a low score because the model used the token budget on reasoning before final content. This endpoint may not support content-only benchmark prompts or chat_template_kwargs thinking control."
        }
        return "Benchmark assigned a low score because the model returned reasoning without final content. This endpoint may not support content-only benchmark prompts or chat_template_kwargs thinking control."
    }

    private func resolvedHostSnapshot(
        base: BenchmarkHostSnapshot,
        mlxLMVersion: String?,
        systemFingerprint: String?
    ) -> BenchmarkHostSnapshot {
        BenchmarkHostSnapshot(
            macOSVersion: base.macOSVersion,
            chipName: base.chipName,
            memoryText: base.memoryText,
            mlxLMVersion: mlxLMVersion ?? systemFingerprint ?? "Unavailable"
        )
    }

    private func readyFailureMessage(from result: ReadyCheckResult) -> String {
        switch result {
        case let .ready(url, statusCode):
            return "Ready: \(url.absoluteString) HTTP \(statusCode)"
        case let .notReady(_, statusCode):
            return "HTTP \(statusCode) from /v1/models"
        case let .invalidInput(message):
            return message
        case let .failed(_, message):
            return message
        case .timedOut:
            return "Request timed out"
        }
    }

    private func readyStatusCode(from result: ReadyCheckResult) -> Int? {
        switch result {
        case let .ready(_, statusCode), let .notReady(_, statusCode):
            return statusCode
        default:
            return nil
        }
    }

    private func isTimeout(_ result: ReadyCheckResult) -> Bool {
        if case .timedOut = result {
            return true
        }
        return false
    }

    private func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmed)/chat/completions")
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private static let speedProbePrompt = """
    Output exactly the following Japanese text and nothing else:
    ローカルモデルは準備できています。短い診断応答を安定して返しています。推論エンドポイントは接続確認に応答しています。
    """

    private static let speedProbeFallbackPrompt = """
    Output only this exact text:
    ローカルモデルは準備できています。
    """
}

private struct BenchmarkCompletionMeasurement: Equatable {
    let httpStatusCode: Int?
    let ttftMS: Double?
    let totalLatencyMS: Double?
    let outputText: String
    let reasoningText: String
    let outputTokenCount: Int
    let outputTokensPerSecond: Double?
    let finishReason: String?
    let systemFingerprint: String?
    let timedOut: Bool
    let errorMessage: String?

    var isReasoningOnly: Bool {
        outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !reasoningText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasContent: Bool {
        !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func invalid(message: String) -> BenchmarkCompletionMeasurement {
        BenchmarkCompletionMeasurement(
            httpStatusCode: nil,
            ttftMS: nil,
            totalLatencyMS: nil,
            outputText: "",
            reasoningText: "",
            outputTokenCount: 0,
            outputTokensPerSecond: nil,
            finishReason: nil,
            systemFingerprint: nil,
            timedOut: false,
            errorMessage: message
        )
    }

    static func cancelled() -> BenchmarkCompletionMeasurement {
        BenchmarkCompletionMeasurement(
            httpStatusCode: nil,
            ttftMS: nil,
            totalLatencyMS: nil,
            outputText: "",
            reasoningText: "",
            outputTokenCount: 0,
            outputTokensPerSecond: nil,
            finishReason: "cancelled",
            systemFingerprint: nil,
            timedOut: false,
            errorMessage: "Cancelled"
        )
    }
}

struct BenchmarkChatMessage: Encodable {
    let role: String
    let content: String
}

struct BenchmarkChatTemplateKwargs: Encodable {
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case enableThinking = "enable_thinking"
    }
}

struct BenchmarkResponseFormat: Encodable {
    let type: String
}

struct BenchmarkChatCompletionRequest: Encodable {
    let model: String
    let messages: [BenchmarkChatMessage]
    let stream: Bool
    let maxTokens: Int
    let temperature: Double
    let chatTemplateKwargs: BenchmarkChatTemplateKwargs?
    let responseFormat: BenchmarkResponseFormat?

    init(
        model: String,
        messages: [BenchmarkChatMessage],
        stream: Bool,
        maxTokens: Int,
        temperature: Double,
        chatTemplateKwargs: BenchmarkChatTemplateKwargs?,
        responseFormat: BenchmarkResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.chatTemplateKwargs = chatTemplateKwargs
        self.responseFormat = responseFormat
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case chatTemplateKwargs = "chat_template_kwargs"
        case responseFormat = "response_format"
    }
}

struct BenchmarkStreamingChatChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
            let reasoning: String?
            let reasoningContent: String?

            enum CodingKeys: String, CodingKey {
                case content
                case reasoning
                case reasoningContent = "reasoning_content"
            }
        }

        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct ErrorPayload: Decodable {
        let message: String?
    }

    let choices: [Choice]?
    let error: ErrorPayload?
    let systemFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case choices
        case error
        case systemFingerprint = "system_fingerprint"
    }
}

struct BenchmarkCompletionDiagnostics {
    nonisolated static func errorMessage(output: String, reasoning: String, finishReason: String?) -> String? {
        let hasOutput = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !hasOutput else {
            return nil
        }

        let hasReasoning = !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasReasoning && finishReason == "length" {
            return "Model produced reasoning but reached the token limit before final content."
        }
        if hasReasoning {
            return "Model produced reasoning-only output before final content."
        }
        if finishReason == "length" {
            return "Response reached the token limit before content."
        }
        return "Empty response from /chat/completions"
    }
}

struct BenchmarkTokenEstimator {
    nonisolated static func estimatedTokenCount(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }

        let scalarCount = trimmed.unicodeScalars.count
        let whitespaceSeparatedCount = trimmed
            .split { $0.isWhitespace || $0.isNewline }
            .count
        let characterEstimate = max(1, Int((Double(scalarCount) / 3.2).rounded()))
        return max(whitespaceSeparatedCount, characterEstimate)
    }
}
