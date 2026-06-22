import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case japanese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            "System"
        case .japanese:
            "Japanese"
        case .english:
            "English"
        }
    }

    var resolved: AppLanguage {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("ja") ? .japanese : .english
        case .japanese, .english:
            return self
        }
    }
}

struct AppLocalization {
    let language: AppLanguage

    init(language: AppLanguage) {
        self.language = language.resolved
    }

    func text(_ key: AppTextKey) -> String {
        switch language {
        case .japanese:
            key.japanese
        case .english, .system:
            key.english
        }
    }
}

enum AppTextKey {
    case dashboard
    case models
    case downloads
    case runtime
    case settings
    case logs
    case dashboardSubtitle
    case modelsSubtitle
    case downloadsSubtitle
    case runtimeSubtitle
    case settingsSubtitle
    case logsSubtitle
    case language
    case saveSettings
    case runDiagnostics
    case nextActions
    case recentActivity
    case start
    case stop
    case restart
    case speedTest
    case copyHermes
    case copyOpenAICompatible
    case search
    case download
    case retry
    case cancel
    case downloadQueue
    case noRuntimeEvents
    case runtimeControls
    case benchmark
    case connectionPresets

    var english: String {
        switch self {
        case .dashboard: "Dashboard"
        case .models: "Models"
        case .downloads: "Downloads"
        case .runtime: "Runtime"
        case .settings: "Settings"
        case .logs: "Logs"
        case .dashboardSubtitle: "Overview and next actions"
        case .modelsSubtitle: "Model profiles and inspector"
        case .downloadsSubtitle: "Search, download, and recovery"
        case .runtimeSubtitle: "Start, diagnose, and benchmark"
        case .settingsSubtitle: "App settings and language"
        case .logsSubtitle: "Logs and troubleshooting"
        case .language: "Language"
        case .saveSettings: "Save Settings"
        case .runDiagnostics: "Run Diagnostics"
        case .nextActions: "Next actions"
        case .recentActivity: "Recent activity"
        case .start: "Start"
        case .stop: "Stop"
        case .restart: "Restart"
        case .speedTest: "Speed Test"
        case .copyHermes: "Copy Hermes"
        case .copyOpenAICompatible: "Copy OpenAI-compatible"
        case .search: "Search"
        case .download: "Download"
        case .retry: "Retry"
        case .cancel: "Cancel"
        case .downloadQueue: "Download queue"
        case .noRuntimeEvents: "No runtime events in this session."
        case .runtimeControls: "Runtime controls"
        case .benchmark: "Benchmark"
        case .connectionPresets: "Connection presets"
        }
    }

    var japanese: String {
        switch self {
        case .dashboard: "ダッシュボード"
        case .models: "モデル"
        case .downloads: "ダウンロード"
        case .runtime: "ランタイム"
        case .settings: "設定"
        case .logs: "ログ"
        case .dashboardSubtitle: "概要と次の操作"
        case .modelsSubtitle: "モデル profile と詳細"
        case .downloadsSubtitle: "検索・取得・復旧"
        case .runtimeSubtitle: "起動・診断・benchmark"
        case .settingsSubtitle: "アプリ設定と言語"
        case .logsSubtitle: "ログと troubleshooting"
        case .language: "言語"
        case .saveSettings: "設定を保存"
        case .runDiagnostics: "診断を実行"
        case .nextActions: "次の操作"
        case .recentActivity: "最近のアクティビティ"
        case .start: "起動"
        case .stop: "停止"
        case .restart: "再起動"
        case .speedTest: "スピードテスト"
        case .copyHermes: "Hermes 設定をコピー"
        case .copyOpenAICompatible: "OpenAI互換設定をコピー"
        case .search: "検索"
        case .download: "ダウンロード"
        case .retry: "再試行"
        case .cancel: "キャンセル"
        case .downloadQueue: "ダウンロード queue"
        case .noRuntimeEvents: "この session の runtime event はありません。"
        case .runtimeControls: "ランタイム操作"
        case .benchmark: "Benchmark"
        case .connectionPresets: "接続 preset"
        }
    }
}
