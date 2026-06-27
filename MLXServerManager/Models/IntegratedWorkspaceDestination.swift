import Foundation

enum IntegratedWorkspaceDestination: String, CaseIterable, Identifiable {
    case models
    case downloads
    case settings
    case logs

    var id: String { rawValue }

    var title: String {
        title(language: .japanese)
    }

    func title(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .models:
            return strings.text(english: "Models", japanese: "モデル一覧")
        case .downloads:
            return strings.text(english: "Downloads", japanese: "ダウンロード")
        case .settings:
            return strings.text(english: "Settings", japanese: "設定")
        case .logs:
            return strings.text(english: "Logs", japanese: "ログ")
        }
    }

    var systemImageName: String {
        switch self {
        case .models:
            AppSymbol.models
        case .downloads:
            AppSymbol.downloads
        case .settings:
            AppSymbol.settings
        case .logs:
            AppSymbol.logs
        }
    }
}
