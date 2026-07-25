# v34.0.0 Release Candidate Readiness

## Scope

This document records the implementation state for the v31.0.0 through v34.0.0 development series. The latest published release remains v30.0.0.

Direct Mode remains unchanged:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

## Implemented Product Work

### Safe Quit

- Application termination is delayed only when app-owned managed processes are running.
- Users choose Stop All and Quit, Leave Running and Quit, or Cancel.
- Stop All uses the existing owned-process lifecycle and port-release checks.
- A failed stop cancels app termination.
- External endpoints are never stopped.

### Runtime Setup Assistant

- Candidate discovery is explicit and bounded.
- Candidate use updates the unsaved Settings draft only.
- No software installation or automatic settings save occurs.
- Version output is best-effort and may remain unavailable.

### Runtime Compatibility Matrix

- Compatibility is projected from detected command flags.
- Version and help probes are explicit.
- Missing probes remain Unknown.
- Partial support is used when a multi-flag feature is only partly detected.
- The matrix does not guarantee model compatibility or successful launch.

### Session Recovery

- Prior managed endpoint metadata is stored locally.
- Clean and leave-running shutdown paths are distinguished from interrupted sessions.
- Previous endpoint records do not restore process ownership.
- Endpoint checks use `/v1/models` and do not generate model output.
- Confirmed endpoints can be adopted only as external connection context.

## Safety Review

- No proxy or request-path changes.
- No automatic server start.
- No automatic runtime installation.
- No external process termination.
- No process-wide termination commands.
- No model-folder deletion.
- No credentials in session recovery.
- No telemetry, analytics, crash upload, remote logging, or inference-content persistence.

## Automated Verification Completed

- Focused v31–v34 tests: 17 passed.
- Full test suite: 525 passed, 0 failed, 0 skipped.
- Localization guards: passed.
- English/Japanese and light/dark rendering tests, including Session Recovery: passed.
- Release build: succeeded.
- Xcode Analyze: succeeded.
- Strict-concurrency build with warnings treated as errors: succeeded.
- AppViewModel raw Task ownership: absent.
- `git diff --check`: passed.
- Process-wide command, unsafe-cast, personal-path, and new-secret checks: no new findings.

## Real Runtime Evidence

The configured local `mlx_lm.server` executable was found at the saved Settings path and was executable. Its `--help` output exposed flags for model selection, host and port, allowed origins, chat templates, trust-remote-code, draft model, and draft-token count. Reasoning-parser and tool-call-parser flags were not detected. Its `--version` invocation returned usage text rather than a parseable version, so the matrix correctly leaves the version unavailable.

Rapid-MLX remains unconfigured in the inspected local Settings and therefore remains Unknown rather than being reported as supported.

## Manual Verification Remaining

- Quit with one managed model and confirm Stop All and Quit.
- Quit with multiple managed models and confirm progress and port release.
- Confirm Leave Running and Quit leaves only app-owned child processes running.
- Relaunch and confirm those endpoints are presented as external candidates.
- Confirm Session Recovery cannot Stop or Restart a recovered endpoint.
- Inspect Runtime Setup Assistant with real mlx-lm and Rapid-MLX environments.
- Review compatibility results against real runtime `--help` output.
- Verify Japanese/English and light/dark layouts on a real app window.

## Release Boundary

The app target version is `34.0.0`, but no commit, tag, push, asset, or GitHub Release is authorized by implementation completion alone.
