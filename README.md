# MLX Server Manager

MLX Server Manager is a macOS SwiftUI app for starting, stopping, restarting, and monitoring `mlx_lm.server` without changing the pure MLX inference path.

It is not a chat UI. It does not use LM Studio, Ollama, llama.cpp, or any other inference backend. Version 0.1 is Direct Mode only:

```text
OpenAI-compatible client -> mlx_lm.server
```

The app controls and observes the local server process, but it does not proxy inference traffic.

## v0.1 Implemented Features

- Start, Stop, and Restart for the `mlx_lm.server` process started by this app.
- Port Check before launch, using the selected host and port.
- Ready Check via `GET /v1/models`.
- Settings save and restore for app settings and model configuration.
- Managed process memory usage display.
- Runtime log display with bounded log history and Clear Logs.
- OpenAI-compatible connection copy actions:
  - Copy Base URL
  - Copy Model ID
  - Copy JSON config
  - Copy `curl /v1/models`
  - Copy `curl /v1/chat/completions`

## v0.1 Non-Goals

- Chat UI.
- Proxy mode.
- Auto unload.
- LAN Web UI.
- App Intents.
- Hugging Face download manager.
- Multiple simultaneous server management.
- Running `/v1/chat/completions` from the app.
- LM Studio, Ollama, llama.cpp, or alternate inference backend support.

The copied `curl /v1/chat/completions` text is only a client-side convenience example. The app itself uses `/v1/models` for readiness and does not send inference requests.

## Local Setup

Configure the `mlx_lm.server` executable path in the app UI. Do not hardcode user-specific absolute paths in source code or committed documentation.

For v0.1, local loopback usage is recommended:

- Host: `127.0.0.1`
- Port: `8080`
- Base URL: `http://127.0.0.1:8080/v1`
- API Key placeholder: `not-required-local`

Do not expose this server directly to the internet. Treat it as a local development service unless a future version adds explicit LAN or remote-access hardening.

## OpenAI-Compatible Client Example

JSON config:

```json
{
  "api_key": "not-required-local",
  "base_url": "http://127.0.0.1:8080/v1",
  "model": "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit"
}
```

List models:

```sh
curl http://127.0.0.1:8080/v1/models
```

Minimal chat-completions request for an external client:

```sh
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer not-required-local" \
  -d '{
    "model": "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit",
    "messages": [
      {"role": "user", "content": "こんにちは"}
    ],
    "max_tokens": 128,
    "chat_template_kwargs": {
      "enable_thinking": false
    }
  }'
```

## Configuration and Repository Hygiene

The app stores runtime configuration under the user's Application Support directory:

- `settings.json`
- `models.json`

These files are local runtime state and should not be committed. Model directories, model artifacts, logs, virtual environments, `.env`, and `HF_TOKEN` must also stay out of Git.

See `docs/` and `contracts/` for requirements, architecture, UI, testing, and behavioral contracts.
