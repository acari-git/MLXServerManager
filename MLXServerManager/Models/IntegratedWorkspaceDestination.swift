import Foundation

enum IntegratedWorkspaceDestination: String, CaseIterable, Identifiable {
    case models
    case downloads
    case settings
    case logs
    case help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .models:
            "モデル一覧"
        case .downloads:
            "ダウンロード"
        case .settings:
            "設定"
        case .logs:
            "ログ"
        case .help:
            "ヘルプ"
        }
    }

    var systemImageName: String {
        switch self {
        case .models:
            "list.bullet.rectangle"
        case .downloads:
            "arrow.down.circle"
        case .settings:
            "gearshape"
        case .logs:
            "doc.text"
        case .help:
            "questionmark.circle"
        }
    }
}
