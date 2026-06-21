# Diagnostics Result Fixture File Layout Design

## Release

- Added in `v6.22.0`.
- Polished in `v6.22.1`.
- Docs-only design for future diagnostics result fixture file layout.
- Follows `v6.21.0` / `v6.21.1` Diagnostics Result Fixture Design.
- No diagnostics fixture files, tests, or Swift source changes are included in this release.
- No new app binary is produced for this release.

## Purpose

`v6.22.0` defines where future diagnostics result fixtures may live, how they should be named, and which storage format should be used before any fixture implementation is added.

The goal is to keep future diagnostics fixtures deterministic, redaction-safe, reviewable, and test-target friendly without adding tests, running diagnostics, calling endpoints, persisting history, or changing runtime behavior.

This release does not add fixture files, test files, Swift source files, diagnostics execution, endpoint testing, inference requests, telemetry, or app behavior changes.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current diagnostics fixture state:

- diagnostics result model is design-only;
- diagnostics result fixture design is design-only;
- no fixture files are implemented;
- no tests are added;
- no runtime code consumes fixtures;
- no diagnostics history is persisted.

## Layout Goals

Future fixture layout should:

- make fixture purpose visible from file path;
- keep fixture data deterministic;
- separate documentation examples from test fixtures;
- avoid private local values;
- support redaction tests;
- support copy-summary tests;
- support future Swift test target loading;
- avoid mixing fixture design docs with executable test data.

## Non-Goals

This file layout design must not add:

- fixture implementation;
- Swift source changes;
- test target changes;
- diagnostics execution;
- endpoint testing;
- inference requests;
- background monitoring;
- telemetry;
- diagnostics history persistence;
- runtime behavior changes.

## Candidate Directory Layout

A future implementation may use:

```text
Tests/MLXServerManagerTests/Fixtures/Diagnostics/
  results/
  summaries/
  redaction/
  aggregation/
  negative/
```

Candidate files:

```text
results/status_pass.json
results/status_warning.json
results/status_fail.json
results/status_skipped.json
results/status_unknown.json
results/status_cancelled.json
results/status_timeout.json
summaries/mixed_status_copy_summary.txt
redaction/token_redaction.json
aggregation/blocking_precedence.json
negative/no_external_ownership_claim.json
negative/no_profile_mutation.json
```

This is a proposed layout only. It does not create files in `v6.22.0`.

## Format Options

### JSON Fixtures

Pros:

- portable;
- easy to review;
- language-neutral;
- good for redaction and copy-summary tests;
- easy to validate for forbidden strings.

Cons:

- requires loading/parsing support;
- can drift from Swift model types if field names change;
- needs explicit schema discipline.

### Swift Static Fixtures

Pros:

- compile-time type checking;
- easy to use in Swift tests;
- less parsing code.

Cons:

- harder to review as plain fixture data;
- can accidentally mix test construction with production assumptions;
- less useful for redaction string scanning.

### Markdown Examples

Pros:

- useful for documentation;
- readable for manual review;
- good for release notes and design references.

Cons:

- not ideal as executable test data;
- easy to include prose that weakens deterministic assertions;
- not a substitute for structured fixtures.

## Recommended First Implementation

Use JSON fixture files for first test fixture data, with optional Swift helpers that load and validate those files.

Rationale:

- JSON keeps fixture data separate from Swift code;
- redaction and forbidden-value scans are easier;
- copied summary output can be compared deterministically;
- future schema changes can be reviewed explicitly.

Do not use Markdown as the executable fixture source.

## Naming Rules

Fixture file names should be:

- lowercase;
- stable;
- descriptive;
- scoped by category;
- free of local path values;
- free of tokens, ports, machine names, or user names.

Use names such as:

```text
status_timeout_current_target.json
redaction_bearer_token_copy_safe.json
negative_external_server_no_ownership.json
aggregation_blocking_precedence.json
summary_mixed_status_copy_safe.txt
```

Avoid names such as:

```text
my_mac_test.json
localhost_8000_real.json
johns_model_path.json
latest_result.json
```

## Schema Validation Boundary

A future implementation should validate fixture shape in tests only.

Schema validation should confirm:

- required fields exist;
- enum-like values use approved names;
- copy-safe fields contain no forbidden strings;
- IDs are stable and deterministic;
- optional fields do not introduce local environment values.

Schema validation should not become production runtime behavior unless a separate runtime fixture-loading design is approved.

## Fixture Schema Expectations

A future JSON fixture may include:

