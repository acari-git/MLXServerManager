# v22.25.0 English Mode Visible Text Cleanup

v22.25.0 fixes English-mode Japanese text leaks found in the integrated sidebar and right inspector.

## Implemented

- Localized system info row labels from `AppViewModel.systemInfoRows`.
- Localized system info fallback values such as `Unknown`.
- Localized Hugging Face download progress fallback text through `HuggingFaceDownloadPhase.localizedTitle(language:)`.
- Added English-mode branches for memory breakdown and uptime display text.
- Localized memory RSS summary text.
- Localized auto-unload minute text.
- Made English-mode safety row labels and values avoid the older Japanese-only conversion path in the right inspector.
- Added `EnglishModeVisibleTextTests` to fail when selected ViewModel-fed English UI text contains CJK characters.

## Verification

- Debug build passes.
- Test suite passes, including `EnglishModeVisibleTextTests`.
- `git diff --check` passes.
