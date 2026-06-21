# Model Availability Documentation

## Release

- Added in `v6.18.0`.
- Polished in `v6.18.1` with staleness wording, explicit check scope, external identifier caveats, and UI copy rules.
- Docs-only documentation for future model availability surfaces.
- Follows `v6.17.0` / `v6.17.1` Model Download Design.
- No model availability implementation is included in this release.
- No new app binary is produced for this release.

## Purpose

`v6.18.0` defines how the app should describe model availability before any model download, scanning, deletion, cache cleanup, or automatic compatibility detection is implemented.

The goal is to help users understand which model paths are configured, which paths are merely referenced by profiles, and which paths may need user action, without implying that the app owns, verifies, downloads, or manages model files.

This release does not inspect model directories, download models, delete models, clean caches, persist tokens, add background monitoring, or change runtime behavior.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current model handling assumptions:

- profiles may reference local model paths;
- users control model files outside the app;
- external server targets may expose model identifiers;
- the app does not own model files;
- the app does not download or delete model files;
- the app does not scan model directories automatically;
- the app does not verify full model compatibility.

## Documentation Goals

Future model availability documentation should:

- distinguish configured paths from verified files;
- distinguish local profile paths from external server model identifiers;
- avoid claiming compatibility without a launch or server readiness check;
- avoid implying that the app manages model storage;
- make missing-path states understandable;
- make user action explicit;
- preserve Direct Mode boundaries.

## Availability Terms

Use conservative terms:

```text
Configured
Path referenced by a profile or setting.

Present
A known local path exists, if path existence is explicitly checked by a scoped feature.

Missing
A configured local path cannot be found, if path existence is explicitly checked by a scoped feature.

External
Model identifier is reported by or configured for an external server target.

Unknown
The app has not checked availability or cannot determine it safely.

Stale
A previous explicit check exists, but the app has not rechecked the path recently or after a relevant profile edit.
```

Do not use terms such as `installed`, `validated`, `compatible`, or `ready` unless the relevant verification actually occurred.

## Local Profile Availability

For local profiles, a future availability surface may show:

- profile name;
- configured model path;
- whether the app has checked path existence;
- availability state;
- last checked time, only if checks are explicitly user-triggered;
- suggested user action.

Initial implementation should prefer `Unknown` until the user explicitly requests a check.

Explicit check scope:

- check only the selected profile path;
- do not update any profile field from the check result;
- mark results as stale after the profile path changes.

## External Server Availability

For external server targets, availability wording should be separate from local file availability.

External availability may mean:

- the app has a configured external base URL;
- the external server reports a model identifier;
- the user copied a model ID from a server response;
- the app has not verified local files.

Do not imply that external model identifiers correspond to local model files managed by the app.

External identifier caveats:

- a server-reported model ID is not proof of local file availability;
- an external target may change its model list outside the app;
- availability wording should say `External` or `Unknown`, not `Present`;
- local profile path checks should not be run for external targets.

## Compatibility Boundary

Availability is not compatibility.

A model path may exist but still fail to launch because of:

- incompatible format;
- missing files;
- unsupported quantization;
- unsupported architecture;
- insufficient memory;
- wrong server command;
- wrong launch arguments;
- incomplete download.

Use wording such as:

```text
Model path exists. Launch compatibility is not verified.
```

## User Actions

A future availability surface may offer explicit actions such as:

- copy model path;
- reveal in Finder;
- check path existence;
- open profile editor;
- open model download design surface if implemented later;
- read documentation about compatible model formats.

Out of scope for first availability documentation:

- delete model;
- clean cache;
- scan all model directories;
- auto-fix profiles;
- auto-download missing models;
- auto-start server after detection.

## Path Checking Policy

Path checks should be explicit and narrow.

Allowed future checks:

- check only the exact path configured in a selected profile;
- check only after a user action;
- show the result without modifying the profile;
- avoid walking parent directories;
- avoid enumerating unrelated files.

Not allowed without separate scoped design:

- recursive model directory scans;
- background availability polling;
- indexing model caches;
- collecting file sizes for all models;
- deleting or moving files;
- generating profiles from discovered folders.

## Privacy And Safety

Availability documentation should avoid exposing private paths unnecessarily.

A future UI should consider:

- shortening paths in summary views;
- showing full path only when user expands details or copies it;
- avoiding paths in logs by default;
- avoiding paths in exported diagnostics unless explicitly requested;
- never including tokens or credentials.

## UI Copy Rules

Future UI copy should:

- use `Configured`, `Unknown`, `Present`, `Missing`, `External`, or `Stale` consistently;
- explain whether a check was user-triggered;
- avoid implying model ownership;
- avoid implying launch compatibility;
- keep full paths out of compact summary cards unless the user expands details.

## Documentation Examples

Safe wording examples:

```text
This profile references a local model path. Availability has not been checked.
```

```text
The configured path exists. Launch compatibility is not verified.
```

```text
This external target reports a model identifier. Local model files are not managed by MLX Server Manager.
```

Unsafe wording examples:

```text
Model installed.
```

```text
Model is compatible.
```

```text
Ready to run.
```

unless those states have actually been verified by a scoped feature.

## Direct Mode Boundary

Model availability documentation must not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

Availability surfaces are informational. They must not put the app into the inference request path.

## Verification Expectations

A future app-code release should verify:

- availability state defaults to conservative wording;
- local and external model states are distinct;
- checking a path does not modify profiles;
- failed checks do not delete or move files;
- no background scanning is introduced;
- no model download is triggered;
- no token or credential is persisted;
- existing profile import/export tests still pass;
- server start/stop behavior remains unchanged.

## Future Implementation Candidates

Safe follow-up releases may include:

1. Model Availability Documentation Polish.
2. Model availability surface design.
3. Explicit selected-profile path check design.
4. Read-only availability UI implementation.
5. Model download implementation only after separate approval.

## Release Acceptance

`v6.18.0` and `v6.18.1` are acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- no model download is executed;
- no model deletion is added;
- no model scanning is added;
- no cache cleanup is added;
- no token persistence is added;
- no background availability polling is added;
- release notes state that the current binary remains `v6.5.1`;
- future model availability implementation remains explicitly scoped.
