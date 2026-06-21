# Diagnostics Result Model Design

## Release

- Added in `v6.20.0`.
- Polished in `v6.20.1`.
- Docs-only design for future diagnostics result modeling.
- Follows `v6.19.0` / `v6.19.1` Deeper Diagnostics Design.
- No diagnostics result model implementation is included in this release.
- No new app binary is produced for this release.

## Purpose

`v6.20.0` defines a future diagnostics result model before any app-code changes are made.

The goal is to make future diagnostic results consistent, copy-safe, redaction-aware, and scoped without adding automatic diagnostics, endpoint testing, inference requests, background monitoring, telemetry, or runtime behavior changes.

This release does not run diagnostics, call endpoints, inspect traffic, persist diagnostics history, export logs, or change app behavior.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current diagnostics assumptions:

- diagnostics are explicit user actions;
- existing diagnostics remain local and bounded;
- readiness behavior remains scoped to existing app behavior;
- the app does not call `/v1/chat/completions`;
- the app does not run inference as diagnostics;
- the app does not perform background monitoring;
- the app does not inspect request or response traffic;
- diagnostic summaries should be redacted before copying or export.

## Result Model Goals

A future diagnostics result model should:

- make check results consistent across diagnostics surfaces;
- represent explicit check scope;
- separate check status from severity;
- preserve skipped and unknown states;
- keep sensitive values redacted;
- support copy-safe summaries;
- avoid persistent history unless separately scoped;
- avoid mixing runtime state changes with result display.

## Non-Goals

The result model must not add:

- automatic diagnostic execution;
- endpoint testing by itself;
- inference requests;
- background monitoring;
- traffic inspection;
- telemetry;
- analytics;
- persistent diagnostics history;
- automatic repair actions;
- model deletion;
- cache cleanup;
- profile mutation.

## Candidate Data Shape

A future result type may include:

```text
DiagnosticResult
- id
- title
- category
- status
- severity
- scope
- summary
- detail
- userAction
- redactionLevel
- timestamp
```

Stable ID policy:

- `id` should be stable across app launches for the same check definition;
- `id` should not include local paths, tokens, ports, or user-specific values;
- display order should not depend on localized title strings;
- copied summaries may include titles, but tests should prefer stable IDs.

This is conceptual only and does not require these exact field names.

## Status Values

Use a small set of status values:

```text
pass
warning
fail
skipped
unknown
cancelled
timeout
```

Status should describe the check outcome, not the app as a whole.

## Severity Values

Severity should describe user attention level:

```text
info
warning
error
blocking
```

Severity must not imply inference readiness unless the check specifically verified that readiness within the explicit scope.

## Scope Values

Scope should record what was checked:

```text
appConfiguration
executablePath
selectedProfile
currentTarget
managedServer
externalServer
clientSetup
logsSummary
modelAvailability
```

Each scope must remain narrow. A selected profile path check should not become a recursive model scan. An external server check should not imply process ownership.

## Category Policy

Categories should be stable enough for UI grouping and copied summaries.

Recommended categories:

- Configuration;
- Profile;
- Runtime;
- External Target;
- Client Setup;
- Logs;
- Model Availability;
- Privacy / Redaction.

A result should belong to one primary category. Secondary labels should be avoided unless a separate grouping design is approved.

## Copy And Export Eligibility

A future result should have explicit copy/export eligibility:

- include in compact summary;
- include only in detailed local view;
- exclude from copied summaries;
- exclude from exported diagnostics.

Default should be exclusion until redaction rules are applied.

## Redaction Model

Each result should be treated as one of:

```text
publicSafe
copySafe
detailOnly
privateLocalOnly
```

Definitions:

- `publicSafe`: safe for release notes or public docs.
- `copySafe`: safe for user clipboard summaries after redaction.
- `detailOnly`: safe only in expanded local UI.
- `privateLocalOnly`: should not appear in copied summaries or exports.

Default should be `copySafe` only after explicit redaction has run.

## Message Fields

A result may have separate message fields:

```text
summary: short, copy-safe text
detail: longer local-only explanation
userAction: suggested next step
```

Rules:

- summary must not contain secrets;
- detail may contain fuller local context, but should still avoid tokens;
- userAction should be non-destructive;
- raw command output should not be the default detail.

## Timestamp Policy

Timestamps should be optional and local.

Use timestamps only to explain result freshness, not for telemetry.

A timestamp should not imply background monitoring. It should mean the user explicitly ran a diagnostic group at that time.

## Cancellation And Timeout Results

Cancellation should preserve completed results and mark unrun checks as `skipped` or `cancelled`.

Timeout should produce a scoped result such as:

```text
status: timeout
severity: warning
scope: currentTarget
summary: The selected readiness check timed out.
```

Timeout must not trigger automatic retries unless user-triggered.

## Aggregation Precedence

When a compact summary needs one headline state, use this precedence:

```text
blocking > error > warning > timeout > cancelled > unknown > skipped > info
```

This headline is only a summary of diagnostics results. It must not be described as overall app health.

## Aggregation Rules

A future diagnostics summary may aggregate:

- total checks;
- pass count;
- warning count;
- fail count;
- skipped count;
- unknown count;
- timeout count;
- cancelled count.

Do not collapse all state into a single `healthy` label.

If a single top-level label is needed, use conservative wording such as:

```text
Diagnostics completed with warnings.
```

## Copy Summary Format

A copied summary should include:

```text
MLX Server Manager Diagnostics Summary
Target:
Profile:
Checks:
Pass:
Warning:
Fail:
Skipped:
Unknown:
Timeout:
Cancelled:
```

For each result, include:

```text
- [status] [category] title: summary
```

Do not include tokens, raw command output, full private paths, inference prompts, or inference responses.

## UI Surface Boundary

SwiftUI views should not construct diagnostic results directly from process or endpoint calls.

A future implementation should keep:

- check execution;
- endpoint decisions;
- timeout handling;
- redaction;
- aggregation;
- copy summary generation;

behind service/controller boundaries.

Views should display already-formed result state.

## Direct Mode Boundary

The diagnostics result model must not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

A result model organizes app diagnostics output. It must not put the app into the inference request path.

## Fixture Expectations

A future implementation should include fixtures for:

- all status values;
- all severity values;
- skipped and unknown states;
- timeout and cancellation states;
- redacted copy-safe summaries;
- external server results that do not imply ownership;
- selected-profile results that do not mutate profiles.

Fixtures should avoid real local paths, tokens, account names, and raw command output.

## Verification Expectations

A future app-code release should verify:

- result states are stable and conservative;
- skipped and unknown states are preserved;
- timeouts do not trigger background retries;
- copied summaries are redacted;
- external server results do not imply process ownership;
- selected-profile checks do not mutate profiles;
- no inference endpoint is called;
- existing diagnostics behavior remains explicit and user-initiated;
- existing tests still pass.

## Future Implementation Candidates

Safe follow-up releases may include:

1. Diagnostics Result Model Design Polish.
2. Diagnostics result fixture design.
3. Copy Diagnostics Summary model polish.
4. Explicit selected-target readiness check design.
5. Deeper diagnostics app-code implementation.

## Release Acceptance

`v6.20.0` and `v6.20.1` are acceptable if:

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
- no diagnostics history persistence is added;
- release notes state that the current binary remains `v6.5.1`;
- future diagnostics result model implementation remains explicitly scoped.
