# Full App Layout Refresh Design

## Status

- Planning only.
- Target: future v6.x.
- Not implemented in v5.2.0.
- Dashboard UI Refresh v1 remains the current stable surface.

v5.2.0 documents a possible future full app layout direction. It does not change Swift app code, server lifecycle behavior, Direct Mode, import/export behavior, onboarding persistence, API key/token persistence, or process ownership boundaries.

v5.3.0 adds [App Shell / Sidebar Foundation Design](app_shell_sidebar_foundation.md) as a detailed planning document for the first possible future implementation step, `v6.0.0`. It narrows the broader layout direction into a candidate shell/sidebar foundation while still implementing no UI behavior.

v5.4.0 adds [Profiles / Model List Surface Design](profiles_model_list_surface.md) as a detailed planning document for the next possible future implementation step, `v6.1.0`. It focuses on profile metadata browsing and Import / Export placement without implementing model download, model deletion, installed model scanning, or profile behavior changes.

## Goals

- Improve scanability for users managing local MLX servers.
- Make model, profile, server, client setup, logs, and diagnostics context easier to navigate.
- Preserve Direct Mode.
- Preserve explicit lifecycle controls.
- Keep app-managed and external process ownership boundaries clear.
- Keep Dashboard v1 available as the high-level operational overview.
- Avoid turning MLX Server Manager into a Chat UI, inference proxy, or multi-backend router.

## Non-goals

- No inference proxying.
- No Chat UI.
- No multi-backend routing.
- No hidden request rewriting.
- No automatic external process ownership.
- No automatic server Start, Stop, Restart, Adopt, or Forget behavior.
- No model download in this design phase.
- No model deletion.
- No API key, token, or secret storage.
- No onboarding persistence or user tracking.
- No background automation.
- No new network calls.
- No change to `/v1/models` readiness or detection behavior.
- No `/v1/chat/completions` calls by the app.

## Proposed Future Layout Concept

This is a candidate direction, not a finalized implementation.

The future layout may use a larger app shell with:

- Sidebar navigation.
- Main content area.
- Detail or inspector area.

Candidate sidebar sections:

- Dashboard.
- Profiles.
- Server.
- Logs.
- Client Setup.
- Settings.

Candidate main content behavior:

- Dashboard can remain the landing page.
- Section-specific screens can reduce crowding in the current single-page surface.
- Existing controls should remain explicit and discoverable.

Candidate detail or inspector behavior:

- Show selected profile details.
- Show active endpoint and readiness context.
- Show ownership state.
- Show quick copy summary.

This layout should not imply hidden routing, automatic lifecycle actions, or inference proxy behavior.

## Candidate Screens / Areas

### Dashboard

Dashboard v1 should remain the high-level overview:

- Next Steps.
- Current Target.
- Server State.
- Client Setup.
- Diagnostics & Logs Guidance.
- Profiles & Import / Export guidance.

It should remain display-oriented and should not become a hidden automation layer.

### Profiles / Models

A future Profiles screen may include:

- Model profile list.
- Selected profile details.
- `modelID`.
- host and port.
- Advanced Launch Options summary.
- Import / Export entry points.

It must not imply model file installation, model download, model deletion, Hugging Face cache mutation, or server lifecycle changes.

### Server

A future Server screen may focus on:

- app-managed server lifecycle,
- current target,
- readiness,
- ownership,
- explicit Start / Stop / Restart.

Stop and Restart must remain app-managed-process-only. External detected and adopted external servers remain connection context only.

### Logs

A future Logs screen may improve presentation for:

- app logs,
- managed server output surfaced by the app,
- diagnostics entries,
- filtering or grouping if implemented carefully.

It must not capture external server logs. External logs remain where the external process was launched.

### Client Setup

A future Client Setup screen may focus on:

- active endpoint,
- Base URL,
- Model ID guidance,
- API key placeholder,
- JSON config,
- Hermes Agent config,
- readiness curl,
- Direct Mode explanation.

It must not store real API keys, tokens, or secrets.

### Settings

