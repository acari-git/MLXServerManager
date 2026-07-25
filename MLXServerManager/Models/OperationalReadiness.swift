import Foundation

nonisolated enum OperationalReadinessStatus: String, Equatable, Sendable {
    case ready
    case attention
    case blocking
    case unknown
    case checking

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .ready:
            return strings.text(english: "Ready", japanese: "準備完了")
        case .attention:
            return strings.text(english: "Needs review", japanese: "要確認")
        case .blocking:
            return strings.text(english: "Blocking", japanese: "起動不可")
        case .unknown:
            return strings.text(english: "Unknown", japanese: "不明")
        case .checking:
            return strings.text(english: "Checking", japanese: "確認中")
        }
    }
}

nonisolated enum OperationalReadinessCheckKind: String, CaseIterable, Identifiable, Sendable {
    case runtime
    case compatibility
    case modelHealth
    case endpoint
    case resourceForecast
    case profileOptions
    case sessionRecovery
    case benchmark
    case hermesAgent

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .runtime:
            return strings.text(english: "Runtime", japanese: "ランタイム")
        case .compatibility:
            return strings.text(english: "Runtime Compatibility", japanese: "ランタイム互換性")
        case .modelHealth:
            return strings.text(english: "Model Health", japanese: "モデル健全性")
        case .endpoint:
            return strings.text(english: "Endpoint and Port", japanese: "接続先とポート")
        case .resourceForecast:
            return strings.text(english: "Resource Forecast", japanese: "リソース予測")
        case .profileOptions:
            return strings.text(english: "Profile Options", japanese: "プロファイル設定")
        case .sessionRecovery:
            return strings.text(english: "Session Recovery", japanese: "セッション復旧")
        case .benchmark:
            return strings.text(english: "Benchmark Evidence", japanese: "ベンチマーク根拠")
        case .hermesAgent:
            return strings.text(english: "Hermes Agent", japanese: "Hermes Agent連携")
        }
    }
}

nonisolated struct OperationalReadinessItem: Identifiable, Equatable, Sendable {
    let kind: OperationalReadinessCheckKind
    let status: OperationalReadinessStatus
    let detailEnglish: String
    let detailJapanese: String

    var id: OperationalReadinessCheckKind { kind }

    func localizedDetail(language: AppLanguage) -> String {
        language.resolved == .english ? detailEnglish : detailJapanese
    }
}

nonisolated struct OperationalReadinessReport: Equatable, Sendable {
    let selectedProfileID: ModelConfig.ID?
    let selectedProfileName: String?
    let items: [OperationalReadinessItem]
    let modelHealthReports: [RegisteredModelHealthReport]
    let resourceForecast: StartResourceForecast?
    let compatibilityAssessment: ProfileCompatibilityAssessment?
    let tuningRecommendations: [BenchmarkProfileTuningRecommendation]
    let launchFailureDiagnosis: LaunchFailureDiagnosis?
    let generatedAt: Date

    var blockingCount: Int {
        items.filter { $0.status == .blocking }.count
    }

    var attentionCount: Int {
        items.filter { $0.status == .attention }.count
    }

    var overallStatus: OperationalReadinessStatus {
        if blockingCount > 0 { return .blocking }
        if attentionCount > 0 { return .attention }
        if items.contains(where: { $0.status == .unknown }) { return .unknown }
        return .ready
    }

    func copyText(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        var lines = [
            strings.text(english: "MLX Server Manager Operational Readiness", japanese: "MLX Server Manager 運用準備状態"),
            strings.text(
                english: "Profile: \(selectedProfileName ?? "Not selected")",
                japanese: "プロファイル: \(selectedProfileName ?? "未選択")"
            ),
            strings.text(
                english: "Overall: \(overallStatus.localizedTitle(language: .english))",
                japanese: "総合: \(overallStatus.localizedTitle(language: .japanese))"
            )
        ]
        lines.append(contentsOf: items.map { item in
            "[\(item.status.localizedTitle(language: language))] \(item.kind.localizedTitle(language: language)): \(item.localizedDetail(language: language))"
        })
        if let launchFailureDiagnosis {
            lines.append(strings.text(english: "Latest launch diagnosis:", japanese: "最新の起動診断:"))
            lines.append(launchFailureDiagnosis.copyText(language: language))
        }
        return lines.joined(separator: "\n")
    }
}

nonisolated struct OperationalReadinessViewState: Equatable, Sendable {
    var isPresented: Bool
    var isChecking: Bool
    var report: OperationalReadinessReport?

    static let hidden = OperationalReadinessViewState(
        isPresented: false,
        isChecking: false,
        report: nil
    )

    mutating func begin() {
        isPresented = true
        isChecking = true
    }

    mutating func complete(_ report: OperationalReadinessReport) {
        self.report = report
        isChecking = false
        isPresented = true
    }

    mutating func cancel() {
        isChecking = false
    }
}

