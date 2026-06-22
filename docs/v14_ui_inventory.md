# v14 UI Inventory

This inventory captures the v13.0.0 GUI before the v14 optimization pass.

## Current visible surface count

- SwiftUI view files: 19
- Top-level sidebar sections: 6
- Dashboard remains the densest surface.
- Approximate visible text/button/label usage in `Views`: 393 occurrences.

## Current top-level navigation

- Dashboard
- Profiles
- Inspector
- Logs
- Client Setup
- Metrics

## v14 target top-level navigation

- Dashboard
- Models
- Downloads
- Runtime
- Settings
- Logs

## Surface ownership plan

### Dashboard

Current state: contains too many controls and details.

v14 target: overview and action launcher only.

Keep:

- active target summary
- selected/running model summary
- latest benchmark
- recent timeline/log summary
- primary next actions

Move out:

- full Hugging Face search
- full download queue
- detailed runtime diagnostics
- detailed launch command preview
- dense connection presets

### Models

Current state: split between Profiles and Inspector.

v14 target: primary model management page.

Owns:

- profile list
- source filters
- selected/running badges
- selected model inspector
- launch command preview
- advanced launch options preview
- metadata-only profile deletion safety

### Downloads

Current state: mostly inside Unified Dashboard.

v14 target: model acquisition page.

Owns:

- Hugging Face search
- MLX-like filtering
- selected search result preview
- download form
- save-directory picker
- download queue
- retry / restore / copy URL recovery actions

### Runtime

Current state: mixed into Dashboard and Metrics.

v14 target: runtime operation and diagnostics page.

Owns:

- start / stop / restart
- ready check
- speed test
- runtime metrics
- benchmark history
- profile comparison
- runtime timeline
- failure guidance

### Settings

Current state: basic executable path setting only.

v14 target: app configuration and language settings.

Owns:

- executable path
- default host / port
- API key placeholder
- language selection
- diagnostics action

### Logs

Current state: logs surface exists.

v14 target: log review and troubleshooting context.

Owns:

- log list
- category filter
- latest important log
- copy / clear logs

## Localization inventory

Primary UI strings should be routed through a small localization helper before v14.0.0.

Priority groups:

1. Sidebar section titles and subtitles
2. Dashboard overview labels
3. Settings labels
4. Primary buttons
5. Empty states
6. Guidance cards

Out of scope for translation:

- model IDs
- Hugging Face repository IDs
- file paths
- command previews
- raw CLI output
- raw logs

## v14 acceptance

- Dashboard is an overview, not the full workbench.
- Models / Downloads / Runtime / Settings / Logs have clear ownership.
- Sidebar labels are clear in Japanese and English.
- Language can be selected from Settings.
- Direct Mode remains unchanged.
