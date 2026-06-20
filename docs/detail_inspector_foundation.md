# Detail Inspector Foundation Design

## Status

- Implemented in `v6.2.0` as the first read-only Detail Inspector Foundation.
- Polished in `v6.2.1` with Inspector summary cards and clearer target status identifiers.
- Initially documented in `v5.5.0` as a planning-only design.
- Follows `v6.0.0` App Shell / Sidebar Foundation.
- Follows `v6.1.0` Profiles / Model List Surface.
- Dashboard UI Refresh v1 remains the current stable surface.

v6.2.0 adds a top-level Inspector destination for selected profile and connection target details. v6.2.1 keeps that surface read-only and adds summary cards for selected profile, target status, running model, and restart-required state. It does not implement a three-column layout, endpoint testing, model file management, logs panel refresh, metrics widgets, model download, model deletion, installed model scanning, cache cleanup, new persistence behavior, or runtime behavior changes.

## Goals

- Provide a future area for contextual details.
- Make selected profile metadata easier to inspect.
- Make current target state easier to understand.
- Distinguish selected profile, managed server, and adopted external server.
- Keep endpoint, Base URL, and Model ID copy guidance visible.
- Preserve Direct Mode.
- Preserve explicit lifecycle controls.
- Preserve external process ownership boundaries.
- Preserve metadata-only Import / Export boundaries.
- Avoid implying model file management.

## Non-goals

- No Chat UI.
- No inference proxying.
- No multi-backend routing.
- No hidden request rewriting.
- No model download.
- No model deletion.
- No installed model scanning.
- No cache management.
- No automatic diagnostics.
- No background health checks.
- No API key, token, or secret storage.
- No runtime behavior changes.
- No process ownership changes.
- No selected profile behavior changes.
- No current target behavior changes.
- No Import / Export behavior changes.
- No `/v1/chat/completions` calls by the app.

## Inspector Purpose

The future inspector should be a contextual read-only or mostly read-only summary area. It may show:

- selected profile details,
- current target details,
- server ownership status,
- readiness summary,
- endpoint and Base URL guidance,
- Direct Mode boundary reminders,
- Import / Export metadata-only reminders.

It must not become:

- a Chat UI,
- an inference proxy,
- a model file manager,
- a secrets manager,
- an automatic diagnostics runner,
- a background monitoring agent.

## Context Types

### No Selection

The inspector can show a safe empty state:

- explain that users can select a profile or target to inspect,
- show no automatic actions,
- avoid implying background checks or automatic diagnostics.

### Selected Profile

Possible details:

- display name,
- model ID,
- host,
- port,
- computed Base URL,
- Advanced Launch Options summary,
- local-only fields if currently supported,
- selected state,
- whether it can be used for managed launch.

Clarify:

- selected profile is metadata,
- it may not correspond to installed model files,
- it may not correspond to a running server,
- it may require Restart before a running managed server reflects changes.

### Current Managed Server Target

Possible details:

- current target type,
- managed ownership,
- process lifecycle state,
- readiness state,
- model ID if known,
- Base URL,
- port,
- Start / Stop / Restart boundary reminder.

Clarify:

- Stop and Restart apply only to the app-managed server process,
- readiness does not imply proxying,
- the client connects directly to the server endpoint.

### Adopted External Server Target

Possible details:

- adopted external endpoint,
- model ID if detected,
- readiness or detection state,
- ownership boundary,
- Forget External Server behavior.

Clarify:

- adopted external server is connection context only,
- the app does not stop or restart the external process,
- the app does not capture external logs,
- the app does not take ownership.

### Import / Export Context

Possible details:

- metadata-only summary,
- export/import safety boundaries,
- Rename / Replace guidance,
- conflict handling summary.

Clarify:

- no model files,
- no caches,
- no logs,
- no secrets,
- no executable paths,
- no process ownership transfer.

## Candidate Inspector Layout

These layout details are candidate design only, not implemented UI.

### Header

- context title,
- context type badge,
- selected or current status.

### Endpoint Summary

- Base URL,
- Model ID,
- copy guidance.

### Ownership / Lifecycle

- managed vs adopted external,
- explicit action boundary,
- app-managed-process-only Stop / Restart reminder.

### Readiness

- `/v1/models` detection summary only,
- no `/v1/chat/completions`,
- no inference testing,
- no background health checks.

### Metadata

- profile metadata or import/export metadata,
- selected profile vs current target distinction.

### Safety Notes

- Direct Mode,
- metadata-only Import / Export,
- no model file management,
- no secrets persistence.

## Copy Actions

Future copy affordances should be constrained and explicit.

Possible future copy actions:

- Copy Base URL.
- Copy Model ID.
- Copy endpoint summary.
- Copy Direct Mode client setup hint.

