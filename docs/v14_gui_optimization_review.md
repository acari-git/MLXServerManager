# v14 GUI Optimization Review

This document defines the v14.0.0 GUI optimization direction based on the app state through v13.0.0.

## Goal

v14.0.0 should make MLX Server Manager feel like a focused, polished model-management GUI while preserving Direct Mode.

```text
client -> mlx_lm.server
```

It should not become a chat app, proxy, multi-backend router, or request inspector.

## Reference direction

Use model-management patterns commonly seen in tools such as LM Studio and oMLX as product references, without copying their scope or adding unsupported runtime behavior.

Useful reference patterns:

- clear sidebar navigation
- model catalog / model list as the primary surface
- right-side detail inspector
- explicit download / run / stop controls
- visible runtime status
- copyable connection settings
- clear empty states
- compact logs and diagnostics
- local-first operation

Do not carry over these features into v14 unless explicitly scoped later:

- chat UI
- proxy mode
- multi-backend routing
- request rewriting
- telemetry
- automatic model deletion
- cache cleanup

## v13 GUI issues to address

The v13 Dashboard has grown feature-by-feature. It is functional but dense.

Primary issues:

1. Too many panels compete for attention.
2. Setup, search, download, runtime, benchmark, and connection are all visible at once.
3. Runtime diagnostics and benchmark cards need hierarchy.
4. Advanced profile details are useful but visually heavy.
5. Some labels mix Japanese and English inconsistently.
6. Language choice is not centralized.
7. First-time users need a simple path; advanced users need dense details.

## v14 information architecture

Recommended top-level layout:

```text
Sidebar
- Dashboard
- Models
- Downloads
- Runtime
- Settings
- Logs

Main content
- selected top-level workspace

Right inspector
- details for selected model / download / runtime target
```

Dashboard should become a concise overview, not the only place where every control lives.

## Dashboard target structure

```text
Top summary
- active target
- selected model
- runtime state
- latest benchmark
- primary action

Workflow cards
- Setup
- Search / Add model
- Start / Stop
- Benchmark
- Copy connection

Recent activity
- runtime timeline
- latest logs
```

## Models surface

The Models page should become the primary model-management page.

Required sections:

- searchable model list
- source filters
- selected / running status
- model detail inspector
- launch preview
- profile safety controls

## Downloads surface

Downloads should separate search/acquisition from runtime operation.

Required sections:

- Hugging Face search
- selected result preview
- download form
- queue/history
- recovery actions

## Runtime surface

Runtime should focus on diagnosis and measurement.

Required sections:

- current target
- start/stop/restart controls
- ready check
- speed test
- benchmark history
- profile comparison
- launch command preview
- failure guidance

## Language switching

v14.0.0 should support Japanese and English UI selection.

Minimum viable design:

- Add a `Language` setting with values:
  - `System`
  - `Japanese`
  - `English`
- Use a lightweight app-local string table or localization helper.
- Do not require OS language changes.
- Store the selected language in settings.
- Apply language consistently to primary labels, buttons, section titles, messages, and empty states.

Initial implementation can avoid translating deep diagnostic raw logs. User-authored values, model names, paths, CLI output, and command previews should remain unchanged.

## Suggested implementation stages

### v13.1.0 UI inventory

- Inventory all visible strings.
- Identify mixed-language labels.
- Classify UI strings by surface.

### v13.2.0 localization foundation

- Add language enum.
- Add settings field.
- Add string lookup helper.
- Add tests for language selection fallback.

### v13.3.0 app shell redesign foundation

- Redesign sidebar and top-level navigation.
- Move dense controls out of Dashboard.

### v13.4.0 Models page redesign

- Make model list and detail inspector the primary model-management surface.

### v13.5.0 Downloads page redesign

- Separate Hugging Face search, preview, form, and queue into a dedicated page.

### v13.6.0 Runtime page redesign

- Move diagnostics and benchmark into a dedicated runtime page.

### v13.7.0 Dashboard overview redesign

- Convert Dashboard into a compact overview and action launcher.

### v13.8.0 Japanese / English string coverage

- Translate primary UI strings.
- Keep logs and user content raw.

### v13.9.0 v14 readiness stabilization

- Manual review of Japanese and English layouts.
- Accessibility and truncation pass.
- README screenshots and release notes prep.

### v14.0.0 GUI Optimization Milestone

- Release the redesigned GUI foundation with language switching.

## Acceptance criteria for v14.0.0

- Users can choose Japanese or English in Settings.
- Dashboard is no longer overloaded.
- Models, Downloads, Runtime, Settings, and Logs have clearer ownership.
- Primary workflows remain obvious:
  - add model
  - start server
  - run benchmark
  - copy connection settings
- Direct Mode remains unchanged.
- No chat UI or proxy behavior is introduced.
