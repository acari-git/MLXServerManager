# Signed Zip Dry-Run Checklist

## Release

- Added in `v6.13.0`.
- Polished in `v6.13.1` with pass/fail criteria, evidence expectations, and stop conditions.
- Docs-only dry-run checklist for a future signed zip release.
- Follows `v6.11.0` / `v6.11.1` Signed Zip Implementation Readiness and `v6.12.0` / `v6.12.1` Local Signing Command Draft.
- No new app binary is produced for this release.

## Purpose

`v6.13.0` defines a dry-run checklist for future signed zip distribution work before any real signed binary is published.

The dry run should prove that the release owner can build, inspect, sign conceptually, verify, package, checksum, and document a signed zip workflow without uploading a new app asset or changing runtime behavior.

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

These releases do not replace the current app binary.

## Dry-Run Scope

The dry run may verify planning and local commands, but it must not publish a new app asset.

Allowed dry-run actions:

- inspect repository state;
- build locally if explicitly scoped as a local-only dry run;
- inspect the app bundle locally;
- verify expected packaging paths;
- draft signing command shape with placeholders;
- record verification notes;
- validate release notes structure;
- confirm fallback policy.

Disallowed dry-run actions for this docs-only release:

- upload a signed app zip;
- publish a new app binary;
- run real signing as part of the release;
- run notarization;
- staple a ticket;
- create a DMG;
- create an installer;
- add release automation;
- change Swift source files;
- change app runtime behavior.

## Dry-Run Pass / Fail Criteria

Pass only if:

- repository state is clean;
- release scope remains docs-only or explicitly local-only;
- no binary upload is planned;
- no private signing or Apple account values are recorded;
- release notes structure is complete;
- fallback policy is selected before any real signed release.

Fail if:

- an app asset would be uploaded from the dry run;
- real signing or notarization is required to complete the dry run;
- credentials would appear in docs, logs, or release notes;
- zip naming does not match the actual verification state;
- runtime behavior changes are included.

## Checklist

### 1. Repository State

Confirm:

```text
git status --short: clean
branch: main
HEAD matches origin/main
release tag does not already exist
```

Record:

```text
Branch:
HEAD:
origin/main:
Existing tag check:
```

### 2. Release Scope

Confirm:

- release is docs-only unless explicitly converted to a signed zip implementation release;
- no app-code changes are included;
- no new app binary will be attached;
- current downloadable binary remains `v6.5.1`;
- Direct Mode remains unchanged.

### 3. Build Path Planning

Confirm the intended future Release build path:

```text
DerivedData:
Release app path:
Expected app bundle name:
```

Do not publish build output from this docs-only dry run.

### 4. Signing Placeholder Planning

Confirm placeholders only:

```text
SIGNING_IDENTITY="Developer ID Application: <Team or Developer Name> (<TEAMID>)"
```

Do not record real certificate names, Apple account identifiers, app-specific passwords, notary profiles, keychain paths, or private credentials in public docs or release notes.

### 5. Zip Naming Plan

Confirm future asset naming:

```text
Unsigned zip: MLXServerManager-vX.Y.Z-unsigned.zip
Signed zip: MLXServerManager-vX.Y.Z-signed.zip
Notarized zip: MLXServerManager-vX.Y.Z-notarized.zip
```

The asset name must match the actual verification state.

### 6. Forbidden Entries

Future zip verification should reject:

- `__MACOSX`;
- `.dSYM` unless separately published;
- `.env`;
- `HF_TOKEN`;
- Apple credentials;
- certificates;
- private keys;
- keychain exports;
- `.safetensors`;
- `.gguf`;
- `.bin`;
- `/models/`;
- `/logs/`;
- `.venv`;
- hidden resource fork files;
- unrelated build products.

### 7. Release Notes Structure

Future release notes should include:

```text
## Release Settings
## Summary
## Changed
## Asset
## Preserved Behavior
## Boundaries
## Verification
```

Signed or notarized binary releases should also include:

```text
Signing status:
Notarization status:
Stapling status:
SHA-256:
```

### 8. Fallback Decision

Choose one before a real signed release:

- keep docs-only if signing is not ready;
- publish unsigned-only if signing identity is unavailable;
- publish signed-only if signing passes and notarization is out of scope;
- publish notarized only after notarization and stapling are verified.

Do not publish an asset with a more trusted name than its actual state.

## Evidence Expectations

A dry run may record:

- git status summary;
- intended release scope;
- planned asset name;
- planned signing status;
- planned notarization status;
- release notes section check;
- fallback policy;
- explicit `Binary upload planned: No` value.

A dry run must not record:

- certificate names if they are private;
- Apple account identifiers;
- app-specific passwords;
- notary profiles;
- keychain paths;
- private local paths beyond generic placeholders.

## Dry-Run Log Template

Use this local-only log:

```text
Release candidate:
Branch:
Commit:
Scope:
Build planned:
Signing planned:
Notarization planned:
Asset planned:
Fallback policy:
Release notes structure checked:
Binary upload planned:
```

For this release, `Binary upload planned` must be `No`.

## Stop Conditions

Stop the dry run if:

- repository state is not clean;
- release scope is unclear;
- signing identity handling is unclear;
- private credential values would be exposed;
- any generated archive contains forbidden entries;
- release notes cannot clearly state the asset and status;
- Direct Mode boundaries would be changed.

## Direct Mode Boundary

Signed zip dry-run work does not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Future Implementation Candidates

After this checklist, safe follow-up releases may include:

1. Signed zip dry-run checklist polish.
2. Signed zip local dry-run execution notes.
3. Signed zip app-code release.
4. README install update for signed assets.
5. Notarized zip implementation after signed zip distribution is stable.

## Release Acceptance

`v6.13.0` and `v6.13.1` are acceptable if:

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
- future signed zip dry-run work remains separate from real signed binary publishing.
