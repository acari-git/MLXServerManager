# UI Design

## Main Window

The v0.1 main window should be a focused control surface for one local `mlx_lm.server` instance.

Recommended areas:

- Status header with server state and readiness.
- Primary controls for Start, Stop, and Restart.
- Configuration summary for host, port, model, and command.
- Connection panel with copy action.
- Memory usage panel.
- Log panel.

## Controls

- Start is enabled when the server is not running and no blocking validation error exists.
- Stop is enabled when the managed process is running.
- Restart is enabled when the managed process is running or in a recoverable failed state.
- Copy connection config is enabled when host and port are valid.

## Status Display

Use clear operational states:

- Stopped
- Starting
- Waiting for readiness
- Ready
- Stopping
- Failed
- Port conflict

## Copyable Connection Settings

The UI should expose:

- Base URL, for example `http://127.0.0.1:8000/v1`
- API key placeholder if clients require one
- Model identifier as reported or configured

## What to Avoid

- Chat transcript layout
- Prompt input composer
- Marketing-style landing page
- Proxy configuration in v0.1
- Controls for non-MLX inference backends

