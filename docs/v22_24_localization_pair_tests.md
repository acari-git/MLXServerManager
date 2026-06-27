# v22.24.0 Localization Pair Tests

v22.24.0 strengthens AppLocalization guardrails so new user-facing text requires both English and Japanese values.

## Implemented

- Made `AppTextKey` conform to `CaseIterable`.
- Added `LocalizationPairTests`.
- Verified every `AppTextKey` has non-empty English and Japanese text.
- Verified `AppTextKey` values do not accidentally reuse identical English and Japanese strings.
- Scanned inline localization calls to ensure `english:` and `japanese:` arguments are both present and non-empty.

## Scope

This does not auto-translate text. It makes missing or one-sided localization easier to catch in tests.

## Verification

- Debug build passes.
- Test suite passes, including `LocalizationPairTests`.
- `git diff --check` passes.
