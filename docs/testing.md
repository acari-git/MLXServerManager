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
