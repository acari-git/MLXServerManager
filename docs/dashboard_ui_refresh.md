# Dashboard UI Refresh Design

## Purpose

v4.1.0 started the Dashboard UI Refresh design. v4.2.0 through v4.9.0 built the Dashboard in small app-code steps: foundation cards, Current Target polish, Server State polish, Logs / Diagnostics guidance, Profiles / Import Export guidance, Onboarding / Next Steps guidance, layout hierarchy, and Client Setup guidance. v5.0.0 finalizes Dashboard UI Refresh v1 as the current stable display-oriented overview. v5.1.0 keeps that surface stable and clarifies future layout boundaries. The goal remains to make MLX Server Manager easier to read at a glance without changing server lifecycle behavior, Direct Mode, import/export behavior, onboarding persistence, API key/token persistence, or process ownership boundaries.

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

## Dashboard v1 Stable Scope

Dashboard UI Refresh v1 is the current stable dashboard surface. It covers:

- Next Steps,
- Current Target,
- Server State,
- Client Setup,
- Diagnostics & Logs Guidance,
- Profiles & Import / Export guidance,
- Direct Mode and lifecycle boundaries,
- managed vs adopted external server ownership boundaries,
- metadata-only Import / Export boundaries.

Dashboard v1 is intentionally not a full app shell redesign. Larger layout work such as sidebar navigation, table-based model management, a right-side inspector, richer metrics widgets, or dedicated client panels should be designed separately after Dashboard v1 and should not be treated as part of v5.1.0 stabilization.

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

## v4.7.0 Onboarding / Next Steps Polish

v4.7.0 adds a display-only Dashboard guidance card for first-run and returning-user next steps:

- explains the immediate next step for stopped, starting, ready, external, adopted, failed, and unknown states,
- distinguishes managed Start from external server adoption,
- explains that selected profiles are used for managed launch,
- points users toward Import Profiles as metadata-only setup help,
- states that Ready means `/v1/models` responded successfully,
- reiterates Direct Mode in dashboard-friendly language,
- repeats that no automatic Start, Adopt, diagnostics, restart, kill, model download, or model deletion occurs.

The guidance card should answer:

- what users should do first when no target is active,
- whether they should start a managed server or adopt an external server,
- what a selected profile contributes to managed Start,
- what readiness means after Start or Adopt,
- where to look if readiness fails,
- what MLX Server Manager intentionally does not do automatically.

It should not add an onboarding flow, modal, persistence flag, user tracking, background checks, automatic diagnostics, new network calls, lifecycle changes, Import / Export changes, selected profile changes, or process ownership changes.

## v4.8.0 Layout / Information Hierarchy Polish

v4.8.0 polishes the Dashboard as a whole without changing card behavior:

- adds small grouping headings to make the scan order explicit,
- keeps `Next Steps` first so users can quickly see the safest next action,
- groups `Current Target` and `Server State` together as target/state context,
- keeps `Diagnostics & Logs Guidance` as the troubleshooting layer,
- keeps `Profiles & Import / Export` as configuration metadata context,
- refines the Dashboard subtitle to explain the intended scan order,
- clarifies card responsibilities without adding controls or changing runtime logic.

The intended Dashboard scan flow is:

1. `Next Steps`: what should I do next?
2. `Current Target`: what am I connected to?
3. `Server State`: what is the current process/readiness/lifecycle condition?
4. `Diagnostics & Logs Guidance`: where should I look when something is not working?
5. `Profiles & Import / Export`: what configuration/profile metadata is relevant?

This step should not add new Start / Stop / Restart controls, change existing controls, run diagnostics automatically, add background checks, change readiness behavior, change Import / Export behavior, change onboarding persistence, or alter process ownership.

## v4.9.0 Copy / Client Setup Polish

v4.9.0 adds a display-only Dashboard guidance card for OpenAI-compatible client setup:

- shows which base URL should be treated as the client target when an endpoint is active,
- distinguishes selected profile endpoint from active managed or adopted external endpoint,
- clarifies that selected profile model ID is launch/configuration metadata,
- warns that adopted external servers may expose different model names,
- reminds users to wait for `/v1/models` readiness before expecting clients to work,
- points users to the existing Connection Settings copy actions,
- states that Direct Mode keeps clients connected directly to the active server endpoint,
- states that MLX Server Manager does not proxy inference requests or store API keys or tokens.

The intended Dashboard scan flow becomes:

1. `Next Steps`: what should I do next?
2. `Current Target`: what am I connected to?
3. `Server State`: what is the current process/readiness/lifecycle condition?
4. `Client Setup`: what should I paste into an OpenAI-compatible client?
5. `Diagnostics & Logs Guidance`: where should I look when something is not working?
6. `Profiles & Import / Export`: what configuration/profile metadata is relevant?

