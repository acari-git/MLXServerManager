# v22.7.0 Localization Recovery Follow-up

v22.7.0 continues the localization cleanup with the integrated recovery panel.

## Implemented

- Localized the integrated Recovery panel title.
- Localized Recovery panel footer actions:
  - Refresh Safety / 安全性を更新
  - Copy Troubleshooting / トラブルシューティングをコピー
- Passed the active UI language from the integrated workspace into the recovery panel.

## Notes

Recovery issue titles, details, and action text still come from the recovery model and ViewModel layer. Those strings need a later ViewModel localization split so raw technical output and user-facing messages are separated cleanly.

## Deferred

Several legacy views still contain fixed strings. Some structural edits were blocked by the tool safety layer during this pass, so the next safe unit should focus on one file at a time:

- ImportProfilesPreviewView
- ModelListView
- ModelDetailView
- DetailInspectorSurfaceView
- DiagnosticsPanelView
- DashboardHomeView
- UnifiedDashboardView

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
