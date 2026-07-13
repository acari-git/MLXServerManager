import Foundation

enum BenchmarkSuite {
    static let version = "MLXSM Benchmark v1"
}

enum BenchmarkPhase: String, Codable, Equatable {
    case success = "Success"
    case failed = "Failed"
    case cancelled = "Cancelled"

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .success:
            return strings.text(english: "Success", japanese: "成功")
        case .failed:
            return strings.text(english: "Failed", japanese: "失敗")
        case .cancelled:
            return strings.text(english: "Cancelled", japanese: "キャンセル")
        }
    }
}

enum BenchmarkUseCase: String, Codable, CaseIterable, Equatable, Hashable {
    case chat
    case coding
    case agent

    var title: String {
        switch self {
        case .chat:
            "Chat"
        case .coding:
            "Coding"
        case .agent:
            "Agent"
        }
    }

    func localizedTitle(language: AppLanguage) -> String {
        switch self {
        case .chat:
            AppLocalization(language: language).text(english: "Chat", japanese: "チャット")
        case .coding:
            AppLocalization(language: language).text(english: "Coding", japanese: "コーディング")
        case .agent:
            AppLocalization(language: language).text(english: "Agent", japanese: "AIエージェント")
        }
    }
}

enum BenchmarkScoreReasonCode: String, Codable, CaseIterable, Equatable, Hashable {
    case ttftSlowInteractive = "ttft_slow_interactive"
    case ttftDelayed = "ttft_delayed"
    case ttftAcceptable = "ttft_acceptable"
    case ttftResponsive = "ttft_responsive"
    case ttftUnavailable = "ttft_unavailable"
    case chatGenerationTooSlow = "chat_generation_too_slow"
    case generationLimited = "generation_limited"
    case generationUsable = "generation_usable"
    case generationPractical = "generation_practical"
    case generationStrong = "generation_strong"
    case generationUnavailable = "generation_unavailable"
    case responseTokenLimit = "response_token_limit"
    case codeLongResponsesSlow = "code_long_responses_slow"
    case codeGenerationLimited = "code_generation_limited"
    case codeGenerationUsable = "code_generation_usable"
    case codeGenerationPractical = "code_generation_practical"
    case generationTokenLimit = "generation_token_limit"
    case instructionProbesUnstable = "instruction_probes_unstable"
    case instructionProbesMostlyUsable = "instruction_probes_mostly_usable"
    case instructionProbesStable = "instruction_probes_stable"
    case agentProbesUnavailable = "agent_probes_unavailable"
    case jsonUnreliable = "json_unreliable"
    case jsonSometimesBreaks = "json_sometimes_breaks"
    case jsonMostlyStable = "json_mostly_stable"
    case jsonStable = "json_stable"
    case agentInstructionWeak = "agent_instruction_weak"
    case agentInstructionCaution = "agent_instruction_caution"
    case agentInstructionPractical = "agent_instruction_practical"
    case toolSelectionUnreliable = "tool_selection_unreliable"
    case toolSelectionMostlyUsable = "tool_selection_mostly_usable"
    case toolSelectionStable = "tool_selection_stable"
    case probeTimeouts = "probe_timeouts"
    case probeTokenLength = "probe_token_length"
    case repeatedLatencyHigh = "repeated_latency_high"
    case repeatedLatencyAcceptable = "repeated_latency_acceptable"
    case memoryTight = "memory_tight"
    case memoryLimited = "memory_limited"
    case speedNotRun = "speed_not_run"
    case speedTimedOut = "speed_timed_out"
    case reasoningTokenBudget = "reasoning_token_budget"
    case reasoningOnly = "reasoning_only"
    case contentTokenLimit = "content_token_limit"
    case emptyBenchmarkContent = "empty_benchmark_content"
    case speedIncomplete = "speed_incomplete"
    case genericResponsive = "generic_responsive"

