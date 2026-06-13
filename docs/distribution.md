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

## Zip Creation

Create a zip that keeps the `.app` bundle as the parent item:

```sh
ditto -c -k --keepParent \
  /tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app \
  /tmp/MLXServerManager-<version>-unsigned.zip
```

Replace `<version>` with the release version, such as `v0.9.0`.

## Zip Verification

Confirm the zip contents:

```sh
unzip -l /tmp/MLXServerManager-<version>-unsigned.zip
```

Expected result:

- The archive contains `MLXServerManager.app/`.
- The archive does not contain runtime settings.
- The archive does not contain model files.
- The archive does not contain `.dSYM` or derived data.

Confirm the zip size:

```sh
du -h /tmp/MLXServerManager-<version>-unsigned.zip
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

## Release Note Template

Use release notes similar to:

```text
MLX Server Manager <version>

Asset:
- MLXServerManager-<version>-unsigned.zip

Notes:
- This is an unsigned local-use macOS app bundle.
- The app is not notarized and is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- The zip contains only MLXServerManager.app.
- Runtime settings, model profiles, model files, Hugging Face cache, logs, and secrets are not included.
- Configure mlx_lm.server executable path in the app UI after launch.
- Direct Mode is unchanged: OpenAI-compatible client -> mlx_lm.server.
- The app does not proxy inference traffic and does not provide Chat UI.
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
