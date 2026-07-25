# v35.0.0–v40.0.0 Implementation Record

This document records the completed development scope for MLX Server Manager v35.0.0 through v40.0.0. The app version in the development tree is `40.0.0`. The latest published binary remains v34.0.0 until a separate commit, tag, push, packaging, and release workflow is explicitly requested.

## v35.0.0 — Capability-Aware Profile Compatibility

- Generalized runtime option probing across `mlx_lm.server` and Rapid-MLX.
- Compares the optional flags requested by a profile with the flags exposed by the configured executable.
- Treats unknown support as unknown rather than unsupported.
- Rejects stale compatibility evidence when the executable path changes.
- Blocks start only for known unsupported requested options.
- Provides an explicit unsaved-draft cleanup action; saving remains a separate user action.

## v36.0.0 — Structured Launch-Failure Diagnosis

- Captures a bounded in-memory window of managed-process output during launch.
- Classifies common executable, dependency, model-file, port, permission, parser, memory, readiness, and early-exit failures.
- Redacts bearer tokens and secret-like values from copied diagnostic output.
- Connects diagnosis to failed start, failed readiness, and unexpected managed-process termination paths.
- Does not persist raw command output or send diagnostics externally.

## v37.0.0 — Registered Model Health

- Adds an explicit health check for registered profiles only.
- Inspects configured local paths without scanning unrelated folders.
- Reports present, missing, incomplete, duplicate-path, and external-identifier states.
- Reuses the existing local-model integrity boundary for required configuration, tokenizer, and weight files.
- Does not download, delete, relocate, or repair model files.

## v38.0.0 — Start Resource Forecast

- Reuses existing multi-model memory assessment and KV-cache safety logic.
- Shows projected managed memory, available-memory headroom, and conservative cache guidance before start.
- Can place safer values or a Memory Saver template into an unsaved profile draft.
- Never silently changes the saved profile or bypasses existing critical-memory confirmation.

## v39.0.0 — Benchmark-Guided Profile Tuning

- Produces tuning suggestions only from current, comparable benchmark sessions with at least two successful samples.
- Excludes stale execution fingerprints, changed hardware/backend conditions, thermally pressured runs, and insufficient samples.
- Maps supported use-case evidence to existing explicit profile templates.
- Applies recommendations only to an unsaved draft for review.

## v40.0.0 — Operational Readiness

- Adds one explicit, non-generating readiness surface covering runtime readiness, profile compatibility, registered-model health, endpoint state, resource forecast, prior-session recovery candidates, benchmark evidence, latest launch diagnosis, and Hermes Agent configuration.
- Runs independent readiness, compatibility, and model-health work concurrently behind a replaceable coordinator.
- Discards stale completion when settings, profiles, or selected profile change during the run.
- Does not start a server, send a generation request, download a model, adopt an endpoint, stop a process, or save settings.
- Keeps an already-running selected managed endpoint from being misclassified as blocked merely because its port is occupied.

## Persistence

- Advances the authoritative settings snapshot to schema 2.
- Reads and migrates schema 1 snapshots to schema 2.
- Retains authoritative-state and recovery-backup behavior.
- Rejects unsupported future schemas rather than overwriting them.

## Safety Boundaries

- Direct Mode remains unchanged.
- Process termination remains limited to app-owned managed processes.
- External and recovered endpoints never gain process ownership.
- Capability cleanup, resource guidance, and benchmark tuning modify unsaved drafts only.
- Model health is explicit and limited to registered paths.
- Launch diagnosis remains bounded, memory-only, copy-redacted, and local.
- No telemetry, external log sending, inference proxy, background generation, silent downloads, or automatic persistence was added.

## Verification Completed

- Full Debug test suite succeeded.
- Focused v35–v40 tests succeeded, including executable-path staleness handling.
- Release build succeeded with code signing disabled for local verification.
- Static analysis succeeded.
- Strict Concurrency Debug build succeeded with Swift and GCC warnings treated as errors.
- English/Japanese localization guardrails and rendering tests succeeded as part of the full suite.
- `git diff --check` succeeded.

Real-model launch behavior, model-specific memory estimates, and benchmark recommendations still depend on the user's installed runtimes, registered model files, and local Mac conditions. Those environment-specific checks are not represented as universal compatibility claims.
