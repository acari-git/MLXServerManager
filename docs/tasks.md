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

## v0.4 Planned: Menu Bar Quick Actions

1. Define menu bar requirements.
   - Show managed server status in the macOS menu bar.
   - Provide quick Start, Stop, Restart, Run Diagnostics, Open App, Connection Settings, and Quit actions.
   - Keep the menu bar surface lightweight.
2. Define menu bar app architecture.
   - Reuse existing `AppViewModel` state and actions.
   - Keep process control, diagnostics, port checks, and ready checks out of SwiftUI menu views.
   - Avoid duplicating process management logic.
3. Add status display.
   - Map runtime state into `stopped`, `starting`, `ready`, `stopping`, and `failed`.
   - Use text or a simple icon.
   - Ensure status display itself does not start `mlx_lm.server`.
4. Add Start, Stop, and Restart actions.
   - Call the same behavior used by the main window buttons.
   - Stop only the process held by this app.
   - Do not use `pkill`, `killall`, or `pgrep`.
5. Add Run Diagnostics action.
   - Reuse existing Setup Diagnostics behavior.
   - Do not call `/v1/chat/completions`.
   - Do not run model inference.
6. Add Open App and Connection Settings actions.
   - Open or focus the main app window.
   - Either focus the existing Connection Settings panel or show a compact read-only summary.
   - Reuse existing connection config output if copy actions are added later.
7. Define Quit behavior.
   - Provide a normal app quit command.
   - Decide whether managed processes are left running or stopped on quit before implementation.
   - Never stop external `mlx_lm.server` processes.
8. Add manual test checklist.
   - App launch shows a macOS menu bar item.
   - Initial menu bar title is `MLX: stopped`.
   - Main window and menu bar show the same status.
   - Menu bar shows Base URL and Model ID.
   - `Open App` shows and activates the main window.
   - Menu bar `Start` starts the managed server.
   - Main window changes from starting to ready after menu bar Start.
   - Menu bar title changes to `MLX: ready` after Start.
   - Menu bar `Run Diagnostics` updates Diagnostics and Logs in the main window.
   - Menu bar `Restart` preserves Stop, port release, Start, and Ready behavior.
   - Menu bar `Stop` stops only the managed process.
   - Main window and menu bar return to stopped after Stop.
   - Main-window Start, Stop, and Restart still work.
   - Menu bar `Quit` exits normally.
   - Menu bar actions reuse existing `AppViewModel` actions.
   - No separate menu bar process manager exists.
   - Menu bar actions do not call `/v1/chat/completions`, run inference, start a server just for status, enter the inference path, or stop external processes.
   - Stop targets only the managed process.
   - `pkill`, `killall`, and `pgrep` are not used.
   - Direct Mode, no Proxy, and no Chat UI are maintained.
   - `settings.json`, `models.json`, model files, and user-specific fixed paths stay out of Git.
9. Keep deferred items out of v0.4.
   - New model add/delete, multiple simultaneous servers, Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, Hugging Face download manager, model download, model file deletion, full log viewer redesign, and notarization stay out of scope.

## v0.5 Planned: Distribution Build Documentation

1. Define distribution build requirements.
   - Document local personal-use build assumptions.
   - Explain Debug build and Release build differences.
   - Keep Direct Mode, no Proxy, and no Chat UI.
2. Document Release build commands.
   - Add Xcode manual build steps.
   - Add `xcodebuild` Debug and Release examples.
   - Document `.app` output locations.
   - Record the verified Release command using `/tmp/MLXServerManagerReleaseDerivedData` and `CODE_SIGNING_ALLOWED=NO`.
   - Record the verified `BUILD SUCCEEDED` result.
3. Add local app usage checklist.
   - Configure `mlx_lm.server executable path` in the app UI.
   - Run Setup Diagnostics.
   - Confirm Start, Ready Check, Stop, Memory, and Menu bar quick actions.
   - Keep verification independent from model inference.
   - Confirm `open -n`, process existence, and normal quit for the Release `.app`.
4. Add signing and Gatekeeper notes.
   - Explain local builds for personal use.
   - Explain Apple Developer Program limitations for formal distribution.
   - State that notarization is not performed in v0.5.
   - State that `CODE_SIGNING_ALLOWED=NO` is an unsigned local verification build.
5. Document App Sandbox rationale.
   - Explain why sandboxing is disabled for user-selected local process launch and managed Stop.
   - Keep the scope limited to managed local process control.
   - Do not recommend stopping external processes.
