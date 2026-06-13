# Logging and Diagnostics

## Purpose

Logging and Diagnostics help users understand what MLX Server Manager checked, what operation ran, and why an action failed.

v0.8 should improve usability without changing the runtime architecture. The app remains a Direct Mode control surface:

```text
OpenAI-compatible client -> mlx_lm.server
```

## Logging Goals

- Keep log output bounded.
- Keep Clear Logs.
- Improve readability of existing log lines.
- Make categories and severity visible.
- Make Start, Stop, Restart, Diagnostics, Profile, and Switching operations easier to follow.
- Make warnings and errors easier to find.
- Provide a copy path for troubleshooting.

## Suggested Log Categories

The app should use consistent categories where possible:

- `info`: general app state
- `warning`: recoverable warning
- `error`: failed operation or validation error
- `start`: Start sequence
- `stop`: Stop sequence
- `restart`: Restart sequence
- `diagnostics`: Setup Diagnostics
- `profile`: add, edit, and delete profile actions
- `switching`: selected model, running model, and Restart-required state
- `ready`: `/v1/models` readiness checks
- `port`: port availability checks
- `memory`: managed process memory monitoring
- `process`: captured stdout/stderr and managed process exit
- `settings`: settings and model persistence

The UI can remain text based in v0.8. Color, icons, and filters are optional.

## Copy Behavior

v0.8 should consider:

- `Copy Logs`
- `Copy Diagnostics Summary`

Copied output should be local-only text for user troubleshooting. It must not upload logs or send them to any external service.

Runtime logs may include user-selected local paths, such as an executable path. That is acceptable for local display and copy actions. Docs and Swift code must not hardcode personal paths.

## Diagnostics Goals

Diagnostics should make result status and next action easy to see.

Important checks:

- executable path configured
- executable path exists
- executable path is executable
- host is non-empty
- port is in range
- settings and models storage path is available
- Port Check result
- Ready Check result through `GET /v1/models`

Diagnostics should make `pass`, `warning`, and `fail` easy to distinguish. The summary should show failure and warning counts in a form that is easy to scan.

## Troubleshooting Checklist

When Start fails:

- Check executable path configured, exists, and executable.
- Check Port availability.
- Check captured process stderr.
- Check Ready Check status through `/v1/models`.

When Stop fails:

- Confirm a managed pid is attached.
- Confirm Stop targets only the managed process.
- Check port release logs.

When Restart fails:

- Check Stop result first.
- Check port release result.
- Check Start command summary.
- Check Ready Check result.

When Diagnostics show warnings:

- Confirm whether a managed server is intentionally running.
- Check whether Port availability warning is due to the managed server.
- Check whether Ready warning is expected because the server is stopped.

When model switching is confusing:

- Compare Selected Model and Running Model.
- Check whether `Restart required` is visible.
- Restart only when the selected model should replace the running model.

When profile operations fail:

- Check validation messages.
- Confirm `modelID`, `host`, and `serverPort` are valid.
- Confirm duplicate `modelID` is not being added.
- Confirm profile delete is not blocked because a managed server is running.

## Non-Goals

- Remote log sending.
- Telemetry.
- Analytics.
- Crash reporting service.
- External log collection service integration.
- Cloud logging.
- File-persistent logs.
- Automatic log upload.
- Proxy mode.
- Chat UI.
- Model inference from diagnostics.
- `/v1/chat/completions` from the app.
- Stopping external processes.
- Model file deletion.
- Hugging Face cache deletion.
- Model download.

## Safety Requirements

- Keep Direct Mode.
- Diagnostics must not run model inference.
- Diagnostics must not start `mlx_lm.server`.
- Diagnostics must not stop external processes.
- Diagnostics must keep Ready Check limited to `/v1/models`.
- Stop must target only the managed process.
- `pkill`, `killall`, and `pgrep` must not be used.
- Model files, Hugging Face cache, and local model directories must not be deleted.
- `settings.json`, `models.json`, model files, `.app` bundles, and build artifacts must stay outside Git.
