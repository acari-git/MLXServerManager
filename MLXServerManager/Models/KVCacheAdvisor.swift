import Foundation

nonisolated enum KVCacheDiagnosisLevel: String, Codable, Hashable {
    case healthy
    case attention
    case warning
}

nonisolated struct KVCacheEnvironment: Equatable {
    let totalMemoryGigabytes: Double
    let availableMemoryGigabytes: Double?
    let modelStorageGigabytes: Double?
    let isModelLoaded: Bool
}

nonisolated struct KVCacheRecommendation: Equatable {
    let entryLimit: Int
    let byteLimit: UInt64
    let projectedHeadroomGigabytes: Double

    var byteLimitText: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteLimit), countStyle: .memory)
    }
}

nonisolated struct KVCacheAssessment: Equatable {
    let backend: InferenceBackend
    let level: KVCacheDiagnosisLevel
    let recommendation: KVCacheRecommendation
    let effectiveEntryLimit: Int?
    let effectiveByteLimit: UInt64?
    let usesDefaultEntryLimit: Bool
    let usesUnlimitedByteDefault: Bool
    let hasRawArgumentOverride: Bool

    func title(language: AppLanguage) -> String {
        switch (level, language.resolved) {
        case (.healthy, .english): "Configuration is balanced"
        case (.healthy, _): "設定は適正です"
        case (.attention, .english): "Review recommended"
        case (.attention, _): "推奨設定を確認してください"
        case (.warning, .english): "Memory pressure risk"
        case (.warning, _): "メモリ圧迫の可能性があります"
        }
    }

    func detail(language: AppLanguage) -> String {
        if hasRawArgumentOverride {
            return localized(
                language,
                english: "Raw Extra Args contains a prompt-cache option and may override these fields because raw arguments are appended last.",
                japanese: "Raw Extra Argsにプロンプトキャッシュ引数があり、最後に追加されるため、ここでの設定を上書きする可能性があります。"
            )
        }

        if usesUnlimitedByteDefault {
            return localized(
                language,
                english: "mlx_lm.server defaults to 10 cache entries without an explicit byte limit. An explicit limit makes memory use more predictable.",
                japanese: "mlx_lm.serverの既定値は最大10件で、バイト上限は未設定です。上限を明示するとメモリ使用量を予測しやすくなります。"
            )
        }

        if backend == .rapidMLX, effectiveByteLimit == nil {
            return localized(
                language,
                english: "Rapid-MLX uses a memory-aware cache limit of about 20% of RAM by default. Apply an explicit limit when predictable memory headroom is more important than maximum reuse.",
                japanese: "Rapid-MLXは既定でRAMの約20%を目安にメモリ対応キャッシュを調整します。最大限の再利用よりメモリ余力の予測性を重視する場合は、上限を明示してください。"
            )
        }

        guard let effectiveEntryLimit, let effectiveByteLimit else {
            return localized(
                language,
                english: "One or more cache values are invalid. Use positive integers or apply the recommendation.",
                japanese: "キャッシュ設定に不正な値があります。正の整数を入力するか、推奨値を反映してください。"
            )
        }

        let recommendedBytes = recommendation.byteLimit
        if effectiveByteLimit > recommendedBytes + recommendedBytes / 2 {
            return localized(
                language,
                english: "The configured byte limit is high for the estimated memory headroom and can increase memory pressure.",
                japanese: "現在の推定メモリ余力に対してバイト上限が大きく、メモリ圧迫を招く可能性があります。"
            )
        }

        if effectiveByteLimit < max(recommendedBytes / 4, 1) || effectiveEntryLimit < max(recommendation.entryLimit / 2, 1) {
            return localized(
                language,
                english: "The cache is conservative. It is safe, but repeated prompts may receive less reuse than the recommendation.",
                japanese: "保守的な設定です。安全ですが、繰り返しプロンプトで推奨値ほどキャッシュを再利用できない場合があります。"
            )
        }

        return localized(
            language,
            english: "The configured limits are close to the conservative recommendation for this Mac.",
            japanese: "このMac向けの保守的な推奨範囲に収まっています。"
        )
    }

    func recommendationText(language: AppLanguage) -> String {
        let headroom = String(format: "%.1f GB", recommendation.projectedHeadroomGigabytes)
        return localized(
            language,
            english: "Recommended starting point: \(recommendation.entryLimit) entries / \(recommendation.byteLimitText). Estimated reserved headroom: \(headroom).",
            japanese: "推奨開始値: \(recommendation.entryLimit)件 / \(recommendation.byteLimitText)。推定確保余力: \(headroom)。"
        )
    }

    private func localized(_ language: AppLanguage, english: String, japanese: String) -> String {
        language.resolved == .english ? english : japanese
    }
}

nonisolated struct KVCacheSafeModeResult: Equatable {
    let advancedLaunchOptions: AdvancedLaunchOptions?
    let recommendation: KVCacheRecommendation
    let adjustedEntryLimit: Bool
    let adjustedByteLimit: Bool

    var didAdjust: Bool {
        adjustedEntryLimit || adjustedByteLimit
    }

    func actionText(language: AppLanguage) -> String {
        let entryLimit = recommendation.entryLimit
        let byteLimit = recommendation.byteLimitText
        if language.resolved == .english {
            return "Runtime KV cache safe mode applied \(entryLimit) entries / \(byteLimit). The saved profile was not changed."
        }
        return "実行時KVキャッシュ安全モードとして\(entryLimit)件 / \(byteLimit)を適用しました。保存済みプロファイルは変更していません。"
    }
}

