# Product Direction

## Overview

MLX Server Manager is a local macOS control surface for `mlx_lm.server` and related OpenAI-compatible local endpoints. Its purpose is to make `mlx-lm` easier to operate without becoming part of the inference request path.

The current Direct Mode path remains:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app manages setup, lifecycle, diagnostics, profile metadata, logs, memory visibility, and connection settings. It does not proxy inference requests in the current architecture.

## Project Principles

1. Preserve `mlx-lm` runtime performance as the top priority.
2. Make `mlx-lm` usable for users who are not comfortable with CLI workflows.
3. Adopt useful features from other local LLM tools when they do not conflict with `mlx-lm` performance, safety, or Direct Mode boundaries.

## Product Direction

The product should stay focused on making local `mlx_lm.server` operation clear, explicit, and fast. It should reduce routine CLI friction while keeping users in control of server ownership, launch arguments, profile metadata, and OpenAI-compatible connection details.

New features should be evaluated by whether they help users run or connect to `mlx_lm.server` more confidently without adding hidden runtime behavior.

## Performance-First Policy

`mlx-lm` generation performance is the top priority.

The runtime path should stay thin and direct. In the current architecture:

- There is no inference proxy.
- There is no request rewriting.
- There is no hidden routing layer between the client and server.
- Background features must not interfere with active generation.
- The app should avoid CPU, memory, and disk I/O contention during managed server operation.
- New features must not degrade managed `mlx_lm.server` runtime behavior.

Features that are useful but expensive should be opt-in, visible, and easy to avoid during active generation.

## CLI-Friendly mlx-lm Workflow

Users should not need to memorize common `mlx_lm.server` commands to operate a local server.

The GUI should expose common setup and operating workflows:

- executable path setup,
- model profile selection,
- Start / Stop / Restart for app-managed servers,
- readiness checks via `/v1/models`,
- port conflict visibility,
- logs and memory display for managed servers,
- OpenAI-compatible connection settings copy actions.

Advanced users should still be able to inspect and copy command or configuration details. The app should explain Direct Mode and OpenAI-compatible connection settings clearly instead of hiding the underlying server model.

## Direct Mode Boundary

The current boundary is:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

Current boundaries:

- No inference proxy.
- No Chat UI.
- No multi-backend routing.
- No hidden request rewriting.
- No automatic external process ownership changes.
- Stop and Restart apply only to app-managed processes.
- Adopted External Server is connection context only, not process ownership.

These boundaries keep the app understandable and preserve the performance characteristics of the selected server.

## Feature Adoption Policy

Useful features from other local LLM tools can be considered when they pass performance, safety, and scope checks.

A candidate feature should:

- preserve `mlx-lm` runtime performance,
- preserve Direct Mode unless a future release explicitly changes architecture,
- avoid silent server Start / Stop / Restart behavior,
- keep process ownership visible,
- avoid importing or exporting secrets unexpectedly,
- avoid hidden network calls,
- keep user-visible control over files, downloads, endpoints, and launch arguments.

Convenience is welcome when it makes local `mlx-lm` safer or easier without making runtime behavior harder to reason about.

## Current Non-goals

Current releases do not include:

- inference proxy,
- Chat UI,
- multi-backend router,
- automatic model deletion,
- automatic server start after import or future download workflows,
- hidden background downloads,
- external process takeover,
- replacement for dedicated package managers or Hugging Face tooling.

Model download is a current non-goal, but it is not permanently excluded as a future candidate.

## Future Candidate Features

Future candidates can be considered if they preserve performance, safety, and Direct Mode boundaries:

- future full app layout refresh planning after v5.0.0 finalized Dashboard UI Refresh v1, v5.1.0 clarified the stable follow-up boundary, v5.2.0 documented a candidate v6.x direction in [Full App Layout Refresh Design](full_app_layout_refresh.md), v5.3.0 detailed the first candidate App Shell / Sidebar Foundation step in [App Shell / Sidebar Foundation Design](app_shell_sidebar_foundation.md), v5.4.0 detailed the candidate Profiles / Model List Surface in [Profiles / Model List Surface Design](profiles_model_list_surface.md), v5.5.0 detailed the candidate Detail Inspector Foundation in [Detail Inspector Foundation Design](detail_inspector_foundation.md), v5.6.0 detailed the candidate Logs Panel Refresh in [Logs Panel Refresh Design](logs_panel_refresh.md), and v5.7.0 detailed the candidate Client Setup Surface in [Client Setup Surface Design](client_setup_surface.md),
- model download design,
- local cache awareness,
- profile templates,
- logs and diagnostics polish,
- connection settings polish,
- optional speed test polish.

