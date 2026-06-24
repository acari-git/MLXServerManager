# v22.0.0 Daily Workflow Stabilization

v22.0.0 focuses on making the integrated workspace easier to use as a daily GUI for model download, model management, server lifecycle, and client setup.

## Scope

- Keep Direct Mode direct: clients connect to the active server endpoint.
- Keep model download, model management, logs, settings, and runtime controls separated by surface.
- Reduce ambiguous labels and move settings to a clearer location.
- Improve the Hugging Face download flow from search to preview to download.

## Implemented

- Moved Settings out of the main MENU list and into the lower sidebar area above the app name.
- Moved Appearance into the Settings surface.
- Simplified SYSTEM processing text to total CPU count only, such as `14 CPU`.
- Renamed per-model `編集` to `設定`.
- Renamed `サーバーポート` to `ポート/IPアドレス`.
- Renamed `操作` to `モデル管理`.
- Removed the `安全性の概要をコピー` button from the model detail panel.
- Reordered model detail sections so 基本情報 appears before 安全性.
- Added clearer model configuration guidance and restart-required status.
- Added recent logs to the recovery panel.
- Added a download workflow card for search, preview, download, model registration, startup, and connection-copy flow.
- Added Hugging Face download filter presets for MLX-style and safetensors-focused downloads.

## Verification

- Debug build passes.
- `git diff --check` passes.

## Still intentionally out of scope

- Inference proxying.
- Chat UI.
- Multi-backend request routing.
- Request rewriting.
- Model file deletion.
