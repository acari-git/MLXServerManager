# v6 App Layout Stabilization Review

## Release

- Added in `v6.6.0`.
- Docs-only stabilization review.
- Follows `v6.0.0` through `v6.5.1` App Shell and top-level surface work.
- No new app binary is produced for this release.

## Purpose

`v6.6.0` records the post-implementation state of the v6 App Shell / Sidebar work before any later feature work begins. The goal is to make the current layout contract explicit and prevent future changes from accidentally expanding MLX Server Manager beyond its Direct Mode boundary.

This review does not implement new UI, runtime behavior, persistence, process control, diagnostics, monitoring, model download, model deletion, model scanning, cache cleanup, proxying, routing, request rewriting, Chat UI, telemetry, or background tasks.

## Current Top-Level Sections

The implemented App Shell exposes these top-level sections:

1. Dashboard
   - Default section.
   - Primary Direct Mode control surface.
   - Owns runtime controls, model profile selection, diagnostics, logs, and connection settings.

2. Profiles
   - Read-oriented profile and model list surface.
   - Reuses existing profile data.
   - Does not add model download, deletion, scanning, or cache cleanup.

3. Inspector
   - Read-only selected profile and connection target detail surface.
   - Does not add edit, delete, endpoint testing, or model file management actions.

4. Logs
   - App-managed lifecycle and log context surface.
   - Reuses the shared `LogView`.
   - Does not capture external process logs or scrape background logs.

5. Client Setup
   - Copy-safe OpenAI-compatible setup surface.
   - Reuses `ConnectionSettingsView` and existing copy actions.
   - Does not generate client config files, store secrets, auto-detect clients, test endpoints, or proxy traffic.

6. Metrics
   - Read-only system and readiness context surface.
   - Reuses existing app state only.
   - Does not add active monitoring, polling, metrics persistence, benchmarks, token throughput measurement, external process metrics collection, or endpoint testing.

## Stable Section Order

The current section order is:

```text
Dashboard
Profiles
Inspector
Logs
Client Setup
Metrics
```

This order is covered by `AppSectionTests` and should remain stable unless a future release intentionally changes the App Shell navigation contract.

## Direct Mode Contract

The Direct Mode path remains:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

MLX Server Manager may launch, stop, monitor, and display connection details for app-managed servers. It may also show connection context for adopted external servers.

MLX Server Manager must not become:

- an inference proxy;
- a multi-backend router;
- a Chat UI;
- a request rewriter;
- a request inspector;
- a telemetry collector;
- a model weight manager;
- a cache cleanup utility;
- an automatic background diagnostics service.

## Runtime Safety Invariants

Future changes should preserve these invariants:

- Dashboard remains the default section.
- Start, Stop, and Restart remain explicit user actions.
- Profile import/export remains metadata-only.
- External servers remain connection context only.
- Client Setup remains copy-safe and text-only.
- Metrics remains read-only and based on existing app state only.
- Logs remain app-managed lifecycle context only.
- No new network calls are added from read-only surfaces.
- No secrets, API keys, tokens, model weights, caches, or private paths are persisted through new surfaces.

## What Future Releases May Do

Future releases may safely continue with:

- small layout polish;
- screenshots and documentation refresh;
- accessibility identifier coverage;
- wording improvements;
- UI consistency fixes;
- release hygiene;
- manual verification documentation.

Future feature work should be introduced only after a new scoped design review.

## What Future Releases Should Not Do Without New Design Review

Do not introduce the following through incremental polish releases:

- model download;
- model deletion;
- installed model scanning;
- cache cleanup;
- proxy mode;
- Chat UI;
- automatic endpoint testing from read-only sections;
- telemetry;
- background monitoring;
- background log scraping;
- external process metrics collection;
- generated client config persistence;
- API key or token storage;
- automatic client detection;
- request or response inspection;
- benchmark runner;
- token throughput measurement.

## Release Acceptance

`v6.6.0` is acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- release notes explicitly state that the current binary remains `v6.5.1`;
- future work is scoped as design-reviewed work rather than implicit expansion.