    nonisolated var englishText: String {
        switch self {
        case .ttftSlowInteractive: "TTFT is slow for interactive chat."
        case .ttftDelayed: "TTFT may feel delayed."
        case .ttftAcceptable: "TTFT is acceptable but not instant."
        case .ttftResponsive: "TTFT is responsive."
        case .ttftUnavailable: "TTFT could not be measured."
        case .chatGenerationTooSlow: "Generation speed is too slow for comfortable chat."
        case .generationLimited: "Generation speed is limited."
        case .generationUsable: "Generation speed is usable."
        case .generationPractical: "Generation speed is practical."
        case .generationStrong: "Generation speed is strong."
        case .generationUnavailable: "Generation speed could not be measured."
        case .responseTokenLimit: "The response hit the token limit."
        case .codeLongResponsesSlow: "Long code responses will be very slow."
        case .codeGenerationLimited: "Code generation speed is limited."
        case .codeGenerationUsable: "Code generation speed is usable."
        case .codeGenerationPractical: "Code generation speed is practical."
        case .generationTokenLimit: "The model hit the token limit during generation."
        case .instructionProbesUnstable: "Instruction-following probes were unstable."
        case .instructionProbesMostlyUsable: "Instruction-following probes were mostly usable."
        case .instructionProbesStable: "Instruction-following probes were stable."
        case .agentProbesUnavailable: "Agent readiness probes were not available."
        case .jsonUnreliable: "JSON output is unreliable."
        case .jsonSometimesBreaks: "JSON output sometimes breaks."
        case .jsonMostlyStable: "JSON output is mostly stable."
        case .jsonStable: "JSON output was stable."
        case .agentInstructionWeak: "Instruction following is weak for agent loops."
        case .agentInstructionCaution: "Instruction following needs caution."
        case .agentInstructionPractical: "Instruction following is practical."
        case .toolSelectionUnreliable: "Tool-selection probes were unreliable."
        case .toolSelectionMostlyUsable: "Tool-selection probes were mostly usable."
        case .toolSelectionStable: "Tool-selection probes were stable."
        case .probeTimeouts: "Timeouts occurred during repeated probes."
        case .probeTokenLength: "Some probes stopped because of token length."
        case .repeatedLatencyHigh: "Repeated short-task latency is high."
        case .repeatedLatencyAcceptable: "Repeated short-task latency is acceptable."
        case .memoryTight: "Memory headroom is tight on this Mac."
        case .memoryLimited: "Memory headroom is limited."
        case .speedNotRun: "Speed test did not run."
        case .speedTimedOut: "Endpoint timed out during the speed test."
        case .reasoningTokenBudget: "Model used the token budget on reasoning before final content."
        case .reasoningOnly: "Model returned reasoning without final content."
        case .contentTokenLimit: "Response reached the token limit before content."
        case .emptyBenchmarkContent: "Endpoint returned no benchmark content."
        case .speedIncomplete: "Endpoint did not complete the speed test."
        case .genericResponsive: "responsive"
        }
    }

