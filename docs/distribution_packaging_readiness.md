# Distribution / Packaging Readiness Review

## Release

- Added in `v6.7.0`.
- Polished in `v6.7.1` with install documentation planning and manual packaging verification notes.
- Polished in `v6.16.0` with post-closeout packaging checklist guidance.
- Polished in `v6.16.1` with binary release go/no-go, asset naming failure cases, and release body verification notes.
- Docs-only readiness review.
- Follows the `v6.6.0` / `v6.6.1` App Layout Stabilization Review.
- No new app binary is produced for this release.

## Purpose

`v6.7.0` defines the distribution and packaging boundary before any signed, notarized, DMG, or automated release workflow is implemented.

The current public binary remains the unsigned zip produced by `v6.5.1`. This review is meant to prevent packaging work from accidentally changing runtime behavior, app architecture, Direct Mode, local persistence, model handling, or release asset expectations.

This release does not implement signing, notarization, DMG packaging, installer packaging, automated release workflows, update mechanisms, new app binaries, runtime behavior, network behavior, telemetry, or model management.

## Current Distribution State

Current release asset policy:

- App-code releases may publish an unsigned zip asset.
- Docs-only releases publish GitHub Release notes only.
- `v6.5.1` is the current downloadable app binary.
- `v6.6.0` through `v6.16.0` include multiple docs-only distribution and readiness releases after the current app binary.
- Docs-only releases do not replace the app binary.

Current binary:

```text
MLXServerManager-v6.5.1-unsigned.zip
SHA-256: 31e8603f93d3a3eaedee9749a255668c9b804854fb69cb3b63f36b411613274e
```

## Distribution Goals

Future distribution work should aim to:

- make install steps clearer for non-developer users;
- reduce Gatekeeper friction when a signed and notarized path exists;
- keep unsigned local-use builds clearly labeled;
- keep release assets predictable;
- keep SHA-256 checksums visible;
- avoid bundling model weights, caches, logs, settings, secrets, or user-specific paths;
- keep release notes explicit about asset type and pre-release status.

## Distribution Options

### Unsigned zip

Current behavior.

Allowed:

- zip contains only `MLXServerManager.app`;
- release notes include SHA-256;
- release title and asset name clearly mark unsigned local-use distribution.

Not allowed:

- bundling models, caches, logs, settings, `.env`, tokens, or private user paths;
- presenting unsigned distribution as signed or notarized;
- changing runtime behavior to compensate for distribution limitations.

### Signed zip

Possible future option.

Requires:

- Apple Developer ID Application certificate;
- reproducible signing steps;
- verification steps such as `codesign --verify` and `spctl` checks;
- release notes that identify signed status clearly.

Out of scope for `v6.7.0`.

### Notarized zip

Possible future option.

Requires:

- signed app;
- notarization submission workflow;
- stapling where applicable;
- verification steps;
- credential handling plan that avoids committing secrets or exposing private Apple account data.

Out of scope for `v6.7.0`.

### DMG

Possible future option.

Requires:

- DMG layout plan;
- Applications symlink decision;
- signed/notarized DMG decision;
- clear checksum policy;
- manual install verification on a clean machine or test user account.

Out of scope for `v6.7.0`.

### Installer package

Not recommended for near-term work.

A package installer adds complexity and should only be considered if the app later needs privileged helpers, background agents, launch services configuration, or system-level installation. None of those are current requirements.

## Release Asset Naming

Use predictable names:

```text
MLXServerManager-vX.Y.Z-unsigned.zip
MLXServerManager-vX.Y.Z-signed.zip
MLXServerManager-vX.Y.Z-notarized.zip
MLXServerManager-vX.Y.Z.dmg
```

Do not use ambiguous names such as:

```text
latest.zip
release.zip
MLXServerManager.zip
```

Asset naming failure cases:

- `signed.zip` name for an unsigned zip;
- `notarized.zip` name for a signed-only zip;
- docs-only release with an attached app binary;
- source archive referenced as the app download;
- checksum copied from a previous binary asset;
- release title implying a binary replacement when no binary is produced.

## Required Release Settings Block

GitHub Release notes should continue to include:

```text
Tag:
Title:
Asset:
Pre-release:
```

Release body verification should confirm these sections are present:

```text
## Release Settings
## Summary
## Changed
## Asset
## Preserved Behavior
## Boundaries
## Verification
```

