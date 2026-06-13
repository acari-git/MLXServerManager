# MLX Server Manager

MLX Server Manager is a macOS SwiftUI app for starting, stopping, restarting, monitoring, and configuring a local `mlx_lm.server` process.

It is a pure `mlx_lm.server` manager. It is not a chat UI, not a proxy, and not a wrapper for LM Studio, Ollama, llama.cpp, or another inference backend.

The app keeps Direct Mode:

```text
OpenAI-compatible client -> mlx_lm.server
```

MLX Server Manager controls and observes the managed local server process, but it does not enter the inference request path. OpenAI-compatible clients connect directly to `mlx_lm.server`.

## Target Users

- macOS users running local MLX / `mlx-lm`.
- Users who want a GUI for `mlx_lm.server` Start, Stop, Restart, diagnostics, logs, model profiles, and connection settings.
- Users of OpenAI-compatible clients such as Hermes Agent, Open WebUI, LibreChat, AnythingLLM, or custom scripts.

## Stable Scope

The v1.0 stable scope includes:

- Start, Stop, and Restart for the `mlx_lm.server` process started by this app.
- Managed-process-only Stop and Restart behavior.
- Port availability check.
- Ready check via `GET /v1/models`.
- Settings save and restore.
- Model profile add, edit, delete, and selection.
- Model switching with `Restart required` state.
- Menu bar quick actions.
- Logs readability improvements.
- Copy Logs.
- Setup Diagnostics summary.
- Copy Diagnostics Summary.
- OpenAI-compatible connection setting copy actions:
  - Copy Base URL
  - Copy Model ID
  - Copy JSON config
  - Copy `curl /v1/models`
  - Copy `curl /v1/chat/completions`
- Unsigned `.app` zip distribution documentation.

The copied `curl /v1/chat/completions` text is only a client-side convenience example. The app itself uses `/v1/models` for readiness and diagnostics and does not send inference requests.

## Non-Goals

- Chat UI.
- Proxy mode.
- LAN Web UI.
- App Intents.
- Auto unload.
- Hugging Face download manager.
- Model download.
- Model deletion.
- Hugging Face cache deletion.
- Multiple concurrent server management.
- Multiple model simultaneous launch.
- RAG.
- Embedding manager.
- Tool-call translation.
- Telemetry, analytics, crash reporting, external log sending, or cloud logging.
- Persistent file logging.
- Notarization, Developer ID signing, DMG, App Store distribution, Homebrew cask, auto updater, or CI/CD release automation.

## First-Run Workflow

1. Prepare a working local `mlx-lm` environment yourself.
2. Launch MLX Server Manager.
3. Open Settings and set the `mlx_lm.server executable path`.
4. Configure a Model Profile:
   - Display name
   - Model ID
   - Host
   - Port
   - Enable thinking option
   - Notes
5. Run Setup Diagnostics.
6. Start the managed server.
7. Confirm Ready status via `/v1/models`.
8. Copy Base URL, Model ID, JSON config, or curl examples from Connection Settings.
9. Paste those values into your OpenAI-compatible client.
10. Use Stop or Restart when needed.

For local use, `127.0.0.1` is recommended:

- Host: `127.0.0.1`
- Port: `8080`
- Base URL: `http://127.0.0.1:8080/v1`
- API key placeholder: `not-required-local`

Do not expose `mlx_lm.server` directly to the internet.

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

Qwen thinking behavior is controlled by the client request and model template behavior. MLX Server Manager only copies helper text; it does not run this request.

## Known Limitations

- The documented release asset is an unsigned local-use `.app` zip.
- The app is not notarized and is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- The app does not bundle `mlx-lm`.
- The app does not bundle models.
- You must provide model files or Hugging Face cache separately.
- The app does not download models.
- The app does not optimize inference.
- The app does not alter the MLX performance path.
- Ready Check uses `/v1/models` only.
- The app does not test chat completions.
- Stop and Restart affect only the process started and held by this app.
- External `mlx_lm.server` processes are not stopped.
- There is no automatic updater, DMG, installer, or CI/CD release pipeline.

See [docs/known_limitations.md](docs/known_limitations.md) for the full list.

## Configuration and Repository Hygiene

The app stores runtime configuration under the user's Application Support directory:

- `settings.json`
- `models.json`

These files are local runtime state and should not be committed. Model directories, model artifacts, logs, virtual environments, `.env`, `HF_TOKEN`, `.app`, `.zip`, `.dSYM`, and build artifacts must also stay out of Git.

Do not hardcode user-specific absolute paths in source code or committed documentation.

## Documentation

- Stable scope: [docs/stable_scope.md](docs/stable_scope.md)
- Known limitations: [docs/known_limitations.md](docs/known_limitations.md)
- v1.0 plan: [docs/v1.0_plan.md](docs/v1.0_plan.md)
- v1.0.1 maintenance plan: [docs/v1.0.1_maintenance.md](docs/v1.0.1_maintenance.md)
- Requirements: [docs/requirements.md](docs/requirements.md)
- Architecture: [docs/architecture.md](docs/architecture.md)
- Testing: [docs/testing.md](docs/testing.md)
- Distribution: [docs/distribution.md](docs/distribution.md)
- Behavioral contracts: [contracts/](contracts/)
