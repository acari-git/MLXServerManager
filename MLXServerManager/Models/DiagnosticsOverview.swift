import Foundation

nonisolated enum DiagnosticsStatusFilter: String, CaseIterable, Identifiable {
    case all
    case fail
    case warning
    case pass

    var id: String { rawValue }
}

nonisolated enum DiagnosticsPriority: Int, Comparable, Sendable {
    case critical = 0
    case high = 1
    case normal = 2
    case informational = 3

    static func < (lhs: DiagnosticsPriority, rhs: DiagnosticsPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated enum DiagnosticsGuidanceDestination: Equatable, Sendable {
    case settings
    case dashboard
    case none
}

nonisolated struct DiagnosticsGuidance: Equatable, Sendable {
    let priority: DiagnosticsPriority
    let recommendationKey: String
    let destination: DiagnosticsGuidanceDestination
}

nonisolated struct DiagnosticsOverview: Equatable {
    let results: [DiagnosticsResult]

    var passCount: Int { results.filter { $0.status == .pass }.count }
    var warningCount: Int { results.filter { $0.status == .warning }.count }
    var failureCount: Int { results.filter { $0.status == .fail }.count }
    var issueCount: Int { warningCount + failureCount }

    func filtered(status: DiagnosticsStatusFilter, searchText: String) -> [DiagnosticsResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return results.filter { result in
            let matchesStatus: Bool
            switch status {
            case .all: matchesStatus = true
            case .pass: matchesStatus = result.status == .pass
            case .warning: matchesStatus = result.status == .warning
            case .fail: matchesStatus = result.status == .fail
            }
            guard matchesStatus else { return false }
            guard !query.isEmpty else { return true }
            return [result.check.title, result.message, result.detail ?? ""]
                .joined(separator: "\n")
                .localizedCaseInsensitiveContains(query)
        }.sorted { lhs, rhs in
            let left = guidance(for: lhs).priority
            let right = guidance(for: rhs).priority
            if left != right { return left < right }
            return lhs.check.title.localizedCaseInsensitiveCompare(rhs.check.title) == .orderedAscending
        }
    }

    func guidance(for result: DiagnosticsResult) -> DiagnosticsGuidance {
        let priority: DiagnosticsPriority
        switch result.status {
        case .fail: priority = .critical
        case .warning: priority = .high
        case .pass: priority = .informational
        }

        switch result.check {
        case .executablePathConfigured:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "configureExecutable", destination: .settings)
        case .executablePathExists:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "verifyExecutablePath", destination: .settings)
        case .executablePathExecutable:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "verifyExecutablePermission", destination: .settings)
        case .hostConfigured:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "reviewHost", destination: .settings)
        case .portInRange:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "reviewPort", destination: .dashboard)
        case .settingsStorageLocation:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "reviewStorage", destination: .settings)
        case .portAvailability:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "resolvePortConflict", destination: .dashboard)
        case .readyCheck:
            return DiagnosticsGuidance(priority: priority, recommendationKey: "reviewRuntimeState", destination: .dashboard)
        }
    }
}
