# v22.2.0 UI Layout Review

v22.2.0 prepares the integrated workspace for screenshot comparison and final visual review.

## Review points

- Settings is shown in the lower sidebar above the `MLX Server Manager` footer.
- Appearance is shown inside Settings and is not duplicated in the right panel.
- SYSTEM shows total CPU count only, such as `14 CPU`.
- Model list uses `ポート/IPアドレス` and displays `host:port`.
- Model list uses `モデル管理` for row actions.
- Per-model edit action is labeled `設定`.
- Right model panel shows `基本情報` before `安全性`.
- Safety copy action is not shown in the model panel.

## Screenshot anchors

- `integrated-sidebar-settings-footer`
- `settings-appearance-panel`
- `integrated-model-list-header`
- `integrated-model-basic-info-section`
- `integrated-model-safety-section`
- `integrated-model-port-section`

## Verification

- Debug build should pass.
- Test suite should pass.
- `git diff --check` should pass.
