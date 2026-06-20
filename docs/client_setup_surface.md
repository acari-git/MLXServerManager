# Client Setup Surface Design

## Status

- Implemented in `v6.4.0` as the first Client Setup Surface.
- Polished in `v6.4.1` with a copy scope card.
- Initially documented in `v5.7.0` as a planning-only design.
- Follows `v6.0.0` App Shell / Sidebar Foundation.
- Follows `v6.1.0` Profiles / Model List Surface.
- Follows `v6.2.0` Detail Inspector Foundation.
- Follows `v6.3.0` Logs Panel Refresh.
- Dashboard UI Refresh v1 remains the current stable surface.

v6.4.0 adds a top-level Client Setup destination for copy-safe OpenAI-compatible setup values. v6.4.1 keeps that surface copy-safe and adds a copy scope card that clarifies copied values and examples remain text-only. It does not implement client-specific configuration generation, API key management, token storage, secret persistence, generated client config files, automatic client configuration, client auto-detection, endpoint testing, new network behavior, telemetry, background monitoring, automatic diagnostics, proxying, or runtime behavior changes.

## Goals

- Make OpenAI-compatible client setup easier to understand.
- Present Base URL, endpoint, and model ID clearly.
- Reinforce Direct Mode.
- Distinguish app-managed server from adopted external server.
- Keep copy actions safe and predictable.
- Avoid generated secrets, credentials, or persisted client configs.
- Avoid implying that MLX Server Manager proxies inference requests.
- Avoid turning the app into a Chat UI or router.
- Preserve explicit lifecycle controls and external process boundaries.

## Non-goals

- No Chat UI.
- No inference proxying.
- No multi-backend routing.
- No hidden request rewriting.
- No automatic client configuration.
- No client auto-detection.
- No generated client config files.
- No API key, token, or secret storage.
- No endpoint testing beyond existing readiness behavior.
- No new network behavior.
- No background health checks.
- No telemetry.
- No automatic diagnostics.
- No runtime behavior changes.
- No process ownership changes.
- No selected profile behavior changes.
- No current target behavior changes.
- No Import / Export behavior changes.
- No Import / Export schema changes.
- No `/v1/chat/completions` calls by the app.

## Client Setup Surface Purpose

The future Client Setup surface should help users connect external OpenAI-compatible clients directly to the active MLX endpoint.

It may show:

- active Base URL,
- model ID,
- endpoint summary,
- current target type,
- managed vs adopted external context,
- readiness summary already available to the app,
- Direct Mode explanation,
- copy-safe setup hints.

It must not become:

- a Chat UI,
- an inference proxy,
- a router,
- a secrets manager,
- a generated credentials store,
- an automatic client configuration tool,
- a background testing agent.

## Direct Mode Explanation

The surface should restate the Direct Mode path:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

Explain:

- MLX Server Manager helps users understand and copy setup values,
- the client connects directly to the server endpoint,
- MLX Server Manager does not sit between the client and server,
- MLX Server Manager does not rewrite requests,
- MLX Server Manager does not inspect inference traffic,
- MLX Server Manager does not provide `/v1/chat/completions`.

## Managed Server Client Setup

Future managed server context may show:

- Base URL computed from managed host and port,
- model ID from selected profile or detected readiness result if already available,
- readiness summary,
- managed process ownership note,
- Start / Stop / Restart boundary reminder,
- copy buttons for Base URL and Model ID.

Clarify:

- lifecycle actions remain explicit,
- readiness does not imply request proxying,
- copied setup values are informational,
- no client secrets are generated or stored.

## Adopted External Server Client Setup

Future adopted external context may show:

- adopted external Base URL,
- model ID if detected,
- readiness or detection summary,
- external ownership boundary,
- Forget External Server explanation,
- external logs are not captured,
- copy buttons for Base URL and detected Model ID.

Clarify:

- adopted external server is connection context only,
- MLX Server Manager does not stop or restart external server,
- MLX Server Manager does not capture external logs,
- MLX Server Manager does not take ownership.

## Candidate Client Setup Layout

These layout details are candidate design only, not implemented UI.

### Header

- current target,
- managed vs adopted external badge,
- readiness summary.

### Connection Values

- Base URL,
- Model ID,
- endpoint summary.

### Direct Mode Explanation

- client-to-server direct path,
- no proxy reminder,
- no request inspection reminder.

### Copy Actions

- Copy Base URL.
- Copy Model ID.
- Copy endpoint summary.
- Copy generic OpenAI-compatible setup hint.

### Safety Notes

- no secrets,
- no generated credentials,
- no stored API keys,
- no proxying,
- no request rewriting.

### Troubleshooting Links / Notes

