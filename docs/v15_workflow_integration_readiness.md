# v15 Workflow Integration Readiness

This document records the readiness pass for the v15.0.0 GUI Workflow Integration Stable release.

## Goal

v15.0.0 turns the v14 GUI split into practical day-to-day workflows:

- Dashboard is the overview and launcher.
- Models owns profile management.
- Downloads owns model acquisition and recovery.
- Runtime owns start / stop / diagnostics / benchmark / connection presets.
- Settings owns app settings and language selection.
- Logs owns troubleshooting context.

## Verified surface ownership

### Dashboard

Dashboard no longer acts as the dense all-in-one workbench. It shows current state, next actions, and recent activity, then links users to the right surface.

### Models

Models now supports:

- row selection
- source filtering
- text search
- selected model inspector
- Add / Edit / Delete
- Import / Export
- launch command preview
- advanced launch options preview
- metadata-only deletion safety messaging

### Downloads

Downloads now supports:

- Hugging Face search
- selected result preview
- download form
- save directory picker
- queue review
- latest failed download recovery card
- restore form
- copy URL
- retry
- post-completion links to Models and Runtime

### Runtime

Runtime now supports:

- Start / Stop / Restart
- Ready Check
- Speed Test
- runtime metrics
- action-state guidance
- benchmark detail and copy actions
- runtime timeline
- connection presets

### Settings

Settings now supports:

- executable path
- default host
- default port
- API key placeholder
- System / Japanese / English language selection
- Save Settings
- Run Diagnostics

### Logs

Logs now supports:

- log list
- copy logs
- clear logs
- troubleshooting summary
- latest important log
- Direct Mode boundary explanation

## Language boundary

The app-local language setting applies to app labels and primary actions. It should not translate:

- model IDs
- repository IDs
- file paths
- raw logs
- CLI output
- command previews

## Safety boundary

v15.0.0 preserves Direct Mode:

```text
client -> mlx_lm.server
```

No chat UI, inference proxy, request inspection, telemetry, automatic download, automatic start, model-file deletion, cache cleanup, token storage, LAN Web UI, or App Intents are introduced.

## Manual verification checklist

- Open Dashboard and use navigation actions.
- Select a model in Models.
- Filter and search models.
- Open Add / Edit profile sheets.
- Import preview remains preview-only until explicit import.
- Downloads search / preview / form remains explicit.
- Failed download recovery actions are visible when a failure exists.
- Runtime shows disabled reasons for Stop / Restart / Speed Test.
- Settings can edit language, host, port, executable path, and API key placeholder.
- Logs show troubleshooting summary and copy / clear actions.