nonisolated enum KVCacheSafeMode {
    static func apply(
        options: AdvancedLaunchOptions?,
        environment: KVCacheEnvironment,
        backend: InferenceBackend
    ) -> KVCacheSafeModeResult {
        _ = backend
        let recommendation = KVCacheAdvisor.recommendedConfiguration(environment: environment)
        var resolvedOptions = options?.normalized() ?? .empty
        var adjustedEntryLimit = false
        var adjustedByteLimit = false

        if let configuredEntryText = resolvedOptions.promptCacheSize {
            if let configuredEntryLimit = Int(configuredEntryText), configuredEntryLimit > 0,
               configuredEntryLimit > recommendation.entryLimit {
                resolvedOptions.promptCacheSize = String(recommendation.entryLimit)
                adjustedEntryLimit = true
            }
        }

        if let configuredByteText = resolvedOptions.promptCacheBytes {
            if let configuredByteLimit = UInt64(configuredByteText), configuredByteLimit > 0,
               configuredByteLimit > recommendation.byteLimit {
                resolvedOptions.promptCacheBytes = String(recommendation.byteLimit)
                adjustedByteLimit = true
            }
        }

        return KVCacheSafeModeResult(
            advancedLaunchOptions: resolvedOptions.normalized(),
            recommendation: recommendation,
            adjustedEntryLimit: adjustedEntryLimit,
            adjustedByteLimit: adjustedByteLimit
        )
    }
}

nonisolated enum KVCacheAdvisor {
    static let mlxLMDefaultEntryLimit = 10
    static let rapidMLXDefaultEntryLimit = 100

    static func assess(
        options: AdvancedLaunchOptions,
        environment: KVCacheEnvironment,
        backend: InferenceBackend = .mlxLM
    ) -> KVCacheAssessment {
        let recommendation = recommendedConfiguration(environment: environment)
        let normalized = options.normalized()
        let configuredEntryText = normalized?.promptCacheSize
        let configuredByteText = normalized?.promptCacheBytes
        let defaultEntryLimit = backend == .rapidMLX ? rapidMLXDefaultEntryLimit : mlxLMDefaultEntryLimit
        let entryLimit = configuredEntryText.flatMap(Int.init) ?? (configuredEntryText == nil ? defaultEntryLimit : nil)
        let byteLimit = configuredByteText.flatMap(UInt64.init)
        let hasRawOverride = containsPromptCacheOverride(normalized?.rawExtraArgs)

        let level: KVCacheDiagnosisLevel
        if hasRawOverride || entryLimit == nil || (configuredByteText != nil && byteLimit == nil) {
            level = .warning
        } else if byteLimit == nil, backend == .rapidMLX {
            level = .attention
        } else if byteLimit == nil {
            level = recommendation.byteLimit <= gibibytes(1) ? .warning : .attention
        } else if let byteLimit, byteLimit > recommendation.byteLimit + recommendation.byteLimit / 2 {
            level = .warning
        } else if let entryLimit,
                  let byteLimit,
                  byteLimit < max(recommendation.byteLimit / 4, 1)
                    || entryLimit < max(recommendation.entryLimit / 2, 1) {
            level = .attention
        } else {
            level = .healthy
        }

        return KVCacheAssessment(
            backend: backend,
            level: level,
            recommendation: recommendation,
            effectiveEntryLimit: entryLimit,
            effectiveByteLimit: byteLimit,
            usesDefaultEntryLimit: configuredEntryText == nil,
            usesUnlimitedByteDefault: configuredByteText == nil && backend == .mlxLM,
            hasRawArgumentOverride: hasRawOverride
        )
    }

    static func recommendedConfiguration(environment: KVCacheEnvironment) -> KVCacheRecommendation {
        let totalMemory = max(environment.totalMemoryGigabytes, 1)
        let reserve = max(totalMemory * 0.15, 6)
        let projectedAvailable: Double

        if let available = environment.availableMemoryGigabytes {
            if environment.isModelLoaded {
                projectedAvailable = available
            } else if let modelStorage = environment.modelStorageGigabytes {
                projectedAvailable = available - modelStorage * 1.15
            } else {
                projectedAvailable = available
            }
        } else if let modelStorage = environment.modelStorageGigabytes {
            projectedAvailable = totalMemory - modelStorage * 1.25
        } else {
            projectedAvailable = totalMemory * 0.25
        }

        let headroom = max(projectedAvailable - reserve, 0)
        let hardwareCap: Double
        switch totalMemory {
        case ..<40:
            hardwareCap = 1
        case ..<96:
            hardwareCap = 2
        case ..<192:
            hardwareCap = 4
        default:
            hardwareCap = 8
        }

        let rawBudget = min(max(headroom * 0.25, 0.25), hardwareCap)
        let roundedBudget = max(floor(rawBudget * 4) / 4, 0.25)
        let entryLimit: Int
        switch roundedBudget {
        case ..<0.75:
            entryLimit = 2
        case ..<1.5:
            entryLimit = 4
        case ..<3:
            entryLimit = 8
        default:
            entryLimit = 10
        }

        return KVCacheRecommendation(
            entryLimit: entryLimit,
            byteLimit: UInt64(roundedBudget * Double(gibibytes(1))),
            projectedHeadroomGigabytes: headroom
        )
    }

    private static func containsPromptCacheOverride(_ rawArguments: String?) -> Bool {
        guard let rawArguments else { return false }
        let normalized = rawArguments.lowercased()
        return normalized.contains("--prompt-cache-size")
            || normalized.contains("--prompt-cache-bytes")
            || normalized.contains("--prefix-cache-size")
            || normalized.contains("--cache-memory-mb")
            || normalized.contains("--cache-memory-percent")
    }

    private static func gibibytes(_ value: UInt64) -> UInt64 {
        value * 1_073_741_824
    }
}