    nonisolated var japaneseText: String {
        switch self {
        case .ttftSlowInteractive: "対話用途ではTTFTが遅めです。"
        case .ttftDelayed: "TTFTに待ち時間を感じる可能性があります。"
        case .ttftAcceptable: "TTFTは許容範囲ですが、即応ではありません。"
        case .ttftResponsive: "TTFTは良好です。"
        case .ttftUnavailable: "TTFTを測定できませんでした。"
        case .chatGenerationTooSlow: "快適なチャットには生成速度が遅すぎます。"
        case .generationLimited: "生成速度は限定的です。"
        case .generationUsable: "生成速度は実用可能です。"
        case .generationPractical: "生成速度は実用的です。"
        case .generationStrong: "生成速度は良好です。"
        case .generationUnavailable: "生成速度を測定できませんでした。"
        case .responseTokenLimit: "応答がトークン上限に達しました。"
        case .codeLongResponsesSlow: "長いコード応答はかなり遅くなります。"
        case .codeGenerationLimited: "コード生成速度は限定的です。"
        case .codeGenerationUsable: "コード生成速度は実用可能です。"
        case .codeGenerationPractical: "コード生成速度は実用的です。"
        case .generationTokenLimit: "生成中にモデルがトークン上限に達しました。"
        case .instructionProbesUnstable: "指示追従テストは不安定でした。"
        case .instructionProbesMostlyUsable: "指示追従テストはおおむね実用可能です。"
        case .instructionProbesStable: "指示追従テストは安定しています。"
        case .agentProbesUnavailable: "Agent Readinessテストを利用できませんでした。"
        case .jsonUnreliable: "JSON出力は不安定です。"
        case .jsonSometimesBreaks: "JSON出力が崩れることがあります。"
        case .jsonMostlyStable: "JSON出力はおおむね安定しています。"
        case .jsonStable: "JSON出力は安定しています。"
        case .agentInstructionWeak: "エージェント処理では指示追従が弱めです。"
        case .agentInstructionCaution: "指示追従には注意が必要です。"
        case .agentInstructionPractical: "指示追従は実用的です。"
        case .toolSelectionUnreliable: "ツール選択テストは不安定です。"
        case .toolSelectionMostlyUsable: "ツール選択テストはおおむね実用可能です。"
        case .toolSelectionStable: "ツール選択テストは安定しています。"
        case .probeTimeouts: "繰り返しテスト中にタイムアウトが発生しました。"
        case .probeTokenLength: "一部のテストがトークン長により停止しました。"
        case .repeatedLatencyHigh: "短いタスクの繰り返しで遅延が大きめです。"
        case .repeatedLatencyAcceptable: "短いタスクの繰り返し遅延は許容範囲です。"
        case .memoryTight: "このMacではメモリ余裕がかなり少ないです。"
        case .memoryLimited: "メモリ余裕は限定的です。"
        case .speedNotRun: "速度テストは実行されませんでした。"
        case .speedTimedOut: "速度テスト中にエンドポイントがタイムアウトしました。"
        case .reasoningTokenBudget: "モデルが最終回答の前に推論でトークン予算を使い切りました。"
        case .reasoningOnly: "モデルは推論のみを返し、最終回答を返しませんでした。"
        case .contentTokenLimit: "本文生成前に応答がトークン上限に達しました。"
        case .emptyBenchmarkContent: "エンドポイントがベンチマーク本文を返しませんでした。"
        case .speedIncomplete: "エンドポイントが速度テストを完了しませんでした。"
        case .genericResponsive: "応答は良好です。"
        }
    }

    nonisolated init?(legacyText: String) {
        guard let match = Self.allCases.first(where: { $0.englishText == legacyText }) else {
            return nil
        }
        self = match
    }
}

struct BenchmarkScoreReason: Codable, Equatable, Hashable {
    let code: BenchmarkScoreReasonCode?
    let legacyText: String?

    nonisolated init(code: BenchmarkScoreReasonCode) {
        self.code = code
        legacyText = nil
    }

    nonisolated init(legacyText: String) {
        code = BenchmarkScoreReasonCode(legacyText: legacyText)
        self.legacyText = code == nil ? legacyText : nil
    }

    var englishText: String {
        code?.englishText ?? legacyText ?? ""
    }

    func localizedText(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return englishText
        }
        return code?.japaneseText ?? englishText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let code = BenchmarkScoreReasonCode(rawValue: value) {
            self.init(code: code)
        } else {
            self.init(legacyText: value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code?.rawValue ?? legacyText ?? "")
    }
}

struct BenchmarkUseCaseScore: Codable, Equatable {
    let useCase: BenchmarkUseCase
    let score: Int
    private let reasonValues: [BenchmarkScoreReason]

    var reasons: [String] {
        reasonValues.map(\.englishText)
    }

    var reasonCodes: [BenchmarkScoreReasonCode] {
        reasonValues.compactMap(\.code)
    }

