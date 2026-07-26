import Foundation

nonisolated enum DashboardHealth: String, Equatable {
    case healthy
    case attention
    case critical
}

nonisolated enum DashboardActionDestination: String, Equatable, Identifiable {
    case profiles
    case diagnostics
    case settings
    case logs

    var id: String { rawValue }
}

nonisolated struct DashboardAction: Identifiable, Equatable {
    let destination: DashboardActionDestination
    let titleKey: String
    let detailKey: String
    let priority: Int

    var id: String { "\(destination.rawValue):\(titleKey)" }
}

nonisolated struct DashboardOverview: Equatable {
    let profileCount: Int
    let loadedCount: Int
    let transitioningCount: Int
    let degradedCount: Int
    let busyPortCount: Int
    let diagnosticsFailureCount: Int
    let diagnosticsWarningCount: Int
    let diagnosticsHistoryCount: Int
    let hermesInspected: Bool
    let hermesMatchesSelectedModel: Bool

    init(
        rows: [ModelListRowState],
        diagnostics: [DiagnosticsResult],
        diagnosticsHistoryCount: Int,
        hermesInspected: Bool,
        hermesMatchesSelectedModel: Bool
    ) {
        profileCount = rows.count
        loadedCount = rows.filter(\.isLoaded).count
        transitioningCount = rows.filter(\.isTransitioning).count
        degradedCount = rows.filter(\.isDegraded).count
        busyPortCount = rows.filter(\.isPortBusy).count
        diagnosticsFailureCount = diagnostics.filter { $0.status == .fail }.count
        diagnosticsWarningCount = diagnostics.filter { $0.status == .warning }.count
        self.diagnosticsHistoryCount = diagnosticsHistoryCount
        self.hermesInspected = hermesInspected
        self.hermesMatchesSelectedModel = hermesMatchesSelectedModel
    }

    var issueCount: Int {
        degradedCount + busyPortCount + diagnosticsFailureCount + diagnosticsWarningCount
    }

    var health: DashboardHealth {
        if diagnosticsFailureCount > 0 || degradedCount > 0 {
            return .critical
        }
        if busyPortCount > 0 || diagnosticsWarningCount > 0 || transitioningCount > 0 || (hermesInspected && !hermesMatchesSelectedModel) {
            return .attention
        }
        return .healthy
    }

    var actions: [DashboardAction] {
        var values: [DashboardAction] = []
        if profileCount == 0 {
            values.append(DashboardAction(destination: .profiles, titleKey: "addProfile", detailKey: "addProfileDetail", priority: 100))
        }
        if diagnosticsFailureCount > 0 || diagnosticsWarningCount > 0 {
            values.append(DashboardAction(destination: .diagnostics, titleKey: "reviewDiagnostics", detailKey: "reviewDiagnosticsDetail", priority: 90))
        }
        if degradedCount > 0 || busyPortCount > 0 {
            values.append(DashboardAction(destination: .logs, titleKey: "reviewRuntimeIssues", detailKey: "reviewRuntimeIssuesDetail", priority: 80))
        }
        if hermesInspected && !hermesMatchesSelectedModel {
            values.append(DashboardAction(destination: .settings, titleKey: "syncHermes", detailKey: "syncHermesDetail", priority: 70))
        }
        if values.isEmpty {
            values.append(DashboardAction(destination: .diagnostics, titleKey: "verifyReadiness", detailKey: "verifyReadinessDetail", priority: 10))
        }
        return values.sorted { $0.priority > $1.priority }
    }
}
