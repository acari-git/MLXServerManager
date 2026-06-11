# Testing

## Unit Tests

Target service behavior without launching the full UI:

- Port check detects available and occupied ports.
- Ready check handles success, timeout, invalid response, and connection failure.
- Connection config copy produces stable output.
- Process service state transitions are testable through protocol boundaries or fakes.
- Memory monitor handles missing process, running process, and permission failures.

## Manual Tests

- Start server from stopped state.
- Stop server from running state.
- Restart server after ready state.
- Attempt start when port is occupied.
- Confirm ready state after `/v1/models` or equivalent OpenAI-compatible endpoint responds.
- Confirm memory usage updates while the server is running.
- Confirm logs display stdout and stderr.
- Confirm copied connection config works with an external OpenAI-compatible client.

## Performance Guardrails

- Direct Mode must not proxy inference traffic.
- Polling intervals should be conservative enough to avoid meaningful inference slowdown.
- Log reading should avoid unbounded memory growth.

## Security and Repository Hygiene

- `.env` and `HF_TOKEN` must not be committed.
- Model directories and model artifact files must not be committed.
- Logs must not be committed.
- User-specific absolute paths must not appear in source or committed configuration.

