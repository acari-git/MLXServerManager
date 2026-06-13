# Distribution Build

This document describes the planned v0.5 distribution build guidance for MLX Server Manager.

The first target is local personal use on the user's own Mac. v0.5 documents the workflow and caveats; it does not add automated packaging, notarization, or formal release automation.

## Build Types

### Debug Build

Use Debug builds while developing or manually verifying behavior in Xcode.

Debug builds are suitable for:

- Local development.
- Manual UI verification.
- Checking logs and runtime behavior.
- Iterating on SwiftUI views and services.

### Release Build

Use Release builds when preparing a local app bundle for regular personal use.

Release builds are suitable for:

- Running a more optimized local app.
- Checking that the app starts outside the Xcode Run workflow.
- Preparing a candidate `.app` bundle for a local archive or possible GitHub Release asset.

## Xcode Manual Build

Planned manual workflow:

1. Open `MLXServerManager.xcodeproj` in Xcode.
2. Select the `MLXServerManager` scheme.
3. Choose a macOS destination such as `My Mac`.
4. Select Debug or Release configuration as needed.
5. Build the app from Xcode.
6. Locate the generated `.app` in Xcode's build products.
7. Launch the app locally.
8. Configure `mlx_lm.server executable path` in the app UI.
9. Confirm Start, Ready Check, Stop, and Menu bar quick actions work.

Do not write user-specific absolute paths into source code or committed documentation.

## CLI Build

Example Debug build:

```sh
xcodebuild \
  -project MLXServerManager.xcodeproj \
  -scheme MLXServerManager \
  -configuration Debug \
  -derivedDataPath /tmp/MLXServerManagerDerivedData \
  build
```

Example Release build:

```sh
xcodebuild \
  -project MLXServerManager.xcodeproj \
  -scheme MLXServerManager \
  -configuration Release \
  -derivedDataPath /tmp/MLXServerManagerDerivedData \
  build
```

For local compile verification in development environments where signing is not available, `CODE_SIGNING_ALLOWED=NO` may be used:

```sh
xcodebuild \
  -project MLXServerManager.xcodeproj \
  -scheme MLXServerManager \
  -configuration Release \
  -derivedDataPath /tmp/MLXServerManagerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Unsigned builds may not behave like a normal signed app when copied or launched outside the build environment.

### Verified Release Build Command

The following local verification command has been confirmed to finish with `BUILD SUCCEEDED`:

```sh
xcodebuild \
  -project MLXServerManager.xcodeproj \
  -scheme MLXServerManager \
  -configuration Release \
  -derivedDataPath /tmp/MLXServerManagerReleaseDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This is an unsigned local personal-use build check. It is not notarized and is not a formal distribution build.

## App Output Location

With the example derived data path above, the app bundle is expected under:

```text
/tmp/MLXServerManagerDerivedData/Build/Products/<configuration>/MLXServerManager.app
```

Replace `<configuration>` with `Debug` or `Release`.

With the verified Release build command above, the observed app bundle path was:

```text
/tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app
```

The observed app bundle size was:

```text
916K
```

Do not commit `.app` bundles, derived data, or other build artifacts.

## Local Launch Verification

The verified Release app bundle was launched with:

```sh
open -n /tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app
```

The launch check confirmed:

- `open -n` returned successfully.
- `System Events` reported that the `MLXServerManager` process existed after launch.
- The app could be quit normally through the app bundle identifier.
- The final Git status was clean.
- The generated `.app`, build artifacts, `settings.json`, `models.json`, and model files were not tracked by Git.

Window-name inspection through `osascript` is not a required verification step because it may not respond consistently for this app. For v0.5 local Release verification, `open`, process existence, and normal quit are sufficient.

## Runtime Configuration

The app stores runtime configuration under the user's Application Support directory:

- `settings.json`
- `models.json`

These files are local runtime state. They must not be committed and should not be included in release assets.

The `mlx_lm.server` executable path is configured in the app UI. Use placeholders in documentation examples, such as:

```text
<path-to-mlx_lm.server>
```

Do not commit user-specific absolute paths.

## Model Files

Model files are not bundled with MLX Server Manager.

Do not include model directories or model artifact files in Git or release assets. Users should manage model availability through their local MLX setup outside this app.

## Signing, Gatekeeper, and Notarization

For personal local use, a developer may build and run the app on their own Mac from Xcode.

Important caveats:

- A local unsigned or ad-hoc signed `.app` may trigger Gatekeeper warnings when moved between machines.
- `CODE_SIGNING_ALLOWED=NO` Release builds are unsigned local verification builds for personal use.
- Formal public distribution generally requires signing with an Apple Developer Program certificate.
- Notarization is not performed in v0.5.
- DMG or zip packaging is not automated in v0.5.
- GitHub Release assets are not produced in v0.5.
- App Store distribution is out of scope.

During local CLI verification, `xcodebuild` may print non-blocking notes such as multiple destination selection, bitcode strip being skipped without signing, or App Intents metadata extraction being skipped when no App Intents dependency exists. These notes do not change the Release build result when the build ends with `BUILD SUCCEEDED`.

v0.5 should document these constraints without claiming that the app is ready for formal public distribution.

## App Sandbox

App Sandbox is disabled because the app must launch a user-configured local `mlx_lm.server` executable and stop only the process it started.

This permission model should stay narrowly scoped:

- Start uses the executable path configured in the app UI.
- Stop targets only the managed process held by this app.
- External `mlx_lm.server` processes must not be stopped.
- `pkill`, `killall`, and `pgrep` must not be used.

## GitHub Release Asset Policy

v0.5 should prefer documenting the release asset policy before attaching app bundles.

Recommended policy:

- Do not attach model files.
- Do not attach `settings.json` or `models.json`.
- Do not attach derived data.
- If attaching a `.app` bundle later, clearly state signing, Gatekeeper, and notarization status.
- Prefer source release plus local build instructions until signing and packaging are deliberately addressed.

## Local Use Checklist

- Build Debug or Release locally.
- Confirm Release build finishes with `BUILD SUCCEEDED`.
- Confirm the `.app` bundle exists in the build products directory.
- Confirm the `.app` bundle size with `du -sh`.
- Launch the app locally.
- Confirm `open -n` can launch the Release `.app`.
- Confirm the `MLXServerManager` process exists after launch.
- Confirm the app can quit normally.
- Configure `mlx_lm.server executable path` with a local executable path.
- Run Setup Diagnostics.
- Start the managed server.
- Confirm Ready Check uses `/v1/models`.
- Confirm Memory display updates.
- Confirm Stop releases the port.
- Confirm Menu bar quick actions still work.
- Confirm the app does not send `/v1/chat/completions`.
- Confirm no model inference is required for distribution verification.
- Confirm `.app` bundles and build artifacts are not staged or tracked in Git.
- Confirm `settings.json`, `models.json`, and model files are not staged or tracked in Git.