nonisolated enum OperationalReadinessProjector {
    static func makeReport(
        selectedModel: ModelConfig?,
        runtimeReadiness: RuntimeReadinessReport?,
        compatibility: ProfileCompatibilityAssessment?,
        healthReports: [RegisteredModelHealthReport],
        portCheckResult: PortCheckResult?,
        selectedEndpointIsActive: Bool,
        resourceForecast: StartResourceForecast?,
        sessionRecoveryCandidateCount: Int,
        tuningRecommendations: [BenchmarkProfileTuningRecommendation],
        hermesConfigPath: String,
        launchFailureDiagnosis: LaunchFailureDiagnosis?
    ) -> OperationalReadinessReport {
        let selectedHealth = selectedModel.flatMap { model in
            healthReports.first { $0.profileID == model.id }
        }
        var items: [OperationalReadinessItem] = []

        items.append(runtimeItem(runtimeReadiness))
        items.append(compatibilityItem(compatibility))
        items.append(modelHealthItem(selectedHealth, hasSelection: selectedModel != nil))
        items.append(endpointItem(
            portCheckResult,
            selectedModel: selectedModel,
            selectedEndpointIsActive: selectedEndpointIsActive
        ))
        items.append(resourceItem(resourceForecast, hasSelection: selectedModel != nil))
        items.append(profileOptionsItem(compatibility, launchFailureDiagnosis: launchFailureDiagnosis))
        items.append(sessionRecoveryItem(candidateCount: sessionRecoveryCandidateCount))
        items.append(benchmarkItem(tuningRecommendations, hasSelection: selectedModel != nil))
        items.append(hermesItem(path: hermesConfigPath))

        return OperationalReadinessReport(
            selectedProfileID: selectedModel?.id,
            selectedProfileName: selectedModel?.displayName,
            items: items,
            modelHealthReports: healthReports,
            resourceForecast: resourceForecast,
            compatibilityAssessment: compatibility,
            tuningRecommendations: tuningRecommendations,
            launchFailureDiagnosis: launchFailureDiagnosis,
            generatedAt: Date()
        )
    }

    private static func runtimeItem(_ report: RuntimeReadinessReport?) -> OperationalReadinessItem {
        guard let report else {
            return item(.runtime, .unknown, "Runtime readiness has not been checked.", "ランタイム準備状態は未確認です。")
        }
        switch report.status {
        case .ready:
            return item(.runtime, .ready, "The configured executable is available.", "設定済み実行ファイルを利用できます。")
        case .warning:
            return item(.runtime, .attention, "The executable is available, but capability inspection needs review.", "実行ファイルは利用できますが、対応状況の確認が必要です。")
        case .unavailable:
            return item(.runtime, .blocking, "The configured executable is unavailable.", "設定済み実行ファイルを利用できません。")
        case .notChecked, .checking:
            return item(.runtime, .unknown, "Runtime readiness is not complete.", "ランタイム準備確認が完了していません。")
        }
    }

    private static func compatibilityItem(_ assessment: ProfileCompatibilityAssessment?) -> OperationalReadinessItem {
        guard let assessment else {
            return item(.compatibility, .unknown, "Profile compatibility is unavailable.", "プロファイル互換性を確認できません。")
        }
        switch assessment.level {
        case .compatible:
            return item(.compatibility, .ready, assessment.localizedDetail(language: .english), assessment.localizedDetail(language: .japanese))
        case .blocked:
            return item(.compatibility, .blocking, assessment.localizedDetail(language: .english), assessment.localizedDetail(language: .japanese))
        case .unknown:
            return item(.compatibility, .unknown, assessment.localizedDetail(language: .english), assessment.localizedDetail(language: .japanese))
        }
    }

    private static func modelHealthItem(
        _ report: RegisteredModelHealthReport?,
        hasSelection: Bool
    ) -> OperationalReadinessItem {
        guard hasSelection else {
            return item(.modelHealth, .blocking, "Select a model profile.", "モデルプロファイルを選択してください。")
        }
        guard let report else {
            return item(.modelHealth, .unknown, "Model health has not been checked.", "モデル健全性は未確認です。")
        }
        let detailEnglish = report.localizedDetail(language: .english)
        let detailJapanese = report.localizedDetail(language: .japanese)
        switch report.status {
        case .ready, .externalIdentifier, .duplicatePath:
            return item(.modelHealth, report.status == .duplicatePath ? .attention : .ready, detailEnglish, detailJapanese)
        case .incomplete, .missing:
            return item(.modelHealth, .blocking, detailEnglish, detailJapanese)
        case .uninspectable:
            return item(.modelHealth, .attention, detailEnglish, detailJapanese)
        }
    }

    private static func endpointItem(
        _ result: PortCheckResult?,
        selectedModel: ModelConfig?,
        selectedEndpointIsActive: Bool
    ) -> OperationalReadinessItem {
        guard selectedModel != nil else {
            return item(.endpoint, .blocking, "Select a model profile.", "モデルプロファイルを選択してください。")
        }
        if selectedEndpointIsActive {
            return item(
                .endpoint,
                .ready,
                "The selected managed or explicitly adopted endpoint is active. A busy port is expected and no external ownership is inferred.",
                "選択中の管理対象または明示採用した接続先が稼働中です。ポート使用中は正常で、外部プロセスの所有権は推定しません。"
            )
        }
        guard let result else {
            return item(.endpoint, .unknown, "Endpoint availability was not checked.", "接続先の利用可否は未確認です。")
        }
        switch result {
        case .available:
            return item(.endpoint, .ready, "The configured port is available.", "設定済みポートを利用できます。")
        case .busy:
            return item(.endpoint, .blocking, "The configured port is already in use.", "設定済みポートは使用中です。")
        case let .invalidInput(message), let .failed(_, _, message):
            return item(.endpoint, .attention, "Port check failed: \(message)", "ポート確認に失敗しました: \(message)")
        }
    }

    private static func resourceItem(
        _ forecast: StartResourceForecast?,
        hasSelection: Bool
    ) -> OperationalReadinessItem {
        guard hasSelection else {
            return item(.resourceForecast, .unknown, "Select a model to estimate resources.", "リソースを推定するモデルを選択してください。")
        }
        guard let forecast else {
            return item(.resourceForecast, .unknown, "Resource capacity could not be estimated.", "リソース容量を推定できません。")
        }
        let english = forecast.localizedDetail(language: .english)
        let japanese = forecast.localizedDetail(language: .japanese)
        switch forecast.assessment.level {
        case .safe:
            return item(.resourceForecast, .ready, english, japanese)
        case .caution:
            return item(.resourceForecast, .attention, english, japanese)
        case .critical:
            return item(.resourceForecast, .blocking, english, japanese)
        case .unavailable:
            return item(.resourceForecast, .unknown, english, japanese)
        }
    }

    private static func profileOptionsItem(
        _ compatibility: ProfileCompatibilityAssessment?,
        launchFailureDiagnosis: LaunchFailureDiagnosis?
    ) -> OperationalReadinessItem {
        if launchFailureDiagnosis?.category == .unsupportedOption {
            return item(
                .profileOptions,
                .blocking,
                "The latest launch failed because of an unsupported option.",
                "最新の起動は未対応オプションが原因で失敗しました。"
            )
        }
        guard let compatibility else {
            return item(.profileOptions, .unknown, "Profile options were not evaluated.", "プロファイル設定は未評価です。")
        }
        return compatibility.level == .blocked
            ? item(.profileOptions, .blocking, "Clear the unsupported options before launch.", "起動前に未対応オプションを解除してください。")
            : item(.profileOptions, .ready, "No known blocking profile option was detected.", "既知の起動阻害プロファイル設定は検出されませんでした。")
    }

    private static func sessionRecoveryItem(candidateCount: Int) -> OperationalReadinessItem {
        guard candidateCount > 0 else {
            return item(.sessionRecovery, .ready, "No unresolved prior-session endpoint remains.", "未解決の前回セッション接続先はありません。")
        }
        return item(
            .sessionRecovery,
            .attention,
            "\(candidateCount) prior-session endpoint candidate(s) need explicit review. Ownership is not restored.",
            "前回セッションの接続先候補が\(candidateCount)件あります。明示確認が必要で、所有権は復元されません。"
        )
    }

    private static func benchmarkItem(
        _ recommendations: [BenchmarkProfileTuningRecommendation],
        hasSelection: Bool
    ) -> OperationalReadinessItem {
        guard hasSelection else {
            return item(.benchmark, .unknown, "Select a model profile.", "モデルプロファイルを選択してください。")
        }
        guard !recommendations.isEmpty else {
            return item(
                .benchmark,
                .unknown,
                "No current, comparable multi-sample benchmark evidence is available.",
                "現在の条件と比較可能な複数サンプルのベンチマーク根拠がありません。"
            )
        }
        return item(
            .benchmark,
            .ready,
            "Comparable benchmark evidence is available for \(recommendations.count) use case(s).",
            "\(recommendations.count)用途について比較可能なベンチマーク根拠があります。"
        )
    }

    private static func hermesItem(path: String) -> OperationalReadinessItem {
        let normalized = NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        guard !normalized.isEmpty else {
            return item(.hermesAgent, .attention, "Hermes Agent config path is not configured.", "Hermes Agent設定ファイルパスが未設定です。")
        }
        if FileManager.default.fileExists(atPath: normalized) {
            return item(.hermesAgent, .ready, "The configured Hermes Agent file exists.", "設定済みHermes Agentファイルが存在します。")
        }
        return item(.hermesAgent, .attention, "The configured Hermes Agent file does not currently exist.", "設定済みHermes Agentファイルは現在存在しません。")
    }

    private static func item(
        _ kind: OperationalReadinessCheckKind,
        _ status: OperationalReadinessStatus,
        _ english: String,
        _ japanese: String
    ) -> OperationalReadinessItem {
        OperationalReadinessItem(
            kind: kind,
            status: status,
            detailEnglish: english,
            detailJapanese: japanese
        )
    }
}
