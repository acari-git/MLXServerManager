# Tasks

## v0.1 Completed

- Define app settings and model configuration for executable path, host, port, API key placeholder, and model identifiers.
- Persist and restore `settings.json` and `models.json` under the user's Application Support directory.
- Implement process management service for Start, Stop, and Restart.
- Ensure Stop and Restart only target the managed process held by the app.
- Implement port availability checks before launch.
- Implement ready checks via `/v1/models`.
- Implement memory monitoring for the managed process.
- Implement bounded runtime log display with Clear Logs.
- Implement OpenAI-compatible connection copy actions:
  - Base URL
  - Model ID
  - JSON config
  - `curl /v1/models`
  - `curl /v1/chat/completions`
- Build SwiftUI views bound to observable state, without direct `Process` usage in views.

## v0.1 Manual Verification

- Start reaches Ready when `mlx_lm.server` responds on `/v1/models`.
- Stop terminates only the managed process and releases the port.
- Restart performs Stop, port release wait, Start, and Ready check.
- Port Check reports busy for occupied ports and available after Stop.
- Settings persist across app restart.
- Memory display updates while the managed process runs and clears after Stop.
- Logs remain bounded and Clear Logs leaves a single `[info] logs cleared` entry.
- Connection copy buttons produce OpenAI-compatible text for external clients.

## Later

- Unit tests for services where practical.
- App Intents for start, stop, restart, and status.
- LAN Web UI.
- Proxy mode as an explicit opt-in architecture.
- Automatic unload policies.
- More advanced resource graphs.
- Hugging Face download manager.
- Multiple simultaneous server management.
- Presets for frequently used model configurations.
