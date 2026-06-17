# Known Limitations

This document lists known limitations for MLX Server Manager.

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
- The app does not currently download models.
- The app does not validate that a model exists before `mlx_lm.server` attempts to load it.
- Model download may be considered in a future release only if it preserves `mlx-lm` runtime performance and keeps explicit safety, privacy, and user-control boundaries.
- Model Profile import/export is stable for metadata-only profile backup and transfer.
- Import supports selected valid profiles, explicit Rename for profile-name conflicts, and explicit Replace for one unambiguous existing profile target.
- Profile-name conflicts can be imported with explicit Rename, or replaced when they map to exactly one local profile and the user confirms.
- Ambiguous Replace targets and duplicate selected Replace actions remain skipped or disabled.
- Import/export fixtures and XCTest coverage exist for the current schema, validation, Rename, and Replace behavior, but they are service-level metadata tests and do not run live `mlx_lm.server`.

## Dashboard UI

- The current dashboard exposes the required controls and state, and v4.2.0 adds the first small foundation cards for Current Target and Server State.
- v4.3.0 polishes Current Target wording and state grouping, but it does not implement the full dashboard refresh.
- v4.4.0 polishes Server State wording and separates process state, readiness, and lifecycle expectations, but it does not implement the full dashboard refresh.
- v4.5.0 adds display-only Logs / Diagnostics guidance for readiness failures, port busy states, unavailable targets, and external server log boundaries, but it does not implement a troubleshooting wizard or background health checks.
- v4.6.0 adds display-only Profiles / Import Export guidance for selected profile metadata, current target relationship, profile endpoint, Export Profiles, Import Preview, Rename, Replace, and metadata-only safety, but it does not change Import / Export behavior or schema.
- v4.7.0 adds display-only Onboarding / Next Steps guidance for first-run setup, managed Start, external adoption, readiness expectations, and Direct Mode, but it does not add a wizard, persistence, automatic diagnostics, automatic Start, or automatic Adopt.
- v4.8.0 adds display-only grouping headings and clearer Dashboard scan order, but it does not move runtime controls, add new controls, change behavior, or implement the full Dashboard UI Refresh v1.
- v4.9.0 adds display-only Client Setup guidance for active endpoint, profile endpoint relationship, readiness before client use, and Direct Mode copy context, but it does not add client configuration automation, API key storage, token storage, new network calls, or a proxy.
- v5.0.0 finalizes Dashboard UI Refresh v1 as the current stable display-oriented overview, but it does not implement a full app shell redesign, sidebar navigation, model table redesign, right-side inspector, persistent metrics widgets, or client-specific panels.
- v5.1.0 keeps Dashboard v1 stable and documents future layout work separately; it does not add a three-column shell, sidebar, model table, inspector, metrics widgets, or Hermes-specific panels.
- v5.2.0 documents a future Full App Layout Refresh direction only; sidebar navigation, model table redesign, detail inspector, logs panel refresh, metrics widgets, and client setup surfaces remain unimplemented.
- v5.3.0 documents a future App Shell / Sidebar Foundation design only; sidebar navigation, `NavigationSplitView`, model table redesign, detail inspector, logs panel refresh, and metrics widgets remain unimplemented.
- v5.4.0 documents a future Profiles / Model List Surface design only; dedicated Profiles navigation, model list table, installed model scanning, model download, model deletion, cache cleanup, and profile behavior changes remain unimplemented.
- v5.5.0 documents a future Detail Inspector Foundation design only; inspector UI, three-column layout, endpoint testing, model detail inspector behavior, model scanning, model download, model deletion, cache cleanup, selected profile behavior changes, and current target behavior changes remain unimplemented.
- v5.6.0 documents a future Logs Panel Refresh design only; a dedicated Logs surface, log filtering, log search, log export, log file persistence, external log capture, background log scraping, telemetry, and background monitoring remain unimplemented.
- v5.7.0 documents a future Client Setup Surface design only; a dedicated Client Setup surface, client-specific config generation, automatic client configuration, client auto-detection, API key storage, token storage, secret persistence, generated client config persistence, endpoint testing, and new network behavior remain unimplemented.
- Future dashboard or app layout work should be treated as separate design work after Dashboard v1.
- Dashboard UI work must continue to preserve Direct Mode, explicit lifecycle actions, managed-process-only Stop/Restart, and external server connection-context boundaries.

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
