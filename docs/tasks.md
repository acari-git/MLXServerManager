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
   - `git diff --check` passes.
   - `v1.0.0` tag does not exist yet.
   - `v0.1.0` through `v0.9.0` tags exist.
   - Debug and Release builds.
   - Start, Stop, Restart, Port Check, Ready Check, Diagnostics, Logs, model profiles, model switching, menu bar actions, and connection copy.
   - Forbidden files and personal fixed paths are absent.
5. Add release note template.
   - Mention v1.0 stable release.
   - Mention Direct Mode, managed `mlx_lm.server`, model profiles, diagnostics/logging, unsigned zip asset, known limitations, and safety boundaries.
6. Prepare final Debug and Release build verification.
   - Confirm both builds succeed before tagging.
   - Do not create build artifacts inside Git.
7. Prepare unsigned zip asset verification.
   - Use `ditto -c -k --norsrc --noextattr --keepParent`.
   - Confirm zip contents, size, unzip launch, and no forbidden files.
   - Confirm `settings.json`, `models.json`, model files, `.env`, `HF_TOKEN`, `.dSYM`, DerivedData, logs, Hugging Face cache, and AppleDouble `._*` metadata files are not included.
8. Prepare v1.0 tag.
   - Confirm docs and stable scope match implemented behavior.
   - Confirm Direct Mode, no Proxy, and no Chat UI are maintained.
9. Keep deferred items out of v1.0.
   - Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, Hugging Face download manager, model download, model deletion, Hugging Face cache deletion, multiple concurrent server management, multiple model simultaneous launch, RAG, embedding manager, tool-call translation, telemetry, analytics, crash reporting, external log sending, cloud logging, persistent file logging, notarization, Developer ID signing, DMG, App Store distribution, Homebrew cask, auto updater, CI/CD, and GitHub Actions release automation stay out of scope.

## v1.0.1 Planned: Maintenance Verification

1. Create maintenance plan.
   - Keep v1.0.1 limited to light verification, docs clarifications, wording fixes, obvious bug fixes, and release asset verification.
   - Do not add new product scope.
2. Re-download and verify the v1.0.0 Release asset.
   - Download `MLXServerManager-v1.0.0-unsigned.zip` from GitHub Release.
   - Confirm the zip contains only `MLXServerManager.app/`.
   - Confirm runtime settings, model files, secrets, `.dSYM`, DerivedData, logs, Hugging Face cache, and AppleDouble `._*` metadata are absent.
   - Extract and launch with `open -n`.
   - Quit the verification process and confirm no verification process remains.
3. Review first-run documentation.
   - Confirm users can find where to configure `mlx_lm.server executable path`.
   - Confirm users can understand model profile setup.
   - Confirm users can find Connection Settings copy actions.
   - Confirm Direct Mode and "app is not in the inference request path" are clear.
4. Review Gatekeeper notes.
   - Confirm unsigned app, no notarization, and possible Gatekeeper warnings are visible.
   - Clarify wording if users may misunderstand the unsigned local-use status.
   - Document the observed "damaged and can't be opened" quarantine warning.
   - Explain that users should verify the Release asset and checksum before removing quarantine with `xattr`.
5. Run lightweight regression pass.
   - Start, Stop, Restart, Port Check, Ready Check, Run Diagnostics, Logs, Menu bar, and Connection Settings.
   - Confirm `/v1/chat/completions` remains copy-only text and is not executed by the app.
6. Apply README/docs wording fixes if needed.
   - Fix typos, omissions, and inconsistent wording.
   - Keep changes small and release-focused.
7. Prepare v1.0.1 final verification.
   - Confirm Git status is clean.
   - Confirm forbidden files are not tracked.
   - Confirm Direct Mode, no Proxy, and no Chat UI are maintained.
8. Prepare v1.0.1 tag.
   - Tag only after asset re-download verification and lightweight regression pass.
9. Keep deferred items out of v1.0.1.
   - New features, large UI changes, Proxy, Chat UI, LAN Web UI, App Intents, Auto unload, model downloader, model deletion, Hugging Face cache deletion, multiple concurrent server management, automatic updates, DMG, notarization, CI/CD, GitHub Actions release automation, App Store distribution, and Xcode project setting changes stay out of scope.

## v1.0.2 Planned: First-Run Quick Start Maintenance

1. Improve README Quick Start.
   - Add a short first-run path near the top of README.
   - Cover Release asset download, zip extraction, Gatekeeper warning, app launch, Settings, Model Profile, Run Diagnostics, Start, and Connection Settings copy.
2. Clarify Gatekeeper handling.
   - Keep the damaged-app warning visible.
   - State that users should verify the Release asset, zip contents, and checksum before using `xattr`.
   - Use `/path/to/MLXServerManager.app` placeholders only.
3. Clarify bundled dependency boundaries.
   - State that `mlx-lm`, `mlx_lm.server`, model files, and Hugging Face cache are not bundled.
4. Keep Direct Mode concise.
   - State that the app is not in the inference path.
   - State that OpenAI-compatible clients connect directly to `mlx_lm.server`.
5. Link to detailed docs.
   - Point README readers to distribution and known limitations docs.
6. Keep v1.0.2 maintenance-only.
   - No Swift code changes, UI changes, new features, Xcode project changes, app binaries, zip creation, or tag creation.
   - Proxy, Chat UI, model downloader, auto updater, notarization, DMG, CI/CD, and GitHub Actions remain out of scope.

## v1.0.3 Planned: Benchmark-Informed Documentation Update

1. Add benchmark findings.
   - Add `docs/benchmark_findings.md`.
   - Summarize workload-dependent benchmark results for oMLX and pure `mlx_lm.server`.
   - State that MLX Server Manager does not claim to be faster than oMLX in every workload.
2. Add README link.
   - Link to benchmark-informed product direction from the README.
   - Keep the README wording modest and direct.
3. Update known limitations.
   - State that local benchmarks are workload-dependent.
   - State that MLX Server Manager does not guarantee faster performance than oMLX or other backends.
   - State that Advanced `mlx_lm.server` options are not enabled by default.
   - State that the app does not proxy inference requests.
4. Keep v1.0.3 docs-only.
   - No app code changes.
   - No Swift changes.
   - No Xcode project changes.
   - No new `.app`, `.zip`, `.dSYM`, DerivedData, or release asset.
   - Direct Mode is maintained.
5. Keep Advanced Launch Options future optional work.
   - v1.1 candidate: Advanced Launch Options design.
   - Future optional controls may include raw extra launch args, chat template args, prompt cache related options, prefill/decode/concurrency related options, command preview, and validation.
   - Aggressive defaults are avoided.
6. Keep deferred architecture out of scope.
   - Proxy mode remains deferred.
   - Chat UI remains deferred.
   - Multi-backend wrapper behavior remains deferred.
   - Automatic tuning remains deferred.

## v1.0.4 Planned: Public Repository Readiness Documentation

1. Improve README for public visitors.
   - Clarify OSS-facing project purpose.
   - Add or improve Why this project exists.
   - Add or improve What this is not.
   - Clarify supported OpenAI-compatible client context.
   - Clarify current binary asset and docs-only release history.
   - Add AI-assisted maintenance notes.
   - Add README screenshot.
   - Improve public repository presentation.
2. Add contribution guidance.
   - Add `CONTRIBUTING.md`.
   - Document project scope, Direct Mode boundary, welcome contributions, out-of-scope changes, development safety rules, repository hygiene, basic checks, and human-reviewed AI-assisted workflow.
3. Add security policy.
   - Add `SECURITY.md`.
   - Document latest-release best effort support, security reporting, local-only assumptions, unsigned app warnings, secrets/log safety, artifact safety, process safety, and inference boundary.
4. Add public release checklist.
   - Add `docs/public_release_checklist.md`.
   - Include secrets check, tracked file check, personal path check, binary artifact check, README check, release check, screenshot check, GitHub repo settings check, recommended topics, and Codex OSS readiness notes.
   - Confirm README screenshot is checked for secrets, personal paths, and public display safety.
5. Keep v1.0.4 docs-only.
   - No app code changes.
   - No Swift changes.
   - No Xcode project changes.
   - No new `.app`, `.zip`, `.dSYM`, DerivedData, or release asset.
   - Direct Mode is maintained.
   - Proxy mode, Chat UI, model downloader, model deletion, and multi-backend wrapper behavior remain out of scope.

## v1.1 Planned: Advanced Launch Options Design

1. Add Advanced Launch Options design documentation.
   - Add `docs/advanced_launch_options.md`.
   - Document goals, non-goals, Direct Mode boundary, optional behavior, candidate options, UI design, data model design, argument construction, validation, safety boundaries, tests, and future work.
2. Keep this step docs-only.
   - No app code changes in this design step.
   - No Swift changes.
   - No Xcode project changes.
   - No new `.app`, `.zip`, `.dSYM`, DerivedData, or release asset.
3. Maintain Direct Mode.
   - MLX Server Manager remains outside the inference request path.
   - Advanced Launch Options affect only the future `mlx_lm.server` launch command.
4. Keep Advanced Launch Options optional.
   - Do not enable advanced settings by default.
   - Omit empty advanced values from launch arguments.
   - Avoid aggressive tuning defaults.
   - Defer implementation to a later step.
5. Preserve architecture boundaries.
   - SwiftUI views should not construct `Process` arguments directly.
   - Future flow should remain `ModelConfig -> ModelLaunchRequest -> ModelProcessManager argument builder`.

## v1.2 In Progress: Advanced Launch Options Initial Implementation

1. Add per-profile Advanced Launch Options data model.
   - Add optional `advancedLaunchOptions` to `ModelConfig`.
   - Preserve loading compatibility for existing `models.json` files without advanced fields.
   - Keep empty advanced values omitted from launch arguments.
