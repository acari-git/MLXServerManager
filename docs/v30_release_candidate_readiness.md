# v30.0.0 Release Candidate Readiness

## Scope

This document records the implemented v27.0.0 through v30.0.0 product work layered on the v26 architecture and Kinetic UX stabilization. The stable version marker remains unchanged until release work is explicitly requested.

Direct Mode remains:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

MLX Server Manager does not proxy, route, inspect, rewrite, or persist inference requests.

## v27.0.0 — Runtime Readiness and Recovery

Implemented:

- explicit runtime checks from Settings,
- checks for unconfigured, missing, non-executable, ready, and capability-warning states,
- existing `mlx_lm.server --help` capability provider reuse,
- unsaved Settings draft paths can be checked before saving,
- cancellation and stale-result rejection through `LatestRequestCoordinator`,
- English and Japanese status text,
- no server start or process takeover during the check.

Primary tests:

- `RuntimeReadinessTests`
- `AppViewModelAsyncOwnershipTests`
- `MainSurfaceRenderingTests`

## v28.0.0 — Profile Templates

Implemented built-in templates:

- Minimal,
- Balanced,
- Memory Saver,
- Throughput.

Template rules:

- apply only after an explicit button press,
- modify only managed concurrency, prefill, and prompt-cache fields,
- preserve model identity, display name, backend, host, port, notes, reasoning, sampling, CORS, chat-template, and raw arguments,
- do not save, start, stop, restart, or download anything automatically,
- show the exact managed values before application.

Primary tests:

- `ModelProfileTemplateTests`
- `MainSurfaceRenderingTests`

## v29.0.0 — Discovery Controls

Implemented local projection controls for existing explicit Hugging Face results:

- Recommended,
- Downloads,
- Likes,
- Recently Updated,
- Name,
- minimum-download thresholds,
- MLX-tag-only filtering,
- localized compatibility and popularity reasons.

Changing a discovery control never sends a network request. Search, result selection, and download remain explicit operations.

Recommended ordering prioritizes verified MLX-tagged results before comparing quality and popularity metadata.

Primary tests:

- `HuggingFaceDiscoveryTests`
- existing Hugging Face request and download tests
- `MainSurfaceRenderingTests`

## v30.0.0 — Operational History

Implemented a separate operational history section on Logs:

- bounded to the newest 100 events,
- memory-only for the current app session,
- category filtering,
- severity filtering,
- explicit copy and clear actions,
- event context for model identity and endpoint when available,
- English and Japanese category, severity, and major operation messages,
- records lifecycle requests, port checks, Ready checks, runtime readiness, runtime health faults, profile changes, benchmark runs, and terminal download outcomes.

Operational History and the detailed log buffer remain separate. No history file, telemetry, remote transmission, or inference-content capture is introduced.

Primary tests:

- `OperationalHistoryTests`
- `LocalizationPairTests`
- `EnglishModeVisibleTextTests`
- `MainSurfaceRenderingTests`

## Automated Verification

Verified for the v30.0.0 development tree:

- 508 unit and integration tests passed with 0 failures and 0 skipped,
- localization guards passed,
- UI rendering smoke tests passed in English/Japanese, light/dark, standard/narrow widths,
- Debug tests and Release build succeeded,
- Xcode Analyze succeeded,
- strict-concurrency build succeeded with warnings treated as errors,
- `git diff --check` passed after the final version, documentation, and ignore-rule updates,
- AppViewModel raw Task ownership remains absent,
- forbidden process-wide commands remain absent.

## Manual Verification Status

Completed local evidence:

- the configured real `mlx_lm.server` executable exists, is executable, and returned `--help` successfully with 24 detected long-form options,
- Rapid-MLX is unconfigured and correctly remains an unavailable manual-verification item,
- the live Hugging Face API returned valid ID, tag, download, and like metadata for a 10-result MLX query,
- the Debug app remained alive through a short launch smoke check without an initialization crash,
- public-safety checks found no token patterns, forbidden tracked runtime files, personal paths, or build artifacts.

Manual checks still required before publishing the binary:

- ready-state verification with a real Rapid-MLX installation,
- template review with representative 30B-class and smaller workloads,
- Operational History readability during simultaneous operations,
- light/dark appearance and Japanese/English switching on the real app window,
- practical CPU and GPU impact of simultaneous Kinetic Border Beam surfaces,
- visual Reduce Motion and Reduce Transparency behavior.

See `docs/v30_manual_verification.md` for the evidence record.

## Release Boundary

Implementation readiness does not itself authorize a release. Only when explicitly requested:

Completed in the development tree:

- changed the app target `MARKETING_VERSION` to `30.0.0`,
- updated `docs/stable_scope.md` with the v30 release-candidate surface,
- updated README development-facing scope while retaining the published v25 asset and checksum,
- prepared `docs/v30_release_notes_draft.md`.

Still separately authorized release steps:

- update screenshots when safe release images are available,
- build and package the unsigned v30 app asset,
- calculate and insert the final checksum,
- commit,
- tag,
- push,
- create the GitHub Release.
