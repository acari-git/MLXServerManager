# v40.0.0 Release Candidate Readiness

## Scope

This document records the implementation and verification state for v35.0.0 through v40.0.0. The development tree is versioned as v40.0.0. The latest published release remains v34.0.0 until a separate commit, tag, push, asset, and GitHub Release workflow is explicitly requested.

Direct Mode remains unchanged:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

## Implemented Product Work

### Capability-Aware Profiles

- Optional launch flags are projected for both managed backends.
- Known unsupported requested flags block managed start.
- Missing or stale evidence remains Unknown and non-blocking.
- Compatibility results are valid only for the same backend and normalized executable path.
- Unsupported-option cleanup changes only an unsaved profile draft.

### Structured Launch Diagnosis

- App-owned launch output is captured in a bounded in-memory coordinator.
- Common executable, dependency, option, model, endpoint, parser, memory, readiness, and early-exit failures are classified.
- Copied evidence is sanitized.
- Successful readiness clears transient launch-diagnosis state.

### Registered Model Health

- Inspection is limited to local paths referenced by registered profiles.
- Configuration, tokenizer, weights, shards, empty files, unsafe references, missing paths, external identifiers, and shared paths are represented explicitly.
- No broad model-directory or cache scan occurs.

### Resource Forecast and Benchmark Tuning

- Start forecasting reuses existing multi-model memory and KV-cache safety models.
- Critical memory protection and explicit confirmation remain intact.
- Benchmark tuning requires current, comparable, multi-sample evidence.
- Resource and benchmark recommendations open unsaved drafts and never persist automatically.

### Unified Operational Readiness

- One explicit surface aggregates runtime, compatibility, model health, endpoint state, resources, recovery, benchmark evidence, Hermes Agent state, and latest launch diagnosis.
- Checks do not generate text, start a server, download a model, save settings, adopt an endpoint, or stop a process.
- Copied readiness output is bounded and redacted.

### Settings Migration

- The authoritative settings-state schema advances from 1 to 2.
- Schema 1 is decoded and migrated atomically.
- Recovery backup update failures are surfaced without discarding a valid primary state.
- Unsupported future schemas still block load and save.

## Automated Verification Completed

- Focused v35–v40 feature tests: 12 passed.
- Full test suite before the final executable-path staleness regression was added: 537 passed, 0 failed, 0 skipped, 0 expected failures.
- The added executable-path staleness regression passed in the subsequent focused v35–v40 run.
- English/Japanese localization guardrails: passed as part of the full suite.
- English/Japanese and light/dark rendering coverage, including Operational Readiness: passed as part of the full suite.
- Debug build through test execution: succeeded.
- Release build: succeeded.
- Xcode Analyze: succeeded.
- Swift strict-concurrency build with Swift and compiler warnings treated as errors: succeeded.
- AppViewModel raw Task ownership guard: passed.
- Settings schema 1-to-2 migration and unsupported-future-schema protection: passed.
- `git diff --check`: passed.

## Smoke Verification

- Built app version: `40.0.0`.
- Build number: `1`.
- Debug app launched with an isolated temporary HOME.
- The process remained alive for more than six seconds.
- Only the test-owned app PID was terminated with SIGTERM.

## Structural Stabilization

- v35–v40 readiness projection and coordination is isolated in `AppViewModel+OperationalReadiness.swift`.
- Integrated workspace hover-help and visual-effect support is isolated in `IntegratedWorkspaceViewSupport.swift`.
- The unused legacy custom `NSPanel` help path was removed.
- `IntegratedWorkspaceView.swift` was reduced from 3,118 to 2,499 lines while preserving the active standard-popover implementation.

## Safety and Repository Audit

No new findings were detected for:

- `pkill`, `killall`, or `pgrep` in production Swift;
- unsafe forced casts or `unsafeBitCast` in production Swift;
- user-specific absolute paths in the source or documentation changes;
- real credential material in the source or documentation changes;
- runtime settings, profiles, session-recovery files, model weights, virtual environments, app bundles, zip archives, dSYM files, DerivedData, or build directories in Git status.

Secret-shaped matches are limited to synthetic redaction test inputs, established fake-token fixtures, and the documented `not-required-local` placeholder. The worktree otherwise contains source, tests, documentation, and project-version changes only.

## Manual Real-Environment Verification Remaining

- Confirm profile compatibility against real current `mlx_lm.server` and Rapid-MLX help output.
- Change a configured executable path and confirm the prior compatibility result becomes Unknown in the real UI.
- Inspect registered-model health with complete, incomplete, missing, external-ID, and shared-path profiles.
- Trigger representative real launch failures and compare classification with raw local logs.
- Review resource forecasts under normal and constrained memory conditions.
- Run Standard or Detailed benchmarks with at least two successful samples and review unsaved tuning drafts.
- Review Operational Readiness in English and Japanese, light and dark appearance, at narrow and wide window sizes.

These checks require local runtime and model combinations and do not alter the completed automated release-candidate result.

## Release State

Not performed:

- commit;
- tag;
- push;
- unsigned zip asset;
- checksum publication;
- GitHub Release.

The latest published binary remains `MLXServerManager-v34.0.0-unsigned.zip`.
