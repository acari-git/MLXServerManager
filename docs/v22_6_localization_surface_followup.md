# v22.6.0 Localization Surface Follow-up

v22.6.0 continues the language cleanup beyond the primary integrated workspace.

## Implemented

- Localized `LogView` and `LogsSurfaceView` while preserving raw log contents unchanged.
- Passed the selected UI language from the integrated workspace into the Logs surface.
- Localized `ConnectionSettingsView` copy actions, explanatory text, and connection metadata labels.
- Localized `ClientSetupSurfaceView` headers, Direct Mode explanations, copy-scope guidance, and safety boundary text.
- Localized `RuntimeSurfaceView` headers, runtime detail rows, Ready Check, benchmark copy actions, timeline label, and connection copy buttons.
- Localized `ProfilesSurfaceView` headers, toolbar actions, summary cards, empty states, profile state pills, metadata labels, inspector labels, and profile safety note.

## Preserved English text

The following remain intentionally unchanged where they are product, protocol, model, or command terms:

- MLX
- mlx_lm.server
- Hugging Face
- Hermes
- OpenAI-compatible
- Direct Mode
- Base URL
- API Key
- Model ID
- curl
- `/v1/models`

## Remaining work

- `UnifiedDashboardView` is an older unused surface and still contains many fixed strings.
- Smaller legacy views still have a few fixed strings: import preview, detail inspector, model list/detail, dashboard home/overview, diagnostics panel, and integrated recovery panel.
- `AppViewModel` still contains user-facing status summaries mixed with raw logs and command output. A later pass should split localizable UI text from raw technical output.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
