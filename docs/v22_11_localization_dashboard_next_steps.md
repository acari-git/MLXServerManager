# v22.11.0 Localization Dashboard Next Steps

v22.11.0 continues localization for the older Dashboard Overview surface.

## Implemented

- Localized the Dashboard `Next Steps` card title.
- Localized `Next Steps` key labels:
  - Primary Step / 主な手順
  - Selected Profile / 選択プロファイル
  - Managed Path / 管理サーバー経路
  - External Path / 外部サーバー経路
  - Readiness / 準備状態
- Passed the active UI language into `DashboardNextStepsDisplay`.
- Localized main `Next Steps` display text for common runtime states:
  - stopped / port available
  - external server detected
  - adopted external server
  - starting / loading / checking ready
  - ready
  - stopping
  - checking port
- Localized selected-profile and managed-start fallback text.

## Deferred

The remaining Dashboard Overview cards still have display-model strings to localize in smaller units:

- Current Target
- Server State
- Client Setup
- Diagnostics Guidance
- Profile Import / Export

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
