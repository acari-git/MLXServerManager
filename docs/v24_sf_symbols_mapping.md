# v24 SF Symbols Mapping

This project uses SF Symbols as semantic UI vocabulary. The app should not pick symbols ad hoc per view. Symbol names are centralized in `MLXServerManager/Design/AppSymbols.swift`.

## Rules

- Use stable SF Symbols for primary navigation and core actions.
- Avoid beta-only symbols for essential actions unless a fallback plan is added.
- Use one symbol for one meaning throughout the app.
- Pair status symbols with readable labels; do not rely on color alone.
- Keep sidebar symbols simple and recognizable at small size.

## Current mapping

| Purpose | Symbol |
| --- | --- |
| Models | `cube.box` |
| Downloads | `arrow.down.circle` |
| Logs | `doc.text.magnifyingglass` |
| Settings | `gearshape` |
| Left sidebar | `sidebar.left` |
| Right inspector | `sidebar.right` |
| Bottom panel | `rectangle.bottomthird.inset.filled` |
| Start | `play.fill` |
| Stop | `stop.fill` |
| Restart / refresh | `arrow.clockwise` |
| Ready / completed | `checkmark.circle.fill` |
| Warning | `exclamationmark.triangle.fill` |
| Error | `xmark.octagon.fill` |
| Copy | `doc.on.doc` |
| Add | `plus` |
| Search | `magnifyingglass` |
| Model inspector | `slider.horizontal.3` |
| Connection | `network` |
| Recovery | `wrench.and.screwdriver` |
| Hermes Agent | `point.3.connected.trianglepath.dotted` |
| Expanded disclosure | `chevron.down` |
| Collapsed disclosure | `chevron.right` |

## Applied in this pass

- Added `AppSymbols` catalog.
- Updated integrated workspace navigation, sidebar controls, inspector sections, copy action, and destination icons to use the catalog.
- Changed the Models navigation icon from `list.bullet.rectangle` to `cube.box` to better match model artifacts.
- Changed Logs from `doc.text` to `doc.text.magnifyingglass` to match diagnostic review.
