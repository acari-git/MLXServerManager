# v6 Implementation Readiness Review

## Status

- Planning / readiness review only.
- Not implemented in `v5.9.0`.
- Target implementation series: future `v6.x`.
- Dashboard UI Refresh v1 remains the current stable surface.

v5.9.0 consolidates the future v6 planning docs and defines readiness criteria before app-code implementation starts. It does not implement v6 UI, app shell, sidebar navigation, Profiles section, Detail Inspector, Logs Panel, Client Setup Surface, Metrics / System Context, new persistence, new network behavior, or app behavior changes.

## Purpose

The v6 planning sequence now has detailed design documents for each proposed surface. This readiness review defines the order, guardrails, and acceptance criteria that should be checked before any future v6 app-code release begins.

The main decision is conservative:

- v6 implementation may start with a narrow `v6.0.0 App Shell / Sidebar Foundation`.
- v6.0.0 must preserve Dashboard UI Refresh v1.
- v6.0.0 must not pull in later surfaces.
- every future v6 release must preserve Direct Mode, lifecycle, external ownership, Import / Export, and privacy boundaries.

## Reviewed Planning Docs

- [Full App Layout Refresh Design](full_app_layout_refresh.md)
- [App Shell / Sidebar Foundation Design](app_shell_sidebar_foundation.md)
- [Profiles / Model List Surface Design](profiles_model_list_surface.md)
- [Detail Inspector Foundation Design](detail_inspector_foundation.md)
- [Logs Panel Refresh Design](logs_panel_refresh.md)
- [Client Setup Surface Design](client_setup_surface.md)
- [Metrics / System Context Design](metrics_system_context.md)

## Proposed v6 Sequence

These versions are proposals only. Implementation should remain staged and independently reviewable.

1. `v6.0.0` - App Shell / Sidebar Foundation
2. `v6.1.0` - Profiles / Model List Surface
3. `v6.2.0` - Detail Inspector Foundation
4. `v6.3.0` - Logs Panel Refresh
5. `v6.4.0` - Client Setup Surface
6. `v6.5.0` - Metrics / System Context

Each release should avoid pulling in later-stage scope.

## v6.0.0 Readiness

Future v6.0.0 should focus only on:

- app shell foundation,
- sidebar or navigation structure,
- Dashboard v1 as the default landing surface,
- minimal wiring needed to preserve existing behavior,
- no runtime behavior changes.

Future v6.0.0 should not include:

- Profiles model table,
- Detail Inspector,
- Logs Panel refresh,
- Client Setup Surface expansion,
- Metrics / System Context,
- telemetry,
- background monitoring,
- proxying,
- new network behavior,
- model download or deletion,
- Import / Export behavior changes.

## Required Safety Invariants

Every future v6 implementation release must preserve the following invariants.

### Direct Mode

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app must not:

- proxy inference requests,
- provide Chat UI,
- route between backends,
- rewrite requests,
- inspect inference traffic.

### Lifecycle

- Start / Stop / Restart remain explicit user actions.
- Stop / Restart apply only to app-managed server processes.
- Adopted external servers remain connection context only.

### External Process Ownership

The app must not:

- stop external processes,
- restart external processes,
- kill external processes,
- take ownership of external processes,
- capture external logs,
- collect external process metrics.

### Import / Export

Import / Export remains metadata-only.

The app must not:

- copy model files,
- download models,
- delete models,
- scan installed models,
- clean caches,
- copy logs,
- store secrets,
- transfer process ownership.

### Privacy / Security

The app must not add:

- API key storage,
- token storage,
- secret persistence,
- telemetry,
- analytics,
- request logging,
- request tracing,
- inference traffic inspection,
- generated client config persistence,
- automatic client configuration.

### Performance

The app must avoid:

- heavy polling,
- background monitoring by default,
- inference-path instrumentation,
- metrics persistence,
- token throughput measurement,
- benchmark runner behavior.

## Implementation Guardrails

Future v6 implementation PRs or commits should follow these guardrails:

