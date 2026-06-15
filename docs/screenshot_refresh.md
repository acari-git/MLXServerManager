# Screenshot Refresh

## Overview

Screenshot Refresh is a v2.1.0 docs-only planning step for updating public README screenshots to match the v1.9+ UI.

This step does not add image files and does not change the app. Existing README screenshot links should remain unchanged until refreshed image files are actually committed.

## Goals

- Plan a small screenshot set that explains the current public feature set.
- Show Direct Mode server management without implying proxy, Chat UI, or multi-backend behavior.
- Make Connection Settings Current Target, External Server Detection, Adopted External Server, and Advanced Launch Options visible.
- Keep screenshots safe for a public repository.
- Avoid exposing personal paths, real API keys, tokens, private repositories, or local shell history.

## Non-goals

- Do not add new screenshot image files in this planning step.
- Do not update README to point at missing files.
- Do not change Swift code, Xcode settings, app binaries, or release assets.
- Do not add Chat UI, Proxy mode, or multi-backend wrapper screenshots.
- Do not imply MLX Server Manager owns external processes.
- Do not show external process kill, stop, or restart behavior.

## Screenshot Inventory

Current committed screenshots:

- `screenshots/main-window.png`
- `screenshots/advanced-launch-options.png`
- `screenshots/main-dashboard-v2.2.png`
- `screenshots/connection-settings-current-target-v2.2.png`
- `screenshots/adopted-external-server-v2.2.png`

v2.2.0 adds the three v2.2 screenshots above and publishes them in the README.

The v2.2.0 screenshot refresh follows the privacy checklist: no real API keys, tokens, private paths, personal home paths, private repository URLs, or app binary artifacts are added.

## Recommended Screenshot Set

Recommended future screenshots:

- Main dashboard.
- Connection Settings / Current Target summary.
- External Server Detected.
- Adopted External Server.
- Advanced Launch Options.
- Logs / diagnostics panel, if useful and safe.

## Capture Scenarios

### Managed Server Running

- App-managed server is running.
- Status clearly indicates a managed process.
- Memory and logs are visible only if they do not expose private paths or sensitive runtime details.
- Stop and Restart are visible as managed-process actions.

### Connection Settings Current Target

- Target Type is visible.
- Base URL is visible.
- Model ID is visible.
- API key placeholder is visible.
- Ownership note is visible.
- Direct Mode note is visible.

Recommended values:

- Host: `127.0.0.1`
- Port: `8080`
- API key placeholder: `not-required-local`

### External Server Detected

- External OpenAI-compatible server was detected via `/v1/models`.
- Adopt External Server button is visible.
- Stop and Restart are unavailable for the external server.
- Wording clearly says the server is not managed by MLX Server Manager.

### Adopted External Server

- Adopted External Server state is visible.
- `Connection context only` note is visible.
- `Not managed by MLX Server Manager` is visible.
- Forget External Server button is visible.
- Stop and Restart remain unavailable for the external server.

### Advanced Launch Options

- Advanced options disclosure is open.
- Optional fields are visible.
- Command preview is visible.
- Copy Preview and Clear Advanced Options are visible if they fit naturally.
- No personal paths, secrets, tokens, or private command arguments are visible.

### Logs / Diagnostics

- Diagnostics summary is visible.
- Logs show generic app-side events only.
- Avoid showing local executable paths, personal home directories, shell history, private URLs, or sensitive model cache paths.

## Privacy and Redaction Checklist

Before committing screenshots, confirm:

- No real API keys.
- No Hugging Face tokens.
- No GitHub tokens.
- No private paths.
- No personal user home path.
- No local shell history.
- No private repository URLs.
- Model IDs are public or intentionally shown.
- Host is preferably `127.0.0.1`.
- Port can be `8080`.
- API key placeholder is `not-required-local`.
- Logs do not reveal secrets or private local context.
- Screenshots do not imply Chat UI, Proxy mode, or multi-backend routing.

## File Naming Convention

Use descriptive names with the target UI version:

- `screenshots/main-dashboard-v2.1.png`
- `screenshots/connection-settings-current-target-v2.1.png`
- `screenshots/external-server-detected-v2.1.png`
- `screenshots/adopted-external-server-v2.1.png`
- `screenshots/advanced-launch-options-v2.1.png`

Use lowercase words separated by hyphens. Avoid local machine names, user names, dates, or temporary labels in filenames.

## README Placement Plan

Keep existing screenshots until refreshed image files are actually committed.

Once refreshed screenshots are available:

- Put the primary main dashboard screenshot near the top.
- Put the Connection Settings screenshot near the feature or Supported Client Context section.
- Put External Server Detected and Adopted External Server screenshots near the external server explanation.
- Put Advanced Launch Options screenshot near the Advanced Launch Options section.
- Do not link to missing files.

## Release Workflow

Suggested workflow for the later screenshot update:

1. Capture screenshots from a clean local demo state.
2. Save files under `screenshots/` using the naming convention above.
3. Review each image for secrets, personal paths, and misleading UI state.
4. Update README links only after files exist.
5. Run repository safety checks.
6. Commit screenshots and README/docs updates together.

No app binary, zip asset, or release asset is required unless a later release specifically chooses to include the screenshot docs update.

## Testing / Review Checklist

- Existing README screenshot links still point to committed files.
- New README links are added only after new screenshot files are committed.
- Screenshot filenames match the naming convention.
- Screenshots show Direct Mode clearly.
- Screenshots do not imply the app proxies inference requests.
- Screenshots do not show Chat UI.
- Screenshots do not imply multi-backend wrapper behavior.
- External server screenshots show not-managed wording.
- Adopted external screenshots show connection-context-only wording.
- No secrets, personal paths, tokens, or private URLs appear.
- No `.app`, `.zip`, `.dSYM`, DerivedData, model files, settings files, or logs are committed.

## Future Work

- Capture the v1.9+ Connection Settings Current Target UI.
- Capture External Server Detected and Adopted External Server states.
- Refresh the README primary screenshot when the new image is available.
- Consider a compact screenshot collage only if it remains readable in GitHub README.
