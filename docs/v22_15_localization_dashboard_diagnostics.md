# v22.15.0 Localization Dashboard Diagnostics Guidance

v22.15.0 continues localization for the older Dashboard Overview surface.

## Implemented

- Passed the active UI language into `DashboardDiagnosticsGuidanceCard` and `DashboardDiagnosticsGuidanceDisplay`.
- Ensured `DashboardClientSetupCard` receives the active UI language from `DashboardOverviewView`.
- Localized the Dashboard `Diagnostics & Logs Guidance` card title.
- Localized `Diagnostics & Logs Guidance` key labels:
  - Next Step / 次の手順
  - Readiness / 準備状態
  - Logs / ログ
  - Automation / 自動化
- Localized diagnostics/logs guidance text for runtime states:
  - stopped
  - starting / loading
  - ready
  - stopping
  - checkingPort
  - portAvailable
  - portBusy
  - externalServerDetected
  - adoptedExternalServer
  - portCheckFailed
  - checkingReady
  - readyCheckFailed
  - error
  - unknown

## Preserved text

Technical terms such as `/v1/models`, OpenAI-compatible, Direct Mode, host/port pairs, and process ownership language remain unchanged where they are technical identifiers or protocol names.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
