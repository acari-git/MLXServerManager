# v23.0.0 Integrated GUI Refresh

v23.0.0 completes the current GUI refresh for the integrated workspace.

## Included work

- Bottom-left Settings popover for language and theme.
- Saved app chrome preferences in `AppSettings`.
- Downloads command-center deck with queue and progress summary.
- Logs command-center deck with troubleshooting context.
- Right-side Operations Inspector for selected model, connection, recovery, and agent copy values.
- Workspace overview strip for Models, Downloads, Logs, and Settings.
- Model-list empty state with direct next actions.
- Regression tests for chrome settings persistence and legacy settings decode.

## Verification

- Debug build passed during v22.28.0.
- Full test suite passed during v22.29.0.
- v23.0.0 should be built as the release checkpoint before packaging.

## Release settings

```text
Tag: v23.0.0
Title: MLXServerManager v23.0.0
Asset: MLXServerManager-v23.0.0.zip
Pre-release: No
```

## Direct Mode

Direct Mode remains unchanged. MLX Server Manager still does not proxy inference requests, rewrite requests, provide chat UI, or route across multiple backends.
