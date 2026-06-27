# v22.17.0 Unused View Quarantine

v22.17.0 starts a staged cleanup for unused legacy SwiftUI surfaces.

## Policy

Unused UI files should not be deleted immediately. The cleanup process is:

1. Identify candidate files by checking non-definition references.
2. Quarantine candidates in this document for one release cycle.
3. Keep candidates compiled during quarantine.
4. Run Debug build, test suite, and `git diff --check`.
5. Delete only after a later pass confirms the candidate is still unused and no regressions occur.

## Quarantined deletion candidates

### `MLXServerManager/Views/UnifiedDashboardView.swift`

Observed references:

- `MLXServerManager/Views/UnifiedDashboardView.swift:3:struct UnifiedDashboardView: View`

No non-definition references were found during the v22.17.0 pass.

Status: quarantine candidate. Do not delete in v22.17.0.

### `MLXServerManager/Views/DashboardHomeView.swift`

Observed references:

- `MLXServerManager/Views/DashboardHomeView.swift:3:struct DashboardHomeView: View`

No non-definition references were found during the v22.17.0 pass.

Status: quarantine candidate. Do not delete in v22.17.0.

## Confirmed still used

### `MLXServerManager/Views/DashboardOverviewView.swift`

Observed references:

- `MLXServerManager/ContentView.swift:137:DashboardOverviewView(...)`
- `MLXServerManager/Views/DashboardOverviewView.swift:3:struct DashboardOverviewView: View`

Status: not a deletion candidate.

### `MLXServerManager/Views/ModelListView.swift`

Observed references:

- `MLXServerManager/ContentView.swift:108:ModelListView(...)`

Status: not a deletion candidate.

### `MLXServerManager/Views/ModelDetailView.swift`

Observed references:

- `MLXServerManager/ContentView.swift:179:ModelDetailView(...)`
- `MLXServerManager/Views/ModelDetailView.swift:3:struct ModelDetailView: View`

Status: not a deletion candidate.

## Notes

An attempted in-file quarantine marker was blocked by the tool safety layer, so v22.17.0 records quarantine status in this document rather than modifying the candidate Swift files directly.

## Verification

- Debug build passes.
- Test suite passes.
- `git diff --check` passes.