A future Settings screen may organize app preferences. This design phase does not add new settings, secrets, background automation, or model download behavior.

## Direct Mode Boundary

The inference path remains:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

MLX Server Manager provides management context. Clients connect directly to the active server endpoint. The app does not sit in the inference path and does not proxy or rewrite requests.

## Process Ownership Boundary

- App-managed server: process started and tracked by MLX Server Manager.
- External detected server: endpoint detected by `/v1/models`, not managed by MLX Server Manager.
- Adopted external server: connection context selected by the user, not process ownership.

Stop and Restart apply only to app-managed server processes. Forget External Server clears connection context only and does not stop the external process.

## Import / Export Boundary

Import / Export remains profile metadata only:

- no model files,
- no Hugging Face cache,
- no logs,
- no secrets,
- no executable paths,
- no automatic server start,
- no external process ownership changes.

Future layout work may make Import / Export easier to find, but it must not change schema, Rename behavior, Replace behavior, or selected profile semantics without a separate implementation plan.

## Staged Implementation Plan

These versions are proposals only. Do not create tags or implement them from this design document alone.

### v6.0.0 - App Shell / Sidebar Foundation

- Introduce navigation shell.
- Preserve Dashboard v1 behavior.
- Keep existing controls available.
- No runtime behavior change.
- See [App Shell / Sidebar Foundation Design](app_shell_sidebar_foundation.md) for the detailed planning boundary.

### v6.1.0 - Profiles / Model List Surface

- Improve model/profile list presentation.
- Add selected profile summary.
- Keep model profile metadata separate from installed model files.
- No model download or deletion.
- See [Profiles / Model List Surface Design](profiles_model_list_surface.md) for the detailed planning boundary.

### v6.2.0 - Detail Inspector Foundation

- Add selected profile and server detail summary.
- Show endpoint, readiness, ownership, and selected profile context.
- No ownership behavior changes.

### v6.3.0 - Logs Panel Refresh

- Improve managed logs presentation.
- Keep external log boundary explicit.
- Do not capture external process logs.

### v6.4.0 - Client Setup Surface

- Add a focused client setup area.
- Improve active endpoint copy guidance.
- Explain Direct Mode clearly.
- Do not store real API keys, tokens, or secrets.

### v6.5.0 - Metrics / System Context Design

- Explore memory and system context presentation.
- Avoid expensive polling.
- Do not add background automation unless separately designed and reviewed.

## Risks

- UI complexity could make common workflows harder to scan.
- Duplicate Dashboard information could create inconsistent status wording.
- Process ownership could become unclear if managed and external states are not visually separated.
- Users could assume the app proxies inference if client setup is presented carelessly.
- Metrics widgets could add performance overhead.
- Model profile metadata could be confused with installed model files.

## Acceptance Criteria

A future full layout refresh should proceed only if:

- Direct Mode remains clear.
- Lifecycle ownership remains explicit.
- Current Dashboard v1 remains stable during migration.
- Future implementation can be staged safely.
- No runtime behavior changes are required merely to introduce the layout.
- Docs clearly separate current functionality from future work.
- Import / Export remains metadata-only unless a separate proposal changes it.
- API key, token, and secret persistence are not introduced accidentally.

## v5.2.0 Planning Boundary

v5.2.0 adds this planning document only. It does not implement the full app layout refresh, create a new app binary, create a zip asset, tag a release, or change app behavior.

## v5.3.0 Detailed Design Boundary

v5.3.0 adds detailed app shell and sidebar foundation planning only. It does not implement `NavigationSplitView`, sidebar navigation, model table redesign, detail inspector, logs refresh, metrics widgets, new app binary, zip asset, tag, release, or any app behavior change.

## v5.4.0 Profiles Surface Design Boundary

v5.4.0 adds detailed Profiles / Model List Surface planning only. It does not implement a Profiles section, model list table, sidebar navigation, model detail inspector, installed model scanning, model download, model deletion, cache cleanup, new persistence behavior, new app binary, zip asset, tag, release, or any app behavior change.