    nonisolated init(useCase: BenchmarkUseCase, score: Int, reasons: [String]) {
        self.useCase = useCase
        self.score = score
        reasonValues = reasons.map(BenchmarkScoreReason.init(legacyText:))
    }

    nonisolated init(useCase: BenchmarkUseCase, score: Int, reasonCodes: [BenchmarkScoreReasonCode]) {
        self.useCase = useCase
        self.score = score
        reasonValues = reasonCodes.map(BenchmarkScoreReason.init(code:))
    }

    private enum CodingKeys: String, CodingKey {
        case useCase
        case score
        case reasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        useCase = try container.decode(BenchmarkUseCase.self, forKey: .useCase)
        score = try container.decode(Int.self, forKey: .score)
        reasonValues = try container.decodeIfPresent([BenchmarkScoreReason].self, forKey: .reasons) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(useCase, forKey: .useCase)
        try container.encode(score, forKey: .score)
        try container.encode(reasonValues, forKey: .reasons)
    }

    var compactText: String {
        "\(useCase.title): \(score)/10"
    }

    func localizedCompactText(language: AppLanguage) -> String {
        "\(useCase.localizedTitle(language: language)): \(score)/10"
    }

    func localizedReason(_ reason: String, language: AppLanguage) -> String {
        BenchmarkScoreReason(legacyText: reason).localizedText(language: language)
    }

    func localizedReasons(language: AppLanguage) -> [String] {
        reasonValues.map { $0.localizedText(language: language) }
    }
}

struct BenchmarkHostSnapshot: Codable, Equatable {
    let macOSVersion: String
    let chipName: String
    let memoryText: String
    let mlxLMVersion: String
}

struct BenchmarkSpeedMetrics: Codable, Equatable {
    let readinessLatencyMS: Double?
    let ttftMS: Double?
    let totalLatencyMS: Double?
    let outputTokensPerSecond: Double?
    let outputTokenCount: Int
    let finishReason: String?
    let httpStatusCode: Int?
    let timedOut: Bool
    let errorMessage: String?
    let managedMemoryGigabytes: Double?
    let availableMemoryGigabytes: Double?

    var ttftText: String {
        Self.millisecondsText(ttftMS)
    }

    var totalLatencyText: String {
        Self.millisecondsText(totalLatencyMS)
    }

    var outputSpeedText: String {
        guard let outputTokensPerSecond else {
            return "-"
        }
        return String(format: "%.1f tok/s", outputTokensPerSecond)
    }

    var outputTokenText: String {
        outputTokenCount > 0 ? "\(outputTokenCount)" : "-"
    }

    var finishReasonText: String {
        finishReason?.isEmpty == false ? finishReason! : "-"
    }

    func localizedFinishReasonText(language: AppLanguage) -> String {
        guard language.resolved == .japanese, let finishReason, !finishReason.isEmpty else {
            return finishReasonText
        }
        switch finishReason {
        case "stop":
            return "正常終了"
        case "length":
            return "トークン上限"
        case "timeout":
            return "タイムアウト"
        default:
            return finishReason
        }
    }

    var memoryText: String {
        let managed = managedMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? "-"
        let available = availableMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? "-"
        return "managed \(managed), available \(available)"
    }

    func localizedMemoryText(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return memoryText
        }
        let managed = managedMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? "-"
        let available = availableMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? "-"
        return "管理 \(managed)、空き \(available)"
    }

    private static func millisecondsText(_ value: Double?) -> String {
        guard let value else {
            return "-"
        }
        if value >= 1000 {
            return String(format: "%.2f s", value / 1000)
        }
        return "\(Int(value)) ms"
    }
}

struct BenchmarkAgentReadiness: Codable, Equatable {
    let totalRuns: Int
    let successfulRuns: Int
    let jsonValidResponses: Int
    let instructionFollowingPasses: Int
    let toolSelectionPasses: Int
    let toolSelectionProbeCount: Int
    let timeoutCount: Int
    let lengthFinishCount: Int
    let averageTTFTMS: Double?
    let averageTotalLatencyMS: Double?