Docs-only releases should explicitly state:

```text
Asset: No new app binary; current binary remains <previous app asset>
```

## Install Documentation Plan

A future README install section refresh should cover:

- which release asset to download;
- how to distinguish docs-only releases from app-code releases;
- how to verify the SHA-256 checksum;
- how to unzip the app;
- where to place the app;
- what unsigned local-use distribution means;
- what to do when macOS warns about an unsigned app;
- how to confirm the app version from GitHub Release context;
- how to avoid downloading source archives when the user wants the app binary.

The install section should not imply that unsigned builds are signed, notarized, or Apple-verified.

## Packaging Safety Checklist

Before publishing any binary asset, verify:

- the app launches locally;
- `git diff --check` passes;
- Debug build passes;
- tests pass;
- Release build passes;
- zip or DMG contains expected app entries only;
- no `.dSYM` is bundled unless intentionally published as a separate debug symbol asset;
- no `.env`, token, secret, model weight, cache, log, setting, or user-specific path is bundled;
- SHA-256 is calculated and included in release notes;
- release asset name matches signing/notarization status;
- GitHub Release title and release body match the tag.

## Post-Closeout Packaging Checklist

After `v6.15.0`, packaging work should follow this decision order:

1. Use signed zip distribution only when Developer ID signing is ready.
2. Use packaging checklist polish when signing is not ready.
3. Keep docs-only releases explicit about the current public binary.
4. Do not publish a binary asset from a docs-only release.
5. Do not use signed or notarized asset names unless verification actually passed.

For any docs-only packaging release, record:

```text
Asset: No new app binary; current binary remains MLXServerManager-v6.5.1-unsigned.zip
Signing status: Not executed
Notarization status: Not submitted
Stapling status: Not applicable
```

## Binary Release Go / No-Go

Proceed with a binary release only if:

- Release build succeeds;
- app launch is checked locally;
- test results are recorded;
- asset name matches unsigned, signed, or notarized state;
- final archive contents are checked;
- SHA-256 is recorded;
- release notes state exactly whether the asset replaces the current public binary.

Do not proceed if:

- the release scope is docs-only;
- asset status cannot be stated accurately;
- forbidden entries are present;
- signing or notarization status is unclear;
- the archive contains source files instead of the app bundle;
- the release notes body does not include the required release settings block.

## Manual Packaging Verification Notes

For any later app-code release with a binary asset, manually record:

- local app launch result;
- zip or DMG path;
- asset size;
- SHA-256;
- top-level archive entries;
- forbidden-entry scan result;
- signing status;
- notarization status;
- release URL;
- whether the asset replaces the current downloadable binary.

## Signing / Notarization Safety Checklist

Before implementing signed or notarized distribution, define:

- where certificates live;
- how signing identity is selected;
- how notarization credentials are provided;
- how secrets are excluded from Git;
- how local and CI flows differ;
- how failures are reported;
- how release notes distinguish unsigned, signed, and notarized builds;
- how the current unsigned local-use path remains available or is deprecated.

## Explicit Non-Goals for v6.7.0

`v6.7.0` does not:

- create a new app binary;
- create a signed app;
- run notarization;
- create a DMG;
- create an installer package;
- add auto-update behavior;
- add release automation;
- change runtime behavior;
- change Direct Mode;
- add telemetry;
- add background monitoring;
- add model download;
- add model deletion;
- add model scanning;
- clean caches;
- alter app persistence.

## Next Implementation Candidates

After this readiness review, safe follow-up releases may include:

1. README install section refresh.
2. Manual packaging checklist polish.
3. Signed distribution design.
4. Notarization workflow design.
5. DMG design.
6. Automated release workflow design.

Any actual signed/notarized/DMG implementation should be scoped separately and should not be bundled into an unrelated UI or runtime release.

## Packaging Checklist Polish Acceptance

`v6.16.0` and `v6.16.1` are acceptable if:

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
- the next real binary release remains explicitly scoped.

## Release Acceptance

`v6.7.0`, `v6.7.1`, and `v6.16.0` are acceptable if:

- it remains docs-only;
- no Swift source files are changed;
- no runtime behavior changes are introduced;
- no app binary zip is produced;
- no signing, notarization, DMG, or installer workflow is executed;
- release notes state that the current binary remains `v6.5.1`;
- future distribution work is scoped explicitly before implementation.
