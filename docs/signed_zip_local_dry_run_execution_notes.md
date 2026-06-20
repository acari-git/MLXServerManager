# Signed Zip Local Dry-Run Execution Notes

## Release

- Added in `v6.14.0`.
- Polished in `v6.14.1` with scrub checklist, public summary wording, and handoff criteria.
- Docs-only execution notes for a future local signed zip dry run.
- Follows `v6.13.0` / `v6.13.1` Signed Zip Dry-Run Checklist.
- No new app binary is produced for this release.

## Purpose

`v6.14.0` defines how to record a local signed zip dry run without publishing a new binary asset.

The purpose is to separate local command rehearsal from real signed distribution. A local dry run may validate paths, expected outputs, checklist structure, evidence requirements, and release-note wording, but it must not be treated as a release binary workflow.

This release does not sign the app, run notarization, staple a ticket, create a DMG, create an installer, add CI release automation, create a new app binary, or change app behavior.

## Current State

Current downloadable app binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

Current docs-only releases after that binary:

- `v6.6.0`
- `v6.6.1`
- `v6.7.0`
- `v6.7.1`
- `v6.8.0`
- `v6.8.1`
- `v6.9.0`
- `v6.9.1`
- `v6.10.0`
- `v6.10.1`
- `v6.11.0`
- `v6.11.1`
- `v6.12.0`
- `v6.12.1`
- `v6.13.0`
- `v6.13.1`
- `v6.14.0`

These releases do not replace the current app binary.

## Dry-Run Execution Boundary

A local dry run may:

- confirm repository state;
- confirm intended version and asset naming;
- validate checklist and release-note structure;
- inspect expected local build paths;
- record placeholder-only signing and notarization status;
- confirm that no binary upload is planned.

A local dry run must not:

- publish a binary asset;
- represent an unsigned artifact as signed;
- represent a signed artifact as notarized;
- expose credentials or account-specific private values;
- modify Swift source files;
- modify runtime behavior;
- add release automation.

## Suggested Local Dry-Run Record

Use a local-only record such as:

```text
Release candidate: vX.Y.Z
Branch: main
Commit: <short-sha>
Scope: docs-only / local-only dry run
Current public binary: MLXServerManager-v6.5.1-unsigned.zip
New binary upload planned: No
Signing planned: Placeholder only
Notarization planned: No
Stapling planned: No
Fallback policy: Keep current public binary
Release notes structure checked: Yes
```

Do not commit this local run record unless it is intentionally generalized and scrubbed of private values.

## Execution Steps

### 1. Confirm repository state

Record:

```text
git status --short:
git rev-parse --abbrev-ref HEAD:
git rev-parse --short HEAD:
git rev-parse --short origin/main:
git tag --points-at HEAD:
```

Expected:

- branch is `main`;
- working tree is clean;
- local HEAD matches `origin/main`;
- no unexpected tag collision exists.

### 2. Confirm release scope

Record:

```text
Release type: docs-only / local-only dry run
Binary upload planned: No
Signing execution planned: No
Notarization execution planned: No
Runtime behavior change planned: No
```

If any answer changes to `Yes`, stop and rescope the release.

### 3. Confirm public asset state

Record:

```text
Current public app asset: MLXServerManager-v6.5.1-unsigned.zip
Current public app SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
Replacement asset planned: No
```

This prevents docs-only dry runs from implying that a new app binary exists.

### 4. Confirm placeholder status wording

Use placeholder-only status wording:

```text
Signing status: Not executed
Notarization status: Not submitted
Stapling status: Not applicable
```

Do not use:

- `signed` unless signing actually completed and was verified;
- `notarized` unless notarization was accepted and verified;
- `stapled` unless stapling actually completed and was verified.

### 5. Confirm release notes structure

Check release notes include:

```text
## Release Settings
## Summary
## Changed
## Asset
## Preserved Behavior
## Boundaries
## Verification
```

For docs-only dry-run releases, the Asset section must state that no new app binary is produced.

### 6. Confirm stop conditions

Stop if:

- repository state is not clean;
- release scope is ambiguous;
- a binary upload becomes part of the plan;
- real signing becomes part of the plan;
- private credential details are needed;
- release notes cannot accurately state the asset state;
- Direct Mode boundaries would change.

## Evidence to Keep Local

A local dry run may keep private local notes for:

- local command output;
- local path checks;
- build-path validation;
- signing identity availability checks.

Do not publish or commit local evidence containing:

- private account names;
- Apple IDs;
- certificate serial details;
- keychain paths;
- notary profiles;
- local user paths;
- credentials;
- tokens.

## Public Summary Wording

Use conservative public wording for local dry runs:

```text
Signing status: Not executed
Notarization status: Not submitted
Stapling status: Not applicable
New binary asset: None
Current public binary: MLXServerManager-v6.5.1-unsigned.zip
```

Avoid wording such as `signed build verified`, `notarization-ready`, or `release candidate binary` unless a scoped binary release actually produced and verified that artifact.

## Public Documentation Criteria

Public docs may include:

- generic command shapes;
- placeholder values;
- pass/fail criteria;
- stop conditions;
- release-note wording requirements;
- fallback policy.

Public docs must not include:

- real signing identity names unless intentionally public;
- real Apple account identifiers;
- local keychain details;
- private failure logs;
- private CI secret names if they reveal account structure.

## Scrub Checklist

Before any local dry-run notes are made public, remove:

- user home directory paths;
- machine names;
- Apple account identifiers;
- certificate serial details;
- keychain names or paths;
- notary profile names;
- CI secret names that expose account structure;
- private command output;
- local-only failure logs;
- tokens or credentials.

Keep only generalized placeholders and release-relevant status.

## Fallback Policy

For docs-only local dry-run releases:

- keep the current public binary unchanged;
- publish no new app asset;
- state that signing was not executed;
- state that notarization was not submitted;
- state that stapling is not applicable.

For a future real signed zip release:

- publish only after signing and verification pass;
- do not imply notarization unless notarization also passes;
- include checksum and verification notes;
- keep fallback policy explicit before release work starts.

## Direct Mode Boundary

Signed zip dry-run execution notes do not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Handoff Criteria

Move from local dry-run notes to real signed zip implementation only when:

- signed zip scope is explicitly approved;
- signing identity handling is ready outside the repository;
- private evidence does not need to be published;
- release notes can state exact signing and notarization status;
- asset naming is chosen before build work starts;
- fallback policy is agreed before build work starts;
- Direct Mode boundaries remain unchanged.

## Future Implementation Candidates

After this execution-notes release, safe follow-up releases may include:

1. Signed zip local dry-run execution notes polish.
2. Signed zip implementation readiness closeout.
3. Signed zip app-code release.
4. README install update for signed assets.
5. Notarized zip implementation after signed zip distribution is stable.

## Release Acceptance

`v6.14.0` and `v6.14.1` are acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- no signing is executed;
- no notarization is executed;
- no stapling is executed;
- no DMG or installer is produced;
- no release automation is added;
- release notes state that the current binary remains `v6.5.1`;
- local dry-run notes remain separate from real signed binary publishing.
