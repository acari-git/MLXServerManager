import Foundation

nonisolated enum RuntimeReadinessStatus: String, Equatable, Sendable {
    case notChecked
    case checking
    case ready
    case warning
    case unavailable

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .notChecked:
            return strings.text(english: "Not checked", japanese: "未確認")
        case .checking:
            return strings.text(english: "Checking", japanese: "確認中")
        case .ready:
            return strings.text(english: "Ready", japanese: "準備完了")
        case .warning:
            return strings.text(english: "Needs review", japanese: "要確認")
        case .unavailable:
            return strings.text(english: "Unavailable", japanese: "利用不可")
        }
    }
}

nonisolated enum RuntimeReadinessIssue: Equatable, Sendable {
    case notChecked
    case checking
    case pathNotConfigured
    case fileMissing
    case notExecutable
    case capabilityProbeUnavailable
    case ready(supportedFlagCount: Int?)

    var status: RuntimeReadinessStatus {
        switch self {
        case .notChecked:
            .notChecked
        case .checking:
            .checking
        case .pathNotConfigured, .fileMissing, .notExecutable:
            .unavailable
        case .capabilityProbeUnavailable:
            .warning
        case .ready:
            .ready
        }
    }

    func localizedDetail(
        backend: InferenceBackend,
        executablePath: String,
        language: AppLanguage
    ) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .notChecked:
            return strings.text(
                english: "Run the explicit readiness check to verify this runtime.",
                japanese: "明示的な準備確認を実行して、このランタイムを確認してください。"
            )
        case .checking:
            return strings.text(
                english: "Checking the configured executable without starting a server.",
                japanese: "サーバーを起動せず、設定済みの実行ファイルを確認しています。"
            )
        case .pathNotConfigured:
            return strings.text(
                english: "Configure the executable path before using this backend.",
                japanese: "このバックエンドを使う前に実行ファイルパスを設定してください。"
            )
        case .fileMissing:
            return strings.text(
                english: "No file exists at the configured path: \(executablePath)",
                japanese: "設定されたパスにファイルがありません: \(executablePath)"
            )
        case .notExecutable:
            return strings.text(
                english: "The configured file is not executable: \(executablePath)",
                japanese: "設定されたファイルを実行できません: \(executablePath)"
            )
        case .capabilityProbeUnavailable:
            return strings.text(
                english: "The executable is available, but its optional-flag capability probe could not be completed. Launch preflight will remain conservative.",
                japanese: "実行ファイルは利用できますが、オプション対応状況の確認を完了できませんでした。起動前確認は保守的に継続します。"
            )
        case let .ready(supportedFlagCount):
            if backend == .mlxLM, let supportedFlagCount {
                return strings.text(
                    english: "Executable verified. Detected \(supportedFlagCount) supported command flags.",
                    japanese: "実行ファイルを確認しました。対応するコマンドフラグを\(supportedFlagCount)件検出しました。"
                )
            }
            return strings.text(
                english: "Executable path and execute permission are ready.",
                japanese: "実行ファイルパスと実行権限を確認しました。"
            )
        }
    }
}

nonisolated struct RuntimeReadinessReport: Identifiable, Equatable, Sendable {
    let backend: InferenceBackend
    let executablePath: String
    let issue: RuntimeReadinessIssue
    let checkedAt: Date?

    var id: InferenceBackend { backend }
    var status: RuntimeReadinessStatus { issue.status }

    static func initial(backend: InferenceBackend, executablePath: String) -> RuntimeReadinessReport {
        RuntimeReadinessReport(
            backend: backend,
            executablePath: executablePath,
            issue: .notChecked,
            checkedAt: nil
        )
    }

    static func checking(backend: InferenceBackend, executablePath: String) -> RuntimeReadinessReport {
        RuntimeReadinessReport(
            backend: backend,
            executablePath: executablePath,
            issue: .checking,
            checkedAt: nil
        )
    }
}

nonisolated struct RuntimeReadinessViewState: Equatable, Sendable {
    private(set) var reports: [RuntimeReadinessReport]
    private(set) var isChecking: Bool

    static func initial(settings: AppSettings = .defaults) -> RuntimeReadinessViewState {
        RuntimeReadinessViewState(
            reports: InferenceBackend.allCases.map { backend in
                RuntimeReadinessReport.initial(
                    backend: backend,
                    executablePath: settings.executablePath(for: backend)
                )
            },
            isChecking: false
        )
    }

    mutating func begin(settings: AppSettings) {
        reports = InferenceBackend.allCases.map { backend in
            RuntimeReadinessReport.checking(
                backend: backend,
                executablePath: settings.executablePath(for: backend)
            )
        }
        isChecking = true
    }

    mutating func complete(_ reports: [RuntimeReadinessReport]) {
        self.reports = InferenceBackend.allCases.compactMap { backend in
            reports.first { $0.backend == backend }
        }
        isChecking = false
    }

    mutating func cancel(settings: AppSettings) {
        reports = InferenceBackend.allCases.map { backend in
            RuntimeReadinessReport.initial(
                backend: backend,
                executablePath: settings.executablePath(for: backend)
            )
        }
        isChecking = false
    }

    func report(for backend: InferenceBackend) -> RuntimeReadinessReport {
        reports.first { $0.backend == backend }
            ?? RuntimeReadinessReport.initial(backend: backend, executablePath: "")
    }
}
