# v25 Apple UI Audit

## Reference Basis

This audit uses Apple Human Interface Guidelines pages provided by the user and the current official Apple HIG direction as the design baseline:

- Human Interface Guidelines
- Designing for macOS
- Materials
- Sidebars
- Typography
- Color
- Layout
- Scroll views
- Search fields
- Menus
- Accessibility

The working interpretation for MLX Server Manager is:

- Prefer native SwiftUI/AppKit controls over custom drawn controls.
- Use semantic system text styles before custom point sizes.
- Use system colors and materials before app-defined color plates.
- Use sidebar/inspector materials for peripheral panes.
- Keep content dense, quiet, and operational because this is a local server manager, not a marketing page.

## Current Implementation Shape

- App shell: `NavigationSplitView` plus a SwiftUI inspector.
- Main model list: native `Table` with custom cell content.
- Right inspector: custom SwiftUI content, now backed by `NSVisualEffectView` sidebar material.
- Settings, Downloads, and Logs surfaces: custom ScrollView-based sections with rounded group containers.
- Test Chat: deliberately small diagnostic surface for endpoint/model-load testing, not a chat app.
- Process, port, ready, memory, downloads, and Hermes config writes remain outside SwiftUI views.

## First-Pass Fixes Applied

- Replaced the highest-impact custom font sizes in the main workspace, sidebar, settings, downloads, and logs surfaces with semantic styles such as `title3`, `headline`, `callout`, and `caption`.
- Removed `light` and `ultraLight` weights from the primary surfaces because they reduce readability in Japanese and dark appearance.
- Changed the main sidebar rows from gesture-only rows to real SwiftUI `Button` controls.
- Added lightweight hover feedback for sidebar rows using system selection colors.
- Changed the right inspector background from a flat window color to sidebar material.

## Still To Refine

- Replace custom settings/downloads/logs section containers with more native `Form`, `Section`, `Table`, or `List` structure where practical.
- Keep custom model status control only if a standard button cannot express loaded/loading/unloaded states clearly.
- Keep the Test Chat bubbles as an exception because they are diagnostic transcript content, but avoid expanding them into full chat UI.
- Continue reducing hard-coded padding and widths where native controls can own their layout.
- Recheck dark mode, Japanese labels, English labels, and narrow window behavior after each batch.

## Guardrails

- Do not add proxy mode while applying UI polish.
- Do not move process, port, pipe, or polling logic into SwiftUI views.
- Do not hardcode user-specific paths.
- Do not remove the Direct Mode boundary.
