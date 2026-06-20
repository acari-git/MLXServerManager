# Metrics / System Context Design

## Status

- Implemented in `v6.5.0` as the first Metrics / System Context surface.
- Initially documented in `v5.8.0` as a planning-only design.
- Follows `v6.0.0` App Shell / Sidebar Foundation.
- Follows `v6.1.0` Profiles / Model List Surface.
- Follows `v6.2.0` Detail Inspector Foundation.
- Follows `v6.3.0` Logs Panel Refresh.
- Follows `v6.4.0` Client Setup Surface.
- Dashboard UI Refresh v1 remains the current stable surface.

v6.5.0 adds a top-level Metrics / System Context destination for existing readiness, memory, runtime, and boundary context. It does not implement active system monitoring, system monitoring, memory polling, CPU/GPU/ANE polling, process sampling, telemetry, analytics, crash reporting, request logging, request tracing, inference traffic inspection, metrics persistence, benchmarks, token throughput measurement, background monitoring, or app behavior changes.

## Goals

- Provide useful local system context without harming MLX runtime performance.
- Make memory and readiness context easier to understand.
- Keep metrics lightweight, optional, and non-invasive.
- Avoid telemetry and analytics.
- Avoid background monitoring unless separately designed and explicitly justified.
- Avoid inspecting inference requests.
- Preserve Direct Mode.
- Preserve explicit lifecycle controls.
- Preserve external process ownership boundaries.
- Preserve metadata-only Import / Export boundaries.

## Non-goals

- No telemetry.
- No analytics.
- No crash reporting.
- No request logging.
- No request tracing.
- No inference traffic inspection.
- No token throughput measurement.
- No benchmark runner.
- No heavy polling.
- No background monitoring.
- No automatic diagnostics.
- No external process inspection.
- No external log capture.
- No external process metrics collection.
- No model download.
- No model deletion.
- No installed model scanning.
- No cache management.
- No API key, token, or secret storage.
- No metrics persistence.
- No runtime behavior changes.
- No process ownership changes.
- No selected profile behavior changes.
- No current target behavior changes.
- No Import / Export behavior changes.
- No Import / Export schema changes.
- No `/v1/chat/completions` calls by the app.

## Metrics / System Context Purpose

The future surface should be a lightweight context area that may help users understand whether their local environment looks ready for running `mlx_lm.server`.

It may show:

- current target context,
- managed vs adopted external status,
- readiness summary already available to the app,
- memory guidance or static memory context,
- process ownership notes,
- lightweight troubleshooting context,
- performance caution notes.

It must not become:

- a telemetry system,
- an analytics collector,
- a benchmark runner,
- a background monitoring agent,
- an inference request inspector,
- a request logger,
- a router,
- a Chat UI,
- a process owner for external servers.

## Candidate Metrics Categories

These categories describe the v6.5.0 read-only surface and future constraints.

### Readiness Context

Possible display:

- current readiness state from existing `/v1/models` detection,
- last known readiness summary if already available,
- managed vs adopted external context.

Constraints:

- do not call `/v1/models` differently,
- do not add inference endpoint testing,
- do not call `/v1/chat/completions`,
- do not add background polling.

### Memory Context

Possible display:

- user-facing memory guidance,
- static explanation of why memory matters for MLX models,
- current profile launch context if already available,
- caution that large models may fail or swap if memory is insufficient.

Constraints:

- do not add heavy polling,
- do not add persistent monitoring,
- do not collect private data,
- do not imply exact model fit unless separately designed.

### Process Context

Possible display:

- app-managed process ownership,
- adopted external server connection-only state,
- lifecycle action boundary,
- current target type.

Constraints:

- do not inspect external process internals,
- do not take ownership of external processes,
- do not stop or restart external processes,
- do not capture external logs,
- do not collect external process metrics.

### Runtime Performance Context

Possible display:

- lightweight guidance about keeping inference direct,
- explanation that Direct Mode protects performance,
- warning against proxying or hidden routing.

Constraints:

- no benchmarks,
- no token throughput measurement,
- no request inspection,
- no instrumentation in inference path.

## Candidate Layout

These layout details are implemented as a first read-only surface in v6.5.0.

### Header

- current target,
- managed vs adopted external badge,
- readiness summary.

### Readiness Context

- existing detection summary only,
- no new polling,
- no inference endpoint testing.

### Memory / System Guidance

- lightweight static guidance,
- no heavy polling,
- no persistent monitoring.

### Process Ownership

- managed vs adopted external boundary,
- app-managed-process-only lifecycle reminder.

### Performance Notes

- Direct Mode explanation,
- no proxying,
- no request inspection.

### Privacy Notes

- no telemetry,
- no analytics,
- no secrets,
- no request logging or tracing.

### Troubleshooting Notes

- check managed logs or external terminal,
- confirm client Base URL,
- confirm model ID.

## Managed Server Context

Future app-managed context may show:

