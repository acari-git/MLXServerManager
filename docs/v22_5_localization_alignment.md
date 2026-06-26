# v22.5.0 Localization Alignment

v22.5.0 begins the language cleanup for the current integrated UI.

## Implemented

- Added a direct English/Japanese text helper to `AppLocalization`.
- Corrected mixed Japanese labels in existing `AppTextKey` values.
- Localized integrated workspace destinations so the sidebar can switch between English and Japanese.
- Localized the integrated sidebar menu header.
- Localized the Downloads surface labels, button text, help text, workflow text, status labels, and queue labels.
- Localized the Settings surface labels, appearance controls, scope notes, and settings form labels.
- Localized Hugging Face download phase titles.
- Updated the integrated workspace version label to 22.5.0.

## Japanese wording policy

- Keep product and protocol names in English: MLX, mlx_lm.server, Hugging Face, Hermes Agent, OpenAI, Direct Mode, Base URL, API Key, Model ID, vLLM, Rapid-MLX, LM Studio, Ollama, curl, JSON, HF, aria2c.
- Use common Japanese katakana for UI terms: モデル, プロファイル, ランタイム, ログ, ダウンロード, プリセット, キャッシュ, ベンチマーク, トラブルシューティング, クライアント, サーバー, ポート, ステータス, メタデータ, ローカル, プレビュー, フィルター, キュー, セッション.
- Use Japanese sentences for explanatory text in Japanese mode.

## Follow-up pass

A follow-up pass also localized the visible `ContentView` dialogs, menu bar actions, status panel, profile editor labels, integrated workspace right panel, logs panel labels, model table headers, and model settings panel labels.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.

## Remaining work

- `UnifiedDashboardView` and other older unused surfaces still contain mixed fixed strings. Current app entry uses `IntegratedWorkspaceView`, so these are lower priority unless re-enabled.
- Some ViewModel-provided status/log strings remain English. Raw logs, command output, model IDs, paths, and protocol names should stay unchanged; user-facing status summaries should be separated and localized in a later pass.