Each candidate should define what it changes, what it refuses to change, and how it avoids interfering with active `mlx_lm.server` generation.

Import conflict handling should follow the same rule. v3.3.0 implements Rename for profile-name conflicts as an explicit metadata operation. v3.4.0 implements Replace only for one unambiguous existing profile target, with explicit confirmation. v3.5.0 adds deterministic fixtures and service-level tests for the current import/export schema and conflict behavior. v4.0.0 treats Import / Export as stable within this metadata-only boundary. Replace remains metadata-only and must not start servers, call readiness endpoints, alter external process ownership, or interfere with active generation.

Dashboard refresh work should follow the same principle. v4.1.0 defined the dashboard information architecture. v4.2.0 through v4.9.0 added the display-oriented dashboard pieces in small behavior-preserving steps: Current Target, Server State, Logs / Diagnostics guidance, Profiles / Import Export guidance, Next Steps guidance, scan-order grouping, and Client Setup guidance. v5.0.0 finalizes Dashboard UI Refresh v1 as the stable overview for Next Steps, Current Target, Server State, Client Setup, Diagnostics & Logs, and Profiles / Import Export. v5.1.0 keeps Dashboard v1 stable and separates future full-layout work from the current dashboard surface. v5.2.0 documents a possible future v6.x Full App Layout Refresh without implementing it. v5.3.0 narrows that into an App Shell / Sidebar Foundation design for a possible future v6.0.0 implementation. v5.4.0 narrows the next stage into a Profiles / Model List Surface design for a possible future v6.1.0 implementation. v5.5.0 narrows the following stage into a Detail Inspector Foundation design for a possible future v6.2.0 implementation. v5.6.0 narrows the following stage into a Logs Panel Refresh design for a possible future v6.3.0 implementation. v5.7.0 narrows the following stage into a Client Setup Surface design for a possible future v6.4.0 implementation. These steps do not change server lifecycle behavior, Direct Mode, import/export behavior, import/export schema, selected profile behavior, current target behavior, onboarding persistence, API key/token persistence, generated client config persistence, automatic client configuration behavior, new network behavior, external process ownership, external log capture behavior, telemetry behavior, background monitoring behavior, model download behavior, model deletion behavior, model scanning, or cache cleanup. Future broader app layout work should be staged separately from Dashboard v1.

## Model Download Position

Model download is not implemented in the current release.

Model download may be considered in the future if it does not reduce `mlx-lm` runtime performance, does not interfere with managed server operation, and keeps clear safety and privacy boundaries.

If model download is ever added:

- download must not be coupled to automatic server start,
- download must not happen silently,
- download must not delete models,
- target location, progress, and failure state should be clear,
- Hugging Face token handling must use an explicit safe storage approach,
- downloaded model metadata must not be confused with profile import/export metadata.

Model deletion remains a separate, higher-risk area and is not part of the current scope.

## Safety and Privacy Boundaries

The app should not silently collect, transmit, import, or export private runtime data.

Safety boundaries:

- no model weights in profile import/export,
- no Hugging Face cache mutation in profile import/export,
- no API keys, tokens, or secrets in profile import/export,
- no committed runtime settings or model files,
- no hidden LAN/WAN exposure,
- no external process stop, restart, kill, or ownership takeover,
- no telemetry, analytics, crash reporting, or external log sending.

Runtime logs can contain local paths because they reflect local execution. Public docs, screenshots, examples, and exported profile metadata should avoid personal paths and secrets.

## Release Roadmap Framing

Releases should be described by their effect on runtime behavior:

- docs-only releases update project guidance, public docs, screenshots, or plans,
- app releases may change UI, state, services, or launch behavior,
- binary asset releases should be explicit when users need a new `.app`.

When a feature is only a future candidate, docs should say so clearly. When a feature is implemented, docs should describe the implemented boundary rather than imply broader automation.
