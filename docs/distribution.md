# Distribution

## Purpose

This document describes the v0.9 distribution policy for packaging an unsigned Release build of MLX Server Manager as a `.zip` file and attaching it to a GitHub Release.

The distribution target is local personal use. The app remains Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

The zip is a packaging artifact only. It must not include runtime settings, model profiles, model files, Hugging Face cache, logs, or secrets.

## Release Asset Policy

GitHub Release assets may include:

- `MLXServerManager-<version>-unsigned.zip`

The zip should contain:

- `MLXServerManager.app`

The zip must not contain:

- `settings.json`
- `models.json`
- model files
- model directories
- Hugging Face cache
- `.env`
- `HF_TOKEN`
- logs
- derived data
- `.dSYM`
- source checkout files

The `.app`, `.zip`, `.dSYM`, and derived data must not be committed to Git.

## Unsigned Build Caveats

The v0.9 asset policy is for an unsigned local-use build.

Users should be told:

- The app is not notarized.
- The app is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- Downloaded zip files may carry quarantine attributes.
- The user is responsible for deciding whether to run the app.
- Formal public distribution should use Developer ID signing and notarization in a future version.

Do not describe the unsigned zip as a fully notarized or formally distributed macOS app.

## Build Command

Create a Release build:

```sh
xcodebuild \
  -project MLXServerManager.xcodeproj \
  -scheme MLXServerManager \
  -configuration Release \
  -derivedDataPath /tmp/MLXServerManagerReleaseDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected app path:

```text
/tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app
```

This path is an example temporary DerivedData location, not a user-specific fixed path.

### Verified v0.9 Build Result

The v0.9 packaging verification confirmed:

- Release build result: `BUILD SUCCEEDED`
- App path: `/tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app`
- App size: `1.1M`

## Zip Creation

Create a zip that keeps the `.app` bundle as the parent item:

```sh
cd /tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release
ditto -c -k --norsrc --noextattr --keepParent \
  MLXServerManager.app \
  /tmp/MLXServerManager-v0.9.0-unsigned.zip
```

Use `--norsrc --noextattr` so the zip does not include AppleDouble `._*` metadata files.
Do not use only `ditto -c -k --keepParent`; without `--norsrc --noextattr`, AppleDouble `._*` metadata files may be included.

For a future release, replace `v0.9.0` with the release version.

## Zip Verification

Confirm the zip contents:

```sh
unzip -l /tmp/MLXServerManager-v0.9.0-unsigned.zip
```

Expected result:

- The archive contains `MLXServerManager.app/`.
- The archive does not contain runtime settings.
- The archive does not contain model files.
- The archive does not contain `.dSYM` or derived data.
- The archive does not contain AppleDouble `._*` metadata files.

Confirm the zip size:

```sh
du -h /tmp/MLXServerManager-v0.9.0-unsigned.zip
```

The v0.9 packaging verification confirmed:

```text
284K /tmp/MLXServerManager-v0.9.0-unsigned.zip
```

Confirm release artifacts are not tracked by Git:

```sh
git ls-files \
  '*.app' \
  '*.zip' \
  '*.dSYM' \
  settings.json \
  models.json \
  '*.safetensors' \
  '*.gguf' \
  '*.bin' \
  '.env' \
  HF_TOKEN \
  models \
  logs \
  .venv
```

The command should not list generated app bundles, zip files, runtime settings, secrets, or model files.

### Verified v0.9 Zip Contents

The v0.9 zip verification confirmed that the archive contained only entries under:

```text
MLXServerManager.app/
```

The zip did not include:

- `settings.json`
- `models.json`
- model files
- model directories
- `.env`
- `HF_TOKEN`
- `.dSYM`
- DerivedData
- Hugging Face cache
- logs
- AppleDouble `._*` metadata files

## Local Launch Verification After Unzip

Manual verification should use a temporary location:

1. Unzip the asset into a temporary folder.
2. Confirm `MLXServerManager.app` exists.
3. Launch the app with `open -n`.
4. Confirm the app starts.
5. Confirm the menu bar item appears.
6. Confirm the main window opens.
7. Confirm runtime settings are not bundled in the zip.
8. Configure `mlx_lm.server executable path` in the app UI if needed.
9. Run Setup Diagnostics if local runtime settings are available.
10. Quit the app normally.

This launch verification must not require model inference and must not require `/v1/chat/completions`.

### Verified v0.9 Launch Result

The v0.9 packaging verification confirmed:

- The zip was unzipped under `/tmp`.
- `open -n` launched the unzipped `MLXServerManager.app`.
- The launched app process was observed.
- The verification process was terminated after the check.
- No verification process was left running.
- Git status remained clean after build, zip creation, unzip, launch, and quit checks.

## Release Note Template

Use release notes similar to:

```text
MLX Server Manager <version>

Asset:
- MLXServerManager-v0.9.0-unsigned.zip

Notes:
- This is an unsigned local-use macOS app bundle.
- The app is not notarized and is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- The zip contains only MLXServerManager.app.
- Runtime settings, model profiles, model files, Hugging Face cache, logs, and secrets are not included.
- Configure mlx_lm.server executable path in the app UI after launch.
- Direct Mode is unchanged: OpenAI-compatible client -> mlx_lm.server.
- The app does not proxy inference traffic and does not provide Chat UI.
- Ready checks use /v1/models. The app does not send /v1/chat/completions.
```

### v1.0 Release Note Template

Use release notes similar to:

```text
MLX Server Manager v1.0.0

Asset:
- MLXServerManager-v1.0.0-unsigned.zip

Stable scope:
- Direct Mode: OpenAI-compatible client -> mlx_lm.server.
- Start, Stop, and Restart for the app-managed mlx_lm.server process.
- Port Check and Ready Check via /v1/models.
- Settings save and restore.
- Model profile add, edit, delete, and switching with Restart required.
- Setup Diagnostics and diagnostics summary copy.
- Readable Logs and Copy Logs.
- Menu bar quick actions.
- OpenAI-compatible connection settings copy.

Known limitations:
- This is an unsigned local-use macOS app bundle.
- The app is not notarized and is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- The app does not bundle mlx-lm, model files, Hugging Face cache, runtime settings, logs, or secrets.
- Users must configure mlx_lm.server executable path in the app UI.
- The app does not proxy inference traffic, does not provide Chat UI, and does not execute /v1/chat/completions.

Safety:
- Stop and Restart target only the process started by this app.
- External mlx_lm.server processes are not stopped.
- Runtime settings, model profiles, model files, Hugging Face cache, logs, secrets, .app bundles, zip files, dSYM files, and build artifacts are not included in Git.
```

## Non-Goals

- Notarization.
- Developer ID signing.
- DMG creation.
- Sparkle or other automatic updates.
- CI/CD.
- GitHub Actions.
- App Store distribution.
- Homebrew cask.
- Installer creation.
- Runtime settings bundling.
- Model file bundling.
- Hugging Face cache bundling.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- Hugging Face download manager.
- Model download.
- Model file deletion.
- Multiple simultaneous server management.
