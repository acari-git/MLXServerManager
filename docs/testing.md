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