2. Add launch argument builder support.
   - Keep simple launch unchanged when advanced options are unset.
   - Preserve the `ModelConfig -> ModelLaunchRequest -> ModelProcessManager argument builder` flow.
   - Append structured advanced options only when explicitly set.
   - Append `rawExtraArgs` last only when explicitly set.
3. Add Model Profile Editor UI.
   - Add a collapsed Advanced Launch Options disclosure.
   - Add optional fields for structured options and raw extra args.
   - Show workload-dependent warning copy.
   - Show a read-only launch command preview.
4. Add validation.
   - Validate bounded numeric fields.
   - Validate positive integer fields.
   - Validate `chatTemplateArgs` as JSON when set.
   - Surface validation errors before saving.
5. Preserve safety boundaries.
   - Direct Mode is maintained.
   - No Proxy mode.
   - No Chat UI.
   - No app-executed `/v1/chat/completions`.
   - No new app binary or release asset in this implementation step.

## v1.2.1 In Progress: Advanced Launch Options Polish

1. Improve command preview usability.
   - Add Copy Preview near the read-only launch command preview.
   - Copy the preview generated by `ModelProcessManager.commandPreview`.
   - Log copy success or failure from the ViewModel.
2. Add Clear Advanced Options.
   - Reset the draft advanced options to empty values.
   - Return the preview to simple launch behavior when cleared.
   - Treat the action as a small utility action, not a destructive profile delete.
3. Improve validation messages.
   - Use clearer `must be between 0 and 1` messages for Temperature, Top P, and Min P.
   - Keep positive integer messages item-specific.
   - Keep Chat Template Args JSON validation clear.
4. Preserve safety boundaries.
   - Direct Mode is maintained.
   - No Proxy mode.
   - No Chat UI.
   - No app-executed `/v1/chat/completions`.
   - No new app binary or release asset in this polish step.

## v1.2.2 Completed: Advanced Launch Options README and Docs Polish

1. Add Advanced Launch Options screenshot to README.
   - Use `screenshots/advanced-launch-options.png`.
   - Explain Copy Preview, Clear Advanced Options, validation, and simple launch preservation.
2. Expand Advanced Launch Options docs.
   - Add screenshot section.
   - Document Copy Preview and Clear Advanced Options.
   - Document validation examples.
   - Clarify that raw extra args are expert-only.
3. Keep this step docs-only.
   - No Swift changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, or DerivedData.
4. Preserve product boundaries.
   - Direct Mode is maintained.
   - No Proxy mode.
   - No Chat UI.
   - No multi-backend wrapper behavior.

## v1.3.0 Completed: Hermes Agent Connection Guide

1. Add Hermes Agent and OpenAI-compatible client guide.
   - Add `docs/hermes_agent_connection.md`.
   - Document Direct Mode boundary.
   - Document example Base URL, Model ID, API key placeholder, and curl checks.
   - Treat Hermes Agent as an OpenAI-compatible client without assuming internal configuration details.
2. Link from README.
   - Add a short link from Supported Client Context.
   - Clarify that MLX Server Manager remains outside the inference request path.
3. Keep this step docs-only.
   - No Swift changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, or DerivedData.
4. Preserve product boundaries.
   - Direct Mode is maintained.
   - No Proxy mode.
   - No Chat UI.
   - No multi-backend wrapper behavior.

## v1.4.0 Completed: External Server Detection Design

1. Add external server detection design docs.
   - Add `docs/external_server_detection.md`.
   - Document managed server versus external server ownership.
   - Document conservative detection through `GET /v1/models`.
   - Document UI states for port conflict and external server detected.
2. Keep this step docs-only.
   - No Swift changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, or DerivedData.
3. Preserve Direct Mode.
   - MLX Server Manager remains outside the inference request path.
   - Detection does not add Proxy mode, Chat UI, or multi-backend wrapper behavior.
4. Preserve external process ownership boundaries.
   - External processes are not managed by the app.
   - Stop and Restart remain scoped to app-managed processes.
   - External server detection is status and connection-setting support only.

## v1.5.0 In Progress: External Server Detection Initial Implementation

1. Add detect-only external server state.
   - Represent an external OpenAI-compatible server detected on the selected host and port.
   - Keep managed process state separate from external server status.
   - Show that external servers are not managed by MLX Server Manager.
2. Extend Start flow safely.
   - If the selected port is available, keep the managed launch path unchanged.
   - If the selected port is occupied, check `GET /v1/models` on the same host and port.
   - If `/v1/models` returns HTTP 200, show external server detected and do not launch a managed process.
   - If `/v1/models` fails, keep the existing port conflict behavior.
3. Preserve process ownership boundaries.
   - Stop and Restart remain scoped to app-managed processes.
   - External server logs and memory monitoring are not collected.
   - External server PID discovery and Adopt External Server remain out of scope.
4. Preserve product boundaries.
   - Direct Mode is maintained.
   - No Proxy mode.
   - No Chat UI.
   - No multi-backend wrapper behavior.
   - Detection uses `/v1/models` only.

## v1.5.1 Completed: GitHub Issue Templates

1. Add GitHub issue templates.
   - Add `.github/ISSUE_TEMPLATE/bug_report.yml`.
   - Add `.github/ISSUE_TEMPLATE/feature_request.yml`.
   - Add `.github/ISSUE_TEMPLATE/config.yml`.
2. Keep this repo maintenance scoped to docs/config only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, or DerivedData.
3. Preserve product boundaries.
   - Direct Mode boundary is reflected in feature requests.
   - Issue templates do not frame Proxy mode, Chat UI, or multi-backend wrapper behavior as default directions.
   - Bug reports ask users to remove personal paths, tokens, API keys, and secrets before posting.

## v1.6.0 Completed: Adopt External Server Design

1. Add Adopt External Server design docs.
   - Add `docs/adopt_external_server.md`.
   - Define Adopt as connection context, not process ownership.
   - Document managed server, external server detected, and adopted external server terminology.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, or DerivedData.
3. Preserve Direct Mode and process ownership boundaries.
   - MLX Server Manager remains outside the inference request path.
   - External processes are not stopped or restarted by the app.
   - Stop and Restart remain scoped to app-managed processes.
   - Adopted external servers use connection context only.
4. Link related docs.
   - Link README to the Adopt External Server design.
   - Link `docs/external_server_detection.md` to the separated adopt design.

## v1.7.0 In Progress: Adopt External Server Initial Implementation

1. Add adopted external server runtime state.
   - Represent Adopted External Server separately from External Server Detected.
   - Keep adopted external servers outside managed process ownership.
   - Show adopted state as connection context only.
2. Add Adopt and Forget actions.
   - Adopt is available only from External Server Detected state.
   - Forget clears only the app-side adopted context.
   - Neither action starts, stops, restarts, or modifies the external process.
3. Update UI and menu bar actions.
   - Show Adopt External Server for detected external servers.
   - Show Forget External Server for adopted external servers.
   - Keep Stop and Restart disabled unless an app-managed process exists.
4. Preserve Direct Mode and process ownership boundaries.
   - MLX Server Manager remains outside the inference request path.
   - Adopt means connection context, not process ownership.
   - Detection and readiness continue to use `/v1/models`.
   - No external process kill, stop, restart, memory monitoring, or log collection.

## v1.8.0 Completed: Connection Settings Polish Design

1. Add Connection Settings Polish design docs.
   - Add `docs/connection_settings_polish.md`.
   - Define Current Connection Target summary behavior.
   - Cover Managed Server, External Server Detected, Adopted External Server, and Not Running / Not Connected states.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, or DerivedData.
3. Preserve Direct Mode and ownership boundaries.
   - Connection Settings polish is display and copy UX only.
   - MLX Server Manager remains outside the inference request path.
   - No inference proxy, Chat UI, or multi-backend wrapper behavior.
   - No external process ownership changes.
4. Define copy action direction.
   - Copy Base URL, Model ID, API key placeholder, JSON client config, Hermes Agent config, readiness curl, OpenAI-compatible chat example, and all connection settings.
   - Keep `/v1/chat/completions` examples as client-side helper text only.
   - Keep copied default config free of secrets.

## v1.9.0 Completed: Connection Settings Polish Implementation

1. Add Current Target summary to Connection Settings.
   - Show Target Type, Base URL, Model ID, API key placeholder, readiness/status summary, and ownership note.
   - Cover Managed Server, External Server Detected, Adopted External Server, and Not Running / Not Connected states.
2. Expand copy actions.
   - Add Copy API Key Placeholder.
   - Add Copy All Connection Settings.
   - Add Copy Hermes Agent Config.
   - Rename `/v1/models` copy as Copy curl Readiness Check.
   - Keep chat-completions text as a client-side example only.
3. Keep implementation scoped to display and copy UX.
   - App code changed only around Connection Settings and copy text generation.
   - Direct Mode is maintained.
   - No inference proxy, Chat UI, or multi-backend wrapper behavior.
   - Advanced Launch Options behavior is unchanged.
4. Preserve lifecycle and ownership boundaries.
   - Stop and Restart remain scoped to app-managed processes.
   - External detected and adopted servers remain not managed by MLX Server Manager.
   - No external process kill, stop, restart, memory monitoring, or log collection.

## v2.0.0 Completed: Public README and Docs Polish

1. Refresh README for the current public feature set.
   - Describe MLX Server Manager as a Direct Mode control surface for managed `mlx_lm.server` and adopted external connection context.
   - Add a clear What This Is section.
   - Keep What This Is Not and non-goals visible.
   - Update the feature list to reflect v1.9.0 behavior.
2. Clarify binary asset status.
   - v2.0.0 is docs/public polish only.
   - No new app binary or zip asset is created.
   - Current downloadable app binary remains the v1.9.0 unsigned build.
