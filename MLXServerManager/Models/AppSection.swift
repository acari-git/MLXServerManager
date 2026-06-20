import SwiftUI

/// Top-level app destinations for the staged app shell.
///
/// v6.0.0 intentionally exposes only Dashboard so navigation can be introduced
/// without moving runtime controls, persistence, networking, import/export, or
/// process ownership behavior.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            "Current Direct Mode control surface"
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            "rectangle.grid.2x2"
        }
    }

    var accessibilityIdentifier: String {
        "app-section-\(rawValue)"
    }
}
