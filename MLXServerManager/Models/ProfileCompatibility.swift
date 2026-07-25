import Foundation

nonisolated enum ProfileCompatibilityLevel: String, Equatable, Sendable {
    case compatible
    case blocked
    case unknown

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .compatible:
            return strings.text(english: "Compatible", japanese: "互換性あり")
        case .blocked:
            return strings.text(english: "Unsupported options", japanese: "未対応オプションあり")
        case .unknown:
            return strings.text(english: "Compatibility unknown", japanese: "互換性不明")
        }
    }
}

nonisolated struct ProfileCompatibilityAssessment: Equatable, Sendable {
    let backend: InferenceBackend
    let level: ProfileCompatibilityLevel
    let requestedFlags: [String]
    let unsupportedFlags: [String]
    let checkedAt: Date?

    var canClearUnsupportedOptions: Bool {
        !unsupportedFlags.isEmpty
    }

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch level {
        case .compatible:
            if requestedFlags.isEmpty {
                return strings.text(
                    english: "No optional runtime flags are currently requested by this profile.",
                    japanese: "このプロファイルでは任意のランタイムフラグを要求していません。"
                )
            }
            return strings.text(
                english: "All \(requestedFlags.count) requested optional runtime flags were detected in the configured executable.",
                japanese: "要求している任意ランタイムフラグ\(requestedFlags.count)件は、設定済み実行ファイルで検出されました。"
            )
        case .blocked:
            return strings.text(
                english: "The configured executable did not expose these requested flags: \(unsupportedFlags.joined(separator: ", ")).",
                japanese: "設定済み実行ファイルでは、次の要求フラグを検出できませんでした: \(unsupportedFlags.joined(separator: ", "))。"
            )
        case .unknown:
            return strings.text(
                english: "Run Runtime Compatibility in Settings. Unknown support does not automatically block an explicit start.",
                japanese: "設定でランタイム互換性を確認してください。不明な対応状況だけを理由に、明示的な起動を自動で禁止することはありません。"
            )
        }
    }
}

nonisolated enum RuntimeProfileCompatibilityAdvisor {
    static func assess(
        request: ModelLaunchRequest,
        report: RuntimeCompatibilityReport?
    ) -> ProfileCompatibilityAssessment {
        let requestedFlags = requestedOptionalFlags(for: request)
        guard !requestedFlags.isEmpty else {
            return ProfileCompatibilityAssessment(
                backend: request.backend,
                level: .compatible,
                requestedFlags: [],
                unsupportedFlags: [],
                checkedAt: report?.checkedAt
            )
        }

        guard let report,
              report.backend == request.backend,
              normalizedPath(report.executablePath) == normalizedPath(request.executablePath),
              let supportedFlags = report.supportedFlags else {
            return ProfileCompatibilityAssessment(
                backend: request.backend,
                level: .unknown,
                requestedFlags: requestedFlags,
                unsupportedFlags: [],
                checkedAt: report?.checkedAt
            )
        }

        let unsupportedFlags = requestedFlags.filter { !supportedFlags.contains($0) }
        return ProfileCompatibilityAssessment(
            backend: request.backend,
            level: unsupportedFlags.isEmpty ? .compatible : .blocked,
            requestedFlags: requestedFlags,
            unsupportedFlags: unsupportedFlags,
            checkedAt: report.checkedAt
        )
    }

    static func requestedOptionalFlags(for request: ModelLaunchRequest) -> [String] {
        let managedFlags: Set<String> = ["--model", "--host", "--port"]
        return Array(Set(
            ModelProcessManager.launchArguments(for: request)
                .compactMap(normalizedFlag)
                .filter { !managedFlags.contains($0) }
        )).sorted()
    }

    static func clearingUnsupportedOptions(
        in draft: ModelProfileDraft,
        flags: [String]
    ) -> ModelProfileDraft {
        var next = draft
        var options = draft.advancedLaunchOptions
        let flagSet = Set(flags)

        switch draft.backend {
        case .mlxLM:
            if flagSet.contains("--chat-template-args") {
                options.chatTemplateArgs = nil
                next.enableThinking = false
            }
            clear("--temp", value: &options.defaultTemperature, flags: flagSet)
            clear("--top-p", value: &options.defaultTopP, flags: flagSet)
            clear("--top-k", value: &options.defaultTopK, flags: flagSet)
            clear("--min-p", value: &options.defaultMinP, flags: flagSet)
            clear("--max-tokens", value: &options.defaultMaxTokens, flags: flagSet)
            clear("--allowed-origins", value: &options.allowedOrigins, flags: flagSet)
            clear("--log-level", value: &options.logLevel, flags: flagSet)
            clear("--decode-concurrency", value: &options.decodeConcurrency, flags: flagSet)
            clear("--prompt-concurrency", value: &options.promptConcurrency, flags: flagSet)
            clear("--prefill-step-size", value: &options.prefillStepSize, flags: flagSet)
            clear("--prompt-cache-size", value: &options.promptCacheSize, flags: flagSet)
            clear("--prompt-cache-bytes", value: &options.promptCacheBytes, flags: flagSet)
        case .rapidMLX:
            if flagSet.contains("--no-thinking") {
                next.enableThinking = true
            }
            clear("--default-temperature", value: &options.defaultTemperature, flags: flagSet)
            clear("--default-top-p", value: &options.defaultTopP, flags: flagSet)
            clear("--default-top-k", value: &options.defaultTopK, flags: flagSet)
            clear("--default-min-p", value: &options.defaultMinP, flags: flagSet)
            clear("--max-tokens", value: &options.defaultMaxTokens, flags: flagSet)
            clear("--cors-origins", value: &options.allowedOrigins, flags: flagSet)
            clear("--log-level", value: &options.logLevel, flags: flagSet)
            clear("--max-num-seqs", value: &options.decodeConcurrency, flags: flagSet)
            clear("--max-concurrent-requests", value: &options.promptConcurrency, flags: flagSet)
            clear("--prefill-step-size", value: &options.prefillStepSize, flags: flagSet)
            clear("--prefix-cache-size", value: &options.promptCacheSize, flags: flagSet)
            clear("--cache-memory-mb", value: &options.promptCacheBytes, flags: flagSet)
        }

        if rawArguments(options.rawExtraArgs, containAny: flagSet) {
            options.rawExtraArgs = nil
        }
        next.advancedLaunchOptions = options
        return next
    }

    private static func clear(
        _ flag: String,
        value: inout String?,
        flags: Set<String>
    ) {
        if flags.contains(flag) {
            value = nil
        }
    }

    private static func rawArguments(_ raw: String?, containAny flags: Set<String>) -> Bool {
        guard let raw,
              let arguments = try? ShellArgumentParser.parse(raw) else {
            return false
        }
        return arguments.contains { argument in
            guard let flag = normalizedFlag(argument) else { return false }
            return flags.contains(flag)
        }
    }

    private static func normalizedPath(_ path: String) -> String {
        NSString(
            string: path.trimmingCharacters(in: .whitespacesAndNewlines)
        ).expandingTildeInPath
    }

    private static func normalizedFlag(_ argument: String) -> String? {
        guard argument.hasPrefix("--"), argument.count > 2 else {
            return nil
        }
        return String(argument.split(separator: "=", maxSplits: 1)[0])
    }
}
