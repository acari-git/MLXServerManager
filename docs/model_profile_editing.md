# Model Profile Editing

Model profile editing is the planned v0.3 feature for editing the selected model configuration from the app UI.

The feature expands the existing `ModelConfig` persistence flow while preserving Direct Mode.

## Goals

- Allow editing the selected model profile.
- Persist edits to `models.json`.
- Keep Start, Diagnostics, Connection Settings, and copy actions aligned with the saved profile.
- Prevent invalid model profile values from being saved.
- Avoid confusing edits while a managed server is running.

## Editable Fields

The v0.3 editor should support:

- `modelID`
- `displayName`
- `host`
- `serverPort`
- `enableThinking`
- `notes`

Fields not listed here, such as `family`, `quantization`, and `localName`, can remain read-only or be deferred unless they are needed for a clean UI.

## Validation

Validation should happen before saving:

- `modelID` is required.
- `host` is required.
- `serverPort` must be a number between 1 and 65535.
- Whitespace-only `modelID` or `host` values are invalid.

Invalid data must not be written to `models.json`.

Recommended validation messages:

- `Model ID is required.`
- `Host is required.`
- `Port must be between 1 and 65535.`

Validation results should be visible in the UI and written to Logs.

## Save and Cancel

Use an editable draft state instead of writing directly into the saved model on every keystroke.

Recommended flow:

1. User selects a model.
2. ViewModel creates a draft from the selected `ModelConfig`.
3. User edits draft fields.
4. User clicks `Save Profile`.
5. App validates the draft.
6. If valid, app updates the model list and saves `models.json`.
7. If invalid, app keeps the draft and shows validation messages.
8. User can click `Cancel` to return to the last saved values.

## Connection Settings Refresh

After saving valid edits:

- Base URL should reflect edited `host` and `serverPort`.
- Copy Base URL should reflect the new base URL.
- Copy Model ID should reflect edited `modelID`.
- Copy OpenAI-compatible config should reflect edited values.
- Copy `curl /v1/models` should reflect edited host and port.
- Copy `curl /v1/chat/completions` should reflect edited host, port, and model ID.

The app must still treat `/v1/chat/completions` as copied example text only.

## Start Behavior

Start should use the saved profile values:

- edited `modelID`
- edited `host`
- edited `serverPort`

Profile editing itself must not start `mlx_lm.server`.

## Running Process Guard

When a managed process is running, editing runtime-affecting fields can be misleading.

Runtime-affecting fields:

- `modelID`
- `host`
- `serverPort`

Safer v0.3 behavior:

- Disable runtime-affecting fields while a managed process is running.
- Show a concise message that these fields can be edited after Stop.
- Allow non-runtime metadata edits only if the UI clearly communicates that the running server is unchanged.

Alternative behavior:

- Allow saving while running.
- Show `Restart required` before the running server uses the new values.

The safer default for v0.3 should be disabling runtime-affecting fields while running.

## Non-Goals

- Adding multiple model profiles.
- Deleting model profiles.
- Multiple simultaneous server management.
- Hugging Face download manager.
- Model file deletion.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- Running `/v1/chat/completions` from the app.

## Repository Hygiene

Edited model profiles are local runtime settings. `models.json`, `settings.json`, model files, logs, `.env`, and `HF_TOKEN` must not be committed.

Documentation and code must not hardcode user-specific absolute paths.

## Manual Verification

Manual tests should cover:

- Open `Edit Profile` from the selected model detail area.
- Change `displayName` and click `Save Profile`.
- Change `modelID` and click `Save Profile`.
- Change `host` and click `Save Profile`.
- Change `serverPort` and click `Save Profile`.
- Toggle `enableThinking` on and off, then click `Save Profile`.
- Edit `notes` and click `Save Profile`.
- Leave `displayName` empty and confirm the saved value is filled with `modelID`.
- Leave `modelID` empty and confirm save fails.
- Leave `host` empty and confirm save fails.
- Set `serverPort` to `0` and confirm save fails.
- Set `serverPort` to `65536` and confirm save fails.
- Set `serverPort` to `abc` and confirm save fails.
- Change fields and click `Cancel`, then confirm changes are not saved.
- Confirm save failures are shown in the editor and written to Logs.
- Confirm saved edits appear in Model detail.
- Confirm Connection Settings reflect saved `host`, `serverPort`, and `modelID`.
- Confirm Copy Base URL reflects saved `host` and `serverPort`.
- Confirm Copy Model ID reflects saved `modelID`.
- Confirm Copy OpenAI-compatible config reflects saved values.
- Confirm Copy `curl /v1/models` reflects saved `host` and `serverPort`.
- Confirm Copy `curl /v1/chat/completions` reflects saved `host`, `serverPort`, and `modelID`.
- Change `serverPort`, save, and confirm Start launches on the new port.
- Stop the managed server and confirm the port is released.
- Restore the original port after Stop and confirm it can be saved.
- While the managed server is running, confirm `modelID`, `host`, and `serverPort` changes are blocked.
- While the managed server is running, confirm `displayName`, `enableThinking`, and `notes` can still be saved.
- Confirm Start, Stop, and Restart still work after profile edits.
- Confirm saved edits persist after app restart.
- Confirm edits are written to local `models.json`.
- Confirm `models.json` is not included in Git status or commits.
- Confirm editing does not call `/v1/chat/completions`.
- Confirm editing does not run inference.
- Confirm editing does not launch `mlx_lm.server`.
- Confirm editing does not stop external processes.
- Confirm editing does not use `pkill`, `killall`, or `pgrep`.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm documentation and code do not include user-specific fixed paths.