3. Update public docs consistency.
   - Remove stale future-only wording from External Server Detection, Adopt External Server, and Connection Settings polish docs.
   - Keep Direct Mode, no Proxy, no Chat UI, and no multi-backend wrapper boundaries intact.
4. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new `.app`, `.zip`, `.dSYM`, DerivedData, or release asset.
5. Note future optional presentation work.
   - Refresh screenshots when new v1.9+ UI screenshots are available.
   - Keep screenshot refresh as optional public polish, not a blocker for this docs update.

## v2.1.0 Completed: Screenshot Refresh Design

1. Add screenshot refresh planning docs.
   - Add `docs/screenshot_refresh.md`.
   - Define recommended screenshots for main dashboard, Connection Settings Current Target, External Server Detected, Adopted External Server, Advanced Launch Options, and logs / diagnostics.
   - Document capture scenarios for managed, external detected, adopted external, and advanced options states.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
   - No screenshot image files added yet.
3. Preserve Direct Mode and product boundaries.
   - Screenshots must not imply Proxy mode, Chat UI, or multi-backend wrapper behavior.
   - External server screenshots must preserve the connection-context-only and not-managed wording.
4. Add public screenshot safety checklist.
   - No real API keys, Hugging Face tokens, GitHub tokens, private paths, personal home paths, local shell history, or private repository URLs.
   - Prefer `127.0.0.1`, port `8080`, and `not-required-local` for public examples.

## v2.2.0 Completed: Screenshot Refresh

1. Add updated README screenshots.
   - Add `screenshots/main-dashboard-v2.2.png`.
   - Add `screenshots/connection-settings-current-target-v2.2.png`.
   - Add `screenshots/adopted-external-server-v2.2.png`.
2. Update README screenshot section.
   - Show Main Dashboard.
   - Show Connection Settings / Current Target summary.
   - Show Adopted External Server state.
   - Keep Direct Mode and no-proxy wording near the screenshots.
3. Keep this step docs/public polish only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
4. Follow screenshot privacy checklist.
   - No real API keys, tokens, private paths, personal home paths, or private repository URLs.
   - Use local example values such as `127.0.0.1`, port `8080`, and `not-required-local`.

## v2.3.0 Completed: Onboarding / First-run Guidance Design

1. Add onboarding and first-run guidance docs.
   - Add `docs/onboarding_first_run.md`.
   - Document first-run checklist, required setup, recommended launch flow, managed server flow, external server flow, Connection Settings flow, and Hermes Agent setup flow.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
3. Preserve product boundaries.
   - Direct Mode is maintained.
   - MLX Server Manager remains outside the inference request path.
   - No Proxy mode, Chat UI, multi-backend wrapper behavior, model downloader, or model deleter.
   - External process ownership boundaries remain clear.
4. Document safe first-run concepts.
   - `mlx_lm.server executable path`.
   - Model Profile host, port, and model ID.
   - `/v1/models` readiness.
   - API key placeholder as local dummy config.
   - Adopt External Server as connection context only.

## v2.4.0 Completed: Onboarding / First-run Guidance Initial Implementation

1. Add a small Onboarding Guidance panel.
   - Add app-side guidance for first-run and unconfigured states.
   - Keep the panel lightweight; no large wizard UI.
   - Show only short next-step guidance.
2. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - MLX Server Manager remains outside the inference request path.
   - No Proxy mode, Chat UI, multi-backend wrapper behavior, model downloader, model deleter, or install automation.
   - External process ownership boundaries remain clear.
   - No external process kill, stop, or restart.
3. Keep existing lifecycle behavior unchanged.
   - Start / Stop / Restart enabled states are not changed by onboarding guidance.
   - Adopt / Forget behavior remains unchanged.
   - Advanced Launch Options behavior remains unchanged.

## v2.5.0 Completed: Onboarding Guidance Screenshot Refresh

1. Add onboarding guidance screenshot.
   - Add `screenshots/onboarding-guidance-v2.5.png`.
   - Confirm the screenshot is available before linking it from README.
2. Update README screenshot section.
   - Keep the existing Main Dashboard, Connection Settings / Current Target, and Adopted External Server screenshots.
   - Add First-run Onboarding Guidance.
   - Explain that the panel is informational only.
3. Keep this step docs/public polish only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
4. Follow screenshot privacy checklist.
   - No real API keys, tokens, private paths, personal home paths, or private repository URLs.
   - Direct Mode is maintained.

## v2.6.0 Completed: Model Profile Import / Export Design

1. Add Model Profile import/export design.
   - Add `docs/model_profile_import_export.md`.
   - Define future JSON export format, import preview behavior, validation behavior, conflict handling, and testing plan.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
3. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - Import/export is profile metadata only.
   - No model weights, caches, API keys, tokens, secrets, executable paths, or runtime settings are exported by default.
   - Import does not automatically start servers.
   - External process ownership boundaries remain unchanged.
   - No external process kill, stop, or restart.

## v2.7.0 Completed: Export Profiles Implementation

1. Implement Export Profiles only.
   - Add model profile export schema and export service.
   - Add `Export Profiles...` button near Model Profiles.
   - Save pretty printed JSON as `MLXServerManager-Profiles.json` by default.
   - Show UI privacy summary and export result message.
2. Keep Import Profiles deferred.
   - No Import Profiles implementation.
   - No Import Preview implementation.
   - No conflict handling implementation.
3. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - Export is profile metadata only.
   - No model weights, caches, API keys, tokens, secrets, executable paths, runtime state, PID, memory metrics, readiness result, or adopted external state are exported.
   - Export does not start, stop, restart, adopt, forget, readiness-check, or call external endpoints.
   - External process ownership boundaries remain unchanged.
4. Release note.
   - v2.7.0 is an app-code release and requires a new app binary asset when released.

## v2.8.0 Completed: Import Profiles Preview / Validation Design Polish

1. Refine future Import Profiles design.
   - Document Import Preview sheet contents.
   - Document validation result structure.
   - Document validation severities: error, warning, and info.
   - Document unsupported `schemaVersion` handling.
   - Document duplicate and conflict handling.
   - Document Advanced Launch Options validation for import.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
3. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - Import Profiles is not implemented.
   - Export Profiles remains implemented.
   - Import Preview must be side-effect-free.
   - No model weights, caches, API keys, tokens, secrets, executable paths, or local paths are imported.
   - No automatic server start.
   - No selected target or adopted external server ownership change.
   - No external process kill, stop, restart, or ownership change.
4. Future staging.
   - v2.9.0: Import Preview implementation.
   - v3.0.0: Import selected valid profiles.
   - Future: Conflict handling polish.
   - Future: Import/export schema tests and fixtures.

## v2.9.0 Completed: Import Profiles Preview Implementation

1. Implement Import Profiles Preview only.
   - Add `Import Profiles...` button near `Export Profiles...`.
   - Add JSON file picker.
   - Add Import Preview sheet.
   - Show source file, `schemaVersion`, `app`, `exportedAt`, profile counts, warning count, document messages, profile validation rows, conflict summary, and planned action summary.
2. Add import preview validation service.
   - Decode selected JSON safely.
   - Validate document-level schema.
   - Validate profile metadata.
   - Validate Advanced Launch Options consistently with existing app rules.
   - Detect conflicts for preview.
   - Ignore unsupported unknown fields as data only.
3. Keep actual import deferred.
   - No profile import or save.
   - No write to `models.json`.
   - No skip, rename, or replace execution.
   - No selected profile mutation.
4. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - Import Preview is model profile metadata validation only.
   - No model weights, caches, API keys, tokens, secrets, executable paths, or local paths are imported.
   - No automatic server start.
   - No readiness check or `/v1/models` call from Import Preview.
   - No external HTTP request from Import Preview.
   - No external process kill, stop, restart, adoption, forget, or ownership change.
5. Release note.
   - v2.9.0 is an app-code release and requires a new app binary asset when released.

## v3.0.0 Completed: Import Selected Profiles Implementation

1. Implement selected profile import.
   - Add selection controls to Import Preview.
   - Select valid non-conflicting profiles by default.
   - Disable invalid profiles.
   - Disable conflict profiles.
   - Add `Import Selected Profiles`.
   - Add confirmation before saving.
2. Save selected valid non-conflicting profile metadata.
   - Append selected importable profiles to the existing model profile list.
   - Persist the updated list through the existing `models.json` save path.
   - Re-check validation and conflicts before saving.
   - Keep selected profile unchanged after import.
3. Keep conflict handling limited.
   - Conflict profiles are skipped and disabled.
   - Rename is not implemented.
   - Replace is not implemented.
   - Conflict handling polish remains future work.
4. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - Import saves model profile metadata only.
   - Invalid profiles are blocked.
   - No model weights, caches, API keys, tokens, secrets, executable paths, local paths, runtime state, PID, memory metrics, readiness result, selected target state, or adopted external state are imported.
   - No automatic server start.
   - No readiness check or `/v1/models` call from Import Profiles.
   - No external HTTP request from Import Profiles.
   - No external process kill, stop, restart, adoption, forget, or ownership change.
5. Release note.
   - v3.0.0 is an app-code release and requires a new app binary asset when released.

## v3.1.0 Completed: Project Principles / Product Direction

1. Add project direction documentation.
   - Add `docs/product_direction.md`.
   - Document Project Principles, Product Direction, performance-first policy, CLI-friendly `mlx-lm` workflow, Direct Mode boundary, feature adoption policy, current non-goals, future candidate features, model download position, safety/privacy boundaries, and release roadmap framing.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
3. Clarify product principles.
   - `mlx-lm` runtime performance is the top priority.
   - The app should make `mlx-lm` usable for users who are not comfortable with CLI workflows.
   - Useful features may be adopted when they do not conflict with performance, safety, or Direct Mode boundaries.