6. Define release asset policy.
   - Do not include model files.
   - Do not include `settings.json` or `models.json`.
   - Do not include derived data.
   - Document caveats before attaching `.app` bundles to GitHub Releases.
7. Add build artifact ignore policy.
   - Keep `.app` bundles, derived data, logs, model files, `.env`, and `HF_TOKEN` out of Git.
   - Use placeholders such as `<path-to-mlx_lm.server>` in docs.
8. Add manual test checklist.
   - Debug build succeeds.
   - Release build succeeds.
   - `.app` bundle exists in the expected build products directory.
   - Verified Release output example: `/tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app`.
   - Verified app bundle size example: `916K`.
   - Local launch works.
   - Process existence can be confirmed after `open -n`.
   - Normal quit works.
   - Setup Diagnostics works after configuring the executable path.
   - Start, Stop, and Menu bar quick actions work.
   - `/v1/chat/completions` is not sent by the app.
   - No model inference is required for distribution verification.
   - Runtime files, model files, and build artifacts are not staged.
   - Window-name inspection through `osascript` is not required.
9. Prepare v0.5 tag.
   - Confirm docs are consistent with Direct Mode.
   - Confirm no Swift code or Xcode project settings changed for v0.5 Step 1.
   - Confirm build artifact policy is documented before tagging.
   - Confirm final Git status is clean after Release build verification.
10. Keep deferred items out of v0.5.
    - Notarization, Apple Developer Program formal distribution, DMG creation, Sparkle, Homebrew cask, App Store, CI/CD, GitHub Actions, model bundling, automatic `mlx-lm` installation, Hugging Face download manager, Proxy, Chat UI, LAN Web UI, App Intents, and Auto unload stay out of scope.

## v0.6 Planned: Model Profile Management

1. Define model profile management requirements.
   - Add profiles from the UI.
   - Delete profiles from the UI.
   - Persist add and delete results to `models.json`.
   - Keep multiple simultaneous server management out of scope.
2. Define add profile draft defaults.
   - Start with an empty `modelID`.
   - Fill empty `displayName` from `modelID` on save.
   - Default host to `127.0.0.1`.
   - Default port to the app default, usually `8080`.
   - Default `enableThinking` to `false`.
   - Default `notes` to empty.
3. Add profile validation.
   - Reject empty `modelID`.
   - Reject empty `host`.
   - Reject invalid ports outside 1 through 65535.
   - Reject duplicate `modelID` values for v0.6.
   - Log validation failures.
4. Add profile UI.
   - Place `Add Profile` near the model list.
   - Reuse or extend the existing profile editor flow.
   - Select the newly added profile after save.
   - Refresh Model detail, Connection Settings, Copy Config, and copied curl text.
5. Add delete profile confirmation.
   - Place `Delete Profile` near selected model detail or profile editing.
   - Require confirmation before deletion.
   - Make clear that profile deletion does not delete model files.
6. Add delete guard for the last profile.
   - Prevent deleting the final remaining profile.
   - Show a UI message and Logs entry when blocked.
7. Add delete guard while a managed server is running.
   - Block Delete Profile while any managed server is running.
   - Explain that the managed server must be stopped before deleting profiles.
   - Avoid ambiguity between selected UI profile and active runtime profile.
8. Add selected model fallback after deletion.
   - Select the first remaining profile after deleting the selected profile.
   - Never leave the app with no selected profile while profiles exist.
9. Persist changes to `models.json`.
   - Save after valid add.
   - Save after confirmed delete.
   - Log save success and failure.
   - Keep `models.json` outside Git.
10. Add manual test checklist.
    - Add Profile button is visible.
    - Add Profile opens a draft editor.
    - Cancel add preserves the current profile list.
    - Empty `modelID` and empty `host` fail validation.
    - Invalid ports `0`, `65536`, and `abc` fail validation.
    - Duplicate `modelID` fails validation.
    - Empty `displayName` is filled with `modelID`.
    - Valid add saves to `models.json`.
    - Valid add selects the new profile while stopped.
    - Valid add while running does not auto-select and does not affect the running server.
    - Delete Profile shows confirmation.
    - Delete confirmation explains that only the saved profile is removed.
    - Delete confirmation explains that model files and Hugging Face cache are not deleted.
    - Cancel delete preserves the profile.
    - Confirm delete removes only the profile entry.
    - Last profile cannot be deleted.
    - Delete is blocked while a managed server is running.
    - Selection fallback works after deletion.
    - Model detail, Connection Settings, Copy Config, and copied curl text refresh after add/delete.
    - Logs show add/delete success, failures, and fallback selection.
    - Edit Profile, Start, Stop, Restart, Run Diagnostics, menu bar quick actions, and Release build checks still work.
    - Profile add/delete does not delete model files or Hugging Face cache.
    - Profile add/delete does not download models.
    - Profile add/delete does not call `/v1/chat/completions`, run inference, launch `mlx_lm.server`, or stop external processes.
    - Profile add/delete does not use `pkill`, `killall`, or `pgrep`.
    - Direct Mode, no Proxy, and no Chat UI are maintained.
