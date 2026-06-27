# v22.26.0 Quick Settings Finish

v22.26.0 finishes the bottom-left quick settings pass that started the non-model-list GUI refresh.

## Changes

- Persisted the app appearance setting alongside language and accent color.
- Moved the integrated workspace theme source from local view state to saved `AppSettings`.
- Kept the bottom-left Settings menu as the single place for language, color, and theme changes.
- Connected the Downloads completion action back to the Models workspace.
- Removed the obsolete Downloads workflow card now covered by the command-center deck.
- Removed the unused Settings appearance panel after moving appearance controls to the sidebar footer.
- Updated the integrated footer version label to 22.26.0.

## Verification

- Debug build passed with `xcodebuild -project MLXServerManager.xcodeproj -scheme MLXServerManager -configuration Debug CODE_SIGNING_ALLOWED=NO build`.

## Direct Mode

Direct Mode remains unchanged. The app still keeps client traffic direct to `mlx_lm.server`; no proxying, request rewriting, chat UI, or backend routing was added.
