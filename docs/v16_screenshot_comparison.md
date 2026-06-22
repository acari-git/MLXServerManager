# v16 Screenshot Comparison Review

Reference screenshot target:

- left top menu
- left bottom system metrics
- center top model list
- center action bar
- center bottom logs
- right top selected model settings
- right bottom Hermes Agent connection information

## v16 implemented layout

`IntegratedWorkspaceView` now implements the same primary information architecture:

```text
left column
- MENU
- SYSTEM
- footer/version

center column
- モデル一覧
- action bar: 起動 / 停止 / 再起動 / スピードテスト
- ログ

right column
- モデル設定
- Hermes Agent 接続情報
```

## Match assessment

### Structural match

- Left menu: matched.
- Left system metrics: matched structurally. Memory gauge is implemented; CPU/GPU are GUI-first placeholders.
- Center model list: matched structurally with status, ports, memory, last-used, auto-unload placeholder.
- Center action bar: matched.
- Center logs: matched.
- Right model settings: matched structurally with basic information, ports, behavior, and status sections.
- Right Hermes connection panel: matched structurally with Base URL / API key / model / copy actions.

### Known non-pixel-perfect areas

- CPU/GPU sampling is placeholder data.
- Automatic unload is GUI-first and not yet backed by runtime scheduling.
- Proxy port is derived visually as `serverPort + 10000` for the integrated shell.
- Model-specific memory and last-used values are partly placeholders when the runtime does not provide those values.
- Pixel-perfect colors, spacing, and table column widths may still differ from the provided mockup.

## Conclusion

v16.0.0 reaches the requested integrated GUI structure. Remaining differences are mostly data wiring and pixel-level polish, not layout architecture.

Recommended future polish, if needed after user review:

- v16.1.0: exact table column width tuning
- v16.2.0: real CPU/GPU/Metal sampling
- v16.3.0: model-specific memory and last-used metrics
- v16.4.0: auto-unload scheduler wiring
- v16.5.0: proxy port/runtime model wiring