4. Clarify model download position.
   - Model download is a current non-goal.
   - Model download remains a future candidate under strict performance, safety, privacy, and user-control conditions.
   - Model deletion remains out of current scope and must be handled cautiously.
5. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - No inference proxy, Chat UI, multi-backend router, hidden request rewriting, or automatic external process ownership changes.
   - Convenience features must not silently start, stop, restart, download, import secrets, or obscure process ownership.

## v3.2.0 Completed: Conflict Handling Design Polish

1. Add conflict handling design polish.
   - Update `docs/model_profile_import_export.md`.
   - Document current v3.0.0 Import Selected Profiles behavior.
   - Document conflict types, default behavior, Rename design, Replace design, duplicate handling, confirmation requirements, selection behavior, logging, safety boundaries, and future implementation staging.
2. Keep this step docs-only.
   - No Swift changes.
   - No app code changes.
   - No Xcode project changes.
   - No new app binary, zip asset, `.dSYM`, DerivedData, or release asset.
3. Preserve current import behavior.
   - Valid non-conflicting profiles can be imported.
   - Invalid profiles are blocked.
   - Conflict profiles are currently skipped and disabled.
   - Rename and Replace remain future work.
4. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - `mlx-lm` runtime performance remains the top priority.
   - Conflict handling remains model profile metadata only.
   - No model weights, caches, API keys, tokens, secrets, executable paths, or local paths are imported.
   - No automatic server start.
   - No `/v1/models` call or external HTTP request from Import Profiles.
   - No external process kill, stop, restart, adoption, forget, or ownership change.
   - Replace requires explicit confirmation in the future design.

## v3.3.0 Completed: Rename Conflicted Profiles Implementation

1. Implement Rename for profile-name conflicts only.
   - Add per-profile import actions in Import Preview: `Skip`, `Import`, and `Rename`.
   - Keep valid non-conflicting profiles selected for import by default.
   - Keep conflicts visible in preview.
   - Allow Rename only for otherwise valid profile-name conflicts.
   - Keep Replace unavailable and future work.
2. Validate renamed names.
   - Empty and whitespace-only rename names are rejected.
   - Rename names that conflict with existing local profiles are rejected.
   - Rename names that conflict with another selected import are rejected.
   - Rename is revalidated before saving imported profiles.
3. Preserve metadata-only import behavior.
   - Rename changes only the imported profile display name before saving it as a new profile.
   - Existing local profiles are not overwritten.
   - `modelID`, host, port, Advanced Launch Options, runtime state, selected profile, and adopted external server state are not changed by Rename.
4. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - No Replace implementation.
   - No model download or model deletion.
   - No inference proxy, Chat UI, or multi-backend router.
   - No automatic server start.
   - No `/v1/models` call or external HTTP request from Import Profiles.
   - No external process kill, stop, restart, adoption, forget, or ownership change.
5. Release note.
   - v3.3.0 is an app-code release and requires a new app binary asset when released.

## v3.4.0 Completed: Replace Conflicted Profiles Implementation

1. Implement explicit Replace for safe existing-profile conflicts.
   - Add per-profile import action: `Replace`.
   - Offer Replace only when the imported row maps to exactly one existing local profile target.
   - Detect replacement targets by existing profile name, `modelID`, and `modelID + host + port`.
   - Keep ambiguous targets unavailable.
   - Keep automatic Replace unavailable.
2. Require confirmation before Replace.
   - Show the existing profile being replaced.
   - Show before / after metadata summary.
   - State that Replace updates saved profile metadata only.
   - State that model files, caches, logs, server processes, secrets, and external ownership are not affected.
3. Preserve Rename and import behavior.
   - Keep valid non-conflicting profiles selected for import by default.
   - Keep Rename limited to profile-name conflicts.
   - Keep Rename validation for empty names, existing local names, and selected import collisions.
   - Block duplicate selected Replace actions for the same existing profile target.
4. Apply Replace conservatively.
   - Update display name, `modelID`, host, port, and Advanced Launch Options from imported metadata.
   - Preserve local-only fields not present in the export document: family, quantization, thinking setting, and notes.
   - Recalculate local name from the replacement `modelID`.
   - Preserve selected profile identity when the selected profile itself is replaced and its `modelID` changes.
5. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - No model download or model deletion.
   - No inference proxy, Chat UI, or multi-backend router.
   - No automatic server start.
   - No `/v1/models` call or external HTTP request from Import Profiles.
   - No external process kill, stop, restart, adoption, forget, or ownership change.
6. Release note.
   - v3.4.0 is an app-code release and requires a new unsigned app binary asset when released.
   - v3.5.0 should focus on import/export fixtures and tests.

## v3.5.0 Completed: Import / Export Fixtures and Tests

1. Add deterministic import/export fixtures.
   - Add schema v1 fixtures under `MLXServerManagerTests/Fixtures/`.
   - Cover valid single and multiple profile documents.
   - Cover invalid missing required fields and whitespace-only names.
   - Cover duplicate imported profile names and duplicate imported runtime identities.
   - Cover existing name conflicts, existing runtime identity conflicts, Rename scenarios, Replace scenarios, ambiguous Replace targets, duplicate Replace targets, and export round-trip compatibility.
2. Add minimal XCTest coverage.
   - Add `MLXServerManagerTests`.
   - Cover import preview validation and document-level blocking errors.
   - Cover Rename behavior for profile-name conflicts.
   - Cover Replace target detection by name, `modelID`, and `modelID + host + port`.
   - Cover ambiguous Replace and duplicate selected Replace target blocking.
   - Cover Replace metadata updates and local-only field preservation.
   - Cover selected profile tracking after explicit Replace.
   - Cover export schema output and omission of local-only fields, executable paths, token-like data, and secrets.
3. Keep tests metadata-only.
   - No `mlx-lm` dependency.
   - No model files.
   - No running server requirement.
   - No network calls.
   - No `/v1/models` readiness or detection call from import/export tests.
   - No `/v1/chat/completions` call.
4. Preserve product and safety boundaries.
   - Direct Mode is maintained.
   - No new import/export UI behavior.
   - No schema redesign.
   - No model download or model deletion.
   - No inference proxy, Chat UI, or multi-backend router.
   - No automatic server start.
   - No external process kill, stop, restart, adoption, forget, or ownership change.
5. Release note.
   - v3.5.0 is a code/test/docs stabilization release and requires a new unsigned app binary asset when released.
   - This step does not create a zipped app binary, tag, push, or GitHub release.
   - v4.0.0 should focus on Import / Export stable release polish, final regression, and release readiness.

## v4.0.0 Completed: Import / Export Stable Release Preparation

1. Confirm current Import / Export feature boundary.
   - Export Profiles is stable for schema v1 profile metadata backup.
   - Import Profiles Preview is stable for schema v1 validation.
   - Import Selected Profiles is stable for valid non-conflicting profiles.
   - Rename is stable for profile-name conflicts.
   - Replace is stable only for one unambiguous existing profile target with explicit confirmation.
2. Confirm regression coverage.
   - v3.5.0 fixtures and XCTest cover schema validation, conflict detection, Rename, Replace, local-only field preservation, export shape, and selected-profile tracking after explicit Replace.
   - No additional tests were needed for v4.0.0 because the stable behavior is already covered by v3.5.0 service-level tests.
3. Preserve metadata-only boundaries.
   - Import / Export does not start, stop, or restart servers.
   - Import / Export does not call `/v1/models`.
   - Import / Export does not make network requests.
   - Import / Export does not call `/v1/chat/completions`.
   - Import / Export does not download or delete models.
   - Import / Export does not import model weights, Hugging Face cache, executable paths, API keys, tokens, or secrets.
   - Import / Export does not change external process ownership.
4. Keep this step conservative.
   - No new user-facing import/export feature.
   - No UI redesign.
   - No schema redesign.
   - No runtime launch behavior change.
   - No server lifecycle behavior change.
   - Direct Mode is maintained.
5. Release note.
   - v4.0.0 is a stable Import / Export release preparation step.
   - This step does not create a zipped app binary, tag, push, or GitHub release.
   - If v4.0.0 is released without app-code changes after v3.5.0, the v3.5.0 unsigned app binary can remain the current binary asset.

## v4.1.0 Completed: Dashboard UI Refresh Design

1. Add Dashboard UI Refresh design docs.
   - Add `docs/dashboard_ui_refresh.md`.
   - Define purpose, non-goals, Direct Mode boundary, current UI limitations, target information architecture, proposed dashboard areas, accessibility/readability considerations, staged implementation plan, and safety boundaries.
2. Define future dashboard information architecture.
   - Current Target.
   - Server State.
   - Active Profile.
   - Lifecycle Controls.
   - Readiness.
   - Memory.
   - Logs.
   - Profiles.
   - Import / Export.
   - Onboarding / Diagnostics.
3. Preserve safety boundaries.
   - Dashboard refresh must not become a Chat UI.
   - Dashboard refresh must not proxy inference requests.
   - Dashboard refresh must not perform multi-backend routing.
   - Dashboard refresh must not automatically start, stop, or restart servers.
   - Dashboard refresh must not take ownership of external processes.
   - Dashboard refresh must not download or delete models.
   - Dashboard refresh must not change Import / Export behavior.
   - Dashboard refresh must not change Direct Mode.
4. Keep this step docs-only.
   - No Swift changes.
   - No tests or fixture changes.
   - No Xcode project changes.
   - No app assets or build settings changes.
   - No new app binary or release asset.
5. Release note.
   - v4.1.0 is a docs-only Dashboard UI Refresh design release.
   - It is foundation work for future v4.x implementation planning and a possible v5.0.0 Dashboard UI Refresh v1.
   - The current app binary remains the v3.5.0 unsigned build unless a later app-code release changes the app.

