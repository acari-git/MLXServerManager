# v22.1.0 Launch Settings Alignment

v22.1.0 aligns the model Thinking toggle with the managed launch command and command preview.

## Implemented

- Added `enableThinking` to `ModelLaunchRequest`.
- Updated managed launches, profile editor previews, and launch command previews to pass the same value.
- Kept the app from generating a non-existent `--enable-thinking` flag.
- Mapped the Thinking toggle to `--chat-template-args` with `enable_thinking` true or false.
- Preserved explicit Advanced Launch Options precedence: manually set `chatTemplateArgs` overrides the Thinking toggle output.
- Updated launch command tests for Thinking toggle mapping and explicit override behavior.

## Verification

- Debug build passes.
- Test suite passes.
