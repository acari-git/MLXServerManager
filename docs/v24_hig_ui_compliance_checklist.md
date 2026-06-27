# v24 HIG UI Compliance Checklist

This checklist translates the uploaded Apple Human Interface Guidelines, macOS design, accessibility, layout, materials, typography, sidebars, search fields, menus, and scroll view references into concrete rules for MLX Server Manager.

## Product constraints

- Keep Direct Mode direct: the app launches, stops, monitors, and displays connection details for `mlx_lm.server`; it does not proxy inference requests.
- Keep the integrated model-management workspace as the primary task surface.
- Treat the test chat surface as a direct endpoint test client, not as the product's main identity.

## Window and chrome

- Use SwiftUI window structure first; avoid AppKit titlebar decoration unless it is only enabling standard hidden-titlebar behavior.
- The visible window should not contain a custom titlebar band.
- Traffic light controls must remain standard macOS controls.
- Panel visibility controls belong in the content chrome/sidebar/inspector, not as an artificial titlebar overlay.
- The window must stay useful when resized; side and bottom panels may collapse automatically.

## Sidebar

- The left panel should read as a macOS sidebar: compact rows, clear selected state, subtle material, and no card-like overdecoration.
- Leave top breathing room for traffic lights in a hidden-titlebar/full-size-content window.
- Navigation labels should be concise and localized.
- Selection must be conveyed by shape/text/icon, not color alone.
- Downloads progress should remain visible from the sidebar when active.

## Content area

- The center pane is the primary work area. Models remain the dominant surface.
- Headers should be functional, not ornamental.
- The model list should preserve column clarity and adapt to available width.
- Empty states must provide next actions.
- Bottom operations/log/test panels are secondary and may be hidden when space is constrained.

## Inspector

- The right panel should behave like an inspector for the selected model and connection context.
- It should avoid dashboard-style hero cards unless they help the selected item.
- Sections should be collapsible, grouped, and scannable.
- Values that users need to copy should support text selection or copy actions.

## Materials and Liquid Glass

- Use material to express hierarchy, not as decoration.
- Sidebar material should be calmer than content cards.
- Content cards should use subtle elevation; avoid stacking multiple strong glass effects.
- Text contrast has priority over transparency.
- Reduce visual noise in dense utility areas like logs and settings.

## Color and status

- Status must not rely on color alone. Pair color with text and/or SF Symbols.
- Error, warning, ready, running, and stopped states should remain readable in light and dark mode.
- Accent color should highlight selection and primary action only.

## Typography

- Use system typography.
- Use clear hierarchy: pane title, section title, row label, value, secondary explanation.
- Avoid tiny text for operationally important values such as port, model ID, and status.
- Logs can use monospaced text, but should not dominate the main model-management surface.

## Search fields and filters

- Search fields should look like search fields, not generic text boxes.
- Placeholder text should describe the target, such as models or logs.
- Filtering should be reversible and visibly active.

## Menus and commands

- Common operations should remain available through visible controls.
- Menubar and contextual commands should complement, not replace, visible beginner-friendly actions.
- Destructive actions require clear labels and disabled states when unavailable.

## Accessibility

- Preserve keyboard operation for navigation and primary actions.
- Provide accessible labels for icon-only buttons.
- Do not hide essential actions behind hover-only UI.
- Respect reduced motion by keeping animations short and nonessential.
- English mode must show no Japanese visible text.

## Current correction pass

- Remove the custom floating titlebar overlay.
- Keep hidden titlebar window style and standard traffic light controls.
- Add in-content sidebar/inspector controls instead of artificial titlebar controls.
- Make the sidebar use a calmer material layer and standard top spacing.
- Add a concise inspector header with a hide control inside the inspector pane.
