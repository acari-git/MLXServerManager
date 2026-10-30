# Keyboard Shortcuts

MLX Server Manager registers its keyboard shortcuts as standard macOS menu commands, so they appear in the menu bar and follow the system's key-equivalent handling.

## Shortcuts

| Shortcut | Menu item | Action |
| --- | --- | --- |
| `⌘,` | MLX Server Manager > Settings… (設定…) | Opens the Settings destination in the main window. |

## Behavior

- `⌘,` uses the standard macOS binding for application settings and replaces the `Settings…` slot of the application menu.
- If the main window is open, it is brought to the front and switches to Settings.
- If the main window was closed or minimized (the app keeps running from the menu bar), it is reopened or restored and then shows Settings. No duplicate window is created while one exists.
- If Settings is already shown, the shortcut only brings the window forward.
- Unsaved Settings drafts are not saved or discarded by the shortcut itself. Existing Settings behavior still applies: leaving the Settings destination discards the unsaved draft.
- The menu item title follows the app language setting (English `Settings…`, Japanese `設定…`).
- The shortcut only navigates. It does not start servers, run diagnostics, send requests, or change saved settings, and it does not affect Direct Mode.

## Implementation Notes

- `AppCommandShortcut` (`Models/AppCommandShortcut.swift`) defines the key, modifiers, display text, localized title, and target destination as testable values.
- `AppCommands` (`Views/AppCommands.swift`) registers the `CommandGroup(replacing: .appSettings)` command and is attached to the main `WindowGroup` with `.commands`.
- `AppViewModel.openSettingsRequested()` publishes a one-shot `pendingWorkspaceDestination`. `IntegratedWorkspaceView` consumes it on appear and on change, so the request also works when the window has to be reopened first.

## Adding Shortcuts

1. Add a case to `AppCommandShortcut` with its key, modifiers, display text, title, and destination.
2. Register the command in `AppCommands`.
3. Add the case to `AppCommandShortcutTests` and check that its binding does not duplicate an existing one.
4. Update the table above.
