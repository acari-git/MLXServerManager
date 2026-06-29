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

## Second-Pass Fixes Applied

- Replaced hand-drawn Settings, Downloads, and Logs section containers with standard SwiftUI `GroupBox`.
- Removed custom rounded rectangle strokes from those section containers.
- Removed custom capsule decoration from the Logs summary metadata.
- Replaced the read-only Settings folder display with a disabled rounded `TextField` instead of a hand-drawn text container.

## Third-Pass Fixes Applied

- Replaced the model status pseudo-button with a real SwiftUI `Button`.
- Kept the instant hover text change while moving the control interaction to standard button semantics.
- Used standard bordered/prominent button styles and system tinting for unloaded and loaded states.

## Fourth-Pass Fixes Applied

- Replaced the hand-highlighted Hugging Face search result stack with an inset `List`.
- Removed the custom selected-row rounded rectangle from Hugging Face search results.
- Kept a lightweight checkmark symbol for the selected search result because the selection updates a form outside the list.

## Fifth-Pass Fixes Applied

- Replaced the Test Chat send button's hand-drawn circular styling with a standard bordered prominent icon button.
- Kept the custom `NSTextView` bridge for Test Chat input because it protects Japanese marked-text composition.

## Sixth-Pass Fixes Applied

- Replaced the Hugging Face file preview's custom checkmark button with a standard SwiftUI checkbox `Toggle`.

## Remaining Exceptions

These are intentionally left as small custom UI areas for now:

- Sidebar selection rows: kept as custom `Button` rows because the sidebar mixes navigation, live system metrics, and a footer settings entry rather than a simple `List`.
- Sidebar footer settings row: kept aligned with the same sidebar selection treatment as the main navigation rows.
- Memory usage bar: kept as a custom three-segment visualization because standard `ProgressView` does not represent MLX, other processes, and available memory in one compact control.
- Test Chat transcript bubbles and composer shell: kept because this is a diagnostic transcript surface, and the custom `NSTextView` bridge is required to avoid Japanese marked-text loss.
- Model table name cell tap/drop area: kept to preserve row selection and drag/drop reorder behavior inside the native `Table`.
- Inspector copy rows: kept as compact plain buttons so connection values remain selectable-looking and copyable without adding repeated large controls.

## Still To Refine

- Consider a larger sidebar refactor to a native `List(selection:)` if the sidebar structure becomes simpler.
- Keep the Test Chat bubbles as an exception because they are diagnostic transcript content; avoid expanding them into full chat UI.
- Continue reducing hard-coded padding and widths where native controls can own their layout.
- Recheck dark mode, Japanese labels, English labels, and narrow window behavior after each batch.

## Guardrails

- Do not add proxy mode while applying UI polish.
- Do not move process, port, pipe, or polling logic into SwiftUI views.
- Do not hardcode user-specific paths.
- Do not remove the Direct Mode boundary.