This step should not add new network probes, change `/v1/models` readiness or detection behavior, call `/v1/chat/completions`, add API key storage, add token storage, change copy action behavior, change Start / Stop / Restart behavior, change External Server Detection / Adopt / Forget behavior, change Import / Export behavior, change import/export schema, change onboarding persistence, or alter process ownership.

## v5.0.0 Dashboard UI Refresh v1

v5.0.0 finalizes the Dashboard UI Refresh v1 surface:

- presents the Dashboard as a stable v1 overview,
- keeps the scan flow explicit and consistent,
- keeps each card responsibility clear,
- preserves all existing lifecycle and connection behavior,
- keeps the dashboard display-oriented rather than action-routing-oriented,
- leaves larger app layout redesign work for separate future planning.

Dashboard v1 answers:

1. `Next Steps`: what should I do next?
2. `Current Target`: what am I connected to?
3. `Server State`: what is the current process/readiness/lifecycle condition?
4. `Client Setup`: what should I paste into an OpenAI-compatible client?
5. `Diagnostics & Logs Guidance`: where should I look when something is not working?
6. `Profiles & Import / Export`: what configuration/profile metadata is relevant?

This release should not add new panels, move runtime controls into a new shell, add a sidebar, add a model table redesign, add background metrics widgets, change Start / Stop / Restart behavior, change Direct Mode, change readiness behavior, change Import / Export behavior, add onboarding tracking, add API key/token storage, or change external process ownership.

## v5.1.0 Dashboard Stable Follow-up

v5.1.0 treats Dashboard v1 as the stable current surface and focuses on post-v5.0 documentation clarity:

- keeps Dashboard v1 wording and structure stable,
- reinforces that Dashboard v1 is display-oriented,
- makes future full-layout work explicit and separate,
- preserves all existing lifecycle, readiness, import/export, profile, external server, and connection behavior,
- avoids onboarding persistence, API key/token storage, hidden background checks, and new network calls.

Dashboard Stable Follow-up is not a three-column app redesign. It does not add a sidebar, model table redesign, right-side inspector, persistent system metrics widgets, Hermes-specific panels, automatic diagnostics, or any lifecycle action changes.

## v5.2.0 Full App Layout Refresh Planning

v5.2.0 adds [Full App Layout Refresh Design](full_app_layout_refresh.md) as planning for possible future v6.x layout work. Dashboard v1 remains the current stable surface. The planning document may discuss sidebar navigation, model list tables, detail inspectors, logs panels, client setup surfaces, and metrics areas, but those are future candidates only.

v5.2.0 does not implement a new layout, change Dashboard card order, move runtime controls, add background checks, change readiness behavior, change Import / Export behavior, add onboarding tracking, add API key/token storage, or change process ownership.

v5.3.0 adds [App Shell / Sidebar Foundation Design](app_shell_sidebar_foundation.md) as a narrower design for the first possible future v6.0.0 step. It keeps Dashboard v1 as the future landing surface and does not implement a sidebar, `NavigationSplitView`, or any behavior change.

v5.4.0 adds [Profiles / Model List Surface Design](profiles_model_list_surface.md) as a narrower design for a possible future v6.1.0 Profiles section. Dashboard v1 remains the high-level overview and does not become a model table or model-file management surface.

v5.5.0 adds [Detail Inspector Foundation Design](detail_inspector_foundation.md) as a narrower design for a possible future v6.2.0 inspector area. Dashboard v1 remains the high-level overview; any future inspector should provide contextual detail without changing Dashboard behavior or implying proxying, model-file management, or automatic diagnostics.

v5.6.0 adds [Logs Panel Refresh Design](logs_panel_refresh.md) as a narrower design for a possible future v6.3.0 Logs surface. Dashboard v1 remains the high-level overview; any future Logs surface should provide deeper managed-log context without capturing external logs, adding telemetry, adding background monitoring, or changing lifecycle behavior.

v5.7.0 adds [Client Setup Surface Design](client_setup_surface.md) as a narrower design for a possible future v6.4.0 Client Setup surface. Dashboard v1 remains the high-level overview; any future Client Setup surface should provide deeper endpoint guidance without generating credentials, persisting client configs, adding endpoint tests, or changing Direct Mode.

## Target Information Architecture

Dashboard v1 prioritizes these areas:

1. Next Steps
2. Current Target
3. Server State
4. Client Setup
5. Diagnostics & Logs
6. Profiles / Import Export
7. Lifecycle Controls
8. Readiness
9. Memory
10. Connection Settings
11. Detailed Logs and Diagnostics

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

Dashboard Next Steps guidance should remain static and display-only. It can summarize the first action users should consider for the current state, but it must not become a wizard, store completion state, trigger automatic checks, or perform lifecycle actions.

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

