# Product Design

## Product Shape

MLX Server Manager is an operational utility for a local MLX server. The main screen should prioritize server status, action controls, connection details, resource usage, and logs.

The product should feel like a compact macOS operations panel, not a chat app or model playground.

## Primary User Flow

1. User selects or confirms server launch configuration.
2. App checks the port before launch.
3. User starts the server.
4. App shows launch progress and readiness.
5. User copies the OpenAI-compatible connection settings.
6. User monitors memory and logs.
7. User stops or restarts the server when needed.

## UI Principles

- Keep Start, Stop, and Restart obvious and state-aware.
- Make readiness visible without requiring log reading.
- Show port conflict errors before attempting launch.
- Keep copyable connection settings concise.
- Logs should support quick diagnosis but not dominate the interface.
- Avoid chat-style input boxes, message bubbles, or conversation history.

## State Model

The UI should distinguish:

- Not running
- Starting
- Running but not ready
- Ready
- Stopping
- Failed
- Port conflict

