# v22.28.0 Empty State Guidance

v22.28.0 improves the integrated workspace when no model rows are visible.

## Changes

- Added a model-list empty state.
- Added direct actions to add a local model or open Downloads.
- Updated the integrated footer version label to 22.28.0.

## Verification

- Debug build passed with `xcodebuild -project MLXServerManager.xcodeproj -scheme MLXServerManager -configuration Debug CODE_SIGNING_ALLOWED=NO build`.

## Direct Mode

Direct Mode remains unchanged. These actions only open existing profile and download workflows.
