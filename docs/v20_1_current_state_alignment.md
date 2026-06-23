# v20.1.0 Current State Alignment

v20.1.0 is a documentation-only alignment release after the v20.0.0 Daily Operations Stable app-code release.

## Goal

Align current public documentation with implemented v20 behavior without changing app code, runtime behavior, Direct Mode, or release assets.

## Aligned Areas

- Document that `v20.0.0` remains the latest app-code zip asset.
- Document that `v20.1.0` is docs-only and does not replace the downloadable app binary.
- Update the current feature set from the old v5.9 baseline to the v20.x state.
- Clarify that Hugging Face search and explicit download by model ID / URL are implemented convenience features.
- Keep model-card browsing, HF token storage, model deletion, cache cleanup, and silent/background downloads out of scope.
- Refresh Known Limitations so current limitations describe v20.x behavior instead of older planning boundaries.
- Preserve historical planning documents as historical references rather than editing every old version-specific non-goal list.

## Safety Boundary

This release does not add:

- Swift source behavior changes,
- process-management changes,
- inference proxying,
- Chat UI,
- hidden request rewriting,
- automatic server start after download,
- model file deletion,
- Hugging Face cache cleanup,
- credential storage,
- telemetry,
- background monitoring,
- a new app zip asset.

The inference path remains:

```text
OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model
```

## Verification

Expected verification for this docs-only release:

- `xcodebuild -project MLXServerManager.xcodeproj -scheme MLXServerManager -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild test -project MLXServerManager.xcodeproj -scheme MLXServerManager -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
- Confirm no source behavior changes are included.
- Confirm no new `dist/MLXServerManager-v20.1.0-unsigned.zip` asset is produced.
