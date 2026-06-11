# Agent Instructions

This repository contains a macOS SwiftUI app named MLX Server Manager.

## Product Direction

The app manages `mlx_lm.server` directly. It is not a chat app, and it must not route inference through LM Studio, Ollama, llama.cpp, or another backend.

Version 0.1 supports Direct Mode only. The inference path must remain:

```text
client -> mlx_lm.server
```

The app may launch, stop, monitor, and display connection details for the server. It must not insert a proxy into the request path in v0.1.

## Engineering Rules

- Do not put `Process` launch, termination, pipe handling, port probing, or polling logic directly inside SwiftUI views.
- Keep SwiftUI views focused on rendering state and sending user intents.
- Put process control behind services or controllers that can be tested without UI.
- Do not hardcode user-specific paths such as `/Users/yoinkun`.
- Do not commit `.venv`, `models`, `logs`, `.env`, `HF_TOKEN`, or model files.
- Preserve the ability to add App Intents, LAN Web UI, Proxy mode, and automatic unload later.

## v0.1 Feature Boundary

Implement only:

- Start / Stop / Restart
- Ready checks
- Port conflict checks
- Memory usage display
- OpenAI-compatible connection config copy
- Log display

Do not add chat UI or alternate inference backend support unless the product scope changes explicitly.

