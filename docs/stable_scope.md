# Stable Scope

This document defines the published stable scope for MLX Server Manager v34.0.0. The latest published binary is v34.0.0. Older version-specific planning documents describe historical boundaries; this file records the current product surface and Direct Mode rules.

MLX Server Manager is a Direct Mode control surface for app-managed `mlx_lm.server` and Rapid-MLX processes, plus explicitly adopted external OpenAI-compatible endpoints:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

The app may launch, stop, monitor, diagnose, and document connection settings for supported local servers. It never enters the request path between another client and the selected endpoint.

## Included in the Current Stable Scope

### Managed Server Operations

- Start independent app-managed `mlx_lm.server` or Rapid-MLX processes per profile.
- Run multiple managed profiles concurrently when they use distinct available endpoints.
- Track lifecycle, PID, endpoint, runtime state, and memory per managed profile.
- Stop only app-owned processes, escalating from terminate to interrupt and then force kill only when an owned process does not exit.
- Restart through Stop, port-release wait, and Start.
- Optionally auto-unload a managed profile after its configured idle interval.
- On application quit, explicitly stop all app-owned managed servers, leave them running, or cancel termination.
- Detect and adopt an external compatible endpoint as connection context without taking process ownership.

### Health and Diagnostics

- Port availability check.
- Ready check via `GET /v1/models`.
- Runtime and setup diagnostics for executable path, host, port, storage paths, model path, endpoint state, and readiness.
- Explicit runtime candidate discovery without software installation or automatic settings changes.
- Runtime compatibility inspection from detected command flags and version output.
- Diagnostics, benchmark, and Agent Readiness summaries with copy actions.

### Settings and Profiles

- Save and restore app settings.
- Save and restore model profiles.
- Check configured `mlx_lm.server` and Rapid-MLX executable readiness without starting a server.
- Apply explicit Minimal, Balanced, Memory Saver, or Throughput templates to managed launch-tuning fields while preserving profile identity and unrelated options.
- Add, edit, reorder, import, export, and delete model profiles.
- Validate model ID, host, and port.
- Prevent deletion of the last profile.
- Preserve local model folders during profile deletion.
- Allow separate deletion of the one matching Hugging Face hub cache only after explicit destructive confirmation and path validation.
- Store per-profile backend, launch options, automatic-unload settings, and benchmark history.

### Model Discovery and Download

- Search Hugging Face through the lightweight discovery surface.
- Sort already-fetched discovery results by recommendation, downloads, likes, recent update, or name.
- Filter already-fetched results by verified MLX tag and minimum download count without sending another request.
- Download by model ID or URL using configured local tooling.
- Show queue state and parsed progress, and support retry, cancel, form restore, and URL copy.
- Optionally add and select a successfully downloaded model profile.
- Keep downloads explicit; they never silently start a server.

### Endpoint Tests and Benchmarks

- Ready Check uses `GET /v1/models` and does not generate model output.
- Test Chat sends one user message directly to the selected OpenAI-compatible endpoint only when explicitly requested.
- Benchmark provides Quick, Standard, and Detailed local generation measurements and current-Mac use-case scores.
- Agent Readiness uses deterministic virtual-tool tasks without Docker or real tool execution.
- Diagnostic generation calls are explicit and never proxy traffic for another client.

### Session Recovery

- Record app-owned managed endpoint metadata in a local session-recovery file while the app is running.
- Distinguish clean shutdown, intentional leave-running shutdown, and an interrupted prior session.
- Re-check prior endpoints explicitly through `GET /v1/models`.
- Adopt a confirmed remaining endpoint only as external connection context.
- Never restore process ownership or terminate a recovered endpoint based on the prior-session record.

### Hermes Agent Integration

- Copy selected endpoint values for Hermes Agent and other OpenAI-compatible clients.
- Update the configured Hermes Agent YAML while preserving unrelated settings.
- Create a backup before writes and provide an explicit restore action.

### UI Surfaces

- Integrated SwiftUI workspace with navigation, model table, Test Chat, logs, settings, downloads, and model inspector.
- Restrained Kinetic Border Beam feedback only while explicit lifecycle transitions, Test Chat requests, or downloads are active, with reduced-motion and reduced-transparency handling.
- Menu bar quick actions.
- Copy Base URL, Model ID, OpenAI-compatible JSON, Hermes Agent values, `curl /v1/models`, and example `curl /v1/chat/completions`.

### Logs

- Bounded detailed log buffer.
- Readable log categories and levels.
- Separate memory-only Operational History bounded to the newest 100 events.
- Operational History category and severity filters, model/endpoint context, copy, and clear actions.
- Clear Logs.
- Copy Logs.

### Distribution Documentation

- Debug and Release build instructions.
- Unsigned local-use `.app` zip asset instructions.
- Zip content verification.
- Launch-after-unzip verification.
- Release note template.

## Stable Safety Rules

- Direct Mode only.
- No proxy in the inference path.
- No general-purpose Chat UI.
- No silent model generation. Test Chat, Benchmark, and Agent Readiness run only from explicit user actions.
- No `pkill`, `killall`, or `pgrep` in Swift code.
- No external `mlx_lm.server` process termination.
- Session Recovery never restores process ownership from persisted metadata.
- No local model-folder deletion.
- No broad Hugging Face cache browsing or cleanup.
- No committed runtime settings, model files, secrets, app bundles, zip files, dSYM files, or build artifacts.
- No personal fixed paths in docs or Swift code.

## Deferred or Excluded Beyond Current Scope

- Proxy mode.
- General-purpose Chat UI.
- LAN Web UI.
- App Intents.
- Full Hugging Face model-card browsing.
- Hugging Face token storage or credential management.
- Silent or background model downloads.
- Local model-folder deletion.
- Broad Hugging Face cache browsing or cleanup.
- RAG.
- Embedding manager.
- Tool-call translation.
- Telemetry, analytics, crash reporting, external log sending, cloud logging, or persistent file logging.
- Notarization, Developer ID signing, DMG, App Store distribution, Homebrew cask, auto updater, or CI/CD release automation.
