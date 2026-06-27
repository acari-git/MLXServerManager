# v22.29.0 Chrome Settings Tests

v22.29.0 adds regression coverage for the saved app chrome preferences used by the refreshed GUI.

## Changes

- Added tests for default language and appearance values.
- Added a legacy settings decode test so older settings files continue to load.
- Added an encode/decode round-trip test for the new chrome preferences.
- Updated the integrated footer version label to 22.29.0.

## Verification

- Full test suite is expected for this quality pass before moving to v23.0.0.

## Direct Mode

Direct Mode remains unchanged. The new tests cover settings persistence only.