Dashboard v1 should:

- use clear text labels instead of relying only on color,
- keep status labels short and scannable,
- avoid low-contrast status text,
- keep important actions keyboard reachable,
- avoid hiding destructive or process-affecting actions in ambiguous menus,
- preserve readable log text,
- avoid one-color visual themes that make status harder to scan.

## Staged Implementation Plan

### v4.x Foundation and v5.0.0 Stabilization

- Keep v4.1.0 as the design step.
- Treat v4.2.0 as the first small app-code foundation.
- Treat v4.3.0 as a Current Target presentation polish step.
- Treat v4.4.0 as a Server State presentation polish step.
- Treat v4.5.0 as a Logs / Diagnostics guidance polish step.
- Treat v4.6.0 as a Profiles / Import Export presentation polish step.
- Treat v4.7.0 as an Onboarding / Next Steps presentation polish step.
- Treat v4.8.0 as a Dashboard layout and information hierarchy polish step.
- Treat v4.9.0 as a Copy / Client Setup presentation polish step.
- Treat v5.0.0 as the Dashboard UI Refresh v1 stabilization release.
- Treat v5.1.0 as the Dashboard Stable Follow-up documentation release.
- Treat v5.2.0 as the Full App Layout Refresh planning release.
- Treat v5.3.0 as the App Shell / Sidebar Foundation design release.
- Treat v5.4.0 as the Profiles / Model List Surface design release.
- Treat v5.5.0 as the Detail Inspector Foundation design release.
- Treat v5.6.0 as the Logs Panel Refresh design release.
- Treat v5.7.0 as the Client Setup Surface design release.
- Confirm the v1 information architecture and safety boundaries.
- Keep Import / Export stable release boundaries intact.

### Completed v5.0.0: Dashboard UI Refresh v1

Dashboard UI Refresh v1 focuses on layout and state presentation only:

- Current Target summary in first viewport.
- clearer Server State and profile context sections.
- visible lifecycle boundaries and managed-process-only expectations.
- managed vs external state labels.
- visible readiness, memory, client setup, logs, diagnostics, profiles, and Import / Export guidance.

v5.0.0 does not add runtime features.

### Later Optional Work After Dashboard v1

- screenshot refresh after Dashboard v1,
- broader app layout refresh,
- sidebar navigation,
- model list table,
- model detail inspector,
- logs panel refresh,
- system metrics panel,
- keyboard shortcut polish,
- compact mode,
- deeper log filtering,
- richer diagnostics grouping.

These should be separate scoped steps.

These items are intentionally outside Dashboard Stable Follow-up. Any future layout refresh should define its own scope, behavior boundaries, screenshots, and release checklist before implementation.

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

v4.1.0 is a docs-only design release. v4.2.0 is an app-code foundation release for the dashboard refresh direction. v4.3.0 is a small app-code polish release for Current Target clarity. v4.4.0 is a small app-code polish release for Server State clarity. v4.5.0 is a small app-code polish release for Logs / Diagnostics guidance clarity. v4.6.0 is a small app-code polish release for Profiles / Import Export clarity. v4.7.0 is a small app-code polish release for Onboarding / Next Steps clarity. v4.8.0 is a small app-code polish release for layout and information hierarchy clarity. v4.9.0 is a small app-code polish release for Copy / Client Setup clarity. v5.0.0 is the Dashboard UI Refresh v1 stabilization release. v5.1.0 is a Dashboard Stable Follow-up documentation release. v5.2.0 is a Full App Layout Refresh planning release. v5.3.0 is an App Shell / Sidebar Foundation design release. v5.4.0 is a Profiles / Model List Surface design release. v5.5.0 is a Detail Inspector Foundation design release. v5.6.0 is a Logs Panel Refresh design release. v5.7.0 is a Client Setup Surface design release.

v4.1.0 does not:

- change Swift code,
- change tests,
- change fixtures,
- change Xcode project files,
- add assets,
- create a new app binary,
- create a release asset.

v4.2.0, v4.3.0, v4.4.0, v4.5.0, v4.6.0, v4.7.0, v4.8.0, v4.9.0, and v5.0.0 change SwiftUI view code and therefore require new unsigned app zips when released. v5.1.0 through v5.7.0 are docs-only unless app code changes are added later. These releases still do not change server lifecycle semantics, Direct Mode, readiness behavior, Import / Export behavior, import/export schema, selected profile behavior, current target behavior, onboarding persistence, API key/token persistence, generated client config persistence, automatic client configuration behavior, new network behavior, external process ownership, external log capture behavior, telemetry behavior, background monitoring behavior, model download behavior, model deletion behavior, model scanning, or cache cleanup.