    init(
        totalRuns: Int,
        successfulRuns: Int,
        jsonValidResponses: Int,
        instructionFollowingPasses: Int,
        toolSelectionPasses: Int,
        toolSelectionProbeCount: Int? = nil,
        timeoutCount: Int,
        lengthFinishCount: Int,
        averageTTFTMS: Double?,
        averageTotalLatencyMS: Double?
    ) {
        self.totalRuns = totalRuns
        self.successfulRuns = successfulRuns
        self.jsonValidResponses = jsonValidResponses
        self.instructionFollowingPasses = instructionFollowingPasses
        self.toolSelectionPasses = toolSelectionPasses
        self.toolSelectionProbeCount = max(toolSelectionProbeCount ?? (totalRuns - 2), 0)
        self.timeoutCount = timeoutCount
        self.lengthFinishCount = lengthFinishCount
        self.averageTTFTMS = averageTTFTMS
        self.averageTotalLatencyMS = averageTotalLatencyMS
    }

    private enum CodingKeys: String, CodingKey {
        case totalRuns
        case successfulRuns
        case jsonValidResponses
        case instructionFollowingPasses
        case toolSelectionPasses
        case toolSelectionProbeCount
        case timeoutCount
        case lengthFinishCount
        case averageTTFTMS
        case averageTotalLatencyMS
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let totalRuns = try container.decode(Int.self, forKey: .totalRuns)
        self.init(
            totalRuns: totalRuns,
            successfulRuns: try container.decode(Int.self, forKey: .successfulRuns),
            jsonValidResponses: try container.decode(Int.self, forKey: .jsonValidResponses),
            instructionFollowingPasses: try container.decode(Int.self, forKey: .instructionFollowingPasses),
            toolSelectionPasses: try container.decode(Int.self, forKey: .toolSelectionPasses),
            toolSelectionProbeCount: try container.decodeIfPresent(Int.self, forKey: .toolSelectionProbeCount),
            timeoutCount: try container.decode(Int.self, forKey: .timeoutCount),
            lengthFinishCount: try container.decode(Int.self, forKey: .lengthFinishCount),
            averageTTFTMS: try container.decodeIfPresent(Double.self, forKey: .averageTTFTMS),
            averageTotalLatencyMS: try container.decodeIfPresent(Double.self, forKey: .averageTotalLatencyMS)
        )
    }

    var jsonValidityText: String {
        "\(jsonValidResponses)/\(totalRuns)"
    }

    var instructionFollowingText: String {
        "\(instructionFollowingPasses)/\(totalRuns)"
    }

    var toolSelectionText: String {
        "\(toolSelectionPasses)/\(toolSelectionProbeCount)"
    }
}

