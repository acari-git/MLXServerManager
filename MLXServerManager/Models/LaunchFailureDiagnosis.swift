import Foundation

nonisolated enum LaunchFailureCategory: String, Equatable, Sendable {
    case executable
    case dependency
    case unsupportedOption
    case modelFiles
    case port
    case memory
    case chatTemplate
    case reasoningParser
    case toolCallParser
    case permission
    case readiness
    case processExit
    case unknown

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .executable:
            return strings.text(english: "Runtime executable problem", japanese: "ランタイム実行ファイルの問題")
        case .dependency:
            return strings.text(english: "Runtime dependency problem", japanese: "ランタイム依存関係の問題")
        case .unsupportedOption:
            return strings.text(english: "Unsupported launch option", japanese: "未対応の起動オプション")
        case .modelFiles:
            return strings.text(english: "Model files are incomplete", japanese: "モデルファイルが不完全")
        case .port:
            return strings.text(english: "Endpoint port conflict", japanese: "接続先ポートの競合")
        case .memory:
            return strings.text(english: "Memory capacity problem", japanese: "メモリ容量の問題")
        case .chatTemplate:
            return strings.text(english: "Chat template problem", japanese: "チャットテンプレートの問題")
        case .reasoningParser:
            return strings.text(english: "Reasoning parser problem", japanese: "推論パーサーの問題")
        case .toolCallParser:
            return strings.text(english: "Tool-call parser problem", japanese: "ツールコールパーサーの問題")
        case .permission:
            return strings.text(english: "Permission problem", japanese: "権限の問題")
        case .readiness:
            return strings.text(english: "Server did not become ready", japanese: "サーバーがReadyになりませんでした")
        case .processExit:
            return strings.text(english: "Runtime process exited", japanese: "ランタイムプロセスが終了しました")
        case .unknown:
            return strings.text(english: "Launch failure needs review", japanese: "起動失敗の確認が必要")
        }
    }

    func localizedGuidance(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .executable:
            return strings.text(
                english: "Review the executable path in Settings and run Runtime Setup Assistant.",
                japanese: "設定の実行ファイルパスを確認し、ランタイム設定アシスタントを実行してください。"
            )
        case .dependency:
            return strings.text(
                english: "Open the configured Python environment and repair the missing runtime package manually.",
                japanese: "設定済みPython環境を確認し、不足しているランタイムパッケージを手動で修復してください。"
            )
        case .unsupportedOption:
            return strings.text(
                english: "Inspect Runtime Compatibility and clear only the unsupported profile options.",
                japanese: "ランタイム互換性を確認し、未対応のプロファイル項目だけを解除してください。"
            )
        case .modelFiles:
            return strings.text(
                english: "Run Model Health and verify config, tokenizer, weight, and shard files.",
                japanese: "モデル健全性を実行し、config、tokenizer、重み、shardファイルを確認してください。"
            )
        case .port:
            return strings.text(
                english: "Check the endpoint and select another available port. External processes are not stopped automatically.",
                japanese: "接続先を確認し、別の空きポートを選択してください。外部プロセスは自動停止しません。"
            )
        case .memory:
            return strings.text(
                english: "Stop an unused workload or review the Resource Forecast before retrying.",
                japanese: "不要な処理を停止するか、再試行前にリソース予測を確認してください。"
            )
        case .chatTemplate:
            return strings.text(
                english: "Clear or correct Chat Template Args and verify runtime support.",
                japanese: "Chat Template Argsを解除または修正し、ランタイム対応状況を確認してください。"
            )
        case .reasoningParser:
            return strings.text(
                english: "Review reasoning controls and parser flags for the selected runtime.",
                japanese: "選択ランタイムの推論制御とパーサーフラグを確認してください。"
            )
        case .toolCallParser:
            return strings.text(
                english: "Review the tool-call parser flag and the model/runtime combination.",
                japanese: "ツールコールパーサーフラグとモデル・ランタイムの組み合わせを確認してください。"
            )
        case .permission:
            return strings.text(
                english: "Review execute and read permissions for the runtime and model directory.",
                japanese: "ランタイムとモデルフォルダの実行・読み取り権限を確認してください。"
            )
        case .readiness:
            return strings.text(
                english: "Inspect runtime output, wait for model loading, and run Ready Check again.",
                japanese: "ランタイム出力を確認し、モデルのロードを待ってからReady確認を再実行してください。"
            )
        case .processExit:
            return strings.text(
                english: "Inspect the evidence lines and runtime logs before restarting.",
                japanese: "再起動前に根拠行とランタイムログを確認してください。"
            )
        case .unknown:
            return strings.text(
                english: "Copy the redacted diagnosis and inspect the detailed runtime logs.",
                japanese: "マスキング済み診断をコピーし、詳細なランタイムログを確認してください。"
            )
        }
    }
}

