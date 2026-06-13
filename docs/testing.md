# Testing

## Unit Tests

Target service behavior without launching the full UI:

- Port check detects available and occupied ports.
- Ready check handles success, timeout, invalid response, and connection failure through `/v1/models`.
- Connection config copy produces stable OpenAI-compatible JSON and curl text.
- Process service state transitions are testable through protocol boundaries or fakes.
- Memory monitor handles missing process, running process, and permission failures.
- Log buffer trims old entries when it exceeds the configured maximum.

## Manual Tests

- Configure `mlx_lm.server` executable path in the UI.
- Save settings, quit, relaunch, and confirm settings are restored.
- Start server from stopped state.
- Confirm ready state after `/v1/models` responds.
- Confirm the managed pid is shown.
- Confirm memory usage updates while the server is running.
- Restart server after ready state and confirm a new pid is managed.
- Stop server from running state and confirm the port is released.
- Attempt start when the port is occupied by another process.
- Confirm logs display app actions and captured stdout/stderr.
- Press Clear Logs and confirm `[info] logs cleared` remains.
- Confirm copied OpenAI-compatible config works with an external client.
- Confirm copied curl examples are text only and the app does not send `/v1/chat/completions`.

## v0.2 Setup Diagnostics Manual Tests

- With no managed server running, press `Run Diagnostics`.
- Confirm `Port availability` is `pass` when the selected host and port are free.
- Confirm `Ready check` is `warning` while the server is stopped.
- Confirm Diagnostics UI and Logs both show the diagnostic results.
- With a valid executable path, confirm path `configured`, `exists`, and `executable` checks are `pass`.
- With a missing executable path, confirm path `exists` and `executable` checks are `fail`.
- With an empty executable path, confirm path `configured`, `exists`, and `executable` checks are `fail`.
- Restore the valid executable path and confirm the summary returns to `0 failure(s)`.
- Start the managed server and confirm it reaches Ready.
- Press `Run Diagnostics` while the managed server is running.
- Confirm `Port availability` is `warning`.
- Confirm the port message is `Port is busy because the managed server is running.`
- Confirm the port detail includes the managed pid.
- Confirm `Ready check` is `pass`.
- Confirm Start, Stop, and Restart still work after running diagnostics.
- Confirm diagnostics do not send `/v1/chat/completions`.
- Confirm diagnostics do not run model inference.
- Confirm diagnostics do not launch `mlx_lm.server`.
- Confirm diagnostics do not stop external processes.

## v0.3 Model Profile Editing Manual Tests

