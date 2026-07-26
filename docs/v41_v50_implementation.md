# v41.0.0–v50.0.0 Implementation Record

This document records the implemented development scope for MLX Server Manager v41.0.0 through v50.0.0. The app version in the development tree is `50.0.0`. The latest published binary remains v40.0.0 until a separate commit, tag, push, packaging, and release workflow is explicitly requested.

Direct Mode remains unchanged:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

## v41.0.0 — Platform Compatibility Baseline

- Lowers the application deployment target from macOS 26.5 to macOS 15.0.
- Keeps the application target Apple Silicon (`arm64`) only.
- Adds an explicit Platform Compatibility result with current OS, architecture, declared minimum version, and blocking status for a non-Apple-Silicon process.
- Adds release-asset checks for minimum macOS and arm64 architecture.
- Does not claim real macOS 15 launch verification until a macOS 15 device or virtual machine has run the release candidate.

## v42.0.0 — Evidence Freshness

- Captures bounded deterministic fingerprints for runtime, profile, model, endpoint, memory, benchmark, and Hermes Agent inputs.
- Marks evidence Current, Stale, or Unavailable when the user explicitly compares current inputs.
- Uses configured executable/model/Hermes paths only and does not add broad filesystem monitoring.
- Running all Operations Center checks establishes a new baseline; changing settings or files does not silently rerun checks.

## v43.0.0 — Runtime Environment Doctor

- Inspects both configured managed backends through a testable actor service.
- Checks path configuration, file existence, executable permission, script interpreter availability, thin Mach-O architecture, bounded `--version` output, bounded `--help` output, and Python dependency-import failures.
- Provides copyable command previews for selected manual recovery actions.
- Does not install, update, activate, delete, or repair Python environments.

## v44.0.0 — Model Metadata Inspector

- Inspects only the local path referenced by the selected registered profile.
- Reads model type, architecture, quantization metadata, context length, vocabulary size, tokenizer presence, chat template, reasoning/tool candidates, safetensors file count, indexed shard count, and total direct-weight size.
- Reports incomplete or review states for missing/undecodable metadata, tokenizer data, weights, and referenced shards.
- Does not execute remote code, modify metadata, scan unrelated model folders, or claim guaranteed runtime compatibility.

## v45.0.0 — Post-Launch Stability Verification

- Requires a currently running app-owned selected profile.
- Runs five explicit short checks of PID continuity and `GET /v1/models` readiness.
- Includes current app-observed managed memory and degraded runtime state.
- Reports Stabilizing, Stable, Degraded, Unstable, Exited, or Not Running.
- Sends no generation request and does not monitor adopted external processes.

## v46.0.0 — Resource Calibration

- Records an explicit point-in-time local snapshot for a running app-owned selected profile.
- Stores hardware-memory context, current forecast, observed managed memory, execution fingerprint, and compatible benchmark aggregate values when available.
- Bounds persisted calibration history to the newest 100 records.
- Does not change profile options or claim that one point-in-time measurement predicts every future workload.

## v47.0.0 — Profile Groups and Launch Plans

- Adds persisted named Launch Plan definitions.
- Provides a custom editor for plan name, arbitrary registered-profile inclusion, removal, order, and per-step Required or Optional state.
- Creates quick plans from the selected profile or all registered profiles without starting a server.
- Supports explicit editing, reordering, required-state changes, deletion, validation, execution, cancellation, and plan-owned stop requests.
- Runs profiles sequentially through the existing app-managed start path and waits for each profile to become ready.
- Preserves profiles that were already running before the plan.

## v48.0.0 — Capacity-Aware Multi-Model Operations

- Assesses the active plan using registered model size estimates, current app-managed memory, current system memory, and profiles already running.
- Reports Safe, Caution, Critical, or Unavailable.
- Displays a conservative smaller-estimate-first recommended order for profiles not already running without changing the saved plan order.
- Blocks plan execution when the projection crosses the emergency memory floor.
- Does not stop a model automatically, change a profile, or route inference between profiles.

## v49.0.0 — Architecture, Supportability, and Distribution

- Isolates Operations Center state, services, AppViewModel intents, and SwiftUI rendering from the existing large core files.
- Keeps all new long-running work under replaceable request coordinators rather than raw ViewModel tasks.
- Adds a bounded, memory-only, redacted Support Bundle containing platform, runtime, evidence, model, stability, capacity, launch diagnosis, and the newest operational-history context.
- Excludes prompts, responses, credentials, raw environment variables, model files, and full home paths.
- Adds `scripts/verify_release_asset.sh` for read-only verification of release-asset SHA-256, archive root, forbidden entries, app version, minimum macOS, arm64 architecture, and code signature.

## v50.0.0 — Unified Operations Center 2.0

- Adds one explicit modal Operations Center accessible from Settings.
- Combines Platform Compatibility, existing Operational Readiness, Evidence Freshness, Runtime Environment Doctor, Model Metadata Inspector, Post-Launch Stability, Resource Calibration, Launch Plans, Capacity Assessment, and Support Bundle.
- Keeps existing Operational Readiness available as the narrower non-generating check.
- Adds English/Japanese labels, light/dark rendering coverage, standard macOS controls, keyboard-focusable buttons and toggles, and stable accessibility identifiers.
- Does not add a proxy, request router, background startup, automatic repair, external-process ownership, telemetry, cloud logging, or a general-purpose Chat UI.

## Persistence

- Advances the authoritative settings-state schema from 2 to 3.
- Migrates schema 1 and schema 2 snapshots to schema 3.
- Persists Launch Plan definitions and bounded Resource Calibration records.
- Retains authoritative-state backup recovery and refuses unsupported future schemas without overwriting them.

## Launch Plan Safety

Before execution, a Launch Plan rejects:

- an empty plan;
- duplicate profile entries;
- a missing required profile;
- duplicate plan endpoints;
- non-loopback profiles that require separate network-exposure confirmation;
- profiles with options known to be unsupported by the configured runtime;
- profiles requiring separate critical-memory confirmation;
- a total capacity projection below the emergency memory floor.

A plan never bypasses existing Start guardrails. Stopping plan-started servers affects only app-owned profiles recorded as started by that plan execution.

## Verification Boundary

Automated verification covers models, services, persistence migrations, ViewModel ownership boundaries, launch-plan definition editing, secret redaction, macOS 15 compilation, localization, and rendering. Real runtime/model behavior remains dependent on the user's installed executables, model files, ports, and local memory conditions.

A real macOS 15 device or virtual machine is still required before claiming that a v50 release asset has been launch-tested on the declared minimum operating system.
