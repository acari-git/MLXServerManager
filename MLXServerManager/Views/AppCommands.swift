import AppKit
import SwiftUI

/// Menu bar commands for the app.
///
/// Replaces the standard "Settings…" slot in the application menu so
/// Command-Comma opens the in-window Settings destination.
struct AppCommands: Commands {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(AppCommandShortcut.openSettings.title(language: viewModel.settings.uiLanguage)) {
                openSettings()
            }
            .keyboardShortcut(
                AppCommandShortcut.openSettings.key,
                modifiers: AppCommandShortcut.openSettings.modifiers
            )
        }
    }

    private func openSettings() {
        viewModel.openSettingsRequested()
        if !MainWindowPresenter.presentExistingWindow() {
            openWindow(id: "main")
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

/// Brings an already-created main window to the front instead of opening a
/// duplicate window.
@MainActor
enum MainWindowPresenter {
    /// Returns `true` when an existing window was shown.
    static func presentExistingWindow() -> Bool {
        let window = NSApplication.shared.windows.first { candidate in
            candidate.canBecomeMain
                && !candidate.isKind(of: NSPanel.self)
                && (candidate.isVisible || candidate.isMiniaturized)
        }
        guard let window else {
            return false
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }
}
