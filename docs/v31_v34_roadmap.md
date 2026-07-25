# v31.0.0–v34.0.0 Implementation Roadmap

## Boundary

The v31 through v34 work extends operational safety and setup clarity without changing Direct Mode:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

No proxy, router, request rewriting, request inspection, telemetry, or automatic software installation is introduced.

## v31.0.0 — Safe Application Termination

Implemented:

- macOS application termination interception through `NSApplicationDelegate`,
- prompt only when app-owned managed processes are running,
- explicit choices to stop all and quit, leave servers running and quit, or cancel,
- owned-process-only target projection,
- sequential stop and port-release verification through the existing lifecycle path,
- termination cancellation and failed-target reporting when a stop does not complete,
- progress state that prevents ambiguous repeated quit operations,
- external endpoints remain untouched.

## v32.0.0 — Runtime Setup Assistant

Implemented:

- explicit runtime candidate discovery from:
  - the current configured path,
  - directories in `PATH`,
  - `/opt/homebrew/bin`, `/usr/local/bin`, and `/usr/bin`,
  - a limited set of user-local virtual-environment locations,
- executable permission checks,
- best-effort `--version` display,
- explicit `Use path` action that updates only the unsaved Settings draft,
- no package installation, environment modification, or automatic save.

## v33.0.0 — Runtime Compatibility Matrix

Implemented:

- explicit inspection of configured runtimes,
- version collection through `--version`,
- supported option extraction through `--help`,
- feature projection for:
  - model selection,
  - host and port,
  - CORS,
  - chat templates,
  - trust-remote-code,
  - speculative decoding,
  - reasoning controls,
  - tool-call parsing,
- supported, partial, not-detected, and unknown states,
- unknown remains unknown when the executable or help probe is unavailable,
- no claim that detected flags guarantee model-level compatibility.

## v34.0.0 — Session Recovery

Implemented:

- local `session-recovery.json` record in Application Support,
- clean, active/interrupted, and intentional leave-running dispositions,
- profile identity, model ID, host, and port only,
- no prompts, responses, secrets, credentials, or logs in the recovery record,
- recovery sheet after a prior interrupted or leave-running session,
- explicit endpoint re-check via `GET /v1/models`,
- explicit adoption as external connection context,
- no restoration of process ownership,
- no stop or restart rights inferred from prior session metadata,
- dismissed recovery candidates are cleared from the current session record unless they are currently app-managed.

## Verification Order

1. Focused v31–v34 model and service tests.
2. Existing localization and English-mode tests.
3. UI rendering smoke tests.
4. Full unit and integration test suite.
5. Release build.
6. Xcode Analyze.
7. Strict-concurrency build.
8. `git diff --check` and repository safety checks.

## Release Boundary

The development version is `34.0.0`. The latest published release remains `v30.0.0` until a separate release workflow is explicitly requested.

Do not commit, tag, push, package, or publish this work without explicit authorization.
