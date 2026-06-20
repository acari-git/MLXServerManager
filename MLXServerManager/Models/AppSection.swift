import SwiftUI

/// Top-level app destinations for the staged app shell.
///
/// Staged destinations are introduced without moving runtime controls,
/// persistence, networking, import/export, or process ownership behavior.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case profiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .profiles:
            "Profiles"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            "Current Direct Mode control surface"
        case .profiles:
            "Model profile list surface"
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            "rectangle.grid.2x2"
        case .profiles:
            "list.bullet.rectangle"
        }
    }

    var accessibilityIdentifier: String {
        "app-section-\(rawValue)"
    }
}
