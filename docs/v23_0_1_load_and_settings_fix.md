# v23.0.1 Load and Settings Fix

v23.0.1 fixes a start-button regression found after the v23.0.0 GUI refresh.

## Changes

- Fixed model start availability so it uses actual executable, model path, and port state instead of localized display text.
- Removed the user-facing color setting from the bottom-left settings control.
- Changed the bottom-left settings control from a menu to a popover that opens upward from the footer.
- Kept language and theme in the quick settings popover.
- Removed `uiAccentColor` from `AppSettings` and updated related tests and documentation.
- Added a regression test that confirms a valid local model can start even when UI language is English.
- Updated the integrated footer version label to 23.0.1.

## Verification

- Debug build passed.
- Full test suite passed.

## Direct Mode

Direct Mode remains unchanged. The fix only changes UI settings and start-button availability checks.
