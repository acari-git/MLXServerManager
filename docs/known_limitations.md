# Known Limitations

This document lists known v1.0 limitations for MLX Server Manager.

## Distribution

- The documented release asset is an unsigned local-use `.app` zip.
- The app is not notarized.
- The app is not signed with Developer ID.
- macOS Gatekeeper may warn when opening the app.
- Browser-downloaded builds may show a "damaged and can't be opened" warning because unsigned, non-notarized apps can be quarantined by macOS.
- This warning does not always mean the zip or app bundle is actually corrupted; verify the Release asset and checksum before removing quarantine.
- The GitHub Release asset should be verified after download before broader announcement.
- There is no DMG, installer, Homebrew cask, App Store build, automatic updater, or CI/CD release pipeline.
- Users must decide whether to run an unsigned local build.
- First launch may require users to verify the Release asset and then remove quarantine from the extracted app manually.

## Runtime Dependencies

- The app does not bundle `mlx-lm`.
- The app does not install `mlx-lm`.
- The app does not bundle model files.
- The app does not bundle Hugging Face cache.
- Users must provide the `mlx_lm.server` executable path in Settings.
- Users must provide model files or Hugging Face cache separately.
- The app does not download models.
- The app does not validate that a model exists before `mlx_lm.server` attempts to load it.

## Process Management

- The app manages only the process it starts.
- Stop and Restart do not stop external `mlx_lm.server` processes.
- Multiple concurrent server management is not implemented.
- Multiple model simultaneous launch is not implemented.
- Model selection while running requires Restart to apply runtime-affecting changes.

## Readiness and Inference

- Ready Check uses `/v1/models` only.
- The app does not test `/v1/chat/completions`.
- The app does not run model inference.
- Local benchmark results are workload-dependent.
- MLX Server Manager does not guarantee faster performance than oMLX or other backends.
- Advanced `mlx_lm.server` options are not enabled by default.
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
- Auto unload is not implemented.
- Hugging Face download manager is not implemented.
- Model file deletion is not implemented.
- Hugging Face cache deletion is not implemented.
- RAG, embedding management, and tool-call translation are not implemented.
