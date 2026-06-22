import SwiftUI

/// Top-level app destinations for the staged app shell.
///
/// Staged destinations are introduced without moving runtime controls,
/// persistence, networking, import/export, or process ownership behavior.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case profiles
    case inspector
    case logs
    case clientSetup
    case metrics

    var id: String { rawValue }

    static let v14NavigationOrder: [AppSection] = [
        .dashboard,
        .profiles,
        .clientSetup,
        .inspector,
        .metrics,
        .logs
    ]

    var title: String {
        localizedTitle(language: .english)
    }

    var subtitle: String {
        localizedSubtitle(language: .english)
    }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .dashboard:
            return strings.text(.dashboard)
        case .profiles:
            return strings.text(.models)
        case .inspector:
            return strings.text(.runtime)
        case .logs:
            return strings.text(.logs)
        case .clientSetup:
            return strings.text(.downloads)
        case .metrics:
            return strings.text(.settings)
        }
    }

    func localizedSubtitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .dashboard:
            return strings.text(.dashboardSubtitle)
        case .profiles:
            return strings.text(.modelsSubtitle)
        case .inspector:
            return strings.text(.runtimeSubtitle)
        case .logs:
            return strings.text(.logsSubtitle)
        case .clientSetup:
            return strings.text(.downloadsSubtitle)
        case .metrics:
            return strings.text(.settingsSubtitle)
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            "rectangle.grid.2x2"
        case .profiles:
            "square.stack.3d.up"
        case .inspector:
            "server.rack"
        case .logs:
            "doc.text.magnifyingglass"
        case .clientSetup:
            "arrow.down.circle"
        case .metrics:
            "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "app-section-\(rawValue)"
    }
}