- Open `Edit Profile` from the selected model detail area.
- Change `displayName`, click `Save Profile`, and confirm Model detail updates.
- Change `modelID`, click `Save Profile`, and confirm Model detail and Copy Model ID update.
- Change `host`, click `Save Profile`, and confirm Base URL and copy actions update.
- Change `serverPort`, click `Save Profile`, and confirm Base URL and copy actions update.
- Toggle `enableThinking` on and off, click `Save Profile`, and confirm Model detail updates.
- Edit `notes`, click `Save Profile`, and confirm Model detail updates.
- Leave `displayName` empty, save, and confirm it is filled with `modelID`.
- Leave `modelID` empty and confirm save fails with a UI message and Logs entry.
- Leave `host` empty and confirm save fails with a UI message and Logs entry.
- Set `serverPort` to `0`, `65536`, and `abc`; confirm each save fails.
- Change fields and click `Cancel`; confirm changes are not saved.
- Confirm saved edits persist after app restart.
- Confirm Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` reflect saved values.
- Change `serverPort`, save, and confirm Start launches the managed server on the new port.
- Stop the managed server and restore the original port.
- While the managed server is running, confirm `modelID`, `host`, and `serverPort` changes are blocked.
- While the managed server is running, confirm `displayName`, `enableThinking`, and `notes` can still be saved.
- Confirm Start, Stop, and Restart still work after model profile edits.
- Confirm profile edits are saved to local `models.json`.
- Confirm `models.json` is not included in Git status or commits.
- Confirm profile editing does not send `/v1/chat/completions`.
- Confirm profile editing does not run model inference.
- Confirm profile editing does not launch `mlx_lm.server`.
- Confirm profile editing does not stop external processes.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm no user-specific fixed paths are added to Swift code or docs.

## v0.4 Menu Bar Quick Actions Manual Tests

- Launch the app and confirm a macOS menu bar item appears.
- Confirm the initial menu bar title is `MLX: stopped`.
- Confirm the main window and menu bar show the same status.
- Open the menu bar item and confirm Base URL is visible.
- Open the menu bar item and confirm Model ID is visible.
- Click `Open App` and confirm the main window is shown and activated.
- Click `Start` from the menu bar and confirm the managed server starts.
- Confirm the main window changes from starting to ready after Start.
- Confirm the menu bar title changes to `MLX: ready` after Start.
- Click `Run Diagnostics` from the menu bar and confirm Diagnostics and Logs update in the main window.
- Click `Restart` from the menu bar and confirm Stop, port release, Start, and Ready still work.
- Click `Stop` from the menu bar and confirm only the managed process stops.
- Confirm the main window returns to stopped after Stop.
- Confirm the menu bar title returns to `MLX: stopped` after Stop.
- Confirm Start, Stop, and Restart from the main window still work.
- Click `Quit` from the menu bar and confirm the app exits normally.
- Confirm menu bar actions reuse existing `AppViewModel` actions.
- Confirm there is no separate menu bar process management logic.
- Confirm menu bar actions do not send `/v1/chat/completions`.
- Confirm menu bar actions do not run model inference.
- Confirm menu bar status display does not start `mlx_lm.server`.
- Confirm menu bar actions do not enter the inference path.
- Confirm menu bar Stop does not stop external processes.
- Confirm Stop targets only the managed process.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm `settings.json`, `models.json`, and model files are not included in Git status or commits.
- Confirm no user-specific fixed paths are added to Swift code or docs.

## v0.5 Distribution Build Manual Tests

- Confirm `git status --short --untracked-files=all` is clean before building.
- Run the Release `xcodebuild` command with scheme `MLXServerManager`, configuration `Release`, derived data path `/tmp/MLXServerManagerReleaseDerivedData`, and `CODE_SIGNING_ALLOWED=NO`.
- Confirm the Release build ends with `BUILD SUCCEEDED`.
- Confirm the `.app` output path exists under `/tmp/MLXServerManagerReleaseDerivedData/Build/Products/Release/MLXServerManager.app`.
- Confirm the `.app` size with `du -sh`; one verified local result was `916K`.
- Launch the `.app` with `open -n`.
- Confirm `System Events` can see the `MLXServerManager` process after launch.
- Confirm the app can quit normally.
- Confirm final `git status --short --untracked-files=all` is clean.
- Confirm `.app` bundles and build artifacts are not tracked by Git.
- Confirm `settings.json`, `models.json`, and model files are not tracked by Git.
- Treat `CODE_SIGNING_ALLOWED=NO` as an unsigned personal-use local build check.
- Confirm notarization, DMG creation, and GitHub Release asset creation are not part of v0.5.
- Treat xcodebuild multiple-destination notes, bitcode strip skip without signing, and App Intents metadata extraction skip as non-blocking when the build succeeds.
- Do not require `osascript` window-name inspection; `open`, process existence, and normal quit are sufficient for this checklist.

## v0.6 Model Profile Management Manual Tests

### Add Profile

- Confirm the Add Profile button is visible near the model list.
- Click Add Profile and confirm the Add Profile UI opens.
- Click Cancel and confirm no profile is saved.
- Leave `modelID` empty and confirm save fails with a UI message and Logs entry.
- Leave `host` empty and confirm save fails with a UI message and Logs entry.
- Set `serverPort` to `0`, `65536`, and `abc`; confirm each save fails.
- Use a duplicate `modelID` and confirm save fails.
- Leave `displayName` empty, save a valid profile, and confirm it is filled with `modelID`.
- Save a valid new `modelID` and confirm save succeeds.
- Confirm the new profile is added to local `models.json`.
- While stopped, confirm the added profile is selected automatically.
- Confirm Model detail updates to the added profile.
- Confirm Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` reflect the added profile when selected.
- While a managed server is running, add a valid profile and confirm it is not auto-selected.
- While a managed server is running, confirm Add Profile does not affect the existing running server.
- Confirm Logs show add success and add failures.

### Delete Profile

