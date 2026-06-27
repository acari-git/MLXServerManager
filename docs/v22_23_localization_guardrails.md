# v22.23.0 Localization Guardrails

v22.23.0 adds a regression guard for user-facing localization.

## Implemented

- Localized `OnboardingGuidanceView`'s `Next` label.
- Passed the active UI language into `OnboardingGuidanceView`.
- Localized the legacy `ModelListView` labels and guidance text.
- Passed the active UI language into `ModelListView`.
- Added `LocalizationDirectStringTests` to detect new direct SwiftUI strings in view code.

## Guardrail behavior

The new test scans SwiftUI view files for direct string literals in common UI constructors such as `Text`, `Button`, `Label`, `Picker`, `TextField`, `Toggle`, `ContentUnavailableView`, and `accessibilityLabel`.

Known technical placeholders, app names, dynamic values, and currently quarantined legacy strings are explicitly allowlisted. New user-facing strings should use `AppLocalization`, `l10n.text`, `strings.text`, or `t(...)` instead of direct literals.

## Notes

`MetricsSystemContextSurfaceView.swift` has no non-definition references in the current app search and remains an unused-view cleanup candidate for a later quarantine/delete pass.

## Verification

- Debug build passes.
- Test suite passes, including the new localization direct-string test.
- `git diff --check` passes.
