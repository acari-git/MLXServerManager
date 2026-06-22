# v17 Integrated GUI Functional Readiness

This document records the readiness pass for the v17.0.0 Integrated GUI Functional Stable release.

## Goal

v17.0.0 keeps the v16 integrated operations GUI and connects the main visible controls to app state and existing operations.

## Integrated layout

The main app opens into a single operations workspace:

```text
left column
- MENU
- SYSTEM metrics
- app footer

center column
- model list
- action bar
- logs

right column
- selected model settings
- Hermes Agent / Direct Mode connection information
```

## Functional wiring completed

### Sidebar

- The integrated sidebar uses `IntegratedWorkspaceDestination`.
- Models remains the primary screenshot-like operations surface.
- Downloads, Settings, Logs, and Help are reachable from the left menu.

### SYSTEM metrics

- Memory gauge is connected to the existing managed-process memory monitor.
- CPU and GPU/Metal are intentionally conservative state labels until real sampling is added.
- Uptime is session-scoped and reflects runtime activity availability.

### Model table

- Rows select the active model profile.
- Status, status detail, proxy-port display, memory text, latest-use text, and auto-unload text are derived through ViewModel helpers.
- The screenshot-like table structure remains intact.

### Action bar

- Start, Stop, Restart, and Speed Test call existing ViewModel actions.
- The action bar includes ready/disabled reasons for each primary action.

### Right model settings

- The right model settings panel exposes Edit and Delete actions.
- Edit uses the existing profile editor sheet.
- Delete remains metadata-only and is disabled while managed runtime is running.

### Hermes / Direct Mode connection

- Base URL display now matches the copied Direct Mode Base URL.
- API key placeholder, Model ID, and full Hermes configuration copy actions remain available.
- The panel explicitly states that proxy wiring is not enabled in this release.

### Logs

- The integrated log panel includes category filtering, latest important log, copy, and clear actions.
- Raw logs remain untranslated.

## Remaining known limitations

- CPU and GPU/Metal usage are not real sampled values yet.
- Proxy port display is informational; proxy mode is not implemented.
- Auto-unload display is not connected to an unload scheduler.
- Model-specific memory attribution is limited to the running managed process.
- Pixel-perfect color/spacing may still need user feedback after real app screenshots.

## Safety boundaries

v17.0.0 preserves Direct Mode:

```text
client -> mlx_lm.server
```

The release does not add:

- Chat UI
- inference proxy
- request inspection
- response rewriting
- credential storage
- model file deletion
- Hugging Face cache cleanup
- telemetry
- automatic download
- automatic start
- LAN Web UI
- App Intents

## Manual checklist

- Open app and confirm integrated workspace appears by default.
- Select rows in the model list.
- Use Start / Stop / Restart / Speed Test buttons where available.
- Confirm action-state summary updates.
- Confirm left menu switches to Downloads, Settings, Logs, and Help.
- Confirm right-side Edit opens the profile editor sheet.
- Confirm right-side Delete shows metadata-only confirmation.
- Confirm Hermes copy actions copy Direct Mode values.
- Confirm logs can be filtered, copied, and cleared.
