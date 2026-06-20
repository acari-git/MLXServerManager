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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .profiles:
            "Profiles"
        case .inspector:
            "Inspector"
        case .logs:
            "Logs"
        case .clientSetup:
            "Client Setup"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            "Current Direct Mode control surface"
        case .profiles:
            "Model profile list surface"
        case .inspector:
            "Selected profile detail surface"
        case .logs:
            "Managed log context surface"
        case .clientSetup:
            "OpenAI-compatible setup values"
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            "rectangle.grid.2x2"
        case .profiles:
            "list.bullet.rectangle"
        case .inspector:
            "sidebar.right"
        case .logs:
            "doc.text.magnifyingglass"
        case .clientSetup:
            "link.badge.plus"
        }
    }

    var accessibilityIdentifier: String {
        "app-section-\(rawValue)"
    }
}