struct BenchmarkResult: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let suiteVersion: String
    let profileID: String
    let modelID: String
    let baseURL: String
    let phase: BenchmarkPhase
    let readinessLatencyMS: Double?
    let httpStatusCode: Int?
    let selectedProfileName: String
    let runningProfileID: String?
    let message: String
    let hostSnapshot: BenchmarkHostSnapshot?
    let speedMetrics: BenchmarkSpeedMetrics?
    let agentReadiness: BenchmarkAgentReadiness?
    let useCaseScores: [BenchmarkUseCaseScore]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        suiteVersion: String = BenchmarkSuite.version,
        profileID: String,
        modelID: String,
        baseURL: String,
        phase: BenchmarkPhase,
        readinessLatencyMS: Double?,
        statusCode: Int? = nil,
        selectedProfileName: String = "Unknown",
        runningProfileID: String? = nil,
        message: String,
        hostSnapshot: BenchmarkHostSnapshot? = nil,
        speedMetrics: BenchmarkSpeedMetrics? = nil,
        agentReadiness: BenchmarkAgentReadiness? = nil,
        useCaseScores: [BenchmarkUseCaseScore] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.suiteVersion = suiteVersion
        self.profileID = profileID
        self.modelID = modelID
        self.baseURL = baseURL
        self.phase = phase
        self.readinessLatencyMS = readinessLatencyMS
        self.httpStatusCode = statusCode
        self.selectedProfileName = selectedProfileName
        self.runningProfileID = runningProfileID
        self.message = message
        self.hostSnapshot = hostSnapshot
        self.speedMetrics = speedMetrics
        self.agentReadiness = agentReadiness
        self.useCaseScores = useCaseScores
    }

    var latencyText: String {
        guard let readinessLatencyMS else {
            return "-"
        }
        return "\(Int(readinessLatencyMS)) ms"
    }

    var httpStatusText: String {
        httpStatusCode.map(String.init) ?? "-"
    }

    var runningProfileText: String {
        runningProfileID ?? "Not running"
    }

    var useCaseScoreSummary: String {
        guard !useCaseScores.isEmpty else {
            return "No use-case scores"
        }
        return useCaseScores.map(\.compactText).joined(separator: ", ")
    }

    func localizedUseCaseScoreSummary(language: AppLanguage) -> String {
        guard !useCaseScores.isEmpty else {
            return AppLocalization(language: language).text(
                english: "No use-case scores",
                japanese: "用途別スコアなし"
            )
        }
        return useCaseScores.map { $0.localizedCompactText(language: language) }.joined(separator: ", ")
    }

    var summary: String {
        "\(phase.rawValue): \(useCaseScoreSummary) — \(selectedProfileName) @ \(baseURL) — \(message)"
    }

    func localizedSummary(language: AppLanguage) -> String {
        "\(phase.localizedTitle(language: language)): \(localizedUseCaseScoreSummary(language: language)) — \(selectedProfileName) @ \(baseURL) — \(localizedMessage(language: language))"
    }

    var detailedText: String {
        var lines = [
            "Benchmark: \(suiteVersion)",
            "Timestamp: \(timestamp)",
            "Model: \(modelID)",
            "Endpoint: \(baseURL)",
            "Selected: \(selectedProfileName)",
            "Running: \(runningProfileText)",
            "Status: \(phase.rawValue)",
            "HTTP: \(httpStatusText)",
            "Message: \(message)"
        ]

        if let hostSnapshot {
            lines += [
                "macOS: \(hostSnapshot.macOSVersion)",
                "Chip: \(hostSnapshot.chipName)",
                "Memory: \(hostSnapshot.memoryText)",
                "mlx-lm: \(hostSnapshot.mlxLMVersion)"
            ]
        }

        if let speedMetrics {
            lines += [
                "Speed TTFT: \(speedMetrics.ttftText)",
                "Speed total latency: \(speedMetrics.totalLatencyText)",
                "Speed output: \(speedMetrics.outputSpeedText)",
                "Output tokens: \(speedMetrics.outputTokenText)",
                "Finish reason: \(speedMetrics.finishReasonText)",
                "Memory: \(speedMetrics.memoryText)"
            ]
        }

        if let agentReadiness {
            lines += [
                "Agent runs: \(agentReadiness.successfulRuns)/\(agentReadiness.totalRuns)",
                "Agent JSON: \(agentReadiness.jsonValidityText)",
                "Agent instruction following: \(agentReadiness.instructionFollowingText)",
                "Agent tool selection: \(agentReadiness.toolSelectionText)",
                "Agent timeouts: \(agentReadiness.timeoutCount)",
                "Agent length finishes: \(agentReadiness.lengthFinishCount)"
            ]
        }

        if useCaseScores.isEmpty {
            lines.append("Use-case scores: Not produced")
        } else {
            lines.append("Use-case scores:")
            for score in useCaseScores {
                lines.append("- \(score.compactText): \(score.reasons.joined(separator: " "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    func localizedDetailedText(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return detailedText
        }

        var lines = [
            "ベンチマーク: \(suiteVersion)",
            "日時: \(timestamp)",
            "モデル: \(modelID)",
            "エンドポイント: \(baseURL)",
            "選択中: \(selectedProfileName)",
            "実行中: \(runningProfileID ?? "未実行")",
            "状態: \(phase.localizedTitle(language: language))",
            "HTTP: \(httpStatusText)",
            "メッセージ: \(localizedMessage(language: language))"
        ]

        if let hostSnapshot {
            lines += [
                "macOS: \(hostSnapshot.macOSVersion)",
                "チップ: \(hostSnapshot.chipName)",
                "メモリ: \(hostSnapshot.memoryText)",
                "mlx-lm: \(hostSnapshot.mlxLMVersion)"
            ]
        }

        if let speedMetrics {
            lines += [
                "速度 TTFT: \(speedMetrics.ttftText)",
                "速度 合計時間: \(speedMetrics.totalLatencyText)",
                "出力速度: \(speedMetrics.outputSpeedText)",
                "出力トークン: \(speedMetrics.outputTokenText)",
                "終了理由: \(speedMetrics.localizedFinishReasonText(language: language))",
                "メモリ: \(speedMetrics.localizedMemoryText(language: language))"
            ]
        }

        if let agentReadiness {
            lines += [
                "Agent実行: \(agentReadiness.successfulRuns)/\(agentReadiness.totalRuns)",
                "Agent JSON: \(agentReadiness.jsonValidityText)",
                "指示追従: \(agentReadiness.instructionFollowingText)",
                "ツール判断: \(agentReadiness.toolSelectionText)",
                "タイムアウト: \(agentReadiness.timeoutCount)",
                "length終了: \(agentReadiness.lengthFinishCount)"
            ]
        }

        if useCaseScores.isEmpty {
            lines.append("用途別スコア: 未算出")
        } else {
            lines.append("用途別スコア:")
            for score in useCaseScores {
                lines.append("- \(score.localizedCompactText(language: language)): \(score.localizedReasons(language: language).joined(separator: " "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func localizedMessage(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return message
        }
        if message.hasPrefix("Speed ") {
            return message
                .replacingOccurrences(of: "Speed ", with: "速度 ")
                .replacingOccurrences(of: ", TTFT ", with: "、TTFT ")
                .replacingOccurrences(of: ", Agent JSON ", with: "、Agent JSON ")
        }
        if message.contains("Benchmark assigned a low score because the model used the token budget on reasoning before final content.") {
            return "モデルが最終回答の前に推論でトークン予算を使い切ったため、ベンチマークは低いスコアを割り当てました。このエンドポイントは本文のみのベンチマークプロンプト、または chat_template_kwargs の推論制御に対応していない可能性があります。"
        }
        return message
    }
}

struct BenchmarkResultsSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var benchmarkResultsByProfileID: [String: BenchmarkResult]
    var agenticBenchmarkResultsByProfileID: [String: AgenticBenchmarkResult]

    init(
        schemaVersion: Int = currentSchemaVersion,
        benchmarkResultsByProfileID: [String: BenchmarkResult],
        agenticBenchmarkResultsByProfileID: [String: AgenticBenchmarkResult]
    ) {
        self.schemaVersion = schemaVersion
        self.benchmarkResultsByProfileID = benchmarkResultsByProfileID
        self.agenticBenchmarkResultsByProfileID = agenticBenchmarkResultsByProfileID
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case benchmarkResultsByProfileID
        case agenticBenchmarkResultsByProfileID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        benchmarkResultsByProfileID = try container.decodeIfPresent(
            [String: BenchmarkResult].self,
            forKey: .benchmarkResultsByProfileID
        ) ?? [:]
        agenticBenchmarkResultsByProfileID = try container.decodeIfPresent(
            [String: AgenticBenchmarkResult].self,
            forKey: .agenticBenchmarkResultsByProfileID
        ) ?? [:]
    }

    static let empty = BenchmarkResultsSnapshot(
        benchmarkResultsByProfileID: [:],
        agenticBenchmarkResultsByProfileID: [:]
    )
}
