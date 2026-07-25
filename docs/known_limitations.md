# Known Limitations

This document lists the current known limitations for MLX Server Manager. Older planning documents can still describe earlier version boundaries; this file is the current stable-scope summary.

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

- The app does not bundle or install `mlx-lm` or Rapid-MLX.
- The app does not bundle model files.
- The app does not bundle Hugging Face cache.
- Users must provide a working executable path in Settings for every backend they use.
- Users must provide model files, download models explicitly, or use an existing Hugging Face cache.
- The app does not replace Python, Homebrew, Hugging Face CLI, or backend environment setup.
- Runtime Setup Assistant searches only configured, PATH, Homebrew, and a limited set of user-environment locations. It does not install, update, or repair a runtime.
- Runtime Compatibility Matrix reports detected command flags and version output; it does not guarantee that every model or option combination will execute successfully.
- The app does not verify MLX model compatibility beyond conservative metadata, path, preflight, and detected runtime-option checks.

## Model Search, Download, and Profiles

- Hugging Face search is a lightweight convenience surface, not a full model-card browser, ranking engine, or recommendation system.
- Hugging Face downloads are explicit user actions through the configured local environment and Hugging Face CLI path detection.
- Downloads do not silently start a server.
- The download workflow does not delete model files, mutate Hugging Face cache, or clean partial files automatically.
- Profile deletion can separately remove one matching Hugging Face hub cache only after explicit destructive confirmation; it never removes a local model folder and is not a general cache manager.
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
- Start guardrails block obvious unsafe starts, but they do not guarantee that a supported backend will load every model successfully.
- Recovery actions are guidance and explicit user-triggered shortcuts, not automatic repair.

## Process Management

- The app manages only the process it starts.
- Stop and Restart do not stop external server processes.
- Adopt External Server is connection context only and does not transfer process ownership.
- App-managed profiles can run concurrently when each uses a distinct available endpoint.
- Lifecycle, PID, runtime state, and memory measurements are tracked per managed profile.
- Runtime-affecting edits remain locked while that profile is running.
- Quit prompts when app-owned managed servers are running. Users can stop all and quit, leave servers running and quit, or cancel.
- Stop-all-on-quit waits for each owned process and its port release. If any stop fails, application termination is cancelled and the failed targets remain visible.
- Leaving servers running intentionally does not transfer ownership to a future app session.

## Readiness, Benchmarks, and Inference

- Ready Check uses `/v1/models` only.
- The app does not run `/v1/chat/completions` for diagnostics or readiness.
- Test Chat and benchmark actions are explicit user-triggered calls to the selected OpenAI-compatible endpoint; they do not proxy requests for other clients.
- Benchmark runs are explicit local generation tests with Quick, Standard, and Detailed presets.
- Standard and Detailed results use repeated samples, medians, and stability indicators; single-sample results are not used for final recommendations.
- Model comparison and use-case recommendations apply only to results measured on the current Mac under compatible benchmark conditions.
- Local benchmark results are workload-dependent.
- MLX Server Manager does not guarantee faster performance for one supported backend over another.
- Advanced launch options and KV cache recommendations are optional and per-profile.
- KV cache values are conservative starting points based on local memory headroom, not guaranteed optimal settings.
- The app does not proxy inference requests.
- Qwen thinking behavior is a client/request-side concern.
- The app does not optimize inference.
- The app does not alter the MLX performance path.

## Data and Logs

- `settings.json` and `models.json` are local runtime files.
- `session-recovery.json` stores only prior session disposition and managed profile endpoint metadata. It does not store prompts, responses, tokens, credentials, or process ownership authority.
- Session Recovery can re-check a recorded endpoint and adopt it as external connection context, but it cannot prove the process is the same process previously launched by the app.
- Runtime settings and model profiles are not part of Git or release assets.
- Logs are kept in memory with a bounded buffer.
- Persistent file logging is not implemented.
- Telemetry, analytics, crash reporting, cloud logging, and external log sending are not implemented.

## Safety Boundaries

- Direct Mode is the only supported mode.
- Proxy mode is not implemented.
- A general-purpose Chat UI is not implemented. Test Chat is limited to a single-message endpoint response diagnostic.
- LAN Web UI is not implemented.
- App Intents are not implemented.
- Automatic unload is optional and configured per profile; it is not a request-aware proxy idle detector.
- Local model-folder deletion is not implemented.
- Broad Hugging Face cache browsing or cleanup is not implemented; only the explicitly confirmed matching-cache action described above is supported.
- RAG, embedding management, and tool-call translation are not implemented.