nonisolated struct LaunchFailureDiagnosis: Equatable, Sendable {
    let modelID: ModelConfig.ID
    let backend: InferenceBackend
    let category: LaunchFailureCategory
    let evidenceLines: [String]
    let createdAt: Date

    func localizedSummary(language: AppLanguage) -> String {
        "\(category.localizedTitle(language: language)): \(category.localizedGuidance(language: language))"
    }

    func copyText(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        let evidence = evidenceLines.isEmpty
            ? strings.text(english: "No specific evidence line was captured.", japanese: "特定の根拠行は取得されませんでした。")
            : evidenceLines.joined(separator: "\n")
        return [
            category.localizedTitle(language: language),
            category.localizedGuidance(language: language),
            strings.text(english: "Evidence:", japanese: "根拠:"),
            evidence
        ].joined(separator: "\n")
    }
}

nonisolated enum LaunchFailureClassifier {
    static func classify(
        modelID: ModelConfig.ID,
        backend: InferenceBackend,
        lines: [String],
        fallbackMessage: String
    ) -> LaunchFailureDiagnosis {
        let combined = (lines + [fallbackMessage]).joined(separator: "\n").lowercased()
        let category: LaunchFailureCategory

        if containsAny(combined, ["no such file", "executable does not exist", "executable path", "command not found"]) {
            category = .executable
        } else if containsAny(combined, ["modulenotfounderror", "no module named", "importerror", "dependency"]) {
            category = .dependency
        } else if containsAny(combined, ["unrecognized arguments", "unknown option", "unsupported option", "does not support the configured launch options"]) {
            category = .unsupportedOption
        } else if containsAny(combined, ["safetensors", "tokenizer", "config.json", "weight_map", "shard", "model files are incomplete"]) {
            category = .modelFiles
        } else if containsAny(combined, ["address already in use", "port is already", "port occupied", "port busy"]) {
            category = .port
        } else if containsAny(combined, ["out of memory", "memoryerror", "cannot allocate memory", "metal command buffer", "resource exhausted"]) {
            category = .memory
        } else if containsAny(combined, ["chat template", "chat_template", "template error"]) {
            category = .chatTemplate
        } else if containsAny(combined, ["reasoning parser", "reasoning_parser", "no-reasoning-parser"]) {
            category = .reasoningParser
        } else if containsAny(combined, ["tool call parser", "tool-call-parser", "tool_call_parser"]) {
            category = .toolCallParser
        } else if containsAny(combined, ["permission denied", "operation not permitted", "not executable"]) {
            category = .permission
        } else if containsAny(combined, ["ready check", "readiness", "timed out", "/v1/models"]) {
            category = .readiness
        } else if containsAny(combined, ["exited with status", "terminated", "process exited", "traceback"]) {
            category = .processExit
        } else {
            category = .unknown
        }

        let evidence = Array(
            lines
                .filter { isImportant($0, category: category) }
                .suffix(5)
                .map(redacted)
        )
        return LaunchFailureDiagnosis(
            modelID: modelID,
            backend: backend,
            category: category,
            evidenceLines: evidence,
            createdAt: Date()
        )
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func isImportant(_ line: String, category: LaunchFailureCategory) -> Bool {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("exception") || lower.contains("traceback") || lower.contains("failed") {
            return true
        }
        switch category {
        case .port:
            return lower.contains("port") || lower.contains("address")
        case .memory:
            return lower.contains("memory") || lower.contains("metal")
        case .readiness:
            return lower.contains("ready") || lower.contains("models") || lower.contains("timeout")
        case .unsupportedOption:
            return lower.contains("argument") || lower.contains("option")
        default:
            return false
        }
    }

    private static func redacted(_ line: String) -> String {
        var result = line
        let patterns = [
            #"(?i)authorization:\s*bearer\s+\S+"#,
            #"(?i)bearer\s+\S+"#,
            #"hf_[A-Za-z0-9]{10,}"#,
            #"(?i)(api[_-]?key|token|secret)\s*[=:]\s*\S+"#
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "[REDACTED]"
            )
        }
        return result
    }
}
