# Notarization Workflow Design

## Release

- Added in `v6.10.0`.
- Docs-only notarization workflow design.
- Follows `v6.9.0` / `v6.9.1` Signed Distribution Design.
- No new app binary is produced for this release.

## Purpose

`v6.10.0` defines a future notarization workflow for MLX Server Manager before any notarization implementation is added.

Notarization should improve macOS distribution trust for signed release assets, but it must not change Direct Mode, app runtime behavior, model handling, process ownership, persistence, telemetry, endpoint behavior, or release asset boundaries.

This release does not sign the app, submit the app for notarization, staple a ticket, create a DMG, create an installer, add CI release automation, create a new app binary, or change app behavior.

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

These releases do not replace the current app binary.

## Notarization Goals

Future notarized distribution should:

- make macOS install behavior clearer for users;
- reduce Gatekeeper friction for release assets;
- preserve explicit signing and notarization status in release notes;
- keep checksums visible for every downloadable binary asset;
- avoid embedding model files, caches, logs, settings, secrets, tokens, or user-specific paths;
- keep the app outside the inference request path;
- keep unsigned or signed-only fallback policy explicit while notarization is introduced.

## Notarization Non-Goals

Notarization must not be used to introduce:

- inference proxying;
- Chat UI;
- backend routing;
- request rewriting;
- request or response inspection;
- telemetry;
- background monitoring;
- automatic endpoint testing;
- model download;
- model deletion;
- installed model scanning;
- cache cleanup;
- API key or token storage;
- generated client config persistence;
- auto-update behavior;
- privileged helpers;
- launch agents;
- installer-only distribution.

## Workflow Prerequisites

A future notarization implementation should require:

- a Developer ID signed app bundle;
- an explicit signing identity;
- a notarization credential plan outside the repository;
- a local or CI environment that can run notarization without committing secrets;
- a clear asset naming policy;
- a clear failure policy;
- release notes that identify both signing and notarization status.

## Credential Handling Boundary

Do not commit or expose:

- Apple account credentials;
- app-specific passwords;
- private keys;
- certificates;
- keychain exports;
- API keys;
- CI secret values;
- local notarization profiles;
- team-specific private identifiers unless intentionally documented as placeholders.

Recommended placeholder wording:

```text
NOTARY_PROFILE=<notarytool-profile-name>
TEAM_ID=<TEAMID>
APPLE_ID=<apple-id-placeholder>
```

Actual values must be provided through local keychain state, local environment, or CI secrets outside the repository.

## Conceptual Notarization Flow

A future notarization flow may use this conceptual sequence:

```text
1. Build Release app
2. Verify unsigned app contents
3. Sign MLXServerManager.app with Developer ID Application identity
4. Verify the app signature
5. Zip the signed app for notarization submission
6. Submit the signed app zip to Apple notarization service
7. Wait for notarization result
8. If accepted, staple the notarization ticket where applicable
9. Verify stapled app assessment
10. Create the final distribution archive
11. Calculate SHA-256
12. Verify archive contents
13. Publish GitHub Release with explicit signing and notarization metadata
```

This review does not implement those commands.

## Notarization Result Handling

### Accepted

If notarization is accepted:

- record the accepted status in release notes;
- record whether stapling was performed;
- record verification result;
- publish asset name that identifies notarized status;
- include SHA-256.

### Rejected

If notarization is rejected:

- do not publish the asset as notarized;
- preserve the rejection log locally or in a private CI artifact if needed;
- avoid exposing private account, path, or credential details in public release notes;
- either fix and retry or publish a clearly labeled signed-only or unsigned asset according to the release plan.

### Service unavailable or timeout

If notarization cannot complete:

- do not imply notarized status;
- choose a fallback asset policy before publishing;
- record the actual release status accurately.

## Proposed Asset Naming

Use explicit names:

```text
MLXServerManager-vX.Y.Z-signed.zip
MLXServerManager-vX.Y.Z-notarized.zip
MLXServerManager-vX.Y.Z.dmg
```

Avoid ambiguous names:

```text
MLXServerManager.zip
latest.zip
release.zip
```

If both signed-only and notarized assets are published, include separate checksums and status for each.

## Release Notes Requirements

Future notarized release notes should include:

```text
Tag:
Title:
Asset:
Pre-release:
Signing status:
Notarization status:
Stapling status:
SHA-256:
```

Example:

```text
Tag: vX.Y.Z
Title: vX.Y.Z — Notarized Distribution
Asset: MLXServerManager-vX.Y.Z-notarized.zip
Pre-release: No
Signing status: Developer ID signed
Notarization status: Accepted
Stapling status: Stapled
SHA-256: <hash>
```

## Manual Verification Notes

For a future notarized release, record:

- signing identity label used in release notes;
- notarization submission status;
- accepted or rejected result;
- stapling status;
- local assessment result;
- final archive path and size;
- SHA-256;
- top-level archive entries;
- forbidden-entry scan result;
- release URL;
- fallback asset policy if notarization fails.

## Fallback Policy

Choose fallback policy before implementation:

1. Notarized-only release.
2. Signed zip plus notarized zip.
3. Signed-only release if notarization fails.
4. Continue unsigned-only until notarization is stable.

Release notes must accurately state which policy was used.

## Direct Mode Boundary

Notarized distribution does not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Future Implementation Candidates

After this design, safe follow-up releases may include:

1. Notarization workflow polish.
2. Local notarization command design.
3. Signed Zip Implementation Readiness.
4. Signed zip app-code implementation.
5. Notarized zip implementation.
6. README install update for signed and notarized assets.

Actual notarization should be implemented in a dedicated app-code or release-workflow release, not bundled into unrelated UI work.

## Release Acceptance

`v6.10.0` is acceptable if:

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
- future notarization work is scoped explicitly before implementation.
