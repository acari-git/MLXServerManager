# Requirements

## Goal

MLX Server Manager provides a macOS GUI for operating `mlx_lm.server` while preserving the performance characteristics of a direct `mlx_lm.server` setup.

The app must make routine server operations easier without changing the inference route or adding a proxy in v0.1.

## Direct Mode

v0.1 keeps inference traffic outside the app:

```text
OpenAI-compatible client -> mlx_lm.server
```

The app may launch, stop, restart, monitor, and display connection details for the local server. It must not insert a proxy into the request path.

## v0.1 Functional Requirements

- Start `mlx_lm.server` using the executable path configured in the UI.
- Stop only the server process started and held by this app.
- Restart by stopping the managed process, waiting for port release, and launching again.
- Check whether the configured host and port are available before starting.
- Detect readiness with `GET /v1/models`.
- Save and restore app settings and model configuration.
- Show memory usage for the managed server process.
- Show bounded runtime logs and allow clearing them.
- Copy OpenAI-compatible connection settings for external clients.
- Copy example curl commands for external `/v1/models` and `/v1/chat/completions` use.

## v0.1 Non-Functional Requirements

- Starting the server from the GUI must not add a proxy or middleware to inference requests.
- The app must avoid polling that materially degrades inference performance.
- Runtime actions must be separated from SwiftUI views.
- Configuration must be portable across user accounts.
- User-specific absolute paths must not be hardcoded.
- Secrets, runtime settings, logs, and model files must stay outside Git.
- Local loopback use with `127.0.0.1` is recommended for v0.1.
- The app should not encourage exposing `mlx_lm.server` directly to the internet.

## Explicit Non-Goals

- Chat UI.
- Proxy routing.
- Auto unload.
- LAN Web UI.
- App Intents.
- Hugging Face download manager.
- Multiple simultaneous server management.
- Running `/v1/chat/completions` from the app.
- LM Studio, Ollama, llama.cpp, or other inference backends.
- Remote server management.
- Multi-host orchestration.

The `/v1/chat/completions` curl text is a copy-only helper for external clients. Readiness checks must continue to use `/v1/models`.

## v0.2 Setup Diagnostics Requirements

v0.2 should add Setup Diagnostics while preserving Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

Setup Diagnostics should help users confirm that the configured `mlx_lm.server executable path`, selected model, host, and port are usable before Start.

Functional requirements:

- Check whether the executable path is configured.
- Check whether the configured executable path exists.
- Check whether the configured executable path is executable.
- Run a safe probe such as `--help` with a short timeout.
- Validate host and port values.
- Reuse Port Check to determine whether the configured port is available.
- If the port is busy and no managed process is attached, explain that an external process may be using it.
- Confirm required Start settings are present.
- Reuse Ready Check through `GET /v1/models` after a managed server starts.
- Show the resolved storage location for `settings.json` and `models.json`.
- Write diagnostics results to Logs.
- Add a Diagnostics panel or `Run Diagnostics` button in the UI.

v0.2 non-goals:

- Proxy mode.
- Chat UI.
- Running `/v1/chat/completions` from the app.
- Running inference as a diagnostic.
- Stopping external `mlx_lm.server` processes.
- Menu bar quick actions.
- LAN Web UI.
- App Intents.
- Auto unload.
- Hugging Face download manager.
- Multiple simultaneous server management.

## v0.3 Model Profile Editing Requirements

v0.3 should add Model profile editing while preserving Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

Model profile editing should let users update the selected model configuration from the UI and persist valid edits to `models.json`.

Functional requirements:

- Edit `modelID`.
- Edit `displayName`.
- Edit `host`.
- Edit `serverPort`.
- Toggle `enableThinking`.
- Edit `notes`.
- Save valid edits to `models.json`.
- Cancel unsaved edits.
- Reject empty `modelID`.
- Reject empty `host`.
- Reject `serverPort` values outside 1 through 65535.
- Refresh Connection Settings, Copy Config, and copied curl commands after save.
- Use edited `modelID`, `host`, and `serverPort` for Start.
- Warn or guard before changing runtime-affecting fields while a managed process is running.

Recommended running-process behavior:

- Disable `modelID`, `host`, and `serverPort` edits while a managed process is running.
- Explain that those fields can be edited after Stop.
- Keep metadata-only edits optional if they do not imply the running server changed.

v0.3 non-goals:

- Adding or deleting multiple model profiles.
- Multiple simultaneous server management.
- Hugging Face download manager.
- Model file deletion.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- Running `/v1/chat/completions` from the app.
- Launching `mlx_lm.server` from profile editing.
- Stopping external processes from profile editing.

## v0.4 Menu Bar Quick Actions Requirements

v0.4 should add Menu bar quick actions while preserving Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

Menu bar quick actions should provide a lightweight shortcut surface for existing managed-server operations.

Functional requirements:

- Show a macOS menu bar status item.
- Show current managed server status:
  - `stopped`
  - `starting`
  - `ready`
  - `stopping`
  - `failed`
