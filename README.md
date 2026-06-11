# MLX Server Manager

MLX Server Manager is a macOS SwiftUI app for starting, stopping, and monitoring `mlx_lm.server` without slowing down the pure MLX inference path.

It is not a chat UI. It does not use LM Studio, Ollama, llama.cpp, or any other inference backend. Version 0.1 runs in Direct Mode only: the app controls and observes `mlx_lm.server`, but it does not insert a proxy into the inference route.

## v0.1 Scope

- Start, Stop, and Restart `mlx_lm.server`
- Ready checks for the OpenAI-compatible endpoint
- Port conflict checks before launch
- Memory usage display
- OpenAI-compatible connection config copy
- Server log display

## Non-Goals for v0.1

- Chat interface
- Proxy mode
- Alternative inference backends
- Automatic model unloading
- LAN Web UI
- App Intents

These may be added later through separate modules, without changing the Direct Mode contract.

## Development Policy

- SwiftUI views must not directly start or stop `Process`.
- Process control belongs in service/controller layers.
- User-specific absolute paths such as `/Users/yoinkun` must not be hardcoded.
- Secrets, model files, virtual environments, and logs must not be committed.

See `docs/` and `contracts/` for requirements, architecture, UI, testing, and behavioral contracts.

