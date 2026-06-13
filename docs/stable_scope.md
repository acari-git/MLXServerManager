# Stable Scope

This document defines the v1.0 stable scope for MLX Server Manager.

MLX Server Manager is a Direct Mode control surface for local `mlx_lm.server`:

```text
OpenAI-compatible client -> mlx_lm.server
```

The app may manage, monitor, and document connection settings for the server. It must not enter the inference request path.

## Included in v1.0

### Managed Server Operations

- Start a local `mlx_lm.server` process using the executable path configured in Settings.
- Stop only the process started and retained by this app.
- Restart through the existing Stop -> port release wait -> Start flow.
- Preserve managed-process-only behavior for Stop and Restart.

### Health and Diagnostics

- Port availability check.
- Ready check via `GET /v1/models`.
- Setup Diagnostics for executable path, host, port, storage paths, port status, and readiness.
- Diagnostics summary with pass, warning, and failure counts.
- Copy Diagnostics Summary.

### Settings and Profiles

- Save and restore app settings.
- Save and restore model profiles.
- Add, edit, and delete model profiles.
- Validate model ID, host, and port.
- Prevent deletion of the last profile.
- Avoid deleting model files or Hugging Face cache.

### Model Switching

- Track selected model and running model separately.
- Allow selection changes while running without immediately changing the active server.
- Show Restart-required state when selected model differs from the running model.
- Apply selected model on explicit Restart.

### UI Surfaces

- Main SwiftUI window.
- Menu bar quick actions.
- Status, selected model, running model, diagnostics, connection settings, and logs.
- Copy Base URL, Model ID, OpenAI-compatible JSON config, `curl /v1/models`, and example `curl /v1/chat/completions`.

### Logs

- Bounded log buffer.
- Readable log categories and levels.
- Clear Logs.
- Copy Logs.

### Distribution Documentation

- Debug and Release build instructions.
- Unsigned local-use `.app` zip asset instructions.
- Zip content verification.
- Launch-after-unzip verification.
- Release note template.

## Stable Safety Rules

- Direct Mode only.
- No proxy in the inference path.
- No Chat UI.
- No model inference from diagnostics or packaging checks.
- No app-side `/v1/chat/completions` execution.
- No `pkill`, `killall`, or `pgrep` in Swift code.
- No external `mlx_lm.server` process termination.
- No model file deletion.
- No Hugging Face cache deletion.
- No committed runtime settings, model files, secrets, app bundles, zip files, dSYM files, or build artifacts.
- No personal fixed paths in docs or Swift code.

## Deferred Beyond v1.0

- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- Hugging Face download manager.
- Model download.
- Model deletion.
- Multiple concurrent server management.
- Multiple model simultaneous launch.
- RAG.
- Embedding manager.
- Tool-call translation.
- Telemetry, analytics, crash reporting, external log sending, cloud logging, or persistent file logging.
- Notarization, Developer ID signing, DMG, App Store distribution, Homebrew cask, auto updater, or CI/CD release automation.
