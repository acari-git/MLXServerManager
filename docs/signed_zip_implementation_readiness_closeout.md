# Signed Zip Implementation Readiness Closeout

## Release

- Added in `v6.15.0`.
- Docs-only closeout for signed zip implementation readiness.
- Closes the signed zip readiness document series from `v6.9.0` through `v6.14.1`.
- No new app binary is produced for this release.

## Purpose

`v6.15.0` consolidates the signed zip readiness work and defines the decision point before any real signed zip implementation release.

This closeout is intended to stop expanding design-only signing documentation indefinitely. After this release, the project should either move to a real signed zip implementation when prerequisites are ready, or switch to a non-signing roadmap item.

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
- `v6.14.1`
- `v6.15.0`

These releases do not replace the current app binary.

## Readiness Document Map

Signed zip and distribution readiness documents now cover:

- `docs/signed_distribution_design.md`
  - signed distribution goals;
  - signing scope;
  - unsigned coexistence options;
  - notarization separation.
- `docs/notarization_workflow_design.md`
  - notarization prerequisites;
  - credential boundaries;
  - status wording;
  - fallback policy.
- `docs/signed_zip_implementation_readiness.md`
  - signed zip implementation gate;
  - asset matrix;
  - manual verification log template;
  - Go / No-Go criteria.
- `docs/local_signing_command_draft.md`
  - placeholder command sequence;
  - signing command caveats;
  - dry-run expectations.
- `docs/signed_zip_dry_run_checklist.md`
  - dry-run checklist;
  - pass / fail criteria;
  - evidence expectations;
  - stop conditions.
- `docs/signed_zip_local_dry_run_execution_notes.md`
  - local-only execution notes;
  - scrub checklist;
  - public summary wording;
  - handoff criteria.

## Closeout Decision

The signed zip readiness phase is complete enough to stop adding new design-only prerequisites.

Next step should be one of two paths:

1. **Proceed to signed zip implementation** only if Developer ID signing prerequisites are ready.
2. **Defer signing** and return to packaging polish, install guidance, or app feature work if signing prerequisites are not ready.

Do not add another signed zip readiness document unless a concrete blocker is discovered.

## Implementation Entry Criteria

Move to real signed zip implementation only when all are true:

- Developer ID Application signing identity is available outside the repository;
- signing can be executed locally or in a trusted environment without committing secrets;
- release owner can verify the signed app bundle;
- release owner can verify final zip contents;
- release notes can state exact signing, notarization, and stapling status;
- asset name is selected before build work starts;
- fallback policy is selected before build work starts;
- no unrelated UI or runtime behavior changes are bundled into the release;
- Direct Mode boundaries remain unchanged.

## Implementation No-Go Criteria

Do not start real signed zip implementation if:

- Developer ID signing identity is not available;
- private credential handling is unclear;
- signing verification cannot be recorded;
- release notes cannot accurately state asset status;
- the release would need to include unrelated app behavior changes;
- notarization is required but not scoped;
- the project would publish a binary with a more trusted name than its actual verification state.

## Candidate Next Release If Ready

If all entry criteria are met:

```text
v6.16.0 — Signed Zip Distribution
```

Expected asset:

```text
MLXServerManager-v6.16.0-signed.zip
```

Expected release metadata:

```text
Tag: v6.16.0
Title: v6.16.0 — Signed Zip Distribution
Asset: MLXServerManager-v6.16.0-signed.zip
Pre-release: No
Signing status: Developer ID signed
Notarization status: Not submitted
Stapling status: Not applicable
SHA-256: <hash>
```

Only use this path if signing and verification actually complete.

## Candidate Next Release If Not Ready

If Developer ID or verification readiness is not available:

```text
v6.16.0 — Packaging Checklist Polish
```

This path keeps distribution work useful without implying a signed binary exists.

Alternative non-signing candidates:

- README install guidance polish;
- model availability documentation;
- deeper diagnostics design;
- app feature planning that preserves Direct Mode.

## Public Wording Policy

Use conservative public wording:

```text
Signing status: Not executed
Notarization status: Not submitted
Stapling status: Not applicable
New binary asset: None
Current public binary: MLXServerManager-v6.5.1-unsigned.zip
```

Do not use words such as `signed`, `notarized`, `stapled`, `release candidate binary`, or `Gatekeeper-ready` unless the corresponding action was completed and verified.

## Asset Naming Policy

Use asset names that match verification state:

```text
MLXServerManager-vX.Y.Z-unsigned.zip
MLXServerManager-vX.Y.Z-signed.zip
MLXServerManager-vX.Y.Z-notarized.zip
```

Do not publish:

- a signed asset name for an unsigned zip;
- a notarized asset name for a signed-only zip;
- a binary asset from a docs-only release;
- source archives as app binaries.

## Verification Expectations For First Signed Zip

A first signed zip release should record:

- clean git status;
- Debug build result;
- test result;
- Release build result;
- signing identity label without private details;
- signature verification result;
- optional local Gatekeeper assessment result if used;
- zip path;
- zip size;
- SHA-256;
- top-level zip entries;
- forbidden-entry scan result;
- GitHub Release URL.

## Direct Mode Boundary

Signed zip implementation does not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Release Acceptance

`v6.15.0` is acceptable if:

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
- it clearly defines whether the next step is signed zip implementation or non-signing packaging polish.
