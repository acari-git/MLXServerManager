# v22.16.0 Localization Dashboard Profile Import Export

v22.16.0 completes the remaining Dashboard Overview card localization work.

## Implemented

- Passed the active UI language into `DashboardProfileImportExportCard` and `DashboardProfileImportExportDisplay`.
- Localized the Dashboard `Profiles & Import / Export` card title.
- Localized key labels:
  - Selected Profile / 選択プロファイル
  - Profile Endpoint / プロファイルエンドポイント
  - Current Target / 現在の接続先
  - Relationship / 関係
  - Export / エクスポート
  - Import / インポート
- Localized selected-profile metadata text, no-profile fallback text, endpoint relationship text, export summary, import summary, and safety note.

## Preserved text

Technical values such as Model ID, endpoint host/port, and saved export summary counts remain unchanged.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
