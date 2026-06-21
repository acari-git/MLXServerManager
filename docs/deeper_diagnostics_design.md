# Deeper Diagnostics Design

## Release

- Added in `v6.19.0`.
- Docs-only design for future deeper diagnostics surfaces.
- No deeper diagnostics implementation is included in this release.
- No new app binary is produced for this release.

## Purpose

`v6.19.0` defines boundaries for future deeper diagnostics without adding automatic diagnostics, endpoint testing from read-only surfaces, background monitoring, traffic inspection, telemetry, or inference requests.

The goal is to help users understand local setup issues while preserving Direct Mode and keeping diagnostics explicit, local, and non-destructive.

This release does not run diagnostics, call endpoints, inspect inference traffic, start or stop servers, monitor in the background, persist telemetry, or change app behavior.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current diagnostics assumptions:

- diagnostics are explicit user actions;
- readiness checks use `/v1/models` only where already scoped;
- copied chat examples are client-side convenience text only;
- the app does not call `/v1/chat/completions`;
- the app does not run inference as diagnostics;
- the app does not perform background monitoring;
- the app does not inspect request or response traffic.

## Design Goals

Future deeper diagnostics should:

- make setup problems easier to understand;
- keep checks explicit and user-initiated;
- separate local configuration checks from server readiness checks;
- make each check's scope visible before it runs;
- avoid destructive repair actions;
- avoid automatic background checks;
- avoid inference requests;
- avoid telemetry and analytics;
- keep sensitive values redacted.

## Non-Goals

Future deeper diagnostics must not:

- become a proxy;
- add Chat UI;
- send inference requests;
- rewrite prompts or requests;
- inspect inference traffic;
- perform continuous monitoring;
- stop external processes;
- kill processes by name;
- delete model files;
- clean caches;
- upload logs;
- persist diagnostics history without a separate design.

## Diagnostic Categories

Potential categories:

- App configuration;
- Executable path;
- Model profile configuration;
- Port configuration;
- Managed server lifecycle state;
- External server target state;
- Client setup values;
- Logs summary;
- Model path availability, only if explicitly scoped later.

Each category should have visible scope and conservative status wording.

## Diagnostic Result Terms

Use simple terms:

```text
Pass
The explicit check succeeded.

Warning
The explicit check completed but found a non-blocking issue.

Fail
The explicit check completed and found a blocking issue.

Skipped
The check did not run because it was out of scope or not applicable.

Unknown
The app has not checked this state.
```

Do not use `healthy`, `compatible`, `optimized`, or `ready` unless the exact scope of that claim is visible.

## Explicit Check Scope

Before running a deeper diagnostic group, the app should show:

- what will be checked;
- whether any endpoint will be called;
- whether any local path will be accessed;
- whether any process state will be read;
- whether any profile will be modified;
- whether any data will be persisted.

Default design should be:

```text
No profile changes.
No file deletion.
No model download.
No inference request.
No background monitoring.
```

## Endpoint Policy

Endpoint checks must remain conservative.

Allowed only when explicitly user-triggered and scoped:

- `/v1/models` readiness check for the active managed or adopted server target.

Not allowed as diagnostics without a separate design:

- `/v1/chat/completions`;
- streaming inference;
- embedding requests;
- arbitrary endpoint probing;
- repeated polling from read-only surfaces;
- traffic inspection.

## Local Path Policy

Local path checks should be narrow and explicit.

Allowed future checks:

- executable path exists;
- selected profile model path exists, if scoped by model availability design;
- selected output or log path exists, if already user-configured.

Not allowed without separate design:

- recursive scans;
- cache cleanup;
- model deletion;
- model discovery;
- file-size inventory of model folders;
- background file watching.

## External Server Policy

For external servers, diagnostics should not imply ownership.

Safe checks:

- configured base URL is present;
- adopted target context is displayed;
- optional explicit `/v1/models` check if user requests it.

Do not:

- stop external processes;
- infer process ownership;
- scan external server logs;
- assume local file paths;
- run inference to test the server.

## Privacy And Redaction

Diagnostic output should redact:

- API keys;
- Hugging Face tokens;
- Apple credentials;
- private signing details;
- app-specific passwords;
- bearer tokens;
- query strings that may contain secrets.

Paths should be handled carefully:

- compact summaries may shorten home directory paths;
- full paths should appear only in detailed view or copy actions;
- diagnostics exports should require explicit user action.

## Copy Diagnostics Summary

A future deeper summary may include:

```text
App version:
Release context:
Target type:
Base URL:
Model ID:
Profile name:
Check count:
Pass:
Warning:
Fail:
Skipped:
Unknown:
```

It should not include:

- tokens;
- raw command output by default;
- full private paths unless user chooses detailed export;
- inference prompts or responses.

## Repair Actions Boundary

First deeper diagnostics implementation should not auto-repair.

Possible safe actions:

- copy suggested command;
- open settings;
- open profile editor;
- reveal selected path in Finder;
- copy diagnostics summary.

Out of scope:

- automatically edit profiles;
- delete files;
- stop external servers;
- change ports automatically;
- install dependencies;
- download models;
- clean caches.

## UI Surface Boundary

SwiftUI views should not perform diagnostic logic directly.

A future implementation should keep:

- diagnostic check definitions;
- endpoint call decisions;
- redaction;
- result aggregation;
- copy summary generation;
- cancellation;

behind service/controller boundaries.

Views should present state and user controls only.

## Verification Expectations

A future app-code release should verify:

- diagnostics remain user-initiated;
- no inference endpoint is called;
- no background monitoring is introduced;
- skipped checks are visible;
- warning and failure counts are accurate;
- copied summaries redact secrets;
- external server diagnostics do not imply process ownership;
- existing start/stop/restart behavior remains unchanged;
- existing tests still pass.

## Future Implementation Candidates

Safe follow-up releases may include:

1. Deeper Diagnostics Design Polish.
2. Diagnostics Result Model Design.
3. Copy Diagnostics Summary polish.
4. Explicit selected-target readiness check design.
5. Deeper diagnostics app-code implementation.

## Release Acceptance

`v6.19.0` is acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- no diagnostics are executed;
- no endpoint testing is added;
- no inference requests are added;
- no background monitoring is added;
- no traffic inspection is added;
- no telemetry is added;
- release notes state that the current binary remains `v6.5.1`;
- future deeper diagnostics implementation remains explicitly scoped.