- Confirm the Delete Profile button is visible near selected model detail.
- Click Delete Profile and confirm a confirmation dialog appears.
- Confirm the dialog says only the saved profile is removed.
- Confirm the dialog says model files and Hugging Face cache are not deleted.
- Click Cancel and confirm no profile is deleted.
- Confirm Delete removes only the profile entry from `models.json`.
- Confirm model files are not deleted.
- Confirm Hugging Face cache is not deleted.
- Confirm the last remaining profile cannot be deleted.
- Confirm Delete Profile is blocked while a managed server is running.
- Delete the selected profile while stopped and confirm the first remaining profile is selected.
- Confirm Model detail updates to the fallback profile after delete.
- Confirm Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` update to the fallback profile after delete.
- Confirm Logs show delete success, delete failures, and the fallback model ID.

### Regression

- Confirm Edit Profile still works after Add/Delete Profile.
- Confirm Start, Stop, and Restart still work after Add/Delete Profile.
- Confirm Run Diagnostics still works after Add/Delete Profile.
- Confirm Menu bar quick actions still work after Add/Delete Profile.
- Confirm Release build instructions still produce a working build.

### Safety

- Confirm Add/Delete Profile changes only saved profile data in `models.json`.
- Confirm Add/Delete Profile does not delete model files.
- Confirm Add/Delete Profile does not delete Hugging Face cache.
- Confirm Add/Delete Profile does not download models.
- Confirm Add/Delete Profile does not launch `mlx_lm.server`.
- Confirm Add/Delete Profile does not stop external processes.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm Add/Delete Profile does not run model inference.
- Confirm Add/Delete Profile does not send `/v1/chat/completions`.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm `settings.json`, `models.json`, and model files are not included in Git status or commits.
- Confirm no user-specific fixed paths are added to Swift code or docs.

## v0.7 Model Switching Manual Tests

### Stopped State

- Confirm `Running Model` shows `Not running` while the managed server is stopped.
- Confirm the selected model shows a `Selected` label in the model list.
- Confirm `Restart required` is not shown while stopped.
- Select another profile and confirm Model detail updates.
- Confirm Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` follow the selected model.

### After Start

- Click Start and confirm the selected model starts as the managed server.
- Confirm Ready is reached through `/v1/models`.
- Confirm `Running Model` changes to the launched `modelID`.
- Confirm the running model shows a `Running` label in the model list.
- Confirm `Restart required` is not shown when selected model and running model match.

### Switching While Running

- While the managed server is running, select a different model profile.
- Confirm the selected model changes.
- Confirm the running model does not change.
- Confirm the running server does not switch immediately.
- Confirm a second server is not started.
- Confirm `Restart required` is shown when selected model and running model differ.
- Confirm Model list shows `Restart required` on the selected profile.
- Confirm Status panel shows `Restart required to apply selected model.`
- Confirm Model detail shows Selected Model, Running Model, and Restart-required state.
- If the menu bar title includes restart-required state, confirm it updates.
- Confirm Connection Settings, Copy Config, Copy `curl /v1/models`, and Copy `curl /v1/chat/completions` follow the selected model.

### After Restart

- Click Restart and confirm the existing managed process is stopped.
- Confirm Restart starts the selected model.
- Confirm Ready is reached after Restart.
- Confirm `Running Model` updates to the selected model.
- Confirm `Restart required` disappears after the selected and running models match.
- Confirm Stop still targets only the managed process.

### After Stop

- Click Stop and confirm `Running Model` returns to `Not running`.
- Confirm `Restart required` disappears.
- Confirm the selected model is preserved.

### Regression

- Confirm Add Profile still works after model switching.
- Confirm Edit Profile still works after model switching.
- Confirm Delete Profile still works after model switching.
- Confirm Start, Stop, and Restart still work after model switching.
- Confirm Run Diagnostics still works after model switching.
- Confirm Menu bar quick actions still work after model switching.
- Confirm Release build instructions still produce a working build.

### Safety

- Confirm model switching does not add multiple simultaneous server management.
- Confirm model switching does not start multiple models at the same time.
- Confirm selecting a model does not start `mlx_lm.server`.
- Confirm model switching does not run model inference.
- Confirm the app does not send `/v1/chat/completions`.
- Confirm Restart and Stop target only the managed process.
- Confirm external processes are not stopped.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm model files are not deleted.
- Confirm Hugging Face cache is not deleted.
- Confirm models are not downloaded.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm `settings.json`, `models.json`, and model files are not included in Git status or commits.
- Confirm no user-specific fixed paths are added to Swift code or docs.

## v0.8 Logging and Diagnostics Manual Tests

### Logs

- Confirm Logs are displayed line by line.
- Confirm `[start]`, `[stop]`, `[restart]`, `[diagnostics]`, `[profile]`, `[switching]`, `[warning]`, `[error]`, and `[info]` categories are easy to scan.
- Confirm Start, Stop, and Restart logs still appear.
- Confirm Run Diagnostics logs still appear.
- Confirm Add, Edit, and Delete Profile logs still appear.
- Confirm Model switching and Restart-required logs still appear.
- Click `Clear Logs` and confirm it still works.
- Confirm `[info] logs cleared` appears after Clear Logs.
- Confirm the `Copy Logs` button is visible.
- Click `Copy Logs` and confirm the current bounded log text is copied to the macOS clipboard.
- Confirm `[info] copied logs to clipboard` appears after Copy Logs succeeds.
- Confirm Copy Logs does not break when logs are empty or immediately after Clear Logs.

### Diagnostics