## v4.2.0 Completed: Dashboard UI Refresh Foundation

1. Add reusable dashboard UI structure.
   - Add display-only dashboard section/card views.
   - Keep SwiftUI cards side-effect free.
   - Do not move process launch, termination, port probing, readiness polling, import/export, or networking logic into views.
2. Add Current Target presentation.
   - Surface target type, Base URL, selected model ID, readiness, ownership note, and Direct Mode note.
   - Reuse existing `ConnectionTargetSummary` values.
   - Preserve existing Connection Settings copy actions.
3. Add Server State presentation.
   - Surface runtime state, endpoint, managed/external process ownership, lifecycle expectations, memory status, selected model, running model, and Restart Required.
   - Make adopted external servers clearly connection context only.
   - Keep Stop and Restart scoped to app-managed processes.
4. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No automatic lifecycle action.
   - No readiness behavior change.
   - No `/v1/models` behavior change.
   - No `/v1/chat/completions` calls by the app.
   - No Import / Export behavior change.
   - No model profile schema change.
   - No external server ownership change.
5. Release note.
   - v4.2.0 is the first small app-code foundation for Dashboard UI Refresh.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.2.0 will need a new unsigned app zip when released.

## v4.3.0 Completed: Dashboard Current Target Polish

1. Polish Current Target presentation.
   - Improve no-target wording.
   - Improve managed server wording.
   - Improve external detected and adopted external server wording.
   - Improve unavailable endpoint wording.
   - Improve readiness wording for ready, checking, not checked, unavailable, and failed states.
2. Keep changes display-only.
   - Use existing runtime state and connection target summary data.
   - Do not change process management.
   - Do not change readiness checks.
   - Do not add network calls.
   - Do not change model profile persistence.
   - Do not change Import / Export behavior.
3. Clarify ownership boundaries.
   - Managed targets are app-managed only when a managed process is attached.
   - External detected targets are not owned by the app.
   - Adopted external targets are connection context only.
   - Forget External Server does not stop the external process.
4. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No automatic lifecycle action.
   - No `/v1/models` behavior change.
   - No `/v1/chat/completions` calls by the app.
   - No Import / Export behavior change.
   - No model profile schema change.
   - No external server ownership change.
5. Release note.
   - v4.3.0 is a small app-code polish release for the Current Target card.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.3.0 will need a new unsigned app zip when released.

## v4.4.0 Completed: Dashboard Server State Polish

1. Polish Server State presentation.
   - Improve managed process wording.
   - Improve stopped, running, unavailable, and failed wording.
   - Improve external detected and adopted external context wording.
   - Separate process state, readiness state, lifecycle expectations, and memory context.
2. Keep changes display-only.
   - Use existing runtime state and memory display data.
   - Do not change process management.
   - Do not change readiness checks.
   - Do not add network calls.
   - Do not change model profile persistence.
   - Do not change Import / Export behavior.
3. Clarify lifecycle boundaries.
   - Stop and Restart apply only to app-managed processes.
   - Adopt External Server stores connection context only.
   - Forget External Server clears app-side context only.
   - External processes are not stopped, restarted, killed, monitored for memory, or logged by MLX Server Manager.
4. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No automatic lifecycle action.
   - No `/v1/models` behavior change.
   - No `/v1/chat/completions` calls by the app.
   - No Import / Export behavior change.
   - No model profile schema change.
   - No external server ownership change.
5. Release note.
   - v4.4.0 is a small app-code polish release for the Server State card.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.4.0 will need a new unsigned app zip when released.

## v4.5.0 Completed: Dashboard Logs / Diagnostics Polish

1. Add display-only Dashboard guidance.
   - Add concise guidance for logs, diagnostics, readiness failures, port busy states, unavailable targets, and external server context.
   - Explain where users should look next without turning the dashboard into a troubleshooting wizard.
2. Clarify managed vs external logs.
   - Managed server logs are available only for app-started servers.
   - External server logs must be checked where the external server was launched.
   - Adopted external servers remain connection context only.
3. Clarify readiness and availability.
   - Ready means `/v1/models` responded successfully.
   - Readiness failure should prompt users to check host, port, server logs, and whether the target is still starting or OpenAI-compatible.
   - Port busy / unavailable guidance stays informational and manual.
4. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No automatic diagnostics execution.
   - No background health checks.
   - No new network calls.
   - No `/v1/models` behavior change.
   - No `/v1/chat/completions` calls by the app.
   - No Import / Export behavior change.
   - No model profile schema change.
   - No external server ownership change.
5. Release note.
   - v4.5.0 is a small app-code polish release for Dashboard logs, diagnostics, and readiness guidance.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.5.0 will need a new unsigned app zip when released.

## v4.6.0 Completed: Dashboard Profiles / Import Export Polish

1. Add display-only profile guidance.
   - Show selected profile metadata, model ID, profile endpoint, current target, and their relationship.
   - Clarify that selected profile is saved launch/configuration metadata.
   - Clarify that current target is the active managed or adopted endpoint.
2. Add display-only Import / Export guidance.
   - Explain that Export Profiles is metadata-only.
   - Explain that Import Preview validates before import.
   - Explain that Import Selected Profiles writes selected valid metadata.
   - Explain Rename and Replace at a high level.
3. Preserve Import / Export behavior.
   - No import/export logic change.
   - No import/export schema change.
   - No import/export validation change.
   - No Rename behavior change.
   - No Replace behavior change.
   - No model profile persistence change.
