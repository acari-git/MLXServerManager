# Agent Instructions

This repository contains MLX Server Manager, a macOS SwiftUI control surface for local OpenAI-compatible inference servers.

## Authoritative Scope

Read `docs/stable_scope.md` before making product-scope decisions. It defines the current stable surface. Older version-specific planning documents are historical and must not override it.

The current app supports app-managed `mlx_lm.server` and Rapid-MLX processes, multiple model profiles, explicit Hugging Face search/download workflows, diagnostics, benchmarks, Test Chat, Hermes Agent configuration, and explicitly adopted external OpenAI-compatible endpoints.

Direct Mode is mandatory:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

MLX Server Manager must not insert a proxy, router, request rewriter, or traffic-inspection layer into that path.

## Engineering Rules

- Keep SwiftUI views focused on rendering state and sending user intents.
- Put process launch, termination, pipe handling, port probing, filesystem mutation, polling, and network operations behind testable services or coordinators.
- Preserve explicit process ownership. Stop, Restart, and force termination may affect only processes launched and owned by this app.
- Do not use `pkill`, `killall`, or `pgrep` in production Swift code.
- Keep long-running asynchronous work cancellable and protect replacement requests from stale completion.
- Keep related user-facing state coherent. Prefer one Equatable view state over multiple independently published fields when values change together.
- Do not hardcode user-specific absolute paths.
- Keep English and Japanese user-facing text paired. Raw logs, model IDs, endpoints, command output, and technical identifiers may remain untranslated when translation would change their meaning.
- Preserve Direct Mode performance. Background work must not contend unnecessarily with active model generation.

## Safety and Privacy

- No silent model generation, download, server start, external-process adoption, file deletion, or network exposure.
- Test Chat, Benchmark, Agent Readiness, diagnostics, downloads, profile replacement, cache deletion, and Hermes Agent writes require explicit user actions.
- Never delete local model folders through profile deletion.
- Validate and narrowly scope any Hugging Face cache deletion.
- Never persist or export secrets in profile JSON, logs, diagnostics summaries, or copied troubleshooting text.
- Do not add telemetry, analytics, crash uploads, external log sending, or cloud logging.

## Repository Hygiene

Do not commit runtime settings, model profiles, model files, Hugging Face cache content, logs, secrets, virtual environments, app bundles, zip archives, dSYM files, DerivedData, or build artifacts. In particular, keep these outside Git:

- `settings.json`, `models.json`, `session-recovery.json`
- `.env`, `HF_TOKEN`, token/key files
- `.venv`, `models`, `logs`
- `*.safetensors`, `*.gguf`, `*.bin`, `*.onnx`, `*.mlx`
- `*.app`, `*.zip`, `*.dSYM`, `build`, `DerivedData`

## Agent skills

Use installed Agent Skills automatically when the current task clearly matches a skill description. Read the matching `SKILL.md` before acting, and follow repository instructions when they conflict with a generic skill workflow.

### Issue tracker

Issues and PRDs are tracked in GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default Matt Pocock triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository. See `docs/agents/domain.md`.

For implementation work, prefer the relevant discipline automatically: `diagnosing-bugs` for difficult defects, `tdd` for testable behavior changes, `codebase-design` for module boundaries, `code-review` before handoff, and `domain-modeling` when terminology or architectural decisions need clarification.

Use `hallmark` when creating, auditing, or redesigning application UI. Use `kigen-design-system` when defining or importing design tokens, themes, semantic colors, typography, spacing, radius, Figma handoff, or mapping Kigen exports into SwiftUI; combine it with `apple-design` or `emil-design-eng` when platform behavior or interaction polish is in scope. Use `commit-archaeologist` before risky rewrites where Git history can explain intent, and use `scope-creep-detector` when reviewing whether a change exceeded its stated purpose. Use `advisor-orchestrator-worker` only for work that genuinely requires parallel decomposition. Use `thinking-out-loud` only when the user explicitly starts an exploratory voice-style dump or asks to think aloud.

The `code-review-graph` skills (`build-graph`, `explore-codebase`, `debug-issue`, `refactor-safely`, `review-changes`, `review-delta`, and `review-pr`) require their MCP tools. Invoke them only when those tools are available in the current session; otherwise use the repository-native inspection and review workflow without claiming graph analysis was performed. User-invoked orchestration skills remain opt-in unless the user explicitly requests that workflow.

## Verification

For code changes, run the narrowest relevant tests first, then the full test suite. Before handoff, verify:

- Debug tests pass.
- Release build succeeds.
- Static analysis succeeds.
- Swift strict-concurrency build has no new warnings.
- `git diff --check` passes.
- English and Japanese localization guardrails pass.

Do not commit, tag, push, publish a release, delete files, or perform another destructive or externally visible action unless the user explicitly requests it.