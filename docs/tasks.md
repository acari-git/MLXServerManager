# Tasks

## v0.1 Completed

- Define app settings and model configuration for executable path, host, port, API key placeholder, and model identifiers.
- Persist and restore `settings.json` and `models.json` under the user's Application Support directory.
- Implement process management service for Start, Stop, and Restart.
- Ensure Stop and Restart only target the managed process held by the app.
- Implement port availability checks before launch.
- Implement ready checks via `/v1/models`.
- Implement memory monitoring for the managed process.
- Implement bounded runtime log display with Clear Logs.
- Implement OpenAI-compatible connection copy actions:
  - Base URL
  - Model ID
  - JSON config
  - `curl /v1/models`
  - `curl /v1/chat/completions`
- Build SwiftUI views bound to observable state, without direct `Process` usage in views.

## v0.1 Manual Verification

- Start reaches Ready when `mlx_lm.server` responds on `/v1/models`.
- Stop terminates only the managed process and releases the port.
- Restart performs Stop, port release wait, Start, and Ready check.
- Port Check reports busy for occupied ports and available after Stop.
- Settings persist across app restart.
- Memory display updates while the managed process runs and clears after Stop.
- Logs remain bounded and Clear Logs leaves a single `[info] logs cleared` entry.
- Connection copy buttons produce OpenAI-compatible text for external clients.

## v0.2 Planned: Setup Diagnostics

1. Define `DiagnosticsResult` model.
   - Include diagnostic ID, title, status, message, optional details, and timestamp.
   - Support `pass`, `warning`, `fail`, and `notRun` states.
2. Add `SetupDiagnostics` service.
   - Keep validation and safe probe logic outside SwiftUI views.
   - Coordinate existing `SettingsStore`, `PortChecker`, and `ReadyChecker` where useful.
3. Add Diagnostics UI.
   - Add a Diagnostics panel or `Run Diagnostics` button.
   - Render structured results without embedding low-level validation logic in views.
4. Implement executable path validation.
   - Detect empty path.
   - Detect missing path.
   - Detect non-file path.
   - Detect non-executable path.
5. Implement safe executable probe.
   - Run `--help` or a similar safe command with a short timeout.
   - Capture and truncate stdout/stderr for Logs.
   - Do not start a server or load a model.
6. Implement host and port validation.
   - Validate non-empty host.
   - Validate TCP port range.
   - Warn when configuration is not local loopback for v0.2 local-first use.
7. Integrate Port Check.
   - Reuse the existing bind/listen based Port Check.
   - Report available, busy, and check failure.
   - If busy without a managed process, explain possible external process ownership.
8. Integrate Ready Check.
   - Reuse `GET /v1/models` only.
   - Do not call `/v1/chat/completions`.
   - Report `notRun` when no managed server is running.
9. Show configuration storage location.
   - Display the Application Support directory used by the app.
   - Show expected `settings.json` and `models.json` paths.
   - Keep runtime files outside Git.
10. Add diagnostics log output.
    - Log start, each check result, and a final summary.
    - Avoid secrets and truncate long output.
11. Add manual test checklist for Setup Diagnostics.
    - Empty path.
    - Missing path.
    - Non-executable file.
    - Valid executable path.
    - Invalid port.
    - Busy external port.
    - Available port.
    - Managed server Ready through `/v1/models`.
    - Stopped-server diagnostics: Port availability `pass`, Ready check `warning`.
    - Running managed-server diagnostics: Port availability `warning` with managed-server message, Ready check `pass`.
    - Diagnostics UI and Logs show matching results.
    - Diagnostics do not call `/v1/chat/completions`, run inference, launch `mlx_lm.server`, or stop external processes.
12. Keep deferred items out of v0.2.
    - Menu bar quick actions move to v0.3 or later.
    - LAN Web UI, App Intents, Auto unload, Proxy, Chat UI, and multiple server management stay out of scope.

## v0.3 Planned: Model Profile Editing

1. Define model profile editing requirements.
   - Editable fields: `modelID`, `displayName`, `host`, `serverPort`, `enableThinking`, and `notes`.
   - Keep multiple profile add/delete out of scope.
2. Add editable draft state.
   - Create a draft from the selected `ModelConfig`.
   - Avoid writing to saved model state on every keystroke.
3. Add validation for `modelID`, `host`, and `serverPort`.
   - Reject empty `modelID`.
   - Reject empty `host`.
   - Reject ports outside 1 through 65535.
4. Add edit UI.
   - Keep it within the existing model detail or settings area.
   - Avoid a large layout rewrite.
5. Add save and cancel actions.
   - Save valid edits to `models.json`.
   - Cancel should restore the last saved values.
   - Log save success and validation failures.
6. Refresh connection config after save.
   - Base URL, Model ID, JSON config, and copied curl text should reflect saved edits.
7. Ensure Start uses saved profile values.
   - Use edited `modelID`, `host`, and `serverPort` for the next launch.
8. Add running-process guard.
   - Disable runtime-affecting fields while a managed process is running, or show that Restart is required.
   - Prefer disabling `modelID`, `host`, and `serverPort` while running for v0.3.
9. Add manual test checklist.
   - `Edit Profile` opens from Model detail.
   - `displayName`, `modelID`, `host`, `serverPort`, `enableThinking`, and `notes` save successfully.
   - Empty `displayName` is filled with `modelID`.
   - Empty `modelID` does not save.
   - Empty `host` does not save.
   - Invalid ports `0`, `65536`, and `abc` do not save.
   - `Cancel` does not save draft changes.
   - Model detail updates after save.
   - Connection Settings, Copy Config, and copied curl text refresh after save.
   - Start uses saved edited `modelID`, `host`, and `serverPort`.
   - Changed `serverPort` can be used for Start and restored after Stop.
   - Running-process guard blocks `modelID`, `host`, and `serverPort` changes while a managed server is running.
   - `displayName`, `enableThinking`, and `notes` can still save while a managed server is running.
   - Start, Stop, and Restart continue to work after profile edits.
   - Edits are saved to local `models.json`, which remains outside Git.
   - Editing does not call `/v1/chat/completions`, run inference, launch `mlx_lm.server`, or stop external processes.
   - Editing does not use `pkill`, `killall`, or `pgrep`.
   - Direct Mode, no Proxy, and no Chat UI are maintained.
10. Keep deferred items out of v0.3.
    - Multiple model add/delete, multiple simultaneous servers, Hugging Face download manager, model file deletion, Proxy, Chat UI, LAN Web UI, App Intents, and Auto unload stay out of scope.

## Later

- Unit tests for services where practical.
- App Intents for start, stop, restart, and status.
- LAN Web UI.
- Proxy mode as an explicit opt-in architecture.
- Automatic unload policies.
- More advanced resource graphs.
- Hugging Face download manager.
- Multiple simultaneous server management.
- Presets for frequently used model configurations.
