# Known Limitations

This document lists the current known limitations for MLX Server Manager as of v20.1.0. Older planning documents can still describe earlier version boundaries; this file is the current stable-scope summary.

## Distribution

- The documented app asset is an unsigned local-use `.app` zip.
- The app is not notarized.
- The app is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- Browser-downloaded builds may show a "damaged and can't be opened" warning because unsigned, non-notarized apps can be quarantined by macOS.
- This warning does not always mean the zip or app bundle is actually corrupted; verify the Release asset and checksum before removing quarantine.
- There is no DMG, installer, Homebrew cask, App Store build, automatic updater, or CI/CD release pipeline.
- Users must decide whether to run an unsigned local build.
- First launch may require users to verify the Release asset and then remove quarantine from the extracted app manually.

## Runtime Dependencies

- The app does not bundle `mlx-lm`.
- The app does not install `mlx-lm`.
- The app does not bundle model files.
- The app does not bundle Hugging Face cache.
- Users must provide a working `mlx_lm.server` executable path in Settings.
- Users must provide model files, download models explicitly, or use an existing Hugging Face cache.
- The app does not replace Python, Homebrew, Hugging Face CLI, or `mlx-lm` environment setup.
- The app does not verify MLX model compatibility beyond conservative metadata, path, and preflight checks.

## Model Search, Download, and Profiles

- Hugging Face search is a lightweight convenience surface, not a full model-card browser, ranking engine, or recommendation system.
- Hugging Face downloads are explicit user actions through the configured local environment and Hugging Face CLI path detection.
- Downloads do not silently start a server.
- Downloads do not delete model files, mutate Hugging Face cache, or clean partial files automatically.
- The app does not persist Hugging Face access tokens or API credentials.
- The app does not manage private-model authentication beyond the user's existing local tooling.
- Auto-add after a successful download creates or updates local profile metadata; it does not bundle or copy model weights into Git or release assets.
- Model Profile import/export is stable for metadata-only profile backup and transfer.
- Import supports selected valid profiles, explicit Rename for profile-name conflicts, and explicit Replace for one unambiguous existing profile target.
- Profile-name conflicts can be imported with explicit Rename, or replaced when they map to exactly one local profile and the user confirms.
- Ambiguous Replace targets and duplicate selected Replace actions remain skipped or disabled.
- Import/export fixtures and XCTest coverage exist for the current schema, validation, Rename, and Replace behavior, but they are service-level metadata tests and do not run live `mlx_lm.server`.

## Dashboard and GUI

- The current primary workflow is the integrated Dashboard / workspace for model list, lifecycle actions, logs, details, recovery, settings, and connection copy actions.
- v20.0.0 aligns visible GUI labels with implemented behavior and removes unavailable proxy-port UI from the integrated workspace.
- CPU and GPU/Metal display remains explicit unsampled context, not active CPU/GPU utilization sampling.
- Memory shown for the managed process depends on available process information and may be unavailable when no managed process is running.
- Last-check wording reflects app-observed checks, not automatic model usage telemetry.
- Start guardrails block obvious unsafe starts, but they do not guarantee that `mlx_lm.server` will load every model successfully.
- Recovery actions are guidance and explicit user-triggered shortcuts, not automatic repair.

## Process Management

- The app manages only the process it starts.
- Stop and Restart do not stop external `mlx_lm.server` processes.
- Adopt External Server is connection context only and does not transfer process ownership.
- Multiple concurrent server management is not implemented.
- Multiple model simultaneous launch is not implemented.
- Model selection while running requires Restart to apply runtime-affecting changes.

## Readiness, Benchmarks, and Inference

- Ready Check uses `/v1/models` only.
- The app does not run `/v1/chat/completions` for diagnostics or readiness.
- The copied chat-completions request is only helper text for external clients.
- The app does not run model inference.
- Speed Test is an explicit local endpoint check, not a generation benchmark.
- Local benchmark results are workload-dependent.
- MLX Server Manager does not guarantee faster performance than oMLX or other backends.
- Advanced `mlx_lm.server` options are optional and per-profile.
- The app does not proxy inference requests.
- Qwen thinking behavior is a client/request-side concern.
- The app does not optimize inference.
- The app does not alter the MLX performance path.

## Data and Logs

- `settings.json` and `models.json` are local runtime files.
- Runtime settings and model profiles are not part of Git or release assets.
- Logs are kept in memory with a bounded buffer.
- Persistent file logging is not implemented.
- Telemetry, analytics, crash reporting, cloud logging, and external log sending are not implemented.

## Safety Boundaries

- Direct Mode is the only supported mode.
- Proxy mode is not implemented.
- Chat UI is not implemented.
- LAN Web UI is not implemented.
- App Intents are not implemented.
- Auto unload is not implemented; current controls keep Stop manual and explicit.
- Model file deletion is not implemented.
- Hugging Face cache deletion is not implemented.
- RAG, embedding management, and tool-call translation are not implemented.
