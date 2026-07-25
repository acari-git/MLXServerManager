import Foundation

nonisolated enum ModelProfileTemplate: String, CaseIterable, Identifiable, Sendable {
    case minimal
    case balanced
    case memorySaver
    case throughput

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .minimal:
            return strings.text(english: "Minimal", japanese: "最小構成")
        case .balanced:
            return strings.text(english: "Balanced", japanese: "バランス")
        case .memorySaver:
            return strings.text(english: "Memory Saver", japanese: "メモリ節約")
        case .throughput:
            return strings.text(english: "Throughput", japanese: "スループット重視")
        }
    }

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .minimal:
            return strings.text(
                english: "Clears managed concurrency, prefill, and prompt-cache tuning while preserving sampling, CORS, chat-template, and raw arguments.",
                japanese: "サンプリング、CORS、チャットテンプレート、Raw引数を保持したまま、管理対象の並行数、Prefill、プロンプトキャッシュ調整を解除します。"
            )
        case .balanced:
            return strings.text(
                english: "Conservative concurrency and cache values for general interactive use.",
                japanese: "一般的な対話用途向けの控えめな並行数とキャッシュ設定です。"
            )
        case .memorySaver:
            return strings.text(
                english: "Uses one request lane, a smaller prefill step, and a minimal prompt cache.",
                japanese: "リクエスト処理を1系統に抑え、Prefill単位とプロンプトキャッシュを小さくします。"
            )
        case .throughput:
            return strings.text(
                english: "Raises concurrency and prefill size for workloads that can trade memory headroom for throughput.",
                japanese: "メモリ余裕を使ってスループットを高められるワークロード向けに、並行数とPrefill単位を増やします。"
            )
        }
    }

    func localizedSettingsSummary(
        backend: InferenceBackend,
        language: AppLanguage
    ) -> String {
        let strings = AppLocalization(language: language)
        let values = performanceValues(for: backend)
        guard let values else {
            return strings.text(
                english: "Managed tuning fields will be cleared.",
                japanese: "管理対象のチューニング項目を解除します。"
            )
        }

        return strings.text(
            english: "Decode \(values.decodeConcurrency), prompt \(values.promptConcurrency), prefill \(values.prefillStepSize), cache \(values.promptCacheSize).",
            japanese: "設定値: Decode \(values.decodeConcurrency)、Prompt \(values.promptConcurrency)、Prefill \(values.prefillStepSize)、Cache \(values.promptCacheSize)。"
        )
    }

    func applying(to draft: ModelProfileDraft) -> ModelProfileDraft {
        var updated = draft
        var options = updated.advancedLaunchOptions
        if let values = performanceValues(for: draft.backend) {
            options.decodeConcurrency = values.decodeConcurrency
            options.promptConcurrency = values.promptConcurrency
            options.prefillStepSize = values.prefillStepSize
            options.promptCacheSize = values.promptCacheSize
            options.promptCacheBytes = nil
        } else {
            options.decodeConcurrency = nil
            options.promptConcurrency = nil
            options.prefillStepSize = nil
            options.promptCacheSize = nil
            options.promptCacheBytes = nil
        }
        updated.advancedLaunchOptions = options
        return updated
    }

    private func performanceValues(
        for backend: InferenceBackend
    ) -> (
        decodeConcurrency: String,
        promptConcurrency: String,
        prefillStepSize: String,
        promptCacheSize: String
    )? {
        guard self != .minimal else { return nil }

        switch (self, backend) {
        case (.balanced, .mlxLM):
            return ("1", "1", "512", "2")
        case (.balanced, .rapidMLX):
            return ("2", "2", "512", "2")
        case (.memorySaver, _):
            return ("1", "1", "256", "1")
        case (.throughput, .mlxLM):
            return ("2", "2", "1024", "4")
        case (.throughput, .rapidMLX):
            return ("4", "4", "1024", "4")
        case (.minimal, _):
            return nil
        }
    }
}
