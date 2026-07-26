import Foundation

enum IntegratedWorkspaceDestination: String, CaseIterable, Identifiable, Hashable {
    case models
    case workspace
    case profiles
    case diagnostics
    case automation
    case agents
    case intelligence
    case platform
    case downloads
    case settings
    case logs

    var id: String { rawValue }

    static var primarySidebarDestinations: [IntegratedWorkspaceDestination] {
        [.models, .workspace, .profiles, .diagnostics, .automation, .agents, .intelligence, .platform, .downloads]
    }

    var title: String {
        title(language: .japanese)
    }

    func title(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .models:
            return strings.text(english: "Dashboard", japanese: "ダッシュボード")
        case .workspace:
            return strings.text(english: "Workspace", japanese: "ワークスペース")
        case .profiles:
            return strings.text(english: "Profile Library", japanese: "プロファイルライブラリ")
        case .diagnostics:
            return strings.text(english: "Diagnostics", japanese: "診断")
        case .automation:
            return strings.text(english: "Automation", japanese: "自動化")
        case .agents:
            return strings.text(english: "Multi-Agent Hub", japanese: "マルチエージェントハブ")
        case .intelligence:
            return strings.text(english: "Intelligence", japanese: "インテリジェンス")
        case .platform:
            return strings.text(english: "Platform", japanese: "プラットフォーム")
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
        case .workspace:
            "folder"
        case .profiles:
            "square.grid.2x2"
        case .diagnostics:
            "stethoscope"
        case .automation:
            "checklist"
        case .agents:
            "person.3.sequence"
        case .intelligence:
            "brain.head.profile"
        case .platform:
            "square.3.layers.3d"
        case .downloads:
            AppSymbol.downloads
        case .settings:
            AppSymbol.settings
        case .logs:
            AppSymbol.logs
        }
    }
}
