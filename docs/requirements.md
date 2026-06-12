# Requirements

## Goal

MLX Server Manager provides a macOS GUI for operating `mlx_lm.server` while preserving the performance characteristics of a direct `mlx_lm.server` setup.

The app must make routine server operations easier without changing the inference route or adding a proxy in v0.1.

## Direct Mode

v0.1 keeps inference traffic outside the app:

```text
OpenAI-compatible client -> mlx_lm.server
```

The app may launch, stop, restart, monitor, and display connection details for the local server. It must not insert a proxy into the request path.

## v0.1 Functional Requirements

- Start `mlx_lm.server` using the executable path configured in the UI.
- Stop only the server process started and held by this app.
- Restart by stopping the managed process, waiting for port release, and launching again.
- Check whether the configured host and port are available before starting.
- Detect readiness with `GET /v1/models`.
- Save and restore app settings and model configuration.
- Show memory usage for the managed server process.
- Show bounded runtime logs and allow clearing them.
- Copy OpenAI-compatible connection settings for external clients.
- Copy example curl commands for external `/v1/models` and `/v1/chat/completions` use.

## v0.1 Non-Functional Requirements

- Starting the server from the GUI must not add a proxy or middleware to inference requests.
- The app must avoid polling that materially degrades inference performance.
- Runtime actions must be separated from SwiftUI views.
- Configuration must be portable across user accounts.
- User-specific absolute paths must not be hardcoded.
- Secrets, runtime settings, logs, and model files must stay outside Git.
- Local loopback use with `127.0.0.1` is recommended for v0.1.
- The app should not encourage exposing `mlx_lm.server` directly to the internet.

## Explicit Non-Goals

- Chat UI.
- Proxy routing.
- Auto unload.
- LAN Web UI.
- App Intents.
- Hugging Face download manager.
- Multiple simultaneous server management.
- Running `/v1/chat/completions` from the app.
- LM Studio, Ollama, llama.cpp, or other inference backends.
- Remote server management.
- Multi-host orchestration.

The `/v1/chat/completions` curl text is a copy-only helper for external clients. Readiness checks must continue to use `/v1/models`.
