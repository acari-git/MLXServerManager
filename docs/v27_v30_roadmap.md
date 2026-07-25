# v27.0.0–v30.0.0 Roadmap

## Purpose

This roadmap advances MLX Server Manager from the v26 architecture and Kinetic UX stabilization work to a v30 release candidate without changing the Direct Mode boundary:

```text
OpenAI-compatible client -> selected managed backend or adopted external endpoint
```

The app remains outside the inference request path. No proxy, router, request rewriting, hidden download, hidden server start, external process takeover, telemetry, or persistent file logging is introduced.

## v27.0.0 — Runtime Readiness and Recovery

### Goals

- Add an explicit runtime-readiness check for configured `mlx_lm.server` and Rapid-MLX executables.
- Distinguish missing path, missing file, non-executable file, capability-probe warning, and ready state.
- Reuse the existing `mlx_lm.server --help` capability provider instead of adding another probe path.
- Keep the check user-triggered and cancellable.
- Surface the result in Settings without changing launch behavior.

### Completion criteria

- Runtime readiness has a coherent view state.
- Replaced checks reject stale completion.
- English and Japanese summaries are available.
- Unit tests cover all readiness outcomes.

## v28.0.0 — Profile Templates

### Goals

- Add built-in, local-only templates for Minimal, Balanced, Memory Saver, and Throughput-oriented launch settings.
- Apply templates only after an explicit button press.
- Preserve model identity, display name, host, port, notes, and backend.
- Limit templates to launch-option metadata; templates never start a server or download a model.
- Show the exact option changes before saving the profile.

### Completion criteria

- Templates are deterministic for both supported backends.
- Applying Minimal clears managed advanced options.
- Template application is covered by unit tests.
- Profile editor remains usable without selecting a template.

## v29.0.0 — Discovery Controls

### Goals

- Expand the existing explicit Hugging Face search surface with local filtering and sorting.
- Add sort modes for Recommended, Downloads, Likes, Recently Updated, and Name.
- Add a minimum-download filter and preserve the existing MLX-likely filter.
- Keep search network access explicit; changing filters must never trigger a request.
- Explain why a result is recommended or filtered.

### Completion criteria

- Discovery projection is implemented as a pure, testable policy.
- Result order is deterministic.
- Invalid or missing metadata is handled safely.
- Search selection and download remain explicit.

## v30.0.0 — Operational History

### Goals

- Promote the existing bounded in-memory runtime event stream into an operational history section on the Logs surface.
- Add event severity, optional model identity, and endpoint context while preserving compatibility with existing event calls.
- Add local category and severity filtering, copy, and clear actions.
- Record important explicit operations such as lifecycle requests, readiness checks, benchmark runs, profile changes, and download terminal outcomes.
- Keep history in memory only; do not add persistent file logging or external transmission.

### Completion criteria

- History remains bounded and copy-safe.
- Filters are deterministic and tested.
- Logs and history remain separate concepts.
- Recovery navigation to Logs displays both surfaces.

## Release Boundary

Implementation may reach a v30 release-candidate state while the stable version marker remains unchanged. Version, stable-scope, README release text, screenshots, tag, push, binary asset, and GitHub Release are updated only when explicitly requested after verification.