- check server readiness,
- check managed logs or external terminal,
- verify client points to Base URL.

## Copy Actions

Future copy affordances should be constrained and explicit.

Possible future copy actions:

- Copy Base URL.
- Copy Model ID.
- Copy endpoint summary.
- Copy Direct Mode setup hint.
- Copy generic environment variable hint if already appropriate.

Constraints:

- no API key generation,
- no token storage,
- no secrets persistence,
- no client-specific generated config files unless separately designed,
- no hidden request rewriting,
- no copied text should imply the app proxies requests,
- no copied text should imply external process ownership,
- no copied text should include local user paths unless strictly necessary and safe.

## Relationship to Dashboard v1

Dashboard v1 remains the high-level overview. It can continue to summarize Client Setup.

A future Client Setup surface can provide deeper, focused setup guidance without overloading Dashboard with every client-specific detail.

## Relationship to Detail Inspector

The future Detail Inspector may show compact endpoint details. The Client Setup surface provides the larger setup-oriented view.

Both surfaces should use consistent wording for:

- Direct Mode,
- selected profile vs current target,
- managed vs adopted external ownership,
- no proxying,
- no secrets handling.

See [Detail Inspector Foundation Design](detail_inspector_foundation.md) for the future inspector boundary.

## Relationship to Logs Panel Refresh

The future Logs surface may help troubleshoot managed server startup and readiness. The Client Setup surface may link conceptually to logs guidance.

Adopted external server troubleshooting should point users to the terminal, app, or service where the external server was launched. Client Setup must not imply external log capture.

See [Logs Panel Refresh Design](logs_panel_refresh.md) for the future Logs surface boundary.

## Relationship to Metrics / System Context

The future Client Setup surface shows Base URL, model ID, and Direct Mode setup. A future Metrics / System Context surface can reinforce readiness and performance boundaries.

Both surfaces should avoid proxying, request inspection, generated credentials, background endpoint testing, telemetry, and background monitoring.

See [Metrics / System Context Design](metrics_system_context.md) for the future metrics and system context boundary.

Before any future v6 implementation begins, review [v6 Implementation Readiness Review](v6_implementation_readiness.md). Client Setup Surface remains a later candidate and should not be included in the initial App Shell / Sidebar Foundation implementation.

## Relationship to Profiles / Model List Surface

Selected profile metadata can provide model ID and managed launch context. Current target may differ from selected profile.

The Client Setup surface must clearly show which values apply to the active or current target. It should avoid confusing saved profile metadata with active endpoint state.

See [Profiles / Model List Surface Design](profiles_model_list_surface.md) for the future Profiles surface boundary.

## Safety Boundaries

- Direct Mode remains unchanged.
- The app does not proxy inference requests.
- The app does not provide Chat UI.
- The app does not perform multi-backend routing.
- The app does not rewrite requests.
- Lifecycle controls remain explicit.
- External servers remain connection context only.
- External logs are not captured.
- Import / Export remains metadata-only.
- No model download or deletion.
- No model scanning or cache cleanup.
- No API key, token, or secret persistence.
- No generated client config persistence.
- No telemetry.
- No background automation.

## Risks

- Users may think MLX Server Manager is the OpenAI-compatible server.
- Users may think the app proxies inference traffic.
- Copied setup hints may imply hidden API keys or credentials.
- Adopted external endpoint may be confused with app-managed server.
- Selected profile model ID may be confused with active target model ID.
- Client-specific examples may become outdated.
- Too much setup detail may overwhelm non-CLI users.

## Acceptance Criteria for v6.4.0

The implementation is acceptable because:

- Base URL and model ID are clearly tied to the active or current target,
- selected profile vs current target is clearly separated,
- managed vs adopted external ownership is clear,
- Direct Mode is obvious,
- copied guidance does not imply proxying,
- no API keys, tokens, or secrets are generated or stored,
- no generated client config files are persisted,
- no new network behavior is added,
- no background testing or monitoring is added,
- lifecycle behavior is unchanged,
- Dashboard v1 remains stable,
- Import / Export behavior is unchanged.

## Future Stages

These versions remain proposals only:

- `v6.0.0`: App Shell / Sidebar Foundation.
- `v6.1.0`: Profiles / Model List Surface.
- `v6.2.0`: Detail Inspector Foundation.
- `v6.3.0`: Logs Panel Refresh.
- `v6.4.0`: Client Setup Surface.
- `v6.5.0`: Metrics / System Context Design.

## v5.7.0 Planning Boundary

v5.7.0 added this detailed design only. v6.4.0 is the first app-code Client Setup Surface implementation. v6.4.1 is a focused Client Setup Surface polish release. Both keep the original safety boundaries intact.
