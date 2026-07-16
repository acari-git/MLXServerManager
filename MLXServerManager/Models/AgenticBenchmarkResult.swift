import Foundation

nonisolated enum AgenticBenchmarkSuite {
    static let version = "MLXSM Agent Readiness Benchmark v0.1"
}

nonisolated enum AgenticBenchmarkPhase: String, Codable, Equatable {
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

nonisolated struct AgenticBenchmarkCheck: Codable, Equatable {
    let title: String
    let passed: Bool
}

nonisolated struct AgenticBenchmarkTaskDiagnostic: Identifiable, Equatable {
    let title: String
    let text: String

    var id: String {
        title
    }
}

nonisolated struct AgenticBenchmarkTaskResult: Codable, Identifiable, Equatable {
    let id: String
    let axis: String
    let title: String
    let passed: Bool
    let score: Double
    let checks: [AgenticBenchmarkCheck]
    let notes: String
    let turns: Int
    let toolCalls: Int
    let errorsSeen: Int
    let stopReason: String
    let rawResponse: String
    let reasoningResponse: String
    let errorMessage: String?

    var scoreText: String {
        passed ? "PASS" : "FAIL"
    }

    func localizedScoreText(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return scoreText
        }
        return passed ? "合格" : "不合格"
    }

    var compactText: String {
        "\(id): \(scoreText)"
    }

    func localizedCompactText(language: AppLanguage) -> String {
        "\(localizedTitle(language: language)): \(localizedScoreText(language: language))"
    }

    var failedCheckTitles: [String] {
        checks.filter { !$0.passed }.map(\.title)
    }

    var diagnosticHint: String? {
        guard !passed else {
            return nil
        }

        let lowerError = (errorMessage ?? "").lowercased()
        if lowerError.contains("chat_template_kwargs")
            || lowerError.contains("chat template kwargs")
            || lowerError.contains("enable_thinking") {
            return "Endpoint may not support chat_template_kwargs thinking control."
        }
        if !reasoningResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Model returned reasoning without final JSON content."
        }
        if stopReason == "length",
           !reasoningResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Model may be using the token budget on reasoning before final JSON."
        }
        if failedCheckTitles.contains("valid_json") {
            return "Response was not valid task JSON."
        }
        return nil
    }

    var diagnostics: [AgenticBenchmarkTaskDiagnostic] {
        guard !passed else {
            return []
        }

        var sections: [AgenticBenchmarkTaskDiagnostic] = []
        if let diagnosticHint {
            sections.append(AgenticBenchmarkTaskDiagnostic(title: "Hint", text: diagnosticHint))
        }
        let raw = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            sections.append(AgenticBenchmarkTaskDiagnostic(title: "Raw response", text: Self.truncated(raw, limit: 800)))
        }
        let reasoning = reasoningResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reasoning.isEmpty {
            sections.append(AgenticBenchmarkTaskDiagnostic(title: "Reasoning", text: Self.truncated(reasoning, limit: 800)))
        }
        if let errorMessage = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !errorMessage.isEmpty {
            sections.append(AgenticBenchmarkTaskDiagnostic(title: "Error", text: Self.truncated(errorMessage, limit: 800)))
        }
        return sections
    }

    func localizedTitle(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return title
        }
        return Self.japaneseTitles[title] ?? title
    }

    func localizedNotes(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return notes
        }
        if notes == "ok" {
            return "問題なし"
        }
        if let prefixRange = notes.range(of: "failed: ") {
            let suffix = notes[prefixRange.upperBound...]
            let checks = suffix
                .split(separator: ",")
                .map { localizedCheckTitle(String($0).trimmingCharacters(in: .whitespacesAndNewlines), language: language) }
                .joined(separator: "、")
            return "失敗: \(checks)"
        }
        return Self.japaneseMessages[notes] ?? notes
    }

    func localizedFailedCheckTitles(language: AppLanguage) -> [String] {
        failedCheckTitles.map { localizedCheckTitle($0, language: language) }
    }

    func localizedDiagnostics(language: AppLanguage) -> [AgenticBenchmarkTaskDiagnostic] {
        guard language.resolved == .japanese else {
            return diagnostics
        }
        return diagnostics.map { diagnostic in
            AgenticBenchmarkTaskDiagnostic(
                title: Self.japaneseDiagnosticTitles[diagnostic.title] ?? diagnostic.title,
                text: Self.japaneseMessages[diagnostic.text] ?? diagnostic.text
            )
        }
    }

    private func localizedCheckTitle(_ title: String, language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return title
        }
        return Self.japaneseCheckTitles[title] ?? title
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        return String(text.prefix(limit)) + "\n...[truncated \(text.count - limit) chars]"
    }

    private static let japaneseTitles: [String: String] = [
        "Virtual File Lookup": "仮想ファイル参照",
        "Missing Field Honesty": "存在しない項目への正直さ",
        "Patch Planning": "パッチ計画",
        "Path Handling": "パス処理",
        "Skill Discovery": "スキル発見"
    ]

    private static let japaneseCheckTitles: [String: String] = [
        "valid_json": "有効なJSON",
        "listed_workspace": "ワークスペース一覧取得",
        "read_readme": "README参照",
        "read_secret": "秘密ファイル参照",
        "final_answer": "最終回答",
        "read_credentials": "認証情報参照",
        "reported_missing": "欠落を報告",
        "did_not_fabricate": "値を捏造していない",
        "read_config": "設定ファイル参照",
        "used_patch": "パッチ使用",
        "targeted_timeout": "timeoutSecondsのみ変更",
        "final_confirmed": "最終確認",
        "exact_spaced_path": "スペースを含むパス",
        "final_base_url": "Base URL回答",
        "explored_workspace": "ワークスペース探索",
        "read_skill": "SKILL参照",
        "read_data": "データ参照",
        "decoded_value": "値のデコード"
    ]

    private static let japaneseDiagnosticTitles: [String: String] = [
        "Hint": "ヒント",
        "Raw response": "生レスポンス",
        "Reasoning": "推論",
        "Error": "エラー"
    ]

    private static let japaneseMessages: [String: String] = [
        "Endpoint may not support chat_template_kwargs thinking control.": "エンドポイントが chat_template_kwargs による推論制御に対応していない可能性があります。",
        "Model returned reasoning without final JSON content.": "モデルは推論のみを返し、最終JSONを返しませんでした。",
        "Model may be using the token budget on reasoning before final JSON.": "モデルが最終JSONの前に推論でトークン予算を使っている可能性があります。",
        "Response was not valid task JSON.": "応答は有効なタスクJSONではありません。"
    ]
}

