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

- Edit `modelID` and save.
- Edit `displayName` and save.
- Edit `host` and save.
- Edit `serverPort` and save.
- Toggle `enableThinking` and save.
- Edit `notes` and save.
- Cancel edits and confirm saved values are restored.
- Confirm empty `modelID` cannot be saved.
- Confirm empty `host` cannot be saved.
- Confirm invalid port cannot be saved.
- Confirm saved edits persist after app restart.
- Confirm Connection Settings and copy actions reflect saved edits.
- Confirm Start uses saved `modelID`, `host`, and `serverPort`.
- Confirm runtime-affecting fields are guarded while a managed process is running.
- Confirm editing does not call `/v1/chat/completions`.
- Confirm editing does not run inference.
- Confirm editing does not launch `mlx_lm.server`.
- Confirm editing does not stop external processes.
