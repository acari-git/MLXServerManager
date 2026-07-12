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

struct BenchmarkUseCaseScore: Codable, Equatable {
    let useCase: BenchmarkUseCase
    let score: Int
    let reasons: [String]

    var compactText: String {
        "\(useCase.title): \(score)/10"
    }

    func localizedCompactText(language: AppLanguage) -> String {
        "\(useCase.localizedTitle(language: language)): \(score)/10"
    }

    func localizedReason(_ reason: String, language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return reason
        }
        return Self.japaneseReasons[reason] ?? reason
    }

    func localizedReasons(language: AppLanguage) -> [String] {
        reasons.map { localizedReason($0, language: language) }
    }

    private static let japaneseReasons: [String: String] = [
        "TTFT is slow for interactive chat.": "対話用途ではTTFTが遅めです。",
        "TTFT may feel delayed.": "TTFTに待ち時間を感じる可能性があります。",
        "TTFT is acceptable but not instant.": "TTFTは許容範囲ですが、即応ではありません。",
        "TTFT is responsive.": "TTFTは良好です。",
        "TTFT could not be measured.": "TTFTを測定できませんでした。",
        "Generation speed is too slow for comfortable chat.": "快適なチャットには生成速度が遅すぎます。",
        "Generation speed is limited.": "生成速度は限定的です。",
        "Generation speed is usable.": "生成速度は実用可能です。",
        "Generation speed is practical.": "生成速度は実用的です。",
        "Generation speed is strong.": "生成速度は良好です。",
        "Generation speed could not be measured.": "生成速度を測定できませんでした。",
        "The response hit the token limit.": "応答がトークン上限に達しました。",
        "Long code responses will be very slow.": "長いコード応答はかなり遅くなります。",
        "Code generation speed is limited.": "コード生成速度は限定的です。",
        "Code generation speed is usable.": "コード生成速度は実用可能です。",
        "Code generation speed is practical.": "コード生成速度は実用的です。",
        "The model hit the token limit during generation.": "生成中にモデルがトークン上限に達しました。",
        "Instruction-following probes were unstable.": "指示追従テストは不安定でした。",
        "Instruction-following probes were mostly usable.": "指示追従テストはおおむね実用可能です。",
        "Instruction-following probes were stable.": "指示追従テストは安定しています。",
        "Agent readiness probes were not available.": "Agent Readinessテストを利用できませんでした。",
        "JSON output is unreliable.": "JSON出力は不安定です。",
        "JSON output sometimes breaks.": "JSON出力が崩れることがあります。",
        "JSON output is mostly stable.": "JSON出力はおおむね安定しています。",
        "JSON output was stable.": "JSON出力は安定しています。",
        "Instruction following is weak for agent loops.": "エージェント処理では指示追従が弱めです。",
        "Instruction following needs caution.": "指示追従には注意が必要です。",
        "Instruction following is practical.": "指示追従は実用的です。",
        "Tool-selection probes were unreliable.": "ツール選択テストは不安定です。",
        "Tool-selection probes were mostly usable.": "ツール選択テストはおおむね実用可能です。",
        "Tool-selection probes were stable.": "ツール選択テストは安定しています。",
        "Timeouts occurred during repeated probes.": "繰り返しテスト中にタイムアウトが発生しました。",
        "Some probes stopped because of token length.": "一部のテストがトークン長により停止しました。",
        "Repeated short-task latency is high.": "短いタスクの繰り返しで遅延が大きめです。",
        "Repeated short-task latency is acceptable.": "短いタスクの繰り返し遅延は許容範囲です。",
        "Memory headroom is tight on this Mac.": "このMacではメモリ余裕がかなり少ないです。",
        "Memory headroom is limited.": "メモリ余裕は限定的です。",
        "Speed test did not run.": "速度テストは実行されませんでした。",
        "Endpoint timed out during the speed test.": "速度テスト中にエンドポイントがタイムアウトしました。",
        "Model used the token budget on reasoning before final content.": "モデルが最終回答の前に推論でトークン予算を使い切りました。",
        "Model returned reasoning without final content.": "モデルは推論のみを返し、最終回答を返しませんでした。",
        "Response reached the token limit before content.": "本文生成前に応答がトークン上限に達しました。",
        "Endpoint returned no benchmark content.": "エンドポイントがベンチマーク本文を返しませんでした。",
        "Endpoint did not complete the speed test.": "エンドポイントが速度テストを完了しませんでした。",
        "responsive": "応答は良好です。"
    ]
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