- Before running diagnostics, confirm `No diagnostics run yet.` is shown.
- Before running diagnostics, click `Copy Diagnostics Summary` and confirm a warning is written to Logs.
- Click `Run Diagnostics` and confirm Pass, Warning, and Failure counts are visible.
- Confirm warnings and failures are visually easy to find.
- Confirm each check row clearly shows `PASS`, `WARNING`, or `FAIL`.
- Confirm the `Copy Diagnostics Summary` button is visible.
- Click `Copy Diagnostics Summary` and confirm the clipboard text includes the summary and each check name, status, and message.
- Confirm `[info] copied diagnostics summary to clipboard` appears after the copy succeeds.
- Confirm Diagnostics still uses the existing checks.
- Confirm Diagnostics Ready Check remains limited to `/v1/models`.
- Confirm Diagnostics does not call `/v1/chat/completions`.

### Regression

- Confirm Start, Stop, and Restart still work.
- Confirm Add, Edit, and Delete Profile still work.
- Confirm Model switching and Restart-required behavior still work.
- Confirm Menu bar quick actions still work.
- Confirm Release build instructions still produce a working build.

### Safety

- Confirm no file-persistent logs are created.
- Confirm there is no telemetry, analytics, crash reporting, or external log sending.
- Confirm Logs and Diagnostics improvements do not run model inference.
- Confirm the app does not send `/v1/chat/completions`.
- Confirm Diagnostics does not start `mlx_lm.server`.
- Confirm Diagnostics does not stop external processes.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm `settings.json`, `models.json`, and model files are not included in Git status or commits.
- Confirm no user-specific fixed paths are added to Swift code or docs.

## v0.9 Unsigned Zip Distribution Manual Tests

### Release Build

- Confirm `git status --short --untracked-files=all` is clean before packaging.
- Run the documented Release `xcodebuild` command with `CODE_SIGNING_ALLOWED=NO`.
- Confirm the Release build ends with `BUILD SUCCEEDED`.
- Confirm `MLXServerManager.app` exists under the Release build products directory.
- Confirm `.app`, `.dSYM`, derived data, and build artifacts are not tracked by Git.

### Zip Creation

- Create the unsigned zip with `ditto -c -k --keepParent`.
- Confirm the zip file is created in a temporary or release staging location outside Git.
- Confirm the zip size with `du -h`.
- Confirm `.zip` files are not tracked by Git.

### Zip Contents

- Inspect the zip with `unzip -l`.
- Confirm the zip contains `MLXServerManager.app/`.
- Confirm the zip does not contain `settings.json`.
- Confirm the zip does not contain `models.json`.
- Confirm the zip does not contain model files or model directories.
- Confirm the zip does not contain Hugging Face cache.
- Confirm the zip does not contain `.env` or `HF_TOKEN`.
- Confirm the zip does not contain `.dSYM` or derived data.

### Launch After Unzip

- Unzip the asset into a temporary location.
- Confirm `MLXServerManager.app` exists after unzip.
- Launch the app with `open -n`.
- Confirm the app starts.
- Confirm the menu bar item appears.
- Confirm the main window opens.
- Confirm runtime settings are not bundled.
- Configure `mlx_lm.server executable path` in the app UI if needed.
- Run Setup Diagnostics if local runtime settings are available.
- Quit the app normally.

### GitHub Release Asset Notes

- Confirm the intended Release asset is the unsigned zip only.
- Confirm release notes state the app is unsigned and not notarized.
- Confirm release notes mention Gatekeeper and quarantine caveats.
- Confirm release notes state runtime settings, model profiles, model files, Hugging Face cache, logs, and secrets are not included.
- Confirm release notes state Direct Mode remains `OpenAI-compatible client -> mlx_lm.server`.

### Safety

- Confirm packaging does not run model inference.
- Confirm packaging does not start `mlx_lm.server`.
- Confirm the app does not send `/v1/chat/completions`.
- Confirm external processes are not stopped.
- Confirm `pkill`, `killall`, and `pgrep` are not used.
- Confirm Direct Mode is maintained with no Proxy and no Chat UI.
- Confirm no notarization, Developer ID signing, DMG creation, CI/CD, GitHub Actions, App Store distribution, Homebrew cask, or installer creation is performed in v0.9.
- Confirm no model download, model file deletion, Hugging Face cache deletion, or multiple simultaneous server management is introduced.
- Confirm no personal fixed paths are added to docs or Swift code.

## Performance Guardrails

- Direct Mode must not proxy inference traffic.
- Polling intervals should be conservative enough to avoid meaningful inference slowdown.
- Log reading should avoid unbounded memory growth.
- Memory monitoring should target only the managed pid.

## Security and Repository Hygiene

- `.env` and `HF_TOKEN` must not be committed.
- `settings.json` and `models.json` must not be committed.
- Model directories and model artifact files must not be committed.
- Logs must not be committed.
- User-specific absolute paths must not appear in source or committed configuration.
- Local `127.0.0.1` usage is recommended for v0.1.
- Do not expose the local server directly to the internet.
