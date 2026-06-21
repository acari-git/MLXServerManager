# Diagnostics Result Fixture Design

## Release

- Added in `v6.21.0`.
- Docs-only design for future diagnostics result fixtures.
- Follows `v6.20.0` / `v6.20.1` Diagnostics Result Model Design.
- No diagnostics fixture implementation is included in this release.
- No new app binary is produced for this release.

## Purpose

`v6.21.0` defines fixture expectations for a future diagnostics result model before any Swift source, tests, or app-code implementation are added.

The goal is to ensure future diagnostics result fixtures cover status, severity, scope, category, redaction, copy/export eligibility, timeout/cancellation, and ownership boundaries without running diagnostics, calling endpoints, persisting history, or changing runtime behavior.

This release does not add tests, run diagnostics, call endpoints, inspect traffic, persist diagnostics history, export logs, or change app behavior.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current diagnostics design assumptions:

- diagnostics are explicit user actions;
- deeper diagnostics remain design-only;
- result model is design-only;
- fixtures are not implemented yet;
- no diagnostics history is persisted;
- copied summaries must be redaction-aware;
- external server results must not imply process ownership;
- selected-profile results must not mutate profiles.

## Fixture Goals

Future diagnostics result fixtures should:

- cover every status value;
- cover every severity value;
- cover each approved diagnostic scope;
- cover stable categories;
- verify copy-safe redaction expectations;
- preserve skipped and unknown states;
- represent timeout and cancellation states;
- avoid private local paths and credentials;
- support deterministic UI and copy-summary tests.

## Non-Goals

Fixture design must not add:

- live diagnostic execution;
- endpoint testing;
- inference requests;
- background monitoring;
- traffic inspection;
- telemetry;
- diagnostics history persistence;
- automatic repair actions;
- model deletion;
- cache cleanup;
- profile mutation.

## Fixture Naming Policy

Fixture names should be stable and descriptive.

Recommended pattern:

```text
DiagnosticsResultFixture.<scope>.<status>.<severity>
```

Examples:

```text
selectedProfile.missingPath.warning
externalServer.modelsSkipped.skipped
currentTarget.timeout.warning
copySummary.redactedTokens.pass
```

Fixture names must not include user-specific paths, tokens, ports, account names, or machine names.

## Required Status Fixtures

Future fixtures should include at least one result for each status:

```text
pass
warning
fail
skipped
unknown
cancelled
timeout
```

Each status fixture should include:

- stable ID;
- title;
- category;
- severity;
- scope;
- copy-safe summary;
- non-destructive user action when applicable.

## Required Severity Fixtures

Future fixtures should include at least one result for each severity:

```text
info
warning
error
blocking
```

Severity fixtures should avoid implying full app health. A blocking fixture should block only the explicit diagnostic scope.

## Required Scope Fixtures

Future fixtures should cover approved scopes:

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

Scope fixtures must remain narrow:

- selected profile fixtures must not imply recursive model scanning;
- external server fixtures must not imply process ownership;
- logs summary fixtures must not include raw full logs by default;
- model availability fixtures must not imply compatibility unless explicitly checked.

## Category Fixtures

Future fixtures should cover stable UI categories:

- Configuration;
- Profile;
- Runtime;
- External Target;
- Client Setup;
- Logs;
- Model Availability;
- Privacy / Redaction.

A fixture should use one primary category. Avoid multi-category fixtures unless a separate grouping design is approved.

## Redaction Fixtures

Future fixtures should include copy/export eligibility examples for:

```text
publicSafe
copySafe
detailOnly
privateLocalOnly
```

Required redaction cases:

- bearer token redaction;
- Hugging Face token redaction;
- query string redaction;
- compact home-directory path shortening;
- raw command output excluded from compact summary;
- private local-only result excluded from copied summary.

Redaction fixtures must use fake placeholder values only.

## Copy Summary Fixtures

Copy summary fixtures should verify:

- heading text is stable;
- counts are correct;
- status/category/title ordering is deterministic;
- secrets are absent;
- full private paths are absent from compact summary;
- skipped and unknown states are not dropped;
- timeout and cancellation states are represented.

Example shape:

```text
MLX Server Manager Diagnostics Summary
Target: <redacted or generic>
Profile: Example Profile
Checks: 7
Pass: 1
Warning: 2
Fail: 1
Skipped: 1
Unknown: 1
Timeout: 1
Cancelled: 0
```

## Timeout And Cancellation Fixtures

Future fixtures should include:

- timeout in current target readiness scope;
- cancellation after partial completion;
- skipped checks after cancellation;
- no background retry after timeout;
- no profile mutation after cancellation.

Timeout and cancellation fixtures should not imply app instability outside the explicit check scope.

## External Server Ownership Fixtures

External server fixtures should verify wording such as:

```text
External server target reported a model identifier. MLX Server Manager does not own this process.
```

Fixtures must not:

- include process IDs unless explicitly scoped later;
- infer local model paths;
- claim the app can stop the external server;
- imply local file ownership.

## Selected Profile Mutation Fixtures

Selected profile fixtures should verify:

- diagnostics can report a profile issue;
- diagnostics do not change profile fields;
- diagnostics do not change selected profile;
- diagnostics do not create profiles;
- diagnostics do not overwrite model paths.

Suggested cases:

- missing model path warning;
- invalid executable path fail;
- unknown model availability skipped;
- profile copy summary includes no token or secret.

## Aggregation Fixtures

Future aggregation fixtures should cover:

- all-pass summary;
- warnings-only summary;
- fail plus warning summary;
- timeout plus skipped summary;
- cancelled run summary;
- unknown-heavy summary;
- blocking result precedence.

Aggregation should preserve counts and should not collapse results into a generic `healthy` label.

## Fixture Data Safety

Fixtures must not contain:

- real tokens;
- real API keys;
- real Apple credentials;
- real Hugging Face tokens;
- real home directory paths;
- private account names;
- local machine names;
- raw command output from the user's environment;
- inference prompts or responses.

Use placeholders such as:

```text
/Users/example/Models/mlx/example-model
https://127.0.0.1:8000/v1
hf_***REDACTED***
```

## Verification Expectations

A future app-code release should verify:

- fixture IDs are stable;
- status values are exhaustive;
- severity values are exhaustive;
- copy summaries are deterministic;
- redaction fixtures remove secrets;
- external server fixtures avoid ownership claims;
- selected profile fixtures avoid mutation;
- timeout and cancellation fixtures preserve completed results;
- existing tests still pass.

## Future Implementation Candidates

Safe follow-up releases may include:

1. Diagnostics Result Fixture Design Polish.
2. Diagnostics result fixture file layout design.
3. Copy Diagnostics Summary model polish.
4. Explicit selected-target readiness check design.
5. Deeper diagnostics app-code implementation.

## Release Acceptance

`v6.21.0` is acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no tests are added;
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
- future diagnostics result fixtures remain explicitly scoped.
