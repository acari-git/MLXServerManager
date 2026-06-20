# Model Download Design

## Release

- Added in `v6.17.0`.
- Docs-only design for future model download support.
- No model download implementation is included in this release.
- No new app binary is produced for this release.

## Purpose

`v6.17.0` defines the boundaries for possible future model download support without implementing download, deletion, scanning, cache cleanup, or model management side effects.

The app currently treats models as user-provided local paths or external server targets. This design records what would need to be true before the app can safely offer download-related UI while preserving Direct Mode and avoiding accidental storage, credential, or destructive-file behavior.

This release does not download models, delete models, scan model directories, clean caches, add Hugging Face integration, persist tokens, change runtime behavior, or create a new app binary.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current model handling assumptions:

- users provide local model paths;
- profiles reference model locations and launch arguments;
- app surfaces may display model/profile context;
- the app does not own downloaded model files;
- the app does not delete model files;
- the app does not scan arbitrary model directories;
- the app does not persist Hugging Face tokens.

## Design Goals

Future model download support should:

- help users acquire compatible MLX model directories;
- keep download actions explicit and user-initiated;
- make destination paths visible before download starts;
- avoid storing tokens unless a separate credential design is approved;
- avoid deleting or cleaning model files in the first implementation;
- avoid background downloads;
- avoid automatic model scanning;
- avoid changing Direct Mode request flow;
- distinguish download state from server runtime state.

## Non-Goals

The first model download implementation must not:

- act as an inference proxy;
- add Chat UI;
- route requests between backends;
- rewrite prompts or requests;
- inspect inference traffic;
- delete model directories;
- clean caches;
- scan arbitrary folders automatically;
- persist access tokens;
- auto-detect private models;
- perform background downloads without explicit user action;
- start a downloaded model automatically unless explicitly scoped later.

## Direct Mode Boundary

Model download support must not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

Downloading a model is a setup action. It must not put the app into the inference request path.

## User Flow Candidate

A future minimal user flow may be:

1. User opens a Model Download surface.
2. User enters or pastes a model repository identifier.
3. App shows the destination directory before any download starts.
4. User confirms download.
5. App runs a download task with visible progress.
6. App reports completion or failure.
7. User manually creates or updates a profile to use the downloaded path.

Automatic profile creation should be a separate scoped decision.

## Repository Identifier Handling

A future implementation may accept explicit identifiers such as:

```text
namespace/model-name
```

It should not assume that every identifier is compatible with MLX.

Before download starts, the app should display:

- repository identifier;
- destination path;
- expected local folder name;
- whether authentication is required;
- whether the app can proceed without credentials;
- that compatibility is not guaranteed until user verifies launch behavior.

## Destination Path Policy

A future implementation should require an explicit base directory preference or user-selected destination.

Recommended default concept:

```text
~/Models/mlx/<repository-name>
```

This is only a concept. Do not hardcode a user-specific path.

The app should not write into:

- the app bundle;
- project checkout directories;
- system directories;
- hidden app support cache locations without user-facing explanation;
- directories containing unrelated user files.

## Credential Boundary

First implementation should avoid persistent credential storage.

Allowed in a future scoped implementation:

- user provides a token for one explicit download session;
- token is held in memory only for that action;
- token is not logged;
- token is not written to profiles;
- token is not committed to exported settings.

Out of scope until a separate credential design exists:

- Keychain storage;
- token management UI;
- multiple account support;
- automatic private model discovery;
- CI or shared credential flows.

## Download Task Boundary

Download task handling should be isolated from SwiftUI views.

A future implementation should keep:

- download command construction;
- process execution;
- progress parsing;
- cancellation;
- result reporting;
- path validation;

behind a service/controller boundary.

SwiftUI views should present state and user controls only.

## Progress And Cancellation

A future implementation should show:

- pending state;
- active download state;
- completed state;
- failed state;
- cancelled state;
- destination path;
- last safe error summary.

Cancellation should stop the active download task, but first implementation should not automatically delete partial files unless a separate cleanup design is approved.

## Compatibility Wording

Use conservative wording:

```text
Downloaded model path is available.
Launch compatibility is not guaranteed until tested with the selected server command.
```

Do not imply:

- every downloaded repository is MLX-compatible;
- every MLX directory works with every server command;
- download completion means server readiness;
- download completion means profile correctness.

## Profile Integration Boundary

First implementation should not auto-create or overwrite profiles by default.

Safer first step:

- provide a copied local path;
- optionally offer `Create Profile` only as a separate explicit user action;
- never overwrite an existing profile silently;
- never change the selected profile automatically after download.

## Safety Checklist

Before implementing model download support, confirm:

- no model deletion is included;
- no cache cleanup is included;
- no arbitrary model scanning is included;
- no token persistence is included;
- download destination is visible before start;
- cancellation behavior is defined;
- partial file behavior is defined;
- errors do not expose tokens;
- Direct Mode remains unchanged;
- profile changes are explicit and reversible.

## Verification Expectations

A future app-code release should verify:

- download UI is opt-in;
- destination path is displayed;
- invalid repository identifiers fail safely;
- cancellation does not crash the app;
- failed downloads do not alter profiles;
- token text is not logged;
- exported profiles do not include tokens;
- existing profile import/export tests still pass;
- server start/stop behavior remains unchanged.

## Future Implementation Candidates

Safe follow-up releases may include:

1. Model Download Design Polish.
2. Model Availability Documentation.
3. Download destination preference design.
4. Download service skeleton without network execution.
5. Explicit one-shot download implementation.

## Release Acceptance

`v6.17.0` is acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- no model download is executed;
- no model deletion is added;
- no model scanning is added;
- no cache cleanup is added;
- no token persistence is added;
- release notes state that the current binary remains `v6.5.1`;
- future model download implementation remains explicitly scoped.
