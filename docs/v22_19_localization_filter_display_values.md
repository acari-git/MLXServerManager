# v22.19.0 Localization Filter Display Values

v22.19.0 separates internal filter values from localized display labels.

## Implemented

- Added localized display helpers for model source filters.
- Updated the Profiles surface to show localized source labels while keeping filter tags stable.
- Added a localized display helper for the log category filter.
- Updated the integrated log panel to show localized `All` while keeping the raw filter value stable.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