11. Prepare v0.6 tag.
    - Confirm docs are consistent with Direct Mode.
    - Confirm profile management modifies only `models.json` profile data.
    - Confirm runtime files, model files, `.app` bundles, and build artifacts stay outside Git.
12. Keep deferred items out of v0.6.
    - Multiple simultaneous server management, multiple model launches, model file deletion, Hugging Face download manager, model download, automated model existence checks, Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, CI/CD, notarization, DMG creation, and App Store distribution stay out of scope.

## v0.7 Planned: Model Switching Improvements

1. Define model switching requirements.
   - Document selected model, running model, pending selection, and Restart-required behavior.
   - Keep Direct Mode, no Proxy, and no Chat UI.
2. Add selected model vs running model state.
   - Store the selected profile separately from the profile snapshot used to start the managed process.
   - Compare runtime fields: `modelID`, `host`, and `serverPort`.
3. Add Restart-required state.
   - Show `Restart required` when a managed server is running and selected runtime fields differ from running runtime fields.
   - Do not treat metadata-only fields as runtime changes by themselves.
4. Improve model list UI.
   - Make selected profile state clear.
   - Preserve existing add, edit, and delete behavior.
5. Add running model display.
   - Show the running profile while a managed process exists.
   - Keep the display read-only and concise.
6. Define switch while stopped behavior.
   - Selecting a model while stopped updates Model detail and Connection Settings immediately.
   - Start uses the selected profile.
7. Define switch while running behavior.
   - Allow selecting another profile while running.
   - Do not stop, start, or restart automatically.
   - Show `Restart required` when runtime fields differ.
   - Log that the selected profile will apply after Restart.
8. Implement restart-to-apply behavior.
   - Restart uses the existing Stop -> port release wait -> Start flow.
   - Restart starts the currently selected profile.
   - Stop continues to target only the managed process.
9. Maintain connection settings consistency.
   - Keep Base URL, Model ID, Copy Config, and copied curl commands tied to the selected profile.
   - Show running model separately when the active server differs.
10. Add model switching logs.
    - Log selection changes.
    - Log selected/running mismatch.
    - Log Restart-required state.
    - Log Restart applying the selected profile.
11. Add manual test checklist.
    - Multiple profiles are visible and selectable.
    - Stopped state shows `Running Model: Not running`.
    - Stopped state shows the selected profile with a `Selected` label.
    - Stopped state does not show `Restart required`.
    - Stopped selection updates detail and connection copy output.
    - Start uses the selected profile and marks it as the running model after Ready.
    - Running profile shows a `Running` label in the model list.
    - Running selection changes selected profile without changing the running server.
    - Running selection does not stop or start the server.
    - Running selection shows `Restart required` when runtime fields differ.
    - Model list, Status panel, Model detail, and menu bar title show Restart-required state where available.
    - Connection Settings, Copy Config, and copied curl commands follow the selected profile.
    - Restart applies the selected profile and clears Restart-required state after Ready.
    - Stop clears the running model, preserves selected profile, and stops only the managed process.
    - Add/Edit/Delete, Diagnostics, Menu bar actions, Debug build, and Release build continue to work.
    - Model switching does not add multiple simultaneous server management or multiple model simultaneous startup.
    - Model switching does not call `/v1/chat/completions`, run inference, launch from selection alone, delete model files, download models, stop external processes, or use `pkill`, `killall`, or `pgrep`.
12. Prepare v0.7 tag.
    - Confirm docs and UI behavior match the selected/running model policy.
    - Confirm Direct Mode, no Proxy, and no Chat UI are maintained.
    - Confirm runtime files, model files, `.app` bundles, and build artifacts stay outside Git.