- one major surface per release,
- keep release scope small,
- avoid combining UI shell with behavior changes,
- keep Dashboard v1 available,
- avoid moving controls unless behavior remains obvious,
- use explicit labels for managed vs adopted external,
- keep selected profile distinct from current target,
- keep copy actions safe and non-secret,
- do not introduce new network calls without separate design,
- do not modify Import / Export schema without separate design,
- do not add persistence without separate design.

## v6.0.0 Acceptance Criteria

Future v6.0.0 should only be accepted if:

- Dashboard v1 remains available and is default or easy to access,
- existing behavior remains unchanged,
- Direct Mode remains obvious,
- Start / Stop / Restart behavior remains unchanged,
- external ownership boundary remains obvious,
- selected profile behavior remains unchanged,
- current target behavior remains unchanged,
- Import / Export behavior remains unchanged,
- no model download or deletion is added,
- no telemetry or background monitoring is added,
- no secrets persistence is added,
- no new binary safety risks are introduced,
- build and tests pass.

## Release Verification Checklist

Future v6 implementation releases should run:

- `git diff --check`,
- Xcode build,
- tests if available,
- verify no generated artifacts are tracked,
- verify no `.app`, `.zip`, `.dSYM`, `build/`, or `dist/`,
- verify no `.env`, token files, settings exports, or model files,
- grep for local user paths,
- grep for token-like strings,
- inspect Swift changes for unsafe process commands,
- inspect for new network calls,
- inspect for `/v1/chat/completions`,
- inspect for changed `/v1/models` behavior,
- inspect for new persistence,
- inspect for Import / Export schema changes,
- inspect for lifecycle behavior changes,
- inspect for external process ownership changes.

## Manual Review Checklist

Future v6 implementation releases should manually confirm:

- app launches,
- Dashboard v1 still appears,
- existing controls remain understandable,
- current target display remains correct,
- managed server actions are explicit,
- external adoption boundary remains clear,
- copy guidance does not imply proxying,
- Import / Export remains metadata-only,
- no Chat UI appeared,
- no model download/delete UI appeared,
- no secrets UI appeared,
- no telemetry or metrics collection appeared.

## Risks Before v6

- Too much UI change in one release.
- Sidebar hiding critical server controls.
- Dashboard v1 becoming redundant or inaccessible.
- Users thinking the app proxies requests.
- Users thinking adopted external servers are app-owned.
- Model profile metadata being confused with installed model files.
- Copy actions implying secrets or config generation.
- Metrics implying telemetry or monitoring.
- Logs implying external log capture.

## Recommended v6.0.0 Scope

The recommended first implementation step is narrow:

- implement only app shell/sidebar foundation,
- keep existing Dashboard view as the main content,
- make Dashboard the default selection,
- avoid implementing later surfaces,
- keep existing runtime controls in their current behavior,
- defer Profiles, Inspector, Logs, Client Setup, and Metrics expansion to later releases.

## Not Ready Items

These remain not ready for implementation unless separately designed:

- model download,
- model deletion,
- installed model scanning,
- cache cleanup,
- automatic diagnostics,
- telemetry,
- background monitoring,
- API key/token storage,
- generated client config persistence,
- Chat UI,
- inference proxying,
- multi-backend routing.

## Decision

- v6 planning is documented.
- v6 implementation may start with a narrow `v6.0.0 App Shell / Sidebar Foundation`.
- v6.0.0 must not include later surfaces.
- All safety invariants must hold.

## v5.9.0 Planning Boundary

v5.9.0 adds this readiness review only. It does not implement v6 UI, app shell, sidebar navigation, Profiles section, model list table, Detail Inspector, Logs Panel, Client Setup Surface, Metrics / System Context, telemetry, background monitoring, request logging, request tracing, inference traffic inspection, external process metrics collection, external log capture, new network behavior, model download, model deletion, installed model scanning, cache cleanup, new app binary, zip asset, tag, release, or any app behavior change.
