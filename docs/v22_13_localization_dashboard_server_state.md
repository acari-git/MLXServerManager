# v22.13.0 Localization Dashboard Server State

v22.13.0 continues localization for the older Dashboard Overview surface.

## Implemented

- Passed the active UI language into `DashboardServerStateCard`.
- Localized the Dashboard `Server State` card title.
- Localized `Server State` key labels:
  - Process State / プロセス状態
  - Readiness / 準備状態
  - Lifecycle / ライフサイクル
  - Memory / メモリ
- Localized the restart-required note.
- Localized `DashboardServerStateDisplay` text for runtime states:
  - stopped
  - starting
  - loading
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

Raw technical values such as pid numbers, host/port pairs, `/v1/models`, and `mlx_lm.server` remain unchanged.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
