# MLX Server Manager v30.0.0

Release asset: `MLXServerManager-v30.0.0-unsigned.zip`

SHA-256:

```text
5b11b5b2418a612a783c7cd8eedb24e4de9cc6b0387575212f731a0792e98383
```

## Summary

v30.0.0 improves the internal architecture, active-operation feedback, runtime setup checks, profile tuning workflow, Hugging Face discovery controls, and operational troubleshooting while preserving Direct Mode.

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

MLX Server Manager remains outside the inference request path. It does not proxy, route, inspect, rewrite, or persist inference requests.

## Highlights

### Runtime Readiness

Settings can now check configured `mlx_lm.server` and Rapid-MLX executable paths without starting a server. The app distinguishes unconfigured paths, missing files, non-executable files, ready runtimes, and mlx-lm capability-probe warnings.

### Profile Templates

The profile editor now includes explicit Minimal, Balanced, Memory Saver, and Throughput templates. Templates modify only managed concurrency, prefill, and prompt-cache fields. Model identity, endpoint, notes, sampling settings, CORS, chat-template arguments, and raw arguments remain unchanged.

### Discovery Controls

Hugging Face results can be sorted by recommendation, downloads, likes, recent update, or name. Results can also be filtered by verified MLX tag and minimum download count. These controls operate on already-fetched results and do not trigger another network request.

### Operational History

Logs now include a separate memory-only Operational History for lifecycle, readiness, profile, benchmark, download, and runtime-health events. The newest 100 events can be filtered by category and severity, copied, or cleared. Detailed logs and Operational History remain separate.

### Kinetic UI Feedback

Active lifecycle transitions, Test Chat requests, and downloads use restrained Border Beam feedback. The effect is decorative, does not intercept input, pauses when inactive or offscreen, and responds to Reduce Motion and Reduce Transparency.

### Architecture and Reliability

AppViewModel responsibilities were separated into focused extensions and asynchronous ownership was moved behind cancellable coordinators. Replacement requests reject stale completions, and the Direct Mode/process-ownership boundaries remain unchanged.

## Verification

- 508 tests passed.
- Release build passed.
- Xcode Analyze passed.
- Strict-concurrency build with warnings treated as errors passed.
- English/Japanese localization guards passed.
- Light/dark and standard/narrow rendering smoke tests passed.
- Real configured `mlx_lm.server --help` readiness probe passed.
- Live Hugging Face discovery response shape was verified.
- Secret, personal-path, forbidden-artifact, and tracked-runtime-file checks returned no findings.

See `docs/v30_manual_verification.md` for the local verification record and remaining human-observation checks.

## Safety and Scope

- No inference proxy.
- No general-purpose chat UI.
- No silent server start, download, generation, external-server adoption, or deletion.
- No process-wide termination commands.
- No local model-folder deletion.
- No telemetry, analytics, crash upload, cloud logging, or persistent operational-history file.
- No stored Hugging Face token or API credential management.

## Distribution Notice

This release is an unsigned, non-notarized local-use macOS app zip. Verify the published SHA-256 checksum and zip contents before opening the app. The archive contains `MLXServerManager.app` and does not bundle runtime settings, model profiles, model files, caches, logs, or credentials.
