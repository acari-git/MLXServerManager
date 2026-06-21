# v7 Implementation Readiness Review

## Release

- Added in `v6.30.0`.
- Docs-only readiness review for the first v7 app-code implementation.
- No Swift source, tests, app binary, release asset, runtime behavior, model checks, endpoint calls, downloads, deletion, telemetry, or release automation is added in this release.

## Purpose

`v6.30.0` closes the long v6 design and boundary-setting phase with an implementation handoff for v7.

The recommended first v7 app-code release is:

```text
v7.0.0 — Model Availability Surface
```

The goal is to return to small app-code implementation while preserving the Direct Mode and safety boundaries established throughout v6.

## Why Model Availability First

Model Availability Surface is the safest first v7 implementation because:

- v6 already prepared model download, availability wording, diagnostics, fixture, and surface designs;
- it adds visible user value without adding downloads, deletion, scanning, or inference calls;
- it can be implemented as a selected-profile, read-only UI surface;
- it does not require LAN Web UI, App Intents, automatic unload, or release packaging work;
- it keeps the app outside the inference request path.

## v7.0.0 Recommended Scope

`v7.0.0` should add a small Model Availability card or section to an existing v6 surface.

Allowed initial behavior:

- show selected profile model target summary;
- show conservative availability state;
- support explicit user-triggered check for the selected profile only;
- show copy-safe compact path text;
- show stale or unknown state when selected profile changes;
- show external/adopted targets as not managed or not inspectable;
- keep the result local to the current app session unless a later design approves persistence;
- add stable accessibility identifiers;
- add focused tests for state mapping and boundary behavior.

Recommended states:

```text
unknown
configured
present
missing
external
notInspectable
stale
```

Recommended placement options:

1. Detail Inspector selected profile card.
2. Profiles / Model List selected row detail.
3. Dashboard current target summary.

Preferred first placement:

```text
Detail Inspector selected profile card
```

This keeps the feature contextual and avoids turning the Dashboard into a full model manager.

## v7.0.0 Explicit Non-Goals

Do not include:

- automatic model directory scanning;
- recursive file search;
- Hugging Face API calls;
- model downloads;
- model deletion;
- cache cleanup;
- model compatibility certification;
- endpoint testing;
- `/v1/models` probing for availability;
- `/v1/chat/completions` calls;
- inference requests;
- background monitoring;
- telemetry;
- analytics;
- LAN Web UI;
- App Intents;
- automatic unload;
- packaging or notarization changes.

## Direct Mode Boundary

Direct Mode remains:

```text
OpenAI-compatible client -> mlx_lm.server
```

The v7.0.0 feature must remain an app-side status and context surface.

It must not become:

- inference middleware;
- request router;
- proxy layer;
- backend selector;
- model execution layer;
- traffic monitor.

## Data Sources

Allowed v7.0.0 data sources:

- selected profile model identifier;
- selected profile local path if already configured;
- app-managed versus external/adopted target state;
- explicit user-triggered local file existence check for the selected configured path;
- current session-only stale state.

Disallowed v7.0.0 data sources:

- recursive directory scans;
- Hugging Face remote metadata;
- model cache enumeration;
- inference endpoint calls;
- client request traffic;
- prompts or responses;
- environment variables;
- secrets;
- telemetry events.

## UI Wording Rules

Use conservative wording:

```text
Model path configured
```

```text
Configured path appears present
```

```text
Configured path was not found
```

```text
Availability not checked
```

```text
External target is not managed by MLX Server Manager
```

Avoid overclaiming:

```text
Model is installed
```

```text
Model is compatible
```

```text
Model will load successfully
```

```text
No model problems detected
```

A local path existence check does not prove model compatibility, loadability, architecture support, quantization quality, tokenizer compatibility, or runtime performance.

## State Mapping Requirements

Recommended mapping:

