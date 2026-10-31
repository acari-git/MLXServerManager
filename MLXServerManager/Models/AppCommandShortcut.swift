import SwiftUI

/// Keyboard shortcuts exposed through the app's menu bar commands.
///
/// The definitions are plain values so the key bindings and their localized
/// menu titles stay testable without launching the UI.
enum AppCommandShortcut: String, CaseIterable, Identifiable {
    /// Standard macOS "Settings…" item, bound to Command-Comma.
    case openSettings

    var id: String { rawValue }

    var key: KeyEquivalent {
        switch self {
        case .openSettings:
            ","
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .openSettings:
            .command
        }
    }

    /// Human-readable shortcut for documentation and help text.
    var displayText: String {
        switch self {
        case .openSettings:
            "⌘,"
        }
    }

    /// The workspace destination the shortcut navigates to.
    var destination: IntegratedWorkspaceDestination {
        switch self {
        case .openSettings:
            .settings
        }
    }

    func title(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .openSettings:
            return strings.text(english: "Settings…", japanese: "設定…")
        }
    }
}