- managed ownership,
- lifecycle state,
- readiness summary,
- selected profile relationship,
- Base URL and model ID context,
- logs availability if app-managed logs exist.

Clarify:

- lifecycle actions remain explicit,
- no new monitoring is added,
- no request traffic is inspected,
- no secrets are stored.

## Adopted External Server Context

Future adopted external context may show:

- adopted endpoint,
- detected model ID if already available,
- readiness or detection summary,
- external ownership boundary,
- external logs boundary,
- troubleshooting note to check external terminal or app.

Clarify:

- adopted external server is connection context only,
- MLX Server Manager does not inspect external process internals,
- MLX Server Manager does not stop, restart, or kill external process,
- MLX Server Manager does not capture external logs,
- MLX Server Manager does not monitor external process metrics.

## Privacy / Performance Boundary

- No telemetry.
- No analytics.
- No request logging.
- No request tracing.
- No inference traffic inspection.
- No API key, token, or secret persistence.
- No generated client config persistence.
- No background monitoring by default.
- No heavy polling.
- No metrics persistence unless separately designed.
- No new network behavior.
- Direct Mode remains the performance boundary.

## Relationship to Dashboard v1

Dashboard v1 remains the high-level overview. It may show minimal memory or readiness guidance.

A future Metrics / System Context surface can provide deeper non-invasive context without turning Dashboard into a full monitoring dashboard.

## Relationship to Detail Inspector

The future Detail Inspector may show compact current-target and system context. A future Metrics / System Context surface can provide broader guidance.

Both surfaces must avoid request inspection, telemetry, analytics, and background monitoring.

See [Detail Inspector Foundation Design](detail_inspector_foundation.md) for the future inspector boundary.

## Relationship to Logs Panel Refresh

The future Logs surface provides app-managed log context. Metrics / System Context provides system and readiness context.

Neither surface should capture external logs, add telemetry, add background scraping, or imply external process ownership.

See [Logs Panel Refresh Design](logs_panel_refresh.md) for the future Logs surface boundary.

## Relationship to Client Setup Surface

The future Client Setup surface shows Base URL, model ID, and Direct Mode setup. Metrics / System Context can reinforce readiness and performance boundaries.

Neither surface should imply proxying, request inspection, generated credentials, or background endpoint testing.

See [Client Setup Surface Design](client_setup_surface.md) for the future Client Setup surface boundary.

Before any future v6 implementation begins, review [v6 Implementation Readiness Review](v6_implementation_readiness.md). Metrics / System Context remains a later candidate and should not be included in the initial App Shell / Sidebar Foundation implementation.

## Safety Boundaries

- Direct Mode remains unchanged.
- The app does not proxy inference requests.
- The app does not provide Chat UI.
- The app does not perform multi-backend routing.
- The app does not rewrite requests.
- The app does not inspect inference traffic.
- Lifecycle controls remain explicit.
- External servers remain connection context only.
- External process metrics are not collected.
- External logs are not captured.
- Import / Export remains metadata-only.
- No model download or deletion.
- No model scanning or cache cleanup.
- No API key, token, or secret persistence.
- No generated client config persistence.
- No telemetry.
- No analytics.
- No background monitoring.
- No automatic diagnostics.

## Risks

- Metrics may imply telemetry or monitoring.
- Users may expect exact performance predictions.
- Heavy polling could hurt local inference performance.
- Metrics could accidentally inspect external process state.
- Users may confuse readiness with inference testing.
- Memory guidance may be mistaken for a guarantee that a model will fit.
- Too many metrics may overwhelm non-CLI users.

## Acceptance Criteria for v6.5.0

The implementation is acceptable because:

- metrics are lightweight and non-invasive,
- Direct Mode remains obvious,
- no inference request inspection is added,
- no telemetry or analytics is added,
- no background monitoring is added unless separately approved,
- no API keys, tokens, or secrets are stored,
- no external process metrics are collected,
- no external logs are captured,
- readiness behavior is unchanged,
- lifecycle behavior is unchanged,
- selected profile vs current target remains clear,
- managed vs adopted external ownership is clear,
- Dashboard v1 remains stable,
- Import / Export behavior is unchanged.

## Future Stages

These versions remain proposals only:

- `v6.0.0`: App Shell / Sidebar Foundation.
- `v6.1.0`: Profiles / Model List Surface.
- `v6.2.0`: Detail Inspector Foundation.
- `v6.3.0`: Logs Panel Refresh.
- `v6.4.0`: Client Setup Surface.
- `v6.5.0`: Metrics / System Context.

## v5.8.0 Planning Boundary

v5.8.0 added this detailed design only. v6.5.0 is the first app-code Metrics / System Context implementation. It does not implement active system monitoring, system monitoring, memory polling, CPU/GPU/ANE polling, process sampling, telemetry, analytics, crash reporting, request logging, request tracing, inference traffic inspection, metrics persistence, benchmarks, token throughput measurement, background monitoring, new app binary, zip asset, tag, release, or any app behavior change.
