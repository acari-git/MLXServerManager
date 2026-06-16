# Dashboard UI Refresh Design

## Purpose

v4.1.0 is a documentation-only design step for a future Dashboard UI Refresh. The goal is to make MLX Server Manager easier to read at a glance without changing server lifecycle behavior, Direct Mode, import/export behavior, or process ownership boundaries.

The refreshed dashboard should help users quickly answer:

- Which target am I connected to?
- Is the target managed by MLX Server Manager or external?
- Which model profile is selected?
- Is a managed server running, ready, starting, stopping, stopped, failed, or blocked by an external server?
- What actions are safe right now?
- Where do I copy OpenAI-compatible connection settings?
- Where do I inspect logs, memory, diagnostics, and import/export actions?

## Non-Goals

The Dashboard UI Refresh must not:

- become a Chat UI,
- proxy inference requests,
- perform multi-backend routing,
- hide request rewriting,
- start, stop, or restart servers automatically,
- take ownership of external processes automatically,
- kill, stop, or restart adopted external servers,
- download models,
- delete models,
- change Import / Export behavior,
- change `/v1/models` readiness or detection semantics,
- change Direct Mode.

## Direct Mode Boundary

The inference path remains:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

MLX Server Manager remains a local control surface for process management, state visibility, profile metadata, diagnostics, logs, memory display, and connection settings. It does not sit in the inference request path.

## Current UI Limitations

The current app exposes the required functionality, but the dashboard can become dense as features accumulate:

- managed server status, selected model, running model, adopted external state, and restart-required state are visible but distributed,
- Connection Settings has the best target summary, but it is not always the first place users look,
- Stop / Restart affordances need to remain visibly scoped to app-managed processes,
- adopted external server state needs stronger separation from managed process ownership,
- logs and diagnostics are useful but compete with profile editing and connection-copy actions,
- stable Import / Export actions are available but should be easier to discover without implying model download or install behavior,
- first-run guidance should be visible without turning into a wizard or hidden automation.

## Target Information Architecture

The refreshed dashboard should prioritize these areas in the first viewport:

1. Current Target
2. Server State
3. Active Profile
4. Lifecycle Controls
5. Readiness
6. Memory
7. Logs
8. Profiles
9. Import / Export
10. Onboarding / Diagnostics

This does not require large visual decoration. The goal is a clearer operational hierarchy.

## Proposed Dashboard Areas

### Current Target

The top summary should show the current connection target:

- target type: Managed Server, External Server Detected, Adopted External Server, or Not Running,
- base URL,
- selected model ID,
- API key placeholder,
- whether the target is app-managed,
- whether connection settings are copy-ready.

Current Target should not imply that the app proxies inference. It should state or visually imply that copied settings are for external OpenAI-compatible clients.

### Server State

Server State should show:

- stopped,
- starting,
- ready,
- stopping,
- failed,
- external detected,
- adopted external,
- unavailable or disconnected.

State labels should distinguish process ownership from endpoint reachability.

### Active Profile

Active Profile should show:

- selected profile display name,
- selected `modelID`,
- host and port,
- whether Advanced Launch Options are set,
- whether Restart is required to apply the selected profile.

If a managed server is running a different model than the selected profile, the dashboard should show both selected model and running model.

### Lifecycle Controls

Lifecycle controls should stay explicit:

- Start starts a new app-managed `mlx_lm.server` only when safe.
- Stop stops only the app-managed process.
- Restart applies only to the app-managed process.
- Adopt External Server is a connection-context action only.
- Forget External Server clears connection context only.

Dangerous or disruptive actions should be visually distinct, but not dramatized. Disable states should explain why an action is unavailable.

### Readiness

Readiness display should remain based on `/v1/models` only.

The dashboard should distinguish:

- not checked,
- checking,
- ready,
- failed,
- endpoint reachable but model list unavailable,
- external server detected,
- adopted external server disconnected.

Readiness display must not call `/v1/chat/completions`.

### Memory

