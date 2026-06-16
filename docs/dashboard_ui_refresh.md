# Dashboard UI Refresh Design

## Purpose

v4.1.0 is a documentation-only design step for a future Dashboard UI Refresh. v4.2.0 adds the first small app-code foundation for that direction by introducing reusable dashboard display structure and clearer Current Target / Server State presentation. v4.3.0 polishes the Current Target card copy and state grouping. v4.4.0 polishes the Server State card copy and state grouping. v4.5.0 adds display-only Logs / Diagnostics guidance for readiness and availability troubleshooting. v4.6.0 adds display-only Profiles / Import Export guidance. The goal is to make MLX Server Manager easier to read at a glance without changing server lifecycle behavior, Direct Mode, import/export behavior, or process ownership boundaries.

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

## v4.2.0 Foundation Implementation

v4.2.0 implements a conservative first step:

- reusable dashboard display components,
- a Current Target card,
- a Server State card,
- clearer managed vs external ownership copy,
- selected model and running model summary,
- Restart Required visibility in the dashboard overview.

This implementation is intentionally presentation-only. It does not:

- move lifecycle ownership into the dashboard cards,
- add automatic Start, Stop, Restart, Adopt, or Forget behavior,
- change `/v1/models` readiness or detection behavior,
- add network calls,
- change Import / Export behavior,
- change model profile schema,
- change external server ownership boundaries,
- implement the full v5.0.0 Dashboard UI Refresh v1.

## v4.3.0 Current Target Polish

v4.3.0 improves only the Current Target card presentation:

- clearer no-target wording,
- clearer managed server wording,
- clearer external detected and adopted external server wording,
- clearer unavailable endpoint wording,
- clearer readiness wording,
- endpoint context that includes host and port when available,
- selected model visibility,
- concise ownership and lifecycle notes.

The Current Target card should answer:

- what endpoint the user is targeting,
- whether MLX Server Manager owns the process,
- whether readiness is known, checking, failed, unavailable, or not checked,
- where an OpenAI-compatible client should connect.

It should not become a lifecycle controller. Start, Stop, Restart, Adopt, and Forget remain explicit existing controls outside the display-only card.

## v4.4.0 Server State Polish

v4.4.0 improves only the Server State card presentation:

- clearer managed process wording,
- clearer stopped, running, unavailable, and failed wording,
- clearer external detected and adopted external context wording,
- readiness and lifecycle state shown as separate concepts,
- memory shown as app-managed process context only,
- lifecycle notes that explain managed-process-only Stop / Restart,
- external server notes that explain connection context only.

The Server State card should answer:

- what the current server or process condition is,
- whether a managed process is attached,
- whether readiness is known, checking, ready, unavailable, or failed,
- what lifecycle expectations apply.

It should not change lifecycle behavior. Start, Stop, Restart, Adopt, and Forget remain explicit existing controls outside the display-only card. External servers remain connection context only and are not stopped, restarted, monitored for memory, or owned by MLX Server Manager.

## v4.5.0 Logs / Diagnostics Guidance Polish

v4.5.0 adds a display-only Dashboard guidance card for logs, diagnostics, readiness, and availability:

- explains where to look when `/v1/models` readiness fails,
- distinguishes managed server logs from external server connection context,
- clarifies that external server logs must be checked where the external server was launched,
- explains port busy / unavailable states without automatic remediation,
- reminds users that Start, Stop, Restart, Adopt, and Forget stay explicit manual actions,
- states that readiness failures do not trigger automatic restart, kill, or ownership changes.

The guidance card should answer:

- where users should look next,
- whether the issue is likely managed-process-related or external-context-related,
- whether logs are available in MLX Server Manager,
- what the app intentionally does not do automatically.

It should not run diagnostics automatically, add background health checks, call new endpoints, change `/v1/models` readiness behavior, or perform lifecycle actions.

## v4.6.0 Profiles / Import Export Polish

