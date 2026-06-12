# Product Design

## Product Shape

MLX Server Manager is an operational utility for a local MLX server. The main screen prioritizes server status, action controls, connection details, resource usage, and logs.

The product should feel like a compact macOS operations panel, not a chat app or model playground.

## Primary User Flow

1. User configures the `mlx_lm.server` executable path in the app UI.
2. User selects or confirms model, host, and port settings.
3. App checks the port before launch.
4. User starts the server.
5. App shows launch progress, managed pid, readiness, memory, and logs.
6. App checks readiness through `/v1/models`.
7. User copies OpenAI-compatible connection settings for an external client.
8. User stops or restarts the managed server when needed.

## UI Principles

- Keep Start, Stop, and Restart obvious and state-aware.
- Make readiness visible without requiring log reading.
- Show port conflict errors before attempting launch.
- Keep copyable OpenAI-compatible connection settings concise.
- Treat `/v1/chat/completions` as copied example text only, not an in-app request.
- Keep logs useful for diagnosis while bounding log growth.
- Include Clear Logs for quick reset during manual testing.
- Avoid chat-style input boxes, message bubbles, or conversation history.
- Recommend `127.0.0.1` for v0.1 local use.

## State Model

The UI should distinguish:

- Not running
- Checking port
- Starting
- Loading
- Ready
- Stopping
- Failed
- Port conflict

## Safety and Scope

- v0.1 is Direct Mode only.
- The app does not proxy inference traffic.
- The app does not expose a LAN Web UI.
- The app does not implement chat UI or automatic unload.
- The app should not present internet exposure as a supported deployment mode.
