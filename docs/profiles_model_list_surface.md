# Profiles / Model List Surface Design

## Status

- Planning only.
- Target implementation: future `v6.1.0`.
- Not implemented in `v5.4.0`.
- Depends on or follows future `v6.0.0` App Shell / Sidebar Foundation.
- Dashboard UI Refresh v1 remains the current stable surface.

v5.4.0 documents a future Profiles / Model List Surface. It does not implement a model list table, Profiles section, sidebar navigation, model detail inspector, model download, model deletion, installed model scanning, cache cleanup, new persistence behavior, or app behavior changes.

## Goals

- Make model profiles easier to browse.
- Make selected profile context easier to understand.
- Show model ID, endpoint, and launch metadata clearly.
- Keep Import / Export discoverable.
- Preserve metadata-only Import / Export boundaries.
- Avoid confusing profile metadata with installed model files.
- Preserve Direct Mode and explicit lifecycle controls.
- Avoid adding model download or deletion in this phase.

## Non-goals

- No model download.
- No model deletion.
- No model file scanning.
- No cache management.
- No automatic model discovery beyond existing behavior.
- No inference proxying.
- No Chat UI.
- No multi-backend routing.
- No profile persistence rewrite.
- No import/export schema changes.
- No Rename behavior changes.
- No Replace behavior changes.
- No selected profile behavior changes.
- No API key, token, or secret storage.
- No runtime behavior changes.
- No new network calls.
- No change to `/v1/models` readiness or detection behavior.
- No `/v1/chat/completions` calls by the app.

## Future Profiles Section Purpose

A future Profiles section should be the place for:

- browsing saved model profiles,
- viewing selected profile metadata,
- understanding endpoint configuration,
- seeing Advanced Launch Options summary,
- accessing Import / Export entry points,
- understanding Rename / Replace at a high level.

The section should make profiles easier to understand without implying that MLX Server Manager manages model files. A model profile is saved configuration metadata; it is not proof that a model file exists locally.

## Candidate Model / Profile List

This is a candidate list or table concept, not an implemented UI.

Possible columns:

- Profile name.
- Model ID.
- Host.
- Port.
- Endpoint.
- Runtime role or selected state.
- Last used or notes, only if already available.
- Import / Export safety state, only if useful.

The list should avoid columns that imply model file management unless a separate model-file feature is designed. For example, "installed", "disk size", "downloaded", or "delete model" should not appear in this surface unless future work explicitly adds safe model-file awareness.

## Selected Profile Details

A future selected profile detail area may show:

- display name,
- model ID,
- host,
- port,
- computed base URL,
- Advanced Launch Options summary,
- local-only fields if currently supported,
- current target relationship,
- whether the selected profile is used for managed launch.

Detailed contextual presentation may later move into or populate a future [Detail Inspector Foundation](detail_inspector_foundation.md). The Profiles surface should still keep selected profile metadata understandable without requiring an inspector to perform basic profile management.

Before any future v6 implementation begins, review [v6 Implementation Readiness Review](v6_implementation_readiness.md). Profiles / Model List Surface remains a later candidate after the narrow App Shell / Sidebar Foundation.

Important distinctions:

- Selected profile is configuration metadata.
- Current target is the active managed or adopted endpoint.
- A selected profile may exist when no server is running.
- A running managed server may require Restart before it reflects selected profile changes.
- An adopted external server may expose a model list or model names that differ from the selected profile.

## Import / Export Placement

Import / Export can be placed in the future Profiles section because it operates on profile metadata.

The section should explain:

- Export Profiles exports profile metadata.
- Import Preview validates before import.
- Import Selected Profiles imports selected valid rows.
- Rename changes the imported display name to avoid a profile-name conflict.
- Replace updates one clearly matched local profile with imported metadata.
- Ambiguous or duplicate Replace targets remain blocked.

This design does not change Import / Export behavior, schema, validation, Rename, Replace, selected profile behavior, or server lifecycle behavior.

## Metadata-only Boundary

Import / Export does not:

- copy model files,
- download models,
- delete models,
- copy Hugging Face cache,
- copy logs,
- store or import secrets,
- store executable paths,
- transfer external process ownership,
- start or restart servers.

The future Profiles section should repeat this boundary near Import / Export actions so users do not mistake profile metadata for model-file management.

## Relationship to Dashboard v1

Dashboard v1 remains the high-level overview. It may continue to summarize:

- selected profile,
- selected profile endpoint,
- current target relationship,
- Import / Export guidance,
- metadata-only safety notes.

The future Profiles section should provide deeper profile management context. It should not force the Dashboard to duplicate full profile management or become a table-heavy view.

## Relationship to App Shell / Sidebar

The future sidebar may include `Profiles` as a major section after the App Shell / Sidebar Foundation exists.

Profiles can be introduced after `v6.0.0` if the shell provides a stable destination for profile-related content. The section should not require runtime behavior changes, model download, model deletion, installed model scanning, or new background checks.

See [App Shell / Sidebar Foundation Design](app_shell_sidebar_foundation.md) for the candidate shell boundary.

## Safety Boundaries

- Direct Mode remains unchanged.
- The app does not proxy inference requests.
- Lifecycle controls remain explicit.
- Stop and Restart apply only to app-managed processes.
- External servers remain connection context only.
- Import / Export remains metadata-only.
- No model download or deletion.
- No model file scanning or cache cleanup.
- No API key, token, or secret persistence.
- No hidden background checks or automatic diagnostics.

## Risks

- Users may confuse profile metadata with installed models.
- Users may expect model download or deletion from a model list UI.
- A list or table may imply file management if labels are careless.
- Duplicate selected profile information may conflict with Dashboard copy.
- Import / Export actions may appear to transfer model files unless carefully labeled.
- Adopted external target may be confused with selected profile endpoint.
- Advanced Launch Options summary may imply active runtime behavior before Restart.

## Acceptance Criteria for Future v6.1.0

Future implementation should only be accepted if:

- selected profile metadata is clearly labeled,
- model file management is not implied,
- Import / Export metadata-only boundary is visible,
- Dashboard v1 remains stable,
- Direct Mode remains obvious,
- Start / Stop / Restart behavior is unchanged,
- Import / Export behavior is unchanged,
- no model download or deletion is added,
- no model file scanning or cache cleanup is added,
- no secrets persistence is added,
- selected profile behavior is unchanged unless separately scoped.

## Future Stages

These versions remain proposals only:

- `v6.0.0`: App Shell / Sidebar Foundation.
- `v6.1.0`: Profiles / Model List Surface.
- `v6.2.0`: Detail Inspector Foundation.
- `v6.3.0`: Logs Panel Refresh.
- `v6.4.0`: Client Setup Surface.
- `v6.5.0`: Metrics / System Context Design.

## v5.4.0 Planning Boundary

v5.4.0 adds this detailed design only. It does not implement the Profiles section, model list table, sidebar navigation, model detail inspector, installed model scanning, model download, model deletion, cache cleanup, new persistence behavior, new app binary, zip asset, tag, release, or any app behavior change.
