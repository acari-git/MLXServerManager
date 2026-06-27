# v22.19.0 AppViewModel UI Message Split

v22.19.0 starts separating user-facing `AppViewModel` status text from raw logs, command output, and technical values.

## Implemented

- Added localized helper methods for low-risk default UI messages:
  - Hugging Face access default message
  - Hugging Face CLI default message
  - local model add helper message
  - Hugging Face search helper message
  - Speed Test default message
  - Not checked / 未確認
- Replaced stored-property default English literals with helper-backed values.
- After settings load, default UI messages are refreshed using the active UI language.
- When settings are saved, default UI messages are refreshed using the active UI language.
- Localized Hugging Face access saved / missing messages.
- Localized Hugging Face CLI availability messages.
- Localized Hugging Face access and search input-required validation messages.

## Preserved raw output

The following remain intentionally raw or technical:

- `initialLogLines`
- `appendLog(...)` log entries
- `appendRuntimeEvent(...)` event details
- command paths
- host/port strings
- `/v1/models`
- `hf CLI` lookup details

## Remaining work

Later passes should continue splitting user-facing text from raw output for:

- download status messages
- profile import/export result messages
- recovery issue messages
- diagnostics summary text
- benchmark and speed test result messages
- model availability summary text

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
