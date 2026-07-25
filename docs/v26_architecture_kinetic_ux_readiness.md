# v26.0.0 Architecture and Kinetic UX Readiness

## Purpose

v26.0.0 stabilizes the internal architecture work completed after v25.0.0 and adds restrained visual feedback for active operations. Direct Mode remains unchanged.

## Included Work

### AppViewModel separation

- Separate lifecycle, monitoring, logging, persistence, profile editing, downloads, benchmarks, diagnostics, Test Chat, settings, and connection actions into focused extension files.
- Route owned asynchronous work through cancellable coordinators.
- Reject stale completion from replaced requests.
- Keep output batching and monitoring ownership outside SwiftUI views.
- Guard the separation with `AppViewModelAsyncOwnershipTests`.

### Kinetic operational feedback

Border Beam is implemented as a native SwiftUI decorative layer and is limited to active work:

- a model row during lifecycle transition,
- the selected model inspector header during that transition,
- the Test Chat composer while a request is running,
- the download progress card during preparing, downloading, or finalizing.

Normal selection and idle states remain static.

## Refresh and Accessibility Rules

The animation schedule uses `minimumInterval: nil`, allowing SwiftUI and the display to choose the practical refresh interval. There is no app-defined 30 fps cap.

The implementation must retain these rules:

- Reduce Motion pauses movement.
- Reduce Transparency lowers visual intensity.
- Inactive scenes pause timeline updates.
- Hidden views stop visible animation work.
- The decoration does not receive pointer input.
- The decoration is omitted from the accessibility tree.
- Text, symbols, progress indicators, and button state remain the authoritative status communication.

`KineticBorderBeamSourceTests` directly tests the animation policy and verifies that each usage remains tied to explicit operational state. The refresh interval, pause conditions, reduced-motion progress, and invalid-duration fallback are tested without depending only on source-string matching.

## Automated Release Checks

Before release:

- targeted coordinator and source-guard tests pass,
- the complete test suite passes,
- Debug and Release builds succeed,
- Xcode Analyze succeeds,
- strict-concurrency verification succeeds,
- `git diff --check` passes,
- localization guardrails pass,
- `MainSurfaceRenderingTests` renders the primary workspace in English and Japanese, light and dark appearance, and wide and narrow layouts,
- Downloads and Settings surfaces render in both language and appearance variants,
- the integrated Recovery Action `.logs` destination renders the dedicated Logs surface instead of an empty route.

The rendering tests are smoke tests, not pixel-perfect screenshot comparisons. They verify that the SwiftUI hierarchy can be constructed and rasterized at the required dimensions without crashing.

## Manual Release Checks

Verify:

- light and dark appearance,
- Start, Stop, and Restart transitions,
- inspector synchronization with the selected row,
- Test Chat request state,
- download preparing, transfer, finalizing, completion, and idle states,
- Reduce Motion and Reduce Transparency,
- Japanese and English labels beyond the automated render matrix,
- narrow-window interaction and inspector auto-collapse,
- practical CPU and GPU load when multiple active surfaces are visible,
- visual smoothness on the actual connected display refresh rate.

The last two items require an interactive app session and cannot be established by offscreen rendering alone.

## Release Boundary

v26.0.0 contains architecture stabilization, asynchronous ownership guardrails, and kinetic operational feedback. Runtime capability redesign, recovery redesign, profile templates, broader model discovery, and operational history remain later-version work.

At release time only:

- change `MARKETING_VERSION` from `25.0.0` to `26.0.0`,
- update `docs/stable_scope.md`,
- update relevant README text,
- refresh affected screenshots,
- prepare release notes.

Do not change the stable version marker until automated and manual checks are complete.
