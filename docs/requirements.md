# Requirements

## Goal

MLX Server Manager provides a macOS GUI for operating `mlx_lm.server` while preserving the performance characteristics of a direct `mlx_lm.server` setup.

The app must make routine server operations easier without changing the inference route or adding a proxy in v0.1.

## v0.1 Functional Requirements

- Start `mlx_lm.server` with user-configured launch options.
- Stop the running server process started by the app.
- Restart by stopping the managed process and launching it again.
- Check whether the configured port is already in use before starting.
- Detect readiness by probing the OpenAI-compatible API endpoint.
- Show memory usage relevant to the managed server process.
- Show recent server logs.
- Copy OpenAI-compatible connection settings for external clients.

## v0.1 Non-Functional Requirements

- Starting the server from the GUI must not add a proxy or middleware to inference requests.
- The app must avoid polling that materially degrades inference performance.
- Runtime actions must be separated from SwiftUI views.
- Configuration must be portable across user accounts.
- Secrets and model files must stay outside Git.

## Explicit Non-Goals

- Chat UI
- Proxy routing
- LM Studio, Ollama, llama.cpp, or other backends
- Remote server management
- Multi-host orchestration
- Automatic model unload
- LAN Web UI
- App Intents