13. Keep deferred items out of v0.7.
    - Multiple simultaneous server management, multiple model launches, Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, Hugging Face download manager, model download, model file deletion, automated model existence checks, RAG, embedding management, tool-call translation, CI/CD, notarization, DMG creation, and App Store distribution stay out of scope.

## v0.8 Planned: Logging and Diagnostics Usability

1. Define logging and diagnostics requirements.
   - Preserve Direct Mode, no Proxy, and no Chat UI.
   - Keep diagnostics safe and local.
2. Standardize log categories and levels.
   - Use categories such as `info`, `warning`, `error`, `start`, `stop`, `restart`, `diagnostics`, `profile`, and `switching`.
   - Keep existing bounded log behavior.
3. Improve LogView readability.
   - Keep the existing LogView structure.
   - Improve text scanning first.
   - Show existing log categories in a form that is easy to scan.
   - Do not add filter or search in v0.8 Step 2.
4. Add Copy Logs action.
   - Copy current bounded logs to the pasteboard.
   - Log copy success and empty-log handling.
   - Do not upload logs or send them externally.
   - Preserve Clear Logs.
5. Improve Diagnostics summary.
   - Make pass, warning, and failure counts easy to scan.
   - Add Copy Diagnostics Summary for local clipboard troubleshooting.
   - Show what to inspect next when a check fails or warns.
6. Improve Diagnostics warning/error visibility.
   - Make `pass`, `warning`, and `fail` easy to distinguish.
   - Keep executable path, Port Check, Ready Check, and storage path checks organized.
7. Improve Start/Stop/Restart log consistency.
   - Make command summary, pid, port release, Ready Check, and Stop result easy to follow.
   - Do not log secrets.
8. Improve profile and switching log consistency.
   - Make add/edit/delete outcomes easy to follow.
   - Make selected model, running model, and Restart-required logs easy to follow.
9. Add manual test checklist.
   - Logs are readable line by line and remain bounded.
   - Categories such as `[start]`, `[stop]`, `[restart]`, `[diagnostics]`, `[profile]`, `[switching]`, `[warning]`, `[error]`, and `[info]` are easy to scan.
   - Copy Logs works and logs `[info] copied logs to clipboard`.
   - Copy Logs does not break when logs are empty or immediately after Clear Logs.
   - Clear Logs still works and logs `[info] logs cleared`.
   - Diagnostics shows `No diagnostics run yet.` before the first run.
   - Copy Diagnostics Summary warns when no diagnostics results exist.
   - Diagnostics summary shows pass, warning, and failure counts.
   - Diagnostics warnings and failures are easy to find.
   - Each Diagnostics row clearly shows `PASS`, `WARNING`, or `FAIL`.
   - Copy Diagnostics Summary copies summary plus each check name, status, and message.
   - Start/Stop/Restart logs are understandable.
   - Profile and switching logs are understandable.
   - Logs and diagnostics do not call `/v1/chat/completions`, run inference, start `mlx_lm.server` automatically, upload data, create file-persistent logs, delete model files, stop external processes, or use `pkill`, `killall`, or `pgrep`.
10. Prepare v0.8 tag.
    - Confirm docs and UI behavior match the logging and diagnostics policy.
    - Confirm Direct Mode, no Proxy, and no Chat UI are maintained.
    - Confirm runtime files, model files, `.app` bundles, and build artifacts stay outside Git.
11. Keep deferred items out of v0.8.
    - Remote log sending, telemetry, crash reporting service, analytics, external log collection, cloud logging, file-persistent logs, automatic log upload, Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, Hugging Face download manager, model download, model file deletion, multiple simultaneous server management, CI/CD, notarization, DMG creation, and App Store distribution stay out of scope.

## v0.9 Planned: Unsigned Zip Distribution

1. Define distribution requirements.
   - Preserve Direct Mode, no Proxy, and no Chat UI.
   - Keep packaging independent from model inference.
2. Define unsigned Release asset policy.
   - Treat the asset as an unsigned local-use build.
   - State that the zip contains only `MLXServerManager.app`.
   - State that runtime settings, model profiles, model files, Hugging Face cache, logs, and secrets are not included.
3. Document zip creation commands.
   - Reuse the Release `xcodebuild` command.
   - Document `ditto -c -k --norsrc --noextattr --keepParent`.
   - Use `/tmp/MLXServerManagerReleaseDerivedData` as an example temporary DerivedData path.
