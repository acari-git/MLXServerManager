# Local Signing Command Draft

## Release

- Added in `v6.12.0`.
- Docs-only local signing command draft.
- Follows `v6.11.0` / `v6.11.1` Signed Zip Implementation Readiness.
- No new app binary is produced for this release.

## Purpose

`v6.12.0` drafts the local command sequence for a future signed zip release without executing signing or changing release packaging.

This document is intentionally a draft. It defines command shape, placeholders, verification points, and safety boundaries before any real signing implementation is added.

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

These releases do not replace the current app binary.

## Placeholders

Use placeholders until an actual signing release is explicitly scoped:

```text
VERSION=vX.Y.Z
APP_NAME=MLXServerManager
SCHEME=MLXServerManager
PROJECT=MLXServerManager.xcodeproj
DERIVED_DATA=/tmp/MLXServerManagerReleaseDerivedData
APP_PATH=/tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app
SIGNED_ZIP=/tmp/MLXServerManager-vX.Y.Z-signed.zip
SIGNING_IDENTITY="Developer ID Application: <Team or Developer Name> (<TEAMID>)"
```

Do not commit real certificate names, keychain details, Apple account identifiers, app-specific passwords, or notary profiles unless they are intentionally documented as placeholders.

## Draft Command Sequence

A future signed zip release may use this sequence after the release scope is approved.

### 1. Confirm clean repository state

```sh
git status --short
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
git rev-parse --short origin/main
```

Expected:

- branch is `main`;
- local HEAD matches `origin/main` before release work begins;
- no unrelated local changes are present.

### 2. Build Release app

```sh
rm -rf "$DERIVED_DATA"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected:

- Release build succeeds;
- app bundle exists at `$APP_PATH`;
- the build remains unsigned at this stage.

### 3. Verify pre-signing app bundle

```sh
test -d "$APP_PATH"
find "$APP_PATH" -maxdepth 3 -type f | sort
```

Check for unexpected files before signing.

### 4. Sign app bundle

```sh
codesign \
  --force \
  --deep \
  --options runtime \
  --sign "$SIGNING_IDENTITY" \
  "$APP_PATH"
```

This command is a draft. A future implementation should verify whether `--deep` is appropriate for the final app bundle structure before use.

### 5. Verify signature

```sh
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --display --verbose=4 "$APP_PATH"
```

Expected:

- verification succeeds;
- displayed identity matches the release notes;
- no private credential details are copied into release notes.

### 6. Optional local assessment

```sh
spctl --assess --type execute --verbose=4 "$APP_PATH"
```

Record result if used. Do not overstate this as notarization.

### 7. Create signed zip

```sh
rm -f "$SIGNED_ZIP"
cd "$(dirname "$APP_PATH")"
ditto -c -k --norsrc --noextattr --keepParent "$(basename "$APP_PATH")" "$SIGNED_ZIP"
```

Expected:

- zip contains exactly `MLXServerManager.app` and its expected bundle contents;
- no source archive or unrelated build output is included.

### 8. Verify zip contents

```sh
zipinfo -1 "$SIGNED_ZIP"
```

Forbidden-entry scan should check for:

```text
__MACOSX
.dSYM
.env
HF_TOKEN
.safetensors
.gguf
.bin
/models/
/logs/
.venv
._
```

### 9. Calculate checksum

```sh
shasum -a 256 "$SIGNED_ZIP"
```

Record the hash in release notes.

### 10. Release metadata

Release notes should include:

```text
Tag:
Title:
Asset:
Pre-release:
Signing status:
Notarization status:
SHA-256:
```

For a signed-only release:

```text
Signing status: Developer ID signed
Notarization status: Not submitted
```

## Required Safety Boundaries

A future signing command implementation must not:

- commit certificates;
- commit private keys;
- commit Apple credentials;
- commit app-specific passwords;
- commit notary profiles;
- commit keychain exports;
- embed model files;
- embed logs;
- embed settings files;
- embed user-specific paths;
- change app runtime behavior;
- add telemetry;
- add background monitoring;
- add proxying;
- add request inspection.

## Verification Log Template

Use this compact log for a future signed zip release:

```text
Release:
Commit:
Asset:
Signing status:
Notarization status:
Signature verification:
Gatekeeper assessment:
Zip contents:
Forbidden entries:
SHA-256:
Release URL:
```

Keep private credential details out of this log.

## Fallback Rules

If build fails:

- do not sign;
- do not publish a binary;
- keep the release docs-only or fix the build first.

If signing fails:

- do not publish a signed asset;
- keep current downloadable binary unchanged;
- document the failure privately if needed.

If signature verification fails:

- do not publish the asset;
- repeat from a clean build or signing step.

If zip verification fails:

- do not publish the asset;
- fix packaging and re-check contents.

## Direct Mode Boundary

Local signing commands do not change the app architecture:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

The app remains a control and context surface. It must not become part of the inference request path.

## Future Implementation Candidates

After this draft, safe follow-up releases may include:

1. Local Signing Command Polish.
2. Signed zip dry-run checklist.
3. Signed zip app-code release.
4. README install update for signed assets.
5. Notarized zip implementation after signed zip distribution is stable.

## Release Acceptance

`v6.12.0` is acceptable if:

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
- future signing commands remain placeholders until explicitly scoped.