Memory should be visible for app-managed processes only.

For external or adopted external servers, show:

```text
Not available for external server
```

The dashboard should not attempt to inspect external process memory.

### Logs

Logs should remain local app logs, not server log ingestion for external processes.

The refreshed dashboard should keep:

- recent log visibility,
- Copy Logs,
- Clear Logs,
- warning/error readability,
- bounded log buffer behavior.

### Profiles

Profiles should remain an entry point for:

- selected profile,
- Add Profile,
- Edit Profile,
- Delete Profile,
- Advanced Launch Options,
- Import Profiles,
- Export Profiles.

Profile actions should be clearly metadata-oriented unless they explicitly trigger Start / Stop / Restart through existing lifecycle controls.

### Import / Export

Import / Export is stable as of v4.0.0 and should be discoverable in the refreshed dashboard.

The dashboard should surface:

- Export Profiles,
- Import Profiles Preview,
- Import Selected Profiles,
- Rename conflicted profiles,
- Replace conflicted profiles,
- metadata-only safety notes.

It should not imply:

- model install,
- model download,
- model deletion,
- cache mutation,
- server start after import,
- external process ownership changes.

### Onboarding / Diagnostics

First-run guidance should remain short and state-aware. It can live near the top of the dashboard when setup is incomplete, then collapse or become less prominent once the app is configured.

Diagnostics should stay close to setup state:

- executable path,
- port availability,
- `/v1/models` readiness,
- profile setup,
- connection settings copy readiness.

## Managed vs External Presentation

The refreshed dashboard should clearly distinguish:

- app-managed `mlx_lm.server`,
- detected external OpenAI-compatible server,
- adopted external server,
- no active target,
- unavailable target,
- readiness unknown,
- readiness failed,
- endpoint reachable but model list unavailable.

Adopted External Server must be labeled as:

```text
Connection context only
Not managed by MLX Server Manager
```

Stop and Restart must remain unavailable for adopted external servers.

## Accessibility and Readability

The future dashboard should:

- use clear text labels instead of relying only on color,
- keep status labels short and scannable,
- avoid low-contrast status text,
- keep important actions keyboard reachable,
- avoid hiding destructive or process-affecting actions in ambiguous menus,
- preserve readable log text,
- avoid one-color visual themes that make status harder to scan.

## Staged Implementation Plan

### v4.x Foundation

- Keep this v4.1.0 step docs-only.
- Confirm information architecture and safety boundaries.
- Identify current UI sections that can be reorganized without changing behavior.
- Keep Import / Export stable release boundaries intact.

### v5.0.0 Candidate: Dashboard UI Refresh v1

Potential v5.0.0 implementation should focus on layout and state presentation only:

- Current Target summary in first viewport.
- clearer Server State and Active Profile sections.
- grouped lifecycle controls with safer disabled-state explanations.
- managed vs external state labels.
- visible readiness and memory summaries.
- improved placement for logs, diagnostics, profiles, and Import / Export.

v5.0.0 should not add new runtime features unless separately designed.

### Later Optional Work

- screenshot refresh after the dashboard UI changes,
- keyboard shortcut polish,
- compact mode,
- deeper log filtering,
- richer diagnostics grouping.

These should be separate scoped steps.

## Safety Boundaries

The Dashboard UI Refresh must preserve:

- Direct Mode,
- explicit Start / Stop / Restart,
- managed-process-only Stop and Restart,
- adopted external server as connection context only,
- `/v1/models` readiness and detection only,
- no `/v1/chat/completions` calls by the app,
- no model download,
- no model deletion,
- no hidden network calls,
- no import/export side effects beyond selected metadata writes,
- no external process ownership changes.

## Release Positioning

v4.1.0 is a docs-only design release.

It does not:

- change Swift code,
- change tests,
- change fixtures,
- change Xcode project files,
- add assets,
- create a new app binary,
- create a release asset.

The current binary asset remains the v3.5.0 unsigned build unless a later app-code release changes the app.