4. Document Release asset contents verification.
   - Use `unzip -l` to confirm zip contents.
   - Use `du -h` to confirm zip size.
   - Confirm the zip has no AppleDouble `._*` metadata files.
   - Use `git ls-files` to confirm `.app`, `.zip`, `.dSYM`, build artifacts, runtime settings, secrets, and model files are not tracked.
5. Document local launch verification after unzip.
   - Unzip into a temporary location.
   - Launch with `open -n`.
   - Confirm app startup, menu bar item, main window, and normal quit.
   - Do not require model inference or `/v1/chat/completions`.
6. Add release note template.
   - Explain unsigned local-use status.
   - Explain Gatekeeper, quarantine, signing, and notarization caveats.
   - State Direct Mode and no Chat UI.
7. Add final v0.9 verification checklist.
   - Release build succeeds.
   - Zip contains only the app bundle.
   - Verified v0.9 outputs: app size `1.1M`, zip size `284K`.
   - No runtime settings, secrets, model files, `.app`, `.zip`, `.dSYM`, or build artifacts are tracked by Git.
   - Direct Mode, no Proxy, and no Chat UI are maintained.
8. Prepare v0.9 tag.
   - Confirm docs and Release asset policy match.
   - Confirm v0.9 does not perform notarization, DMG creation, CI/CD, GitHub Actions, App Store distribution, model download, or model file deletion.
9. Keep deferred items out of v0.9.
   - Notarization, Developer ID signing, DMG creation, Sparkle, CI/CD, GitHub Actions, App Store distribution, Homebrew cask, installer creation, runtime settings bundling, model file bundling, Hugging Face cache bundling, Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, Hugging Face download manager, model download, model file deletion, and multiple simultaneous server management stay out of scope.

## v1.0 Planned: Stable Scope and Release Readiness

1. Update README and stable scope docs.
   - Describe MLX Server Manager as a pure `mlx_lm.server` manager.
   - State Direct Mode clearly.
   - State that OpenAI-compatible clients connect directly to `mlx_lm.server`.
   - State that the app is not a Chat UI, Proxy, alternate backend wrapper, model downloader, or multi-server orchestrator.
2. Add known limitations docs.
   - Document unsigned app, no notarization, and Gatekeeper warnings.
   - Document that `mlx-lm`, model files, and Hugging Face cache are not bundled.
   - Document that Ready Check is `/v1/models` only and the app does not test chat completions.
   - Document that Stop and Restart affect only the app-managed process.
3. Document first-run workflow.
   - Prepare `mlx-lm`.
   - Configure `mlx_lm.server executable path`.
   - Configure a Model Profile.
   - Run Diagnostics, Start, Ready Check, copy connection settings, configure a client, Stop or Restart.
4. Add v1.0 manual regression checklist.
   - Clean Git status.
   - Debug and Release builds.
   - Start, Stop, Restart, Port Check, Ready Check, Diagnostics, Logs, model profiles, model switching, menu bar actions, and connection copy.
5. Add release note template.
   - Mention v1.0 stable release.
   - Mention Direct Mode, managed `mlx_lm.server`, model profiles, diagnostics/logging, unsigned zip asset, known limitations, and safety boundaries.
6. Prepare final Debug and Release build verification.
   - Confirm both builds succeed before tagging.
   - Do not create build artifacts inside Git.
7. Prepare unsigned zip asset verification.
   - Use `ditto -c -k --norsrc --noextattr --keepParent`.
   - Confirm zip contents, size, unzip launch, and no forbidden files.
8. Prepare v1.0 tag.
   - Confirm docs and stable scope match implemented behavior.
   - Confirm Direct Mode, no Proxy, and no Chat UI are maintained.
9. Keep deferred items out of v1.0.
   - Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, Hugging Face download manager, model download, model deletion, Hugging Face cache deletion, multiple concurrent server management, multiple model simultaneous launch, RAG, embedding manager, tool-call translation, telemetry, analytics, crash reporting, external log sending, cloud logging, persistent file logging, notarization, Developer ID signing, DMG, App Store distribution, Homebrew cask, auto updater, CI/CD, and GitHub Actions release automation stay out of scope.

## Later

- Unit tests for services where practical.
- LAN Web UI.
- Proxy mode as an explicit opt-in architecture.
- Automatic unload policies.
- More advanced resource graphs.
- App Intents for start, stop, restart, and status.
- Hugging Face download manager.
- Presets for frequently used model configurations.
- DMG or zip packaging.
- Notarization.
- Automated release workflows.