v4.6.0 adds a display-only Dashboard guidance card for selected profile metadata and Import / Export safety:

- shows the selected profile display name and model ID,
- shows the selected profile endpoint,
- distinguishes selected profile metadata from the current target,
- explains profile endpoint vs active endpoint,
- summarizes Export Profiles as metadata-only,
- summarizes Import Preview and Import Selected Profiles,
- explains Rename and Replace at a high level,
- repeats that Import / Export does not download, delete, start, stop, import secrets, or change external ownership.

The guidance card should answer:

- which profile is selected,
- which model ID and endpoint it uses,
- whether the current target matches that profile endpoint,
- what Export Profiles includes at a high level,
- what Import Preview, Rename, and Replace mean.

It should not change Import / Export behavior, schema, validation, Rename, Replace, profile persistence, selected profile behavior, lifecycle behavior, or readiness behavior.

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

Current Target should use concise state language:

- `Ready`: `/v1/models` responded successfully,
- `Checking`: readiness check is in progress,
- `Not checked`: readiness has not been checked yet or no active target exists,
- `Unavailable`: endpoint or process is not currently available,
- `Failed`: readiness or endpoint check failed.

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

Server State should keep process, readiness, and lifecycle language distinct:

- Process State: whether an app-managed process is attached, stopped, starting, stopping, external, or unknown.
- Readiness: whether `/v1/models` is not checked, checking, ready, unavailable, or failed.
- Lifecycle: what the existing controls are expected to affect.

Ready means `/v1/models` responded successfully. It does not imply that the app proxies inference requests or owns an external process.

### Active Profile

Active Profile should show:

- selected profile display name,
- selected `modelID`,
- host and port,
- whether Advanced Launch Options are set,
- whether Restart is required to apply the selected profile.

If a managed server is running a different model than the selected profile, the dashboard should show both selected model and running model.

The dashboard should explain that selected profile is saved launch/configuration metadata, while current target is the active managed or adopted endpoint. A profile can be selected even when no server is running.

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

Readiness guidance should explain that failure can mean the target is not running, still starting, on another port, blocked by a port conflict, or not OpenAI-compatible. Users should verify host, port, logs, and endpoint state manually.

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

Dashboard guidance should distinguish:

- app logs,
- managed server logs surfaced by the app,
- external server logs that must be checked outside MLX Server Manager.

Adopted external servers should not imply server log ingestion.

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

Dashboard Import / Export guidance should stay high-level and should not duplicate the full Import Preview UI. Rename should be described as changing the imported display name to avoid a profile-name conflict. Replace should be described as updating one unambiguous local profile with imported metadata. Ambiguous or duplicate replacement targets remain blocked by the existing import flow.

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

- Keep v4.1.0 as the design step.
- Treat v4.2.0 as the first small app-code foundation.
- Treat v4.3.0 as a Current Target presentation polish step.
- Treat v4.4.0 as a Server State presentation polish step.
- Treat v4.5.0 as a Logs / Diagnostics guidance polish step.
- Treat v4.6.0 as a Profiles / Import Export presentation polish step.
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

v4.1.0 is a docs-only design release. v4.2.0 is an app-code foundation release for the dashboard refresh direction. v4.3.0 is a small app-code polish release for Current Target clarity. v4.4.0 is a small app-code polish release for Server State clarity. v4.5.0 is a small app-code polish release for Logs / Diagnostics guidance clarity. v4.6.0 is a small app-code polish release for Profiles / Import Export clarity.

v4.1.0 does not:

- change Swift code,
- change tests,
- change fixtures,
- change Xcode project files,
- add assets,
- create a new app binary,
- create a release asset.

v4.2.0, v4.3.0, v4.4.0, v4.5.0, and v4.6.0 change SwiftUI view code and therefore require new unsigned app zips when released. They still do not change server lifecycle semantics, Direct Mode, readiness behavior, Import / Export behavior, import/export schema, or external process ownership.
