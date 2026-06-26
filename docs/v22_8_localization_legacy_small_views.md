# v22.8.0 Localization Legacy Small Views

v22.8.0 continues the language cleanup for smaller legacy and supplemental views.

## Implemented

- Localized `ModelDetailView` labels, state messages, and detail grid labels.
- Localized `DashboardHomeView` summary cards, action buttons, and explanatory text.
- Localized `DiagnosticsPanelView` header, copy action, summary labels, and empty state.
- Localized `DetailInspectorSurfaceView` header, summary cards, selected profile details, availability panel, connection target labels, boundary note, and empty state.

## Notes

These views are secondary or legacy-adjacent, but they are still compiled and can appear from the older dashboard path. Product, protocol, model, path, command, and raw technical values remain unchanged.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