- Start the managed server from the menu bar.
- Stop the managed server from the menu bar.
- Restart the managed server from the menu bar.
- Run Setup Diagnostics from the menu bar.
- Open or focus the main app window from the menu bar.
- Open or expose Connection Settings from the menu bar.
- Quit the app from the menu bar.
- Reuse existing `AppViewModel`, process management, diagnostics, and connection settings behavior.

UI requirements:

- Keep the menu bar surface lightweight.
- Use concise text or icons for status.
- Keep detailed model editing, settings editing, and log review in the main window.
- Do not require polished custom icons, launch-at-login behavior, or log viewer expansion in v0.4.

v0.4 non-goals:

- New model add/delete UI.
- Multiple simultaneous server management.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- Hugging Face download manager.
- Model download.
- Model file deletion.
- Running inference from the app.
- Running `/v1/chat/completions` from the app.
- Full log viewer redesign.
- Distribution build and notarization.

Safety requirements:

- Menu bar status display must not start `mlx_lm.server`.
- Stop must target only the managed process held by this app.
- Menu bar actions must not stop external `mlx_lm.server` processes.
- Menu bar actions must not use `pkill`, `killall`, or `pgrep`.
- Menu bar actions must not add a proxy or change the inference route.

## v0.5 Distribution Build Documentation Requirements

v0.5 should document distribution build steps while preserving Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

The goal is to help users build and run MLX Server Manager locally as a normal macOS app on their own Mac.

Functional documentation requirements:

- Explain Debug build and Release build differences.
- Document manual build steps from Xcode.
- Document CLI build steps with `xcodebuild`.
- Document `.app` output locations.
- Explain local personal-use assumptions.
- Document Gatekeeper, signing, and notarization caveats.
- Explain Apple Developer Program considerations for personal use.
- Explain why App Sandbox is disabled.
- Document prerequisites for launching and stopping `mlx_lm.server`.
- State that `mlx_lm.server executable path` must be configured in the app UI.
- Document where `settings.json` and `models.json` are stored.
- State that model files are not bundled with the app.
- Define GitHub Release asset policy for `.app` bundles.
- Defer automatic packaging.

v0.5 non-goals:

- Performing notarization.
- Apple Developer Program based formal distribution.
- DMG creation.
- Sparkle or other automatic updates.
- Homebrew cask.
- App Store distribution.
- CI/CD.
- GitHub Actions.
- Bundling model files.
- Automatic `mlx-lm` installation.
- Hugging Face download manager.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.

Safety requirements:

- Distribution docs must not add a proxy or change the inference route.
- Distribution verification must not require model inference.
- Model files must not be included in Git or release assets.
- `settings.json`, `models.json`, `.app` bundles, and build artifacts must stay outside Git.
- Examples should use placeholders such as `<path-to-mlx_lm.server>`.
- App Sandbox rationale must stay tied to local managed process control.
- Stop must target only the managed process held by this app.
- Distribution docs must not recommend `pkill`, `killall`, or `pgrep`.

## v0.6 Model Profile Management Requirements

v0.6 should add model profile add and delete operations while preserving Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

The goal is to let users manage multiple saved model profiles in `models.json` without introducing multiple simultaneous server management.

Functional requirements:

- Add a new model profile from the UI.
- Delete an existing model profile from the UI.
- Persist added profiles to `models.json`.
- Persist deleted profile results to `models.json`.
- Select the newly added profile after successful save.
- Switch to a safe fallback profile if the selected profile is deleted.
- Keep at least one model profile.
- Define and enforce duplicate `modelID` behavior.
- Define default values for `displayName`, `modelID`, `host`, `serverPort`, `enableThinking`, and `notes`.
- Show a confirmation UI before deleting a profile.
- Block deleting the last remaining profile.
- Block deleting the running selected profile while a managed server is active.
- Ensure deleting a profile removes only `models.json` profile data.

Recommended add defaults:

- `modelID`: empty until the user enters a value.
- `displayName`: empty draft, filled with `modelID` on save if still empty.
- `host`: `127.0.0.1`.
- `serverPort`: app default port, usually `8080`.
- `enableThinking`: `false`.
- `notes`: empty.

Recommended duplicate behavior:

- Reject duplicate `modelID` values in v0.6.
- Show the validation error in the UI and Logs.
- Consider separate stable profile IDs before allowing duplicate `modelID` values later.

v0.6 non-goals:

- Multiple simultaneous server management.
- Multiple model launches at the same time.
- Model file deletion.
- Hugging Face download manager.
- Model download.
- Automated model existence checks.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- CI/CD.
- Notarization.
- DMG creation.
- App Store distribution.
- Running `/v1/chat/completions` from the app.

Safety requirements:

- Profile add/delete must not run model inference.
- Profile add/delete must not launch `mlx_lm.server`.
- Delete must only remove saved profile data from `models.json`.
- Delete must not remove model files, Hugging Face cache, or local model directories.
- Stop must target only the managed process held by this app.
- External processes must not be stopped.
- `pkill`, `killall`, and `pgrep` must not be used.
- `settings.json`, `models.json`, model files, `.app` bundles, and build artifacts must stay outside Git.
- Examples should use placeholders such as `<model-id>` and `<path-to-model>`.