4. Preserve runtime behavior.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/models` behavior change.
   - No `/v1/chat/completions` calls by the app.
   - No model download or deletion.
   - No external server ownership change.
5. Release note.
   - v4.6.0 is a small app-code polish release for Dashboard Profiles / Import Export guidance.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.6.0 will need a new unsigned app zip when released.

## v4.7.0 Completed: Dashboard Onboarding / Next Steps Polish

1. Add display-only Next Steps guidance.
   - Show what users should consider next for stopped, starting, ready, external, adopted, failed, and unknown states.
   - Clarify first-run / no-target paths without adding an onboarding wizard.
   - Keep guidance static and display-only.
2. Clarify managed and external paths.
   - Explain that managed Start uses the selected profile.
   - Explain that external adoption is connection context only.
   - Explain that Import Profiles can help restore profile metadata.
3. Clarify readiness and Direct Mode.
   - Ready means `/v1/models` responded successfully.
   - Running and Ready remain separate concepts.
   - OpenAI-compatible clients connect directly to `mlx_lm.server` or the adopted external endpoint.
4. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No automatic diagnostics execution.
   - No onboarding persistence or user tracking.
   - No Import / Export behavior or schema change.
   - No model download or deletion.
   - No external server ownership change.
5. Release note.
   - v4.7.0 is a small app-code polish release for Dashboard Onboarding / Next Steps guidance.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.7.0 will need a new unsigned app zip when released.

## v4.8.0 Completed: Dashboard Layout / Information Hierarchy Polish

1. Add display-only grouping headings.
   - Clarify Dashboard scan order.
   - Group Next Steps, Target and State, Troubleshooting, and Profile Context.
   - Keep cards easier to scan without moving runtime controls.
2. Clarify card responsibilities.
   - Next Steps answers what to do next.
   - Current Target answers what the app is connected to.
   - Server State answers process, readiness, and lifecycle condition.
   - Diagnostics & Logs answers where to look when something is not working.
   - Profiles & Import / Export answers what metadata context is relevant.
3. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No automatic diagnostics execution.
   - No onboarding persistence or user tracking.
   - No Import / Export behavior or schema change.
   - No model download or deletion.
   - No external server ownership change.
4. Release note.
   - v4.8.0 is a small app-code polish release for Dashboard layout and information hierarchy.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.8.0 will need a new unsigned app zip when released.

## v4.9.0 Completed: Dashboard Copy / Client Setup Polish

1. Add display-only Client Setup guidance.
   - Show client-facing base URL guidance for the current state.
   - Distinguish active endpoint from selected profile endpoint.
   - Explain selected profile model ID vs external server model-name expectations.
   - Point users to existing Connection Settings copy actions.
2. Clarify OpenAI-compatible client setup.
   - Use the active endpoint as the client base URL when a target is active.
   - Wait for `/v1/models` readiness before expecting clients to work.
   - Keep Direct Mode visible: clients connect directly to the active server endpoint.
   - Explain managed vs adopted external setup context without changing ownership.
3. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No copy action behavior change.
   - No API key, token, or secret persistence.
   - No onboarding persistence or user tracking.
   - No Import / Export behavior or schema change.
   - No model download or deletion.
   - No external server ownership change.
4. Release note.
   - v4.9.0 is a small app-code polish release for Dashboard Copy / Client Setup clarity.
   - It is not the full v5.0.0 Dashboard UI Refresh v1.
   - Because app code changed, v4.9.0 will need a new unsigned app zip when released.

## v5.0.0 Completed: Dashboard UI Refresh v1

1. Stabilize Dashboard v1.
   - Present Dashboard as the stable v1 overview.
   - Keep the scan order: Next Steps, Target and State, Client Setup, Troubleshooting, Profile Context.
   - Keep card responsibilities clear and display-oriented.
2. Confirm Dashboard v1 scope.
   - Next Steps answers what to do next.
   - Current Target answers what the app is connected to.
   - Server State answers process, readiness, and lifecycle condition.
   - Client Setup answers what to paste into OpenAI-compatible clients.
   - Diagnostics & Logs answers where to look when something is not working.
   - Profiles & Import / Export answers what metadata context is relevant.
3. Preserve behavior.
   - No Start / Stop / Restart behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No API key, token, or secret persistence.
   - No onboarding persistence or user tracking.
   - No Import / Export behavior or schema change.
   - No model download or deletion.
   - No external server ownership change.
4. Separate future work.
   - Broader app shell redesign is future work.
   - Sidebar navigation, model table redesign, right-side inspector, metrics widgets, and client-specific panels are not part of Dashboard v1.
5. Release note.
   - v5.0.0 is the Dashboard UI Refresh v1 stabilization release.
   - Because app code changed, v5.0.0 will need a new unsigned app zip when released.

## v5.1.0 Completed: Dashboard Stable Follow-up

1. Keep Dashboard v1 stable.
   - Treat the current Dashboard v1 surface as the stable post-v5.0 overview.
   - Avoid app shell redesign, sidebar navigation, model table redesign, right-side inspector, metrics widgets, or Hermes-specific panels.
2. Clarify documentation.
   - Present Dashboard v1 as the current stable dashboard.
   - Clarify that future full-layout work is separate from Dashboard v1.
   - Keep future layout ideas documented as optional future work.
3. Preserve behavior.
   - No Swift app code changes.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No External Server Detection / Adopt / Forget behavior change.
   - No Import / Export behavior or schema change.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No model download or deletion.
   - No external process ownership change.
4. Release note.
   - v5.1.0 is a docs-only Dashboard Stable Follow-up release.
   - The current downloadable app binary remains the v5.0.0 unsigned app zip unless a later app-code release is created.

## v5.2.0 Completed: Full App Layout Refresh Planning

1. Add future layout design documentation.
   - Add `docs/full_app_layout_refresh.md`.
   - Document a candidate future v6.x direction for sidebar navigation, main content, and detail or inspector areas.
   - Keep Dashboard UI Refresh v1 as the current stable surface.
2. Define candidate future areas.
   - Dashboard.
   - Profiles / Models.
   - Server.
   - Logs.
   - Client Setup.
   - Settings.
3. Stage future v6.x work as proposals.
   - v6.0.0 App Shell / Sidebar Foundation.
   - v6.1.0 Profiles / Model List Surface.
   - v6.2.0 Detail Inspector Foundation.
   - v6.3.0 Logs Panel Refresh.
   - v6.4.0 Client Setup Surface.
   - v6.5.0 Metrics / System Context Design.
4. Preserve behavior.
   - No Swift app code changes.
   - No Dashboard behavior or card order change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No External Server Detection / Adopt / Forget behavior change.
   - No Import / Export behavior or schema change.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No model download or deletion.
   - No external process ownership change.
5. Release note.
   - v5.2.0 is a docs-only planning release.
   - No new unsigned app zip is needed.

## v5.3.0 Completed: App Shell / Sidebar Foundation Design

1. Add detailed v6.0.0 design documentation.
   - Add `docs/app_shell_sidebar_foundation.md`.
   - Narrow the broader v5.2.0 Full App Layout Refresh plan into a future `v6.0.0` App Shell / Sidebar Foundation design.
   - Keep Dashboard UI Refresh v1 as the current stable surface and future landing page candidate.
2. Define candidate sidebar sections.
   - Dashboard.
   - Profiles.
   - Server.
   - Logs.
   - Client Setup.
   - Settings.
3. Define migration and mapping guidance.
   - Map existing view concepts to possible future sections.
   - Keep existing controls functional.
   - Move no runtime behavior in the shell foundation design.
   - Avoid duplicate or hidden lifecycle controls.
4. Preserve behavior.
   - No Swift app code changes.
   - No `NavigationSplitView` implementation.
   - No sidebar implementation.
   - No model table or inspector implementation.
   - No Dashboard behavior or card order change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No External Server Detection / Adopt / Forget behavior change.
   - No Import / Export behavior or schema change.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No model download or deletion.
   - No external process ownership change.
5. Release note.
   - v5.3.0 is a docs-only detailed design release.
   - No new unsigned app zip is needed.

## v5.4.0 Completed: Profiles / Model List Surface Design

1. Add detailed v6.1.0 design documentation.
   - Add `docs/profiles_model_list_surface.md`.
   - Narrow the broader v6.x layout plan into a future `v6.1.0` Profiles / Model List Surface design.
   - Keep Dashboard UI Refresh v1 as the current stable overview.
   - Keep `v6.0.0` App Shell / Sidebar Foundation as the preceding future step.
2. Define candidate Profiles surface.
   - Candidate profile list columns.
   - Selected profile details.
   - Model ID, endpoint, base URL, and Advanced Launch Options summary.
   - Import / Export placement.
   - Rename / Replace guidance.
3. Preserve metadata-only boundaries.
   - Profile metadata is not installed model files.
   - Import / Export remains metadata-only.
   - No model file copy, model download, model deletion, Hugging Face cache mutation, log transfer, secrets transfer, or external process ownership transfer.
4. Preserve behavior.
   - No Swift app code changes.
   - No Profiles section implementation.
   - No model list table implementation.
   - No sidebar implementation.
   - No selected profile behavior change.
   - No profile persistence rewrite.
   - No Import / Export behavior or schema change.
   - No Rename or Replace behavior change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No model download or deletion.
   - No model file scanning or cache cleanup.
   - No external process ownership change.
5. Release note.
   - v5.4.0 is a docs-only detailed design release.
   - No new unsigned app zip is needed.

## v5.5.0 Completed: Detail Inspector Foundation Design

1. Add detailed v6.2.0 design documentation.
   - Add `docs/detail_inspector_foundation.md`.
   - Narrow the broader v6.x layout plan into a future `v6.2.0` Detail Inspector Foundation design.
   - Keep Dashboard UI Refresh v1 as the current stable overview.
   - Keep `v6.0.0` App Shell / Sidebar Foundation and `v6.1.0` Profiles / Model List Surface as preceding future steps.
2. Define candidate inspector contexts.
   - No Selection.
   - Selected Profile.
   - Current Managed Server Target.
   - Adopted External Server Target.
   - Import / Export Context.
3. Define candidate inspector areas.
   - Header.
   - Endpoint Summary.
   - Ownership / Lifecycle.
   - Readiness.
   - Metadata.
   - Safety Notes.
4. Preserve behavior.
   - No Swift app code changes.
   - No detail inspector implementation.
   - No inspector UI or three-column layout implementation.
   - No endpoint testing beyond existing readiness behavior.
   - No selected profile behavior change.
   - No current target behavior change.
   - No Import / Export behavior or schema change.
   - No Rename or Replace behavior change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No model download or deletion.
   - No model file scanning or cache cleanup.
   - No external process ownership change.
5. Release note.
   - v5.5.0 is a docs-only detailed design release.
   - No new unsigned app zip is needed.

## v5.6.0 Completed: Logs Panel Refresh Design

1. Add detailed v6.3.0 design documentation.
   - Add `docs/logs_panel_refresh.md`.
   - Narrow the broader v6.x layout plan into a future `v6.3.0` Logs Panel Refresh design.
   - Keep Dashboard UI Refresh v1 as the current stable overview.
   - Keep `v6.0.0` App Shell / Sidebar Foundation, `v6.1.0` Profiles / Model List Surface, and `v6.2.0` Detail Inspector Foundation as preceding future steps.
2. Define candidate Logs surface areas.
   - Header.
   - Managed Log Stream.
   - Lifecycle Events.
   - Troubleshooting Notes.
   - Copy Actions.
3. Define managed vs adopted external log boundaries.
   - App-managed logs may only come from app-owned process context already captured by the app.
   - Adopted external servers are connection context only.
   - External stdout/stderr is not captured.
   - External processes are not stopped, restarted, killed, inspected, or treated as app-owned.
4. Preserve behavior.
   - No Swift app code changes.
   - No Logs panel implementation.
   - No logs UI, log filtering, log search, log export, or log file persistence.
   - No external log capture or background log scraping.
   - No automatic diagnostics, telemetry, or background monitoring.
   - No endpoint testing beyond existing readiness behavior.
   - No selected profile behavior change.
   - No current target behavior change.
   - No Import / Export behavior or schema change.
   - No Rename or Replace behavior change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No model download or deletion.
   - No model file scanning or cache cleanup.
   - No external process ownership change.
5. Release note.
   - v5.6.0 is a docs-only detailed design release.
   - No new unsigned app zip is needed.

## v5.7.0 Completed: Client Setup Surface Design

1. Add detailed v6.4.0 design documentation.
   - Add `docs/client_setup_surface.md`.
   - Narrow the broader v6.x layout plan into a future `v6.4.0` Client Setup Surface design.
   - Keep Dashboard UI Refresh v1 as the current stable overview.
   - Keep `v6.0.0` App Shell / Sidebar Foundation, `v6.1.0` Profiles / Model List Surface, `v6.2.0` Detail Inspector Foundation, and `v6.3.0` Logs Panel Refresh as preceding future steps.
2. Define candidate Client Setup surface areas.
   - Header.
   - Connection Values.
   - Direct Mode Explanation.
   - Copy Actions.
   - Safety Notes.
   - Troubleshooting Links / Notes.
3. Define managed vs adopted external setup boundaries.
   - Managed server setup values are informational and based on app-managed context already available to the app.
   - Adopted external servers are connection context only.
   - External processes are not stopped, restarted, killed, inspected, or treated as app-owned.
   - Client setup values must not imply proxying or external process ownership.
4. Preserve behavior.
   - No Swift app code changes.
   - No Client Setup surface implementation.
   - No client setup UI or client-specific configuration generation.
   - No API key management, token storage, secret persistence, or generated client config persistence.
   - No automatic client configuration or client auto-detection.
   - No endpoint testing beyond existing readiness behavior.
   - No selected profile behavior change.
   - No current target behavior change.
   - No Import / Export behavior or schema change.
   - No Rename or Replace behavior change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No onboarding persistence or user tracking.
   - No model download or deletion.
   - No model file scanning or cache cleanup.
   - No external process ownership change.
5. Release note.
   - v5.7.0 is a docs-only detailed design release.
   - No new unsigned app zip is needed.

## v5.8.0 Completed: Metrics / System Context Design

1. Add detailed v6.5.0 design documentation.
   - Add `docs/metrics_system_context.md`.
   - Narrow the broader v6.x layout plan into a future `v6.5.0` Metrics / System Context design.
   - Keep Dashboard UI Refresh v1 as the current stable overview.
   - Keep `v6.0.0` App Shell / Sidebar Foundation, `v6.1.0` Profiles / Model List Surface, `v6.2.0` Detail Inspector Foundation, `v6.3.0` Logs Panel Refresh, and `v6.4.0` Client Setup Surface as preceding future steps.
2. Define candidate metrics and system context categories.
   - Readiness Context.
   - Memory Context.
   - Process Context.
   - Runtime Performance Context.
3. Define privacy and performance boundaries.
   - No telemetry, analytics, or crash reporting.
   - No request logging, request tracing, or inference traffic inspection.
   - No benchmarks, token throughput measurement, or instrumentation in the inference path.
   - No external process metrics collection.
   - No metrics persistence.
   - No heavy polling or background monitoring by default.
4. Preserve behavior.
   - No Swift app code changes.
   - No metrics UI or system monitoring implementation.
   - No memory polling, CPU/GPU/ANE polling, or process sampling.
   - No automatic diagnostics, background health checks, or background monitoring.
   - No endpoint testing beyond existing readiness behavior.
   - No selected profile behavior change.
   - No current target behavior change.
   - No Import / Export behavior or schema change.
   - No Rename or Replace behavior change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No generated client config persistence.
   - No model download or deletion.
   - No model file scanning or cache cleanup.
   - No external process ownership change.
5. Release note.
   - v5.8.0 is a docs-only detailed design release.
   - No new unsigned app zip is needed.

## v5.9.0 Completed: v6 Implementation Readiness Review

1. Add v6 readiness review documentation.
   - Add `docs/v6_implementation_readiness.md`.
   - Consolidate the v5.2.0 through v5.8.0 planning sequence.
   - Keep Dashboard UI Refresh v1 as the current stable surface.
   - Recommend future app-code work start with a narrow `v6.0.0` App Shell / Sidebar Foundation only.
2. Define proposed v6 implementation sequence.
   - `v6.0.0` App Shell / Sidebar Foundation.
   - `v6.1.0` Profiles / Model List Surface.
   - `v6.2.0` Detail Inspector Foundation.
   - `v6.3.0` Logs Panel Refresh.
   - `v6.4.0` Client Setup Surface.
   - `v6.5.0` Metrics / System Context.
3. Define implementation guardrails.
   - One major surface per release.
   - Keep release scope small.
   - Preserve Dashboard v1.
   - Keep selected profile distinct from current target.
   - Keep managed vs adopted external ownership explicit.
   - Do not add new network calls, persistence, or Import / Export schema changes without separate design.
4. Preserve behavior.
   - No Swift app code changes.
   - No v6 UI implementation.
   - No app shell, sidebar navigation, Profiles section, Detail Inspector, Logs Panel, Client Setup Surface, or Metrics / System Context implementation.
   - No selected profile behavior change.
   - No current target behavior change.
   - No Import / Export behavior or schema change.
   - No Rename or Replace behavior change.
   - No Start / Stop / Restart behavior change.
   - No readiness behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No onboarding persistence or user tracking.
   - No API key, token, or secret persistence.
   - No generated client config persistence.
   - No telemetry, analytics, request logging, request tracing, inference traffic inspection, metrics persistence, or background monitoring.
   - No model download or deletion.
   - No model file scanning or cache cleanup.
   - No external process ownership change.
5. Release note.
   - v5.9.0 is a docs-only readiness review release.
   - No new unsigned app zip is needed.

## v6.0.0 Completed: App Shell / Sidebar Foundation

1. Add native app shell foundation.
   - Add `AppSection` as the staged top-level app destination model.
   - Add `AppShellView` using native SwiftUI `NavigationSplitView`.
   - Keep Dashboard as the default and only active top-level section.
2. Preserve existing Dashboard surface.
   - Mount the existing Dashboard content without changing card order or behavior.
   - Keep existing model list, settings, onboarding, dashboard overview, diagnostics, status, model detail, connection settings, and logs available in the Dashboard surface.
3. Preserve runtime and safety boundaries.
   - No Start / Stop / Restart behavior change.
   - No selected profile behavior change.
   - No Current Target behavior change.
   - No Import / Export behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No new persistence.
   - No API key, token, or secret persistence.
   - No model download, deletion, scanning, or cache cleanup.
4. Release note.
   - v6.0.0 is an app-code shell foundation release.
   - Tag, push, GitHub Release, and zip asset remain release-preparation steps only.

## v6.0.1 Completed: App Shell Sidebar Polish

1. Polish the native sidebar shell.
   - Add macOS sidebar list styling to the app shell section list.
   - Add sidebar row accessibility label and hint wiring.
   - Clarify in code comments that v6.0.x intentionally exposes Dashboard as the only active section.
2. Preserve runtime and safety boundaries.
   - No Dashboard card order change.
   - No Start / Stop / Restart behavior change.
   - No selected profile behavior change.
   - No Current Target behavior change.
   - No Import / Export behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No new persistence.
   - No API key, token, or secret persistence.
   - No model download, deletion, scanning, or cache cleanup.
3. Release note.
   - v6.0.1 is an app-code sidebar polish release.
   - v6.1.0 Profiles / Model List Surface remains future work.

## v6.0.2 Completed: App Shell Release Hygiene

1. Clean up sidebar accessibility ownership.
   - Keep sidebar accessibility label and hint on `AppSectionSidebarRow`.
   - Keep the section list responsible only for selection and tagging.
   - Preserve macOS sidebar list styling.
2. Document the completed v6.0.x shell state.
   - Update README current binary asset notes.
   - Update App Shell / Sidebar Foundation documentation.
   - Keep v6.1.0 Profiles / Model List Surface as the next future implementation step.
3. Preserve runtime and safety boundaries.
   - No Dashboard card order change.
   - No Start / Stop / Restart behavior change.
   - No selected profile behavior change.
   - No Current Target behavior change.
   - No Import / Export behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No new persistence.
   - No API key, token, or secret persistence.
   - No model download, deletion, scanning, or cache cleanup.
4. Release note.
   - v6.0.2 is an app-code release hygiene follow-up.
   - v6.1.0 Profiles / Model List Surface remains future work.

## v6.0.3 Completed: App Shell Stable Identifiers

1. Add stable App Shell identifiers.
   - Add a section-level accessibility identifier on `AppSection`.
   - Add a stable identifier for the App Shell sidebar.
   - Add a stable identifier for the App Shell detail area.
   - Add stable identifiers for sidebar section rows.
2. Preserve runtime and safety boundaries.
   - No Dashboard card order change.
   - No Start / Stop / Restart behavior change.
   - No selected profile behavior change.
   - No Current Target behavior change.
   - No Import / Export behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No new persistence.
   - No API key, token, or secret persistence.
   - No model download, deletion, scanning, or cache cleanup.
3. Release note.
   - v6.0.3 is an app-code App Shell identifier follow-up.
   - v6.1.0 Profiles / Model List Surface remains future work.

## v6.0.4 Completed: AppSection Metadata Tests

1. Add AppSection metadata test coverage.
   - Add `MLXServerManagerTests/AppSectionTests.swift`.
   - Verify Dashboard remains the only v6.0.x app section.
   - Verify stable Dashboard metadata: id, title, subtitle, SF Symbol name, and accessibility identifier.
2. Preserve runtime and safety boundaries.
   - No app UI behavior change.
   - No Dashboard card order change.
   - No Start / Stop / Restart behavior change.
   - No selected profile behavior change.
   - No Current Target behavior change.
   - No Import / Export behavior change.
   - No External Server Detection / Adopt / Forget behavior change.
   - No new network calls.
   - No `/v1/chat/completions` calls by the app.
   - No new persistence.
   - No API key, token, or secret persistence.
   - No model download, deletion, scanning, or cache cleanup.
3. Release note.
   - v6.0.4 is an app-code AppSection metadata test follow-up.
   - v6.1.0 Profiles / Model List Surface remains future work.

## v6.0.5 Completed: v6.1 Implementation Handoff

- Add `docs/v6.1_implementation_handoff.md`.
- Summarize completed v6.0.x App Shell foundation work.
- Define v6.1.0 Profiles / Model List Surface minimum scope, guardrails, acceptance criteria, and release checklist.
- Keep this release docs-only: no app-code changes and no new app zip.
- Keep v6.1.0 Profiles / Model List Surface as the next implementation target.

## v6.1.0 Completed: Profiles / Model List Surface

- Add `AppSection.profiles` with stable metadata and accessibility identifier.
- Add `ProfilesSurfaceView` as a lightweight top-level model profile list surface.
- Mount Profiles through the App Shell while keeping Dashboard as the default section.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Expand `AppSectionTests` to cover Dashboard and Profiles metadata.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.1.1 Completed: Profiles Surface Polish

- Add Profiles summary cards for profile count, selected profile, running profile, and restart-required state.
- Add stable identifiers for the Profiles summary area, list heading, and profile list.
- Keep Profiles read-only for runtime lifecycle behavior.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.2.0 Completed: Detail Inspector Foundation

- Add `AppSection.inspector` with stable metadata and accessibility identifier.
- Add `DetailInspectorSurfaceView` as a read-only selected profile and connection target detail surface.
- Mount Inspector through the App Shell while keeping Dashboard as the default section.
- Preserve the existing Dashboard `ModelDetailView` edit/delete entry points.
- Expand `AppSectionTests` to cover Dashboard, Profiles, and Inspector metadata.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.2.1 Completed: Detail Inspector Polish

- Add Inspector summary cards for selected profile, target status, running model, and restart-required state.
- Add stable identifiers for the Inspector summary area and summary cards.
- Keep Inspector read-only for runtime lifecycle behavior.
- Preserve the existing Dashboard `ModelDetailView` edit/delete entry points.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.3.0 Completed: Logs Panel Refresh

- Add `AppSection.logs` with stable metadata and accessibility identifier.
- Add `LogsSurfaceView` as a top-level app-managed lifecycle and log context surface.
- Mount Logs through the App Shell while keeping Dashboard as the default section.
- Reuse the existing `LogView` and existing copy/clear log actions.
- Add Logs summary cards for entry count, target type, readiness, and running model.
- Add a Logs boundary card that clarifies external server logs are not captured or owned.
- Expand `AppSectionTests` to cover Dashboard, Profiles, Inspector, and Logs metadata.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, external log capture, background scraping, model download, model deletion, model scanning, or cache cleanup.

## v6.3.1 Completed: Logs Surface Polish

- Add shared `LogView` entry count display.
- Add stable identifiers for the shared log view header, title, entry count, copy button, clear button, entry list, and empty state.
- Keep existing copy and clear log actions unchanged.
- Preserve Dashboard LogView availability and Logs surface LogView reuse.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, external log capture, background scraping, model download, model deletion, model scanning, or cache cleanup.

## v6.4.0 Completed: Client Setup Surface

- Add `AppSection.clientSetup` with stable metadata and accessibility identifier.
- Add `ClientSetupSurfaceView` as a top-level copy-safe OpenAI-compatible setup surface.
- Mount Client Setup through the App Shell while keeping Dashboard as the default section.
- Reuse existing `ConnectionSettingsView` and existing copy actions.
- Add Client Setup summary cards for target type, Base URL, model ID, and readiness.
- Add Direct Mode and safety boundary cards.
- Expand `AppSectionTests` to cover Dashboard, Profiles, Inspector, Logs, and Client Setup metadata.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, External Server Detection / Adopt / Forget behavior, and existing Dashboard Connection Settings availability.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, endpoint testing, generated client config persistence, client auto-detection, API key storage, token storage, secret persistence, model download, model deletion, model scanning, or cache cleanup.

## v6.4.1 Completed: Client Setup Surface Polish

- Add a Client Setup copy scope card that clarifies Base URL, model ID, API key placeholder, and config example copy behavior.
- Keep existing `ConnectionSettingsView` reuse and existing copy actions unchanged.
- Preserve Dashboard Connection Settings availability.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, endpoint testing, generated client config persistence, client auto-detection, API key storage, token storage, secret persistence, model download, model deletion, model scanning, or cache cleanup.

## v6.5.0 Completed: Metrics / System Context

- Add `AppSection.metrics` with stable metadata and accessibility identifier.
- Add `MetricsSystemContextSurfaceView` as a top-level read-only system and readiness context surface.
- Mount Metrics through the App Shell while keeping Dashboard as the default section.
- Reuse existing runtime state, connection target summary, memory text, selected model text, running model text, restart-required state, and log entry count.
- Add summary cards for runtime, readiness, memory, and restart-required state.
- Add read-only context cards for readiness, memory guidance, process ownership, privacy/performance boundary, and troubleshooting.
- Expand `AppSectionTests` to cover Dashboard, Profiles, Inspector, Logs, Client Setup, and Metrics metadata.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, External Server Detection / Adopt / Forget behavior, and existing Dashboard metrics-related context.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, request tracing, traffic inspection, active system monitoring, metrics persistence, benchmark runner, token throughput measurement, external process metrics collection, external log capture, endpoint testing, model download, model deletion, model scanning, or cache cleanup.

## v6.5.1 Completed: Metrics Surface Polish

- Add a Metrics context scope card that clarifies source, collection, persistence, external server scope, and diagnostics behavior.
- Keep Metrics read-only and based on existing app state only.
- Preserve Dashboard model list, runtime controls, selected profile behavior, current target behavior, Import / Export behavior, and External Server Detection / Adopt / Forget behavior.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, request tracing, traffic inspection, active system monitoring, metrics persistence, benchmark runner, token throughput measurement, external process metrics collection, external log capture, endpoint testing, model download, model deletion, model scanning, or cache cleanup.

## v6.6.0 Completed: App Layout Stabilization Review

- Add `docs/v6_app_layout_stabilization_review.md` as a docs-only post-v6 surface review.
- Record the implemented top-level sections: Dashboard, Profiles, Inspector, Logs, Client Setup, and Metrics.
- Record the stable section order covered by `AppSectionTests`.
- Reaffirm the Direct Mode contract and runtime safety invariants.
- Document safe future work and work that requires a new scoped design review.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, endpoint testing, generated client config persistence, client auto-detection, API key storage, token storage, secret persistence, model download, model deletion, model scanning, or cache cleanup.

## v6.6.1 Completed: App Layout Stabilization Review Polish

- Add next-phase entry criteria to the v6 App Layout Stabilization Review.
- Add a manual verification checklist for later app-code releases.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no inference proxying, Chat UI, routing, request rewriting, telemetry, background monitoring, endpoint testing, generated client config persistence, client auto-detection, API key storage, token storage, secret persistence, model download, model deletion, model scanning, or cache cleanup.

## v6.7.0 Completed: Distribution / Packaging Readiness Review

- Add `docs/distribution_packaging_readiness.md` as a docs-only review for future distribution work.
- Record the current distribution state and current binary asset.
- Define future distribution goals for unsigned zip, signed zip, notarized zip, DMG, and installer package decisions.
- Document release asset naming expectations and the required release settings block.
- Add packaging and signing/notarization safety checklists.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.7.1 Completed: Distribution / Packaging Readiness Polish

- Add install documentation planning to the Distribution / Packaging Readiness Review.
- Add manual packaging verification notes for later app-code releases with binary assets.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.8.0 Completed: README Install Section Refresh

- Refresh README Install and Quick Start sections around the current downloadable app-code release asset.
- Replace the stale `v1.9.0` Quick Start asset reference with `MLXServerManager-v6.5.1-unsigned.zip`.
- Add checksum verification guidance for the current binary asset.
- Clarify that `v6.6.0`, `v6.6.1`, `v6.7.0`, `v6.7.1`, and `v6.8.0` are documentation releases and do not replace the app binary.
- Clarify that users should download the named release asset, not the source archive, when they want the app binary.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.8.1 Completed: README Install Section Polish

- Clarify that users should download the named asset under GitHub Release Assets, not source archives.
- Add a concrete `shasum -a 256` command for verifying the current app zip.
- Clarify that `v6.8.1` is docs-only and does not replace the current app binary.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.9.0 Completed: Signed Distribution Design

- Add `docs/signed_distribution_design.md` as a docs-only design for future signed zip distribution.
- Define signing goals, non-goals, proposed signed zip asset naming, signing identity boundaries, local signing flow design, required verification, release notes requirements, unsigned build coexistence options, and notarization separation.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.9.1 Completed: Signed Distribution Design Polish

- Add signing implementation entry criteria to `docs/signed_distribution_design.md`.
- Add manual verification notes for future signed binary releases.
- Add decision criteria for signed-only, signed plus unsigned, and unsigned-only release assets.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.10.0 Completed: Notarization Workflow Design

- Add `docs/notarization_workflow_design.md` as a docs-only design for future notarized distribution.
- Define notarization goals, non-goals, workflow prerequisites, conceptual flow, result handling, asset naming, release notes requirements, verification notes, and fallback policy.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, stapling, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.10.1 Completed: Notarization Workflow Polish

- Add notarization implementation entry criteria to `docs/notarization_workflow_design.md`.
- Add conservative signing, notarization, and stapling status wording rules.
- Add fallback decision criteria for notarized-only, signed plus notarized, signed-only fallback, and unsigned-only releases.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, stapling, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.11.0 Completed: Signed Zip Implementation Readiness

- Add `docs/signed_zip_implementation_readiness.md` as a docs-only readiness review for a future signed zip implementation.
- Define readiness gates, proposed scope, local signing preconditions, candidate manual flow, required checks, forbidden entries, release notes requirements, README install update requirements, and fallback policy.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, stapling, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.11.1 Completed: Signed Zip Readiness Polish

- Add Go / No-Go criteria to `docs/signed_zip_implementation_readiness.md`.
- Add release artifact states for docs-only, unsigned zip, signed zip, and notarized zip releases.
- Add a compact manual verification log template for future signed zip releases.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, stapling, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## v6.12.0 Completed: Local Signing Command Draft

- Add `docs/local_signing_command_draft.md` as a docs-only draft for future local signed zip creation.
- Define placeholders, draft build/sign/verify/zip/checksum flow, safety boundaries, verification log template, and fallback rules.
- Keep the current downloadable app binary at `v6.5.1`; no new app zip is produced.
- Keep Direct Mode unchanged; no signing, notarization, stapling, DMG, installer, auto-update, release automation, runtime behavior change, telemetry, background monitoring, model download, model deletion, model scanning, or cache cleanup.

## Later

- Refresh README screenshots after Dashboard UI Refresh v1.
- Local Signing Command Polish.
- Packaging checklist polish.
- Model download design.
- Deeper diagnostics design.
- Model availability documentation.
- Packaging polish.
- LAN Web UI.
- Automatic unload policies.
- More advanced resource graphs.
- App Intents for start, stop, restart, and status.
- Hugging Face download manager.
- Presets for frequently used model configurations.
- DMG or zip packaging.
- Notarization.
- Automated release workflows.
