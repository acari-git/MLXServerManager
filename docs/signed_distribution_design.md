# Signed Distribution Design

## Release

- Added in `v6.9.0`.
- Docs-only signed distribution design.
- Follows the `v6.7.0` / `v6.7.1` Distribution / Packaging Readiness Review and the `v6.8.0` / `v6.8.1` README Install refresh.
- No new app binary is produced for this release.

## Purpose

`v6.9.0` defines a future signed distribution path for MLX Server Manager before any signing implementation is added.

This design separates signing policy from app runtime behavior. Signing should improve distribution trust and reduce local install friction, but it must not change Direct Mode, model handling, process ownership, persistence, telemetry, endpoint behavior, or release asset boundaries.

This release does not sign the app, run notarization, create a DMG, create an installer, add CI release automation, create a new app binary, or change app behavior.

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

These releases do not replace the current app binary.

## Signing Goals

Future signed distribution should:

- make the release asset identity clearer;
- allow users to verify that the app bundle was signed by the expected Developer ID identity;
- keep unsigned local-use builds clearly labeled if they remain available;
- preserve the current Direct Mode architecture;
- avoid embedding model files, caches, logs, settings, secrets, tokens, or user-specific paths;
- keep release notes explicit about signing status;
- keep checksums visible for every downloadable binary asset.

## Signing Non-Goals

Signing must not be used to introduce:

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

## Proposed Signed Zip Asset

A future signed app-code release may publish:

```text
MLXServerManager-vX.Y.Z-signed.zip
```

The zip should contain:

```text
MLXServerManager.app/
```

It should not contain:

- `.dSYM` bundles unless intentionally published as a separate debug-symbol asset;
- source archives as release assets;
- `.env` files;
- API keys;
- tokens;
- settings files;
- model weights;
- caches;
- logs;
- user-specific paths;
- hidden macOS resource fork entries;
- unrelated build products.

## Signing Identity

A future implementation should require an explicit Developer ID signing identity.

The identity should be configured outside the repository. Do not commit certificate names if they are private or account-specific unless they are generic placeholders.

Recommended placeholder wording:

```text
Developer ID Application: <Team or Developer Name> (<TEAMID>)
```

Do not store:

- certificates;
- private keys;
- Apple account credentials;
- app-specific passwords;
- API tokens;
- notarization credentials;
- local keychain exports.

## Local Signing Flow Design

A future local signing flow may use this conceptual sequence:

```text
1. Build Release app
2. Verify unsigned app contents
3. Sign MLXServerManager.app with Developer ID Application identity
4. Verify the signature
5. Zip the signed app
6. Calculate SHA-256
7. Verify the zip contents
8. Create GitHub Release with explicit signed asset metadata
```

This review does not implement those commands.

## Required Verification for Signed App

Before publishing a signed zip, verify:

- `git diff --check` passes;
- Debug build passes;
- tests pass;
- Release build passes;
- the app bundle exists at the expected path;
- signing identity is explicit;
- app signature verification passes;
- Gatekeeper assessment is recorded;
- zip contains only expected app entries;
- forbidden-entry scan passes;
- SHA-256 is recorded;
- GitHub Release `Asset` field identifies the signed zip;
- release body states whether notarization was or was not performed.

## Release Notes Requirements

Signed release notes should include:

```text
Tag:
Title:
Asset:
Pre-release:
Signing status:
Notarization status:
SHA-256:
```

Example:

```text
Tag: vX.Y.Z
Title: vX.Y.Z — Signed Distribution
Asset: MLXServerManager-vX.Y.Z-signed.zip
Pre-release: No
Signing status: Developer ID signed
Notarization status: Not notarized
SHA-256: <hash>
```

## Unsigned Build Coexistence

A future release must decide whether unsigned builds remain available.

Acceptable options:

1. Signed-only app-code release.
2. Signed zip plus unsigned zip.
3. Continue unsigned-only until notarization is ready.

If both signed and unsigned assets are published, release notes must clearly distinguish them and include a separate SHA-256 for each asset.

## Relationship to Notarization

Signing is a prerequisite for notarization, but signed distribution and notarized distribution should be scoped separately.

`v6.9.0` does not design the full notarization workflow. A later Notarization Workflow Design should define credential handling, submission, stapling, verification, failure handling, and release-note language.

## Direct Mode Boundary

Signed distribution does not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Security Boundary

Signing improves app identity verification. It does not make the app sandboxed, audited, notarized, or free of risk by itself.

Release documentation should avoid overstating signing. It should say exactly what was done:

- unsigned;
- signed;
- signed and notarized;
- DMG signed;
- installer signed.

## Future Implementation Candidates

After this design, safe follow-up releases may include:

1. Signed distribution checklist polish.
2. Local signing command design.
3. Notarization Workflow Design.
4. Signed zip app-code implementation.
5. README install section update for signed assets.

Actual signing should be implemented in a dedicated app-code or release-workflow release, not bundled into unrelated UI work.

## Release Acceptance

`v6.9.0` is acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- no signing is executed;
- no notarization is executed;
- no DMG or installer is produced;
- no release automation is added;
- release notes state that the current binary remains `v6.5.1`;
- future signing work is scoped explicitly before implementation.
