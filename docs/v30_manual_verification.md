# v30.0.0 Manual Verification Record

Date: 2026-07-25 (Asia/Tokyo)

## Boundary

This record covers the local verification completed before publishing the v30.0.0 unsigned GitHub Release asset.

Direct Mode remains:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

No proxy, request rewriting, traffic inspection, inference-content persistence, telemetry, or external log sending was introduced.

## Real Runtime Readiness

Configured `mlx_lm.server` path from the local app settings:

- file exists,
- regular executable file,
- `--help` exited with status 0,
- no stderr output,
- 24 distinct long-form options were detected.

This verifies the real mlx-lm readiness path without starting a server or generating model output.

Rapid-MLX:

- no executable path is configured,
- no executable was found in the inspected user paths,
- the expected v27 result is therefore `Path Not Configured` rather than a false-ready state.

A real Rapid-MLX installation remains required to verify its ready state.

## Live Hugging Face Discovery

The same public endpoint used by `HuggingFaceSearchService` was queried with `search=mlx` and `limit=10`.

Observed result boundary:

- 10 results returned,
- every result included a non-empty model ID,
- every result included tags,
- every result included download metadata,
- every result included like metadata,
- all 10 results in this query included the exact `mlx` tag.

The v29 controls operate only on these already-fetched results. Changing sorting or filtering does not send another request.

## App Launch Smoke Check

The current Debug app executable was launched as a separate process and remained alive for more than six seconds without an initialization crash. The verification process was terminated using its exact PID. No process-wide termination command was used.

An existing app instance was left running and was not terminated.

## Idle Process Observation

The existing app instance had no direct child processes during the observation. This is consistent with no app-managed server being active at that moment.

Observed resident memory was approximately 166 MB. CPU samples were usually low but included one transient spike. This observation is not sufficient to quantify active Border Beam cost or GPU impact.

## Accessibility and Motion Evidence

Automated policy coverage verifies that Border Beam animation:

- pauses when Reduce Motion is enabled,
- pauses when the view is not visible,
- pauses while the app scene is inactive,
- freezes at a stable progress value under Reduce Motion,
- remains decorative and does not intercept pointer input,
- is hidden from accessibility,
- reduces bloom intensity when Reduce Transparency is enabled,
- appears only for explicit active operational states.

A visual check using the actual macOS accessibility toggles was not completed before publication and remains a post-release verification item.

## Public-Safety Inspection

The v30 release files were checked for:

- Hugging Face, OpenAI, and GitHub token patterns,
- tracked settings or model profile files,
- tracked model weights or caches,
- personal absolute paths,
- app bundles, zip files, dSYM files, DerivedData, and build directories.

No findings were returned.

## Automated Verification Snapshot

- Tests: 508 passed, 0 failed, 0 skipped.
- Release build: passed.
- Xcode Analyze: passed.
- Strict-concurrency build with warnings as errors: passed.
- Localization guards: passed.
- English/Japanese and light/dark rendering smoke tests: passed.
- `git diff --check`: passed after the version, documentation, and ignore-rule updates.

## Release Asset Verification

The final unsigned asset was built and verified locally:

- asset: `MLXServerManager-v30.0.0-unsigned.zip`,
- size: approximately 2.9 MB,
- SHA-256: `5b11b5b2418a612a783c7cd8eedb24e4de9cc6b0387575212f731a0792e98383`,
- archive root: `MLXServerManager.app` only,
- archive entry count: 7,
- extracted app version: 30.0.0,
- extracted build number: 1,
- signature: ad hoc/linker-signed, not Developer ID signed,
- no settings, profiles, model files, caches, logs, DerivedData, dSYM, AppleDouble metadata, or credentials were found,
- the extracted app executable remained alive for more than six seconds with no stderr output.

## Remaining Manual Checks

The following checks still require direct human observation or unavailable runtime software:

- real Rapid-MLX ready-state verification,
- profile template review with representative small and 30B-class workloads before launch,
- real-window visual review in English and Japanese,
- real-window visual review in light and dark appearance,
- Operational History readability during simultaneous lifecycle, download, and benchmark events,
- Reduce Motion and Reduce Transparency visual behavior in System Settings,
- CPU and GPU impact while multiple active Border Beam surfaces are simultaneously visible.

These items do not invalidate the implemented code or packaged asset. They remain known follow-up verification items for future maintenance.
