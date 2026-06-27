# v22.18.0 Remove Unused Legacy Views

v22.18.0 removes legacy SwiftUI surfaces that were quarantined in v22.17.0.

## Removed

- `MLXServerManager/Views/UnifiedDashboardView.swift`
- `MLXServerManager/Views/DashboardHomeView.swift`

## Pre-removal reference check

### `UnifiedDashboardView`

Before deletion, the only reference was its own type definition:

- `MLXServerManager/Views/UnifiedDashboardView.swift:3:struct UnifiedDashboardView: View`

After deletion, no references remained.

### `DashboardHomeView`

Before deletion, the only reference was its own type definition:

- `MLXServerManager/Views/DashboardHomeView.swift:3:struct DashboardHomeView: View`

After deletion, no references remained.

## Still retained

These older support views are still referenced and were not removed:

- `DashboardOverviewView.swift`
- `ModelListView.swift`
- `ModelDetailView.swift`

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