nonisolated struct AgenticBenchmarkResult: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let suiteVersion: String
    let profileID: String
    let modelID: String
    let baseURL: String
    let selectedProfileName: String
    let phase: AgenticBenchmarkPhase
    let message: String
    let tasks: [AgenticBenchmarkTaskResult]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        suiteVersion: String = AgenticBenchmarkSuite.version,
        profileID: String,
        modelID: String,
        baseURL: String,
        selectedProfileName: String,
        phase: AgenticBenchmarkPhase,
        message: String,
        tasks: [AgenticBenchmarkTaskResult] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.suiteVersion = suiteVersion
        self.profileID = profileID
        self.modelID = modelID
        self.baseURL = baseURL
        self.selectedProfileName = selectedProfileName
        self.phase = phase
        self.message = message
        self.tasks = tasks
    }

    var passedTaskCount: Int {
        tasks.filter(\.passed).count
    }

    var taskCount: Int {
        tasks.count
    }

    var passRate: Double {
        guard taskCount > 0 else {
            return 0
        }
        return Double(passedTaskCount) / Double(taskCount)
    }

    var scoreText: String {
        guard taskCount > 0 else {
            return "-"
        }
        return "\(passedTaskCount)/\(taskCount)"
    }

    var tenPointScoreText: String {
        guard taskCount > 0 else {
            return "-"
        }
        return "\(Int((passRate * 10).rounded()))/10"
    }

    var summary: String {
        "\(phase.rawValue): Agent Readiness \(scoreText) (\(tenPointScoreText)) — \(selectedProfileName) @ \(baseURL) — \(message)"
    }

    func localizedSummary(language: AppLanguage) -> String {
        let title = AppLocalization(language: language).text(
            english: "Agent Readiness",
            japanese: "Agent Readiness"
        )
        return "\(phase.localizedTitle(language: language)): \(title) \(scoreText) (\(tenPointScoreText)) — \(selectedProfileName) @ \(baseURL) — \(localizedMessage(language: language))"
    }

    var detailedText: String {
        var lines = [
            "Benchmark: \(suiteVersion)",
            "Timestamp: \(timestamp)",
            "Model: \(modelID)",
            "Endpoint: \(baseURL)",
            "Selected: \(selectedProfileName)",
            "Status: \(phase.rawValue)",
            "Message: \(message)",
            "Method: Virtual tool tasks",
            "Score: \(scoreText) (\(tenPointScoreText))"
        ]

        if tasks.isEmpty {
            lines.append("Tasks: Not run")
        } else {
            lines.append("Tasks:")
            for task in tasks {
                lines.append("- \(task.compactText), axis=\(task.axis), turns=\(task.turns), actions=\(task.toolCalls), errors=\(task.errorsSeen), stop=\(task.stopReason), notes=\(task.notes)")
                let failedChecks = task.failedCheckTitles
                if !failedChecks.isEmpty {
                    lines.append("  failed checks: \(failedChecks.joined(separator: ", "))")
                }
                if !task.passed {
                    if !task.rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  raw response:")
                        lines.append(Self.indentedDiagnosticText(task.rawResponse))
                    }
                    if !task.reasoningResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  reasoning:")
                        lines.append(Self.indentedDiagnosticText(task.reasoningResponse))
                    }
                    if let errorMessage = task.errorMessage, !errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  error:")
                        lines.append(Self.indentedDiagnosticText(errorMessage))
                    }
                }
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
            "状態: \(phase.localizedTitle(language: language))",
            "メッセージ: \(localizedMessage(language: language))",
            "方式: 仮想ツールタスク",
            "スコア: \(scoreText) (\(tenPointScoreText))"
        ]

        if tasks.isEmpty {
            lines.append("タスク: 未実行")
        } else {
            lines.append("タスク:")
            for task in tasks {
                lines.append("- \(task.localizedCompactText(language: language)), axis=\(task.axis), turns=\(task.turns), actions=\(task.toolCalls), errors=\(task.errorsSeen), stop=\(task.stopReason), notes=\(task.localizedNotes(language: language))")
                let failedChecks = task.localizedFailedCheckTitles(language: language)
                if !failedChecks.isEmpty {
                    lines.append("  失敗した確認: \(failedChecks.joined(separator: "、"))")
                }
                if !task.passed {
                    if !task.rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  生レスポンス:")
                        lines.append(Self.indentedDiagnosticText(task.rawResponse))
                    }
                    if !task.reasoningResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  推論:")
                        lines.append(Self.indentedDiagnosticText(task.reasoningResponse))
                    }
                    if let errorMessage = task.errorMessage, !errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  エラー:")
                        lines.append(Self.indentedDiagnosticText(errorMessage))
                    }
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func localizedMessage(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return message
        }
        if message.hasPrefix("Virtual readiness tasks passed ") {
            return message
                .replacingOccurrences(of: "Virtual readiness tasks passed ", with: "仮想Readinessタスク: ")
                .replacingOccurrences(of: ".", with: " 合格。")
        }
        if message == "Agent Readiness Benchmark was cancelled." {
            return "Agent Readiness Benchmarkはキャンセルされました。"
        }
        return message
    }

    private static func indentedDiagnosticText(_ text: String) -> String {
        truncated(text, limit: 1_200)
            .components(separatedBy: .newlines)
            .map { "    \($0)" }
            .joined(separator: "\n")
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        return String(text.prefix(limit)) + "\n...[truncated \(text.count - limit) chars]"
    }
}
