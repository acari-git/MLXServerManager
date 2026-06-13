# Menu Bar Quick Actions

Menu bar quick actions are the planned v0.4 feature for operating MLX Server Manager from the macOS menu bar.

The feature should expose a compact control surface for the existing managed `mlx_lm.server` workflow. It must not add a new inference route, chat surface, or background model operation.

## Goals

- Show managed server status in the macOS menu bar.
- Provide quick Start, Stop, Restart, and Run Diagnostics actions.
- Provide a quick way to open the main app window.
- Provide a quick way to view or reach OpenAI-compatible Connection Settings.
- Keep menu bar actions aligned with the main window state.
- Reuse existing view-model and service behavior instead of duplicating process logic.

## Status Display

The menu bar item should summarize the current managed server status.

Required status states:

- `stopped`
- `starting`
- `ready`
- `stopping`
- `failed`

The implementation may map existing runtime states into these simpler menu bar states. For example:

- `loading` can display as `starting`.
- `readyCheckFailed`, `portCheckFailed`, `portBusy`, `error`, or `unknown` can display as `failed` or a clear warning state.

Status may be shown as text, a system symbol, or a compact combination of both.

## Actions

The menu bar should expose:

- `Start`
- `Stop`
- `Restart`
- `Run Diagnostics`
- `Open App`
- `Connection Settings`
- `Quit`

`Start`, `Stop`, `Restart`, and `Run Diagnostics` should call the same app-level intents already used by the main SwiftUI controls. SwiftUI menu items must not contain low-level process, port probing, ready polling, or diagnostics logic.

## Connection Settings

The menu bar may handle Connection Settings in one of two ways:

1. Open the main window and rely on the existing Connection Settings panel.
2. Show a compact read-only summary with Base URL and Model ID.

If copy actions are added later, they should reuse the existing `ConnectionConfigBuilder` output.

## Window Behavior

`Open App` should show or focus the main app window. It should not reset runtime state, reload settings unnecessarily, or start the server.

## Quit Behavior

`Quit` should behave like a normal app quit command.

Before implementation, decide whether quitting should leave an already managed server running or attempt a managed Stop. v0.4 planning should prefer predictable macOS behavior and avoid stopping external processes. Any managed-process quit behavior must be explicit in the implementation notes and manual tests.

## Non-Goals

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
- Full log viewer redesign.
- Distribution build or notarization.

## Safety Rules

- Preserve Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

- Do not run `/v1/chat/completions` from the app.
- Do not send inference requests from menu bar actions.
- Do not start `mlx_lm.server` just to refresh menu bar status.
- Stop only the process started and held by this app.
- Do not stop external `mlx_lm.server` processes.
- Do not use `pkill`, `killall`, or `pgrep`.
- Do not hardcode user-specific absolute paths.
- Keep `settings.json`, `models.json`, model files, logs, `.env`, and `HF_TOKEN` outside Git.

## Manual Verification

Manual tests should cover:

- Confirm the menu bar status item appears.
- Confirm status shows stopped before Start.
- Start from the menu bar and confirm the main window reaches Ready.
- Confirm status changes through starting and ready.
- Stop from the menu bar and confirm only the managed process stops.
- Confirm status returns to stopped after Stop.
- Restart from the menu bar and confirm Stop, port release, Start, and Ready still work.
- Run Diagnostics from the menu bar and confirm Diagnostics UI and Logs update.
- Open the main app window from the menu bar.
- Open or view Connection Settings from the menu bar.
- Quit from the menu bar.
- Confirm menu bar actions do not call `/v1/chat/completions`.
- Confirm menu bar actions do not run inference.
- Confirm menu bar status display does not start `mlx_lm.server`.
- Confirm menu bar Stop does not stop external server processes.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
