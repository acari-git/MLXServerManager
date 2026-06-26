# v22.9.0 Localization Import Preview

v22.9.0 localizes the profile import preview flow.

## Implemented

- Added active UI language support to `ImportProfilesPreviewView`.
- Passed the app UI language from `ContentView` into the import preview sheet.
- Localized import preview header, document summary labels, profile section labels, action picker labels, buttons, rename controls, replace controls, confirmation dialog text, validation messages, and safety notes.
- Preserved raw technical values unchanged: model IDs, endpoints, source file names, schema keys, app metadata, and internal conflict summaries.

## Remaining work

- `UnifiedDashboardView` and larger legacy dashboard surfaces still contain fixed strings.
- `AppViewModel` still mixes raw logs, diagnostics text, recovery text, and user-facing status text. A later pass should split user-facing display strings from raw technical output.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
