# Model Profile Management

Model Profile Management is the planned v0.6 feature for adding and deleting saved model profiles in MLX Server Manager.

It builds on v0.3 Model Profile Editing. v0.3 edits the selected profile; v0.6 adds lifecycle operations for the profile list itself.

## Goals

- Add a model profile from the UI.
- Delete a model profile from the UI.
- Save additions and deletions to `models.json`.
- Select the added profile after save.
- Choose a safe fallback selection after delete.
- Prevent deleting the last remaining profile.
- Prevent deleting the running profile while a managed server is active.
- Avoid any file deletion outside `models.json`.

## Non-Goals

- Multiple simultaneous server management.
- Multiple model launches at the same time.
- Model file deletion.
- Hugging Face cache cleanup.
- Hugging Face download manager.
- Model download.
- Automated model existence checks.
- Proxy mode.
- Chat UI.
- LAN Web UI.
- App Intents.
- Auto unload.
- CI/CD.
- Notarization.
- DMG creation.
- App Store distribution.
- Running `/v1/chat/completions` from the app.

## Add Profile Behavior

The recommended v0.6 add flow:

1. User clicks `Add Profile` near the model list.
2. App opens a draft editor.
3. User enters a `modelID` and optional metadata.
4. App validates the draft.
5. App appends the profile to the in-memory list.
6. App saves the updated list to `models.json`.
7. App selects the newly added profile.
8. Connection Settings and copy actions refresh from the selected profile.
9. Logs record success or validation failure.

Recommended draft defaults:

- `modelID`: empty, requiring user input.
- `displayName`: empty until save, then filled with `modelID` if still empty.
- `host`: `127.0.0.1`.
- `serverPort`: app default port, usually `8080`.
- `enableThinking`: `false`.
- `notes`: empty.

Using a blank draft avoids silently duplicating a profile that points to the same model and port. A future version may add `Duplicate Profile` as a separate explicit action.

## Add Validation

Validation should match existing profile editing rules:

- `modelID` must not be empty.
- `host` must not be empty.
- `serverPort` must be an integer from 1 through 65535.
- Empty `displayName` should be replaced with `modelID`.
- `notes` may be empty.
- `enableThinking` must persist as a boolean.

Duplicate `modelID` handling:

- v0.6 should reject duplicate `modelID` values.
- The UI should show a clear validation message.
- Logs should record the validation failure.

This keeps model list behavior predictable until profiles have separate stable IDs.

## Delete Profile Behavior

The recommended v0.6 delete flow:

1. User clicks `Delete Profile` for the selected profile.
2. App checks delete guards.
3. App shows a confirmation dialog.
4. User confirms deletion.
5. App removes only the profile entry from the in-memory list.
6. App saves the updated list to `models.json`.
7. App selects a fallback profile if the deleted profile was selected.
8. Connection Settings and copy actions refresh from the new selection.
9. Logs record success or failure.

Delete must not remove model files, Hugging Face cache, local model directories, logs, or runtime files outside `models.json`.

## Delete Guards

Delete should be blocked when:

- There is only one profile left.
- A managed server is active.
- Saving the updated `models.json` would fail.

v0.6 blocks all profile deletion while a managed server is running. This avoids confusion between the selected UI profile and the runtime profile used by the active managed process.

The UI message should be explicit:

```text
Stop the managed server before deleting profiles.
```

## Selection Fallback

If the selected profile is deleted while no managed process is running, the app should select another profile deterministically:

1. Select the next profile in the list if one exists.
2. Otherwise select the previous profile.
3. Otherwise select the only remaining profile.

The app should never end with no selected profile while profiles exist.

## Running Server Interaction

Adding or deleting profiles must not implicitly start, stop, or restart `mlx_lm.server`.

While a managed server is running:

- Add Profile may be allowed because it does not affect the running process.
- Delete Profile is blocked for all profiles.
- Start, Stop, and Restart continue to use the existing managed process path.
- Stop remains limited to the process held by this app.

## Repository Hygiene

`models.json` is local runtime state and must not be committed.

Do not commit:

- `settings.json`
- `models.json`
- Model files
- Hugging Face cache
- Logs
- `.env`
- `HF_TOKEN`
- `.app` bundles
- Build artifacts

Do not use user-specific absolute paths in docs or source. Use placeholders such as:

```text
<model-id>
<path-to-model>
```

## Manual Test Checklist

### Add Profile

- Add Profile button is visible near the model list.
- Add Profile opens a draft editor.
- Cancel closes the draft without saving.
- Empty `modelID` fails validation.
- Empty `host` fails validation.
- Invalid ports `0`, `65536`, and `abc` fail validation.
- Duplicate `modelID` fails validation.
- Empty `displayName` is filled with `modelID` on save.
- Valid Add Profile saves to `models.json`.
- While stopped, the added profile becomes selected.
- After add, Model detail updates to the added profile when it is selected.
- After add, Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` update to the selected added profile.
- While running, Add Profile can save without changing the selected runtime profile.
- While running, Add Profile does not affect the existing managed server process.
- Logs show add success and validation failures.

### Delete Profile

- Delete Profile button is visible near the selected model detail.
- Delete Profile shows a confirmation dialog.
- The confirmation text says only the saved profile is removed.
- The confirmation text says model files and Hugging Face cache are not deleted.
- Canceling delete keeps the profile.
- Confirming delete removes only the profile entry from `models.json`.
- Delete saves the updated list to `models.json`.
- Model files are not deleted.
- Hugging Face cache is not deleted.
- Last remaining profile cannot be deleted.
- Delete Profile is blocked while a managed server is active.
- Deleting the selected profile switches to the first remaining profile.
- After delete, Model detail updates to the fallback profile.
- After delete, Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` update to the fallback profile.
- Logs show delete success, delete failures, and fallback model ID.

### Regression

- Edit Profile still opens, saves, validates, and cancels as before.
- Start, Stop, and Restart still work after profile add/delete.
- Run Diagnostics still works after profile add/delete.
- Menu bar quick actions still work after profile add/delete.
- Release build instructions remain valid.

### Safety

- Profile add/delete modifies only saved profile data in `models.json`.
- Adding a profile while a managed server is active does not affect the running server.
- Deleting profiles while a managed server is active is blocked.
- Profile add/delete does not start `mlx_lm.server`.
- Profile add/delete does not stop external processes.
- Profile add/delete does not use `pkill`, `killall`, or `pgrep`.
- Profile add/delete does not delete model files or Hugging Face cache.
- Profile add/delete does not download models.
- Profile add/delete does not run model inference.
- Profile add/delete does not call `/v1/chat/completions`.
- Direct Mode is maintained with no Proxy and no Chat UI.
- `settings.json`, `models.json`, and model files stay outside Git.
- No user-specific fixed paths are added.