- no selected profile: `unknown`;
- selected profile without local path: `configured` if model ID exists, otherwise `unknown`;
- selected profile with local path before explicit check: `unknown` or `notInspectable` depending on path policy;
- explicit check and path exists: `present`;
- explicit check and path missing: `missing`;
- external/adopted target: `external`;
- path cannot be safely checked: `notInspectable`;
- selected profile changed after check: `stale` or reset to `unknown`.

## Copy-Safe Display

Path display must be copy-safe:

- compact home paths to `~/...` when shown;
- avoid full user-specific absolute paths in screenshots, docs, fixtures, or tests;
- do not expose tokens, environment variables, private URLs, or command output;
- do not persist generated client config.

## Tests Expected In v7.0.0

Focused test candidates:

- selected profile without path maps to conservative state;
- explicit existing path check maps to `present` using temporary test data;
- explicit missing path check maps to `missing`;
- external/adopted target maps to `external` and does not check local files;
- profile change resets or marks previous check as stale;
- path display compacts home paths;
- no endpoint calls are needed for availability state;
- accessibility identifiers remain stable.

Tests must not require real model files, real Hugging Face downloads, real network access, real inference, or user-specific paths.

## Implementation Order For v7.0.0

Recommended order:

1. Add a small pure model for availability state.
2. Add a local checker protocol with test doubles.
3. Add selected-profile state mapping.
4. Add copy-safe path formatting.
5. Add focused unit tests.
6. Add the read-only UI card.
7. Add accessibility identifiers.
8. Update README and tasks.
9. Build and test.
10. Produce a new app-code release asset only if UI source changes are included and Release build verification is completed.

## Binary Release Decision

Unlike recent docs-only v6 releases, `v7.0.0` is expected to be an app-code release if it changes Swift UI or runtime code.

If v7.0.0 includes Swift source changes:

- build Debug;
- run tests;
- build Release with signing disabled unless a signed path is explicitly ready;
- create a new unsigned app zip;
- compute SHA-256 for the new zip;
- attach the zip to the GitHub Release;
- update release notes with the new asset name and checksum.

If v7.0.0 is only another design release, do not call it v7.0.0. Keep it in v6.x.

## Candidate v7 Sequence

Recommended sequence after `v6.30.0`:

```text
v6.30.1 — v7 Readiness Polish, optional
v7.0.0 — Model Availability Surface
v7.0.1 — Model Availability Surface polish
v7.1.0 — Diagnostics Results Surface
v7.2.0 — Explicit Diagnostics Run
v7.3.0 — Automatic Unload Policy, disabled by default
v7.4.0 — Presets for frequent model configurations
v7.5.0 — Hugging Face Download Manager, explicit/manual only
```

LAN Web UI and App Intents should remain later than v7.0.0.

## v7.0.0 Go Criteria

Proceed to v7.0.0 when:

- v6 readiness review is committed and released;
- Model Availability Surface is accepted as the first v7 feature;
- implementation scope is limited to selected-profile read-only availability;
- no downloads, deletion, scanning, inference calls, telemetry, or background monitoring are included;
- tests can be written with temporary local test data;
- release owner is ready to produce a new unsigned app zip if Swift source changes are made.

## v7.0.0 No-Go Criteria

Do not start v7.0.0 if:

- the feature expands into model management, downloads, deletion, or cache cleanup;
- it requires network access;
- it requires real model files for tests;
- it requires inference endpoint probing;
- it changes Direct Mode;
- it bundles LAN Web UI, App Intents, automatic unload, packaging automation, or notarization;
- release notes cannot accurately state the asset and checksum.

## Release Acceptance

`v6.30.0` is acceptable if:

- this readiness document is added;
- README references the v7 readiness handoff;
- `docs/tasks.md` records the completed docs-only work;
- no Swift source files change;
- no tests change;
- no model checks are implemented;
- no endpoint calls are added;
- no downloads are added;
- no model deletion is added;
- no model scanning is added;
- no telemetry is added;
- no runtime behavior changes;
- no new app binary zip is produced;
- Direct Mode remains unchanged.