```json
{
  "id": "currentTarget.timeout",
  "title": "Selected target readiness check timed out",
  "category": "Runtime",
  "scope": "currentTarget",
  "status": "timeout",
  "severity": "warning",
  "summary": "The selected readiness check timed out.",
  "detail": "No inference request was sent.",
  "userAction": "Check the server process and retry manually.",
  "redactionLevel": "copySafe"
}
```

Schema rules:

- `id` must be stable;
- `summary` must be copy-safe;
- `detail` must avoid secrets;
- `userAction` must be non-destructive;
- `redactionLevel` must be explicit;
- no fixture should depend on current time.

## Snapshot Safety

Snapshot-like expected outputs should live separately from input fixtures.

Candidate layout:

```text
summaries/expected_mixed_status_copy_summary.txt
```

Snapshot safety rules:

- no timestamps;
- no random IDs;
- no local user paths;
- no machine names;
- no live ports;
- no raw command output;
- no localized date strings;
- deterministic ordering only.

## Negative Fixture Layout

Negative fixtures should make boundary regression obvious.

Candidate files:

```text
negative/no_token_in_copy_summary.json
negative/no_full_home_path_in_summary.json
negative/no_external_ownership_claim.json
negative/no_profile_mutation.json
negative/no_raw_command_output.json
```

Negative fixtures should assert absence, not only presence.

## Redaction Fixture Layout

Redaction fixtures should isolate redaction behavior:

```text
redaction/bearer_token.json
redaction/huggingface_token.json
redaction/query_string_secret.json
redaction/home_path_compaction.json
```

Use fake values only:

```text
hf_FAKE_TOKEN_REDACTED
Bearer FAKE_TOKEN_REDACTED
/Users/example/Models/mlx/example-model
```

Do not include real credentials or user-specific paths.

## File Inclusion Rules

Future fixture files should be included in test resources only.

Rules:

- app target should not bundle diagnostic fixture data;
- release app archives should not contain fixture directories;
- fixture helper code should stay in the test target;
- fixture data should not be generated at runtime;
- fixture data should not be copied into user-facing logs or exports.

## Test Target Boundary

If fixtures are added later, they should belong to the test target only unless a separate runtime fixture-loading design is approved.

Rules:

- fixtures should not be bundled into the app target by default;
- production runtime should not depend on fixture files;
- fixture loading helpers should live under tests;
- generated app binaries should not include test fixtures.

## Documentation Boundary

Design docs may reference fixture layout and examples, but docs are not executable fixtures.

Do not treat docs as the single source of truth for test data once fixture files exist. Future implementation should keep:

- design docs for rationale;
- fixture files for deterministic data;
- test helpers for loading and assertions.

## Fixture Review Checklist

Before fixture files are accepted later, review:

- fixture file names are stable;
- fixture IDs are stable;
- copy-safe fields are redacted;
- negative fixtures assert unsafe data absence;
- snapshot outputs contain no unstable local values;
- app bundle inclusion is not introduced;
- production code does not depend on fixtures.

## Review Checklist

Before adding real fixture files later, confirm:

- fixture directory is inside the test area;
- fixture files are deterministic;
- no private values are present;
- JSON field names match approved result model concepts;
- negative fixtures cover redaction regressions;
- snapshot outputs avoid unstable values;
- app target does not bundle fixtures;
- production code does not depend on fixtures.

## Verification Expectations

A future app-code/test release should verify:

- fixture files load successfully;
- required status fixtures exist;
- required severity fixtures exist;
- redaction fixtures remove secrets;
- copy summary fixtures are deterministic;
- negative fixtures fail if unsafe strings appear;
- fixture files are not included in the app bundle;
- existing tests still pass.

## Implementation Entry Criteria

Move from layout design to actual fixture files only when:

- diagnostics result model concepts are stable enough for tests;
- fixture directory naming is approved;
- JSON schema expectations are agreed;
- negative fixture expectations are agreed;
- app target exclusion can be verified;
- no runtime fixture dependency is introduced.

## Future Implementation Candidates

Safe follow-up releases may include:

1. Diagnostics Result Fixture File Layout Polish.
2. Diagnostics result fixture file implementation.
3. Diagnostics result fixture loading tests.
4. Copy Diagnostics Summary model polish.
5. Deeper diagnostics app-code implementation.

## Release Acceptance

`v6.22.0` is acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no tests are added;
- no fixture files are added beyond this design document;
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
- future diagnostics fixture implementation remains explicitly scoped.
