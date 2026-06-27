# v23.0.2 GUI Cleanup and System Metrics

v23.0.2 cleans up the quick settings and Downloads surfaces, and improves SYSTEM hardware and storage display.

## Changes

- Removed the current language/theme summary from the bottom-left Settings button.
- Unified Language and Theme controls as menu-style dropdowns.
- Removed duplicate small labels above those controls.
- Removed the four-step Downloads explanation strip.
- Renamed Download environment to Download tools and clarified that it checks prerequisites, while search is for model discovery.
- Added GPU core count to the SYSTEM Processing row when available.
- Changed storage formatting to decimal GB/TB so it better matches macOS Settings capacity display.
- Updated the integrated footer version label to 23.0.2.

## Verification

- Debug build and test suite should pass before release.

## Direct Mode

Direct Mode remains unchanged. These are UI, diagnostics, and display-format updates only.
