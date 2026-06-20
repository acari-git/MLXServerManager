# Signed Zip Implementation Readiness

## Release

- Added in `v6.11.0`.
- Docs-only readiness review for a future signed zip implementation.
- Follows `v6.9.0` / `v6.9.1` Signed Distribution Design and `v6.10.0` / `v6.10.1` Notarization Workflow Design.
- No new app binary is produced for this release.

## Purpose

`v6.11.0` defines the readiness gate for a future signed zip implementation before any signing commands, release automation, or binary publishing changes are added.

The goal is to decide what must be true before MLX Server Manager publishes a signed app zip. This readiness review does not sign the app, run notarization, staple a ticket, create a DMG, create an installer, add CI release automation, create a new app binary, or change app behavior.

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

These releases do not replace the current app binary.

## Implementation Readiness Gate

A future signed zip implementation should not start until all of the following are true:

- the release target is a signed zip, not a DMG or installer;
- the signing identity is selected outside the repository;
- certificate, keychain, and credential handling are documented without committing secrets;
- the build path is deterministic enough to verify before signing;
- the app bundle contents can be checked before and after signing;
- the final zip contents can be checked before publishing;
- release notes include signing status, notarization status, asset name, and SHA-256;
- fallback behavior is clear if signing fails;
- no unrelated UI or runtime behavior changes are bundled into the implementation release.

## Proposed Implementation Scope

A future signed zip implementation may include:

- a documented local signing command sequence;
- a signed app bundle verification step;
- a signed zip packaging step;
- zip content verification;
- SHA-256 calculation;
- release notes template updates for signed assets;
- README install guidance for signed zip assets.

It should not include:

- notarization unless explicitly scoped in the same release;
- DMG generation;
- installer generation;
- auto-update;
- release automation;
- runtime behavior changes;
- process management changes;
- model management changes;
- telemetry;
- background monitoring;
- request inspection;
- proxying.

## Local Signing Preconditions

Before implementation, confirm:

- a Developer ID Application identity exists locally or in the intended CI environment;
- the identity can be referenced without committing private account-specific values;
- keychain access is available to the person or environment performing the release;
- signing can be performed after the Release build and before zipping;
- signature verification can be recorded without exposing private keychain details.

Recommended placeholder:

```text
Developer ID Application: <Team or Developer Name> (<TEAMID>)
```

## Candidate Manual Flow

A future manual signed zip flow may be:

```text
1. Confirm clean git status
2. Build Release app
3. Verify unsigned app bundle contents
4. Sign MLXServerManager.app with Developer ID Application identity
5. Verify signed app bundle
6. Create signed zip with only MLXServerManager.app
7. Verify zip contents
8. Calculate SHA-256
9. Create Git tag
10. Push main and tag
11. Create GitHub Release with signed asset metadata
12. Verify release page, asset, and checksum
```

This review does not implement these commands.

## Required Checks Before Publishing

A future signed zip release should record:

- `git diff --check` result;
- Debug build result;
- test result;
- Release build result;
- signing identity label;
- signature verification result;
- Gatekeeper assessment result if used;
- zip path;
- zip size;
- SHA-256;
- top-level zip entries;
- forbidden-entry scan result;
- GitHub Release URL;
- exact release settings block.

## Forbidden Entries

The final signed zip must not contain:

- `.dSYM` bundles unless published separately;
- `.env` files;
- API keys;
- Hugging Face tokens;
- Apple credentials;
- certificates;
- private keys;
- keychain exports;
- model weights;
- model caches;
- app settings files;
- logs;
- user-specific paths;
- `.venv`;
- hidden macOS resource fork files;
- unrelated build products.

## Release Notes Requirements

A future signed zip release should include:

```text
Tag:
Title:
Asset:
Pre-release:
Signing status:
Notarization status:
SHA-256:
```

Example signed-only release:

```text
Tag: vX.Y.Z
Title: vX.Y.Z — Signed Zip Distribution
Asset: MLXServerManager-vX.Y.Z-signed.zip
Pre-release: No
Signing status: Developer ID signed
Notarization status: Not submitted
SHA-256: <hash>
```

## README Install Update Requirement

Before publishing a signed zip, README Install should state:

- the exact signed asset name;
- whether unsigned assets remain available;
- checksum verification command;
- signing status;
- notarization status;
- whether Gatekeeper warnings may still appear;
- what users should avoid downloading when they want the app binary.

## Fallback Policy

If signing fails before release publication:

- do not publish the asset as signed;
- either fix and retry or keep the release docs-only;
- do not replace the current downloadable app binary unless the binary asset is verified;
- keep release notes explicit about the current binary.

If signing succeeds but verification fails:

- do not publish the asset;
- preserve failure notes locally;
- fix and repeat from build or signing step.

If signing succeeds and verification passes:

- publish only with exact signing status and checksum;
- do not imply notarization unless notarization is also completed and verified.

## Direct Mode Boundary

Signed zip implementation does not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Future Implementation Candidates

After this readiness review, safe follow-up releases may include:

1. Signed Zip Readiness Polish.
2. Local signing command draft.
3. Signed zip app-code release.
4. README install update for signed assets.
5. Notarized zip implementation after signing is stable.

## Release Acceptance

`v6.11.0` is acceptable if:

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
- future signed zip implementation is gated by explicit readiness checks.
