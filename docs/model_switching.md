# Model Switching

## Purpose

Model profile management allows multiple saved profiles. Model switching defines how the app should behave when the selected profile changes, especially while a managed `mlx_lm.server` process is already running.

The main risk is ambiguity: the user may select a different profile while the server is still running with the previous profile. v0.7 should make that state visible instead of silently implying that the running server changed.

## Definitions

- Selected profile: the profile selected in the model list.
- Running profile: the model profile snapshot used when the current managed process was started.
- Pending profile: a selected profile that differs from the running profile while the server is running.
- Restart required: the state shown when the pending profile will not take effect until Restart.

Runtime profile comparison should use:

- `modelID`
- `host`
- `serverPort`

Metadata-only differences should not require a server restart by themselves.

## Required Behavior

### Stopped State

- Selecting a profile changes the selected profile immediately.
- Model detail follows the selected profile.
- Connection Settings, Copy Config, and copied curl commands follow the selected profile.
- Start launches the selected profile.
- Logs may record the selected profile change.

### Running State

- Selecting a different profile is allowed.
- The running server is not stopped.
- A new server is not started.
- The running profile remains attached to the managed process.
- If runtime fields differ, the UI shows `Restart required`.
- Connection Settings, Copy Config, and copied curl commands continue to follow the selected profile.
- The UI should also show the running profile so users can see what the active server is actually serving.
- Logs should explain that Restart is required before the selected profile is active.

### Restart

- Restart applies the currently selected profile.
- Restart uses the existing managed process flow:
  1. Stop the managed process.
  2. Wait for port release.
  3. Start `mlx_lm.server` with the selected profile.
  4. Check readiness with `GET /v1/models`.
- Restart must not stop external processes.

### Stop

- Stop targets only the managed process held by the app.
- Stop does not depend on the currently selected profile.
- After Stop, the selected profile becomes the profile that Start will use next.

## UI Requirements

- Model list clearly marks the selected profile.
- Status or detail area shows `Running model` when a managed process exists.
- Status or detail area shows `Restart required` when selected runtime profile and running runtime profile differ.
- The message should be concise and operational, for example:

```text
Restart required to apply selected model.
```

- The UI should avoid implying that selection alone changes the active server.

## Log Requirements

Useful log examples:

```text
[model] selected profile: <model-id>
[model] selected profile differs from running profile. Restart required.
[restart] applying selected profile: <model-id>
[start] starting selected profile: <model-id>
```

Logs must not include secrets. Logs should use placeholders or model IDs only.

## Connection Settings

Connection Settings, Copy Config, and copied curl commands follow the selected profile. This lets users prepare external clients for the profile they intend to run next.

When a managed server is running a different profile, the UI should separately show the running profile to prevent confusion.

## Manual Test Checklist

- Multiple profiles are visible in the model list.
- The selected profile is visually clear.
- While stopped, selecting a profile updates Model detail.
- While stopped, Connection Settings and copied config follow the selected profile.
- While stopped, Start uses the selected profile.
- While running, selecting a different profile does not stop the server.
- While running, selecting a different profile does not start another server.
- While running, `Restart required` appears when runtime fields differ.
- While running, the running model remains visible.
- Restart applies the selected profile and reaches Ready.
- After Restart, the running model matches the selected profile.
- Stop stops only the managed process.
- After Stop, Start uses the currently selected profile.
- Logs explain profile selection and Restart-required state.

## Safety Checklist

- Direct Mode is maintained.
- No Proxy is added.
- No Chat UI is added.
- The app does not send `/v1/chat/completions`.
- Model switching does not run inference.
- Selecting a model does not start `mlx_lm.server`.
- Restart and Stop target only the managed process.
- External processes are not stopped.
- `pkill`, `killall`, and `pgrep` are not used.
- Model files, Hugging Face cache, and local model directories are not deleted.
- `settings.json`, `models.json`, model files, `.app` bundles, and build artifacts stay outside Git.