Constraints:

- no generated secrets,
- no real API keys,
- no token storage,
- no client-specific generated config unless separately designed,
- no hidden request rewriting,
- copied guidance must not imply the app proxies requests.

## Relationship to Dashboard v1

Dashboard v1 remains the high-level overview. A future inspector can provide deeper contextual detail without overloading the Dashboard.

Duplicated information should remain minimal and consistent. Dashboard should continue to answer "what should I do next?" while the inspector answers "what exactly is selected or targeted?"

## Relationship to Profiles / Model List Surface

Selecting a profile in a future Profiles section may populate the inspector. The inspector should:

- clarify metadata vs installed files,
- avoid model file operations,
- keep selected profile behavior unchanged,
- show whether selected profile metadata differs from the current target.

See [Profiles / Model List Surface Design](profiles_model_list_surface.md) for the candidate profile list boundary.

## Relationship to Server / Current Target

The inspector can clarify managed vs adopted external target context. It can show readiness state without changing readiness behavior.

It must not:

- add new polling,
- add background health checks,
- change Start / Stop / Restart behavior,
- change External Server Detection / Adopt / Forget behavior,
- take ownership of external processes.

## Relationship to Logs Panel Refresh

The inspector may show a compact current-target and log-boundary summary. A future Logs surface can provide the larger managed log view.

Both surfaces should use the same ownership language:

- app-managed server logs may be shown only when the app already owns the process context,
- adopted external server logs are not captured,
- external processes are not stopped, restarted, killed, inspected, or treated as app-owned.

See [Logs Panel Refresh Design](logs_panel_refresh.md) for the future Logs surface boundary.

## Relationship to Client Setup Surface

The inspector may show compact endpoint details. A future Client Setup surface can provide the larger setup-oriented view.

Both surfaces should use the same Direct Mode and ownership language:

- selected profile metadata may differ from the current target,
- copied setup values are informational,
- MLX Server Manager does not proxy inference requests,
- API keys, tokens, secrets, or generated client config files are not stored.

See [Client Setup Surface Design](client_setup_surface.md) for the future Client Setup surface boundary.

## Relationship to Metrics / System Context

The inspector may show compact readiness or system context. A future Metrics / System Context surface can provide broader non-invasive guidance.

Both surfaces must avoid:

- request inspection,
- telemetry or analytics,
- background monitoring,
- external process metrics collection,
- implying exact model-fit guarantees.

See [Metrics / System Context Design](metrics_system_context.md) for the future metrics and system context boundary.

Before any future v6 implementation begins, review [v6 Implementation Readiness Review](v6_implementation_readiness.md). Detail Inspector remains a later candidate and should not be included in the initial App Shell / Sidebar Foundation implementation.

## Safety Boundaries

- Direct Mode remains unchanged.
- The app does not proxy inference requests.
- Lifecycle controls remain explicit.
- Stop and Restart apply only to app-managed processes.
- External servers remain connection context only.
- Import / Export remains metadata-only.
- No model download or deletion.
- No model scanning or cache cleanup.
- No API key, token, or secret persistence.
- No background automation.

## Risks

- Users may confuse selected profile with running server.
- Users may confuse adopted external server with app-managed server.
- Users may infer model files are installed or managed.
- Copy actions may imply generated client config or secrets handling.
- Readiness display may imply inference testing or proxying.
- Detail density may make Dashboard feel redundant.

## Acceptance Criteria for Future v6.2.0

Future implementation should only be accepted if:

- selected profile vs current target is clearly separated,
- managed vs adopted external ownership is clear,
- Direct Mode is obvious,
- copied endpoint guidance does not imply proxying,
- Import / Export metadata-only boundary is visible,
- no model file management is implied,
- no runtime behavior changes are required,
- no API key, token, or secret persistence is added,
- Dashboard v1 remains stable,
- Start / Stop / Restart behavior is unchanged.

## Future Stages

These versions remain proposals only:

- `v6.0.0`: App Shell / Sidebar Foundation.
- `v6.1.0`: Profiles / Model List Surface.
- `v6.2.0`: Detail Inspector Foundation.
- `v6.3.0`: Logs Panel Refresh.
- `v6.4.0`: Client Setup Surface.
- `v6.5.0`: Metrics / System Context Design.

## v5.5.0 Planning Boundary

v5.5.0 adds this detailed design only. It does not implement the detail inspector, inspector UI, three-column layout, model detail inspector behavior, sidebar navigation, model list table, logs panel refresh, metrics widgets, endpoint testing, model download, model deletion, installed model scanning, cache cleanup, new persistence behavior, new app binary, zip asset, tag, release, or any app behavior change.
