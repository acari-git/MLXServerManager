# v22.14.0 Localization Dashboard Client Setup

v22.14.0 continues localization for the older Dashboard Overview surface.

## Implemented

- Passed the active UI language into `DashboardClientSetupCard` and `DashboardClientSetupDisplay`.
- Localized the Dashboard `Client Setup` card title.
- Localized `Client Setup` key labels:
  - Client Base URL / クライアントBase URL
  - Model ID Guidance / Model IDガイド
  - Endpoint Source / エンドポイント元
  - Readiness Before Client Use / 利用前のReady確認
  - Profile Endpoint / プロファイルエンドポイント
  - Copy From / コピー元
- Localized client setup display text for runtime states:
  - detected external server
  - adopted external server
  - ready endpoint
  - starting / loading / checking ready
  - stopped / port available
  - port busy / failed / error / unknown
  - checking port
  - stopping
- Localized endpoint relationship and model ID guidance helper text.

## Preserved text

Technical values such as Base URL, Model ID, host/port, `/v1/models`, JSON, curl, API Key, Hermes Agent, and Direct Mode remain unchanged where they are product, protocol, command, or configuration terms.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
