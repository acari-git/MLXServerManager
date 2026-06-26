# v22.10.0 Localization Dashboard Overview

v22.10.0 starts localization work on the older Dashboard Overview surface.

## Implemented

- Added active UI language support to `DashboardOverviewView`.
- Passed the app UI language from `ContentView` into the Dashboard Overview.
- Localized the Dashboard Overview section title and subtitle.
- Localized the top-level Dashboard Overview group headers:
  - Next action / 次の操作
  - Target and state / 接続先と状態
  - Client setup / クライアント設定
  - Troubleshooting / トラブルシューティング
  - Profile context / プロファイル情報

## Deferred

`DashboardOverviewView` is a large legacy-adjacent surface with embedded display-model strings. A later pass should localize its card-level display structs in smaller chunks:

- `DashboardNextStepsDisplay`
- `DashboardCurrentTargetDisplay`
- `DashboardServerStateCard`
- `DashboardClientSetupCard`
- `DashboardDiagnosticsGuidanceCard`
- `DashboardProfileImportExportCard`

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
