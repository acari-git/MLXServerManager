# v50.0.0 Development Readiness

## Status

The development tree is versioned as `50.0.0`. The latest published release remains v40.0.0. No v50 commit, tag, push, release asset, or GitHub Release has been created.

Direct Mode remains unchanged:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

## Implemented Scope

v41.0.0 through v50.0.0 implement:

- an Apple Silicon application target with a declared minimum deployment target of macOS 15.0;
- explicit platform compatibility reporting;
- evidence-freshness comparison for runtime, profile, model, endpoint, memory, benchmark, and Hermes Agent inputs;
- Runtime Environment Doctor with bounded executable inspection and no automatic installation or repair;
- selected registered-model metadata inspection without remote-code execution or broad directory scans;
- explicit short app-owned post-launch stability verification using PID continuity and `GET /v1/models` only;
- bounded local resource-calibration snapshots without automatic tuning;
- persisted custom Launch Plans with arbitrary registered-profile selection, ordered steps, and Required / Optional state;
- sequential Launch Plan execution through the existing managed-start path without bypassing current guardrails;
- conservative multi-model capacity assessment and a displayed smaller-known-estimate-first recommended order without changing the saved plan;
- memory-only redacted Support Bundles;
- one unified Operations Center while retaining the narrower Operational Readiness surface;
- authoritative settings-state schema 3 with schema 1 and schema 2 migration;
- a read-only release-asset verification script.

## Automated Verification

Completed against the current source tree:

- Full Debug test suite: 554 passed.
- Failed tests: 0.
- Skipped tests: 0.
- Expected failures: 0.
- English/Japanese localization guardrails: passed as part of the full suite.
- English/Japanese and light/dark rendering tests, including Operations Center and Launch Plan Editor: passed as part of the full suite.
- Launch Plan persistence, ordering, Required / Optional state, and no-start ownership boundaries: passed.
- Settings schema 1-to-3 and schema 2-to-3 migration tests: passed.
- Runtime Doctor, model metadata, evidence freshness, capacity assessment, support redaction, and calibration persistence tests: passed.
- Release build: succeeded.
- Xcode Analyze: succeeded.
- Swift Strict Concurrency complete build with Swift and GCC warnings treated as errors: succeeded.
- AppViewModel raw-Task ownership guard: passed.
- `git diff --check`: passed.

## Local Release-Candidate Verification

A temporary local candidate was created outside the repository:

- Candidate file: `/tmp/MLXServerManager-v50.0.0-final-unsigned.zip`
- Candidate size: `3,871,560` bytes
- Candidate SHA-256: `c3207c8ef284f7a6b5657d3358e2eb688fd022366a981c56ac50e77b1f817d66`
- App version: `50.0.0`
- Minimum macOS metadata: `15.0`
- Executable architecture: `arm64`
- Signature: local ad-hoc signature

`scripts/verify_release_asset.sh` confirmed:

- the expected SHA-256;
- `MLXServerManager.app` as the only archive root;
- no runtime settings, model profiles, session recovery state, models, caches, logs, secrets, dSYM, DerivedData, AppleDouble, or `__MACOSX` entries;
- app version `50.0.0`;
- minimum macOS `15.0`;
- arm64 executable architecture;
- valid code-signature structure.

The extracted candidate remained alive for more than seven seconds on the current test host and only the test-owned application PID was terminated with SIGTERM.

## Test Host

- Device: Mac mini
- Architecture: arm64
- Host operating system: macOS 26.5.2

## Remaining Minimum-OS Verification

The project compiles and links for `arm64-apple-macos15.0`, and the candidate metadata declares macOS 15.0. However, a real macOS 15 device or virtual machine was not available in this session.

Before publishing v50.0.0, complete at least one launch and primary-surface smoke check on macOS 15.x. Until then, the repository must not claim that the v50 binary has been runtime-tested on its declared minimum operating system.

## Safety Audit

No new production findings were detected for:

- `pkill`, `killall`, or `pgrep`;
- unsafe forced casts or `unsafeBitCast`;
- process operations against adopted external endpoints;
- silent generation, download, installation, server start, endpoint adoption, or settings changes;
- user-specific absolute paths in new production source or public documentation;
- real credential material;
- tracked application bundles, zip archives, model files, settings files, logs, dSYM, DerivedData, or other build artifacts.

Launch Plan definitions can be created, edited, reordered, or deleted without starting or stopping a server. Plan execution preserves profiles already running before the plan and records only app-owned profiles newly started by that execution as plan-stop candidates.

## Publication State

Not performed:

- commit;
- tag;
- push;
- v50 release asset publication;
- GitHub Release publication.

The latest published asset remains `MLXServerManager-v40.0.0-unsigned.zip`.
