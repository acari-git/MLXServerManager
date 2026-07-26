import Foundation

nonisolated enum PlatformIntegrationState: String, Equatable {
    case ready
    case attention
    case incomplete
}

nonisolated struct PlatformIntegrationItem: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let detailKey: String
    let state: PlatformIntegrationState
    let evidenceCount: Int
}

nonisolated struct PlatformIntegrationSnapshot: Equatable {
    let profileCount: Int
    let diagnosticsHistoryCount: Int
    let sessionCount: Int
    let enabledRunbookCount: Int
    let enabledAssignmentCount: Int
    let assignedProfileCount: Int
    let hermesConfigured: Bool
    let orphanAssignmentCount: Int

    init(
        profileIDs: Set<String>,
        diagnosticsHistoryCount: Int,
        sessionCount: Int,
        runbooks: [AutomationRunbook],
        assignments: [AgentAssignment],
        hermesConfigPath: String
    ) {
        profileCount = profileIDs.count
        self.diagnosticsHistoryCount = diagnosticsHistoryCount
        self.sessionCount = sessionCount
        enabledRunbookCount = runbooks.filter(\.isEnabled).count
        let enabledAssignments = assignments.filter(\.isEnabled)
        enabledAssignmentCount = enabledAssignments.count
        assignedProfileCount = Set(enabledAssignments.compactMap(\.profileID).filter(profileIDs.contains)).count
        hermesConfigured = !hermesConfigPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        orphanAssignmentCount = enabledAssignments.compactMap(\.profileID).filter { !profileIDs.contains($0) }.count
    }

    var state: PlatformIntegrationState {
        if profileCount == 0 || enabledRunbookCount == 0 || !hermesConfigured { return .incomplete }
        if diagnosticsHistoryCount == 0 || sessionCount == 0 || orphanAssignmentCount > 0 { return .attention }
        return .ready
    }

    var completionPercent: Int {
        let checks = [
            profileCount > 0,
            diagnosticsHistoryCount > 0,
            sessionCount > 0,
            enabledRunbookCount > 0,
            enabledAssignmentCount > 0,
            hermesConfigured,
            orphanAssignmentCount == 0
        ]
        return Int((Double(checks.filter { $0 }.count) / Double(checks.count) * 100).rounded())
    }

    var items: [PlatformIntegrationItem] {
        [
            PlatformIntegrationItem(id: "profiles", titleKey: "profiles", detailKey: "profilesDetail", state: profileCount > 0 ? .ready : .incomplete, evidenceCount: profileCount),
            PlatformIntegrationItem(id: "diagnostics", titleKey: "diagnostics", detailKey: "diagnosticsDetail", state: diagnosticsHistoryCount > 0 ? .ready : .attention, evidenceCount: diagnosticsHistoryCount),
            PlatformIntegrationItem(id: "sessions", titleKey: "sessions", detailKey: "sessionsDetail", state: sessionCount > 0 ? .ready : .attention, evidenceCount: sessionCount),
            PlatformIntegrationItem(id: "automation", titleKey: "automation", detailKey: "automationDetail", state: enabledRunbookCount > 0 ? .ready : .incomplete, evidenceCount: enabledRunbookCount),
            PlatformIntegrationItem(id: "agents", titleKey: "agents", detailKey: "agentsDetail", state: enabledAssignmentCount > 0 && orphanAssignmentCount == 0 ? .ready : .attention, evidenceCount: enabledAssignmentCount),
            PlatformIntegrationItem(id: "hermes", titleKey: "hermes", detailKey: "hermesDetail", state: hermesConfigured ? .ready : .incomplete, evidenceCount: hermesConfigured ? 1 : 0)
        ]
    }

    func markdownReport(generatedAt: Date = Date()) -> String {
        let rows = items.map { "| \($0.id) | \($0.state.rawValue) | \($0.evidenceCount) |" }.joined(separator: "\n")
        return """
        # MLXServerManager Platform Integration Report

        - Generated: \(generatedAt.ISO8601Format())
        - State: \(state.rawValue)
        - Completion: \(completionPercent)%
        - Profiles: \(profileCount)
        - Diagnostics history: \(diagnosticsHistoryCount)
        - Hermes sessions: \(sessionCount)
        - Enabled runbooks: \(enabledRunbookCount)
        - Enabled agent assignments: \(enabledAssignmentCount)
        - Assigned profiles: \(assignedProfileCount)
        - Orphan assignments: \(orphanAssignmentCount)
        - Hermes config path configured: \(hermesConfigured)

        | Integration | State | Evidence |
        |---|---|---:|
        \(rows)
        """
    }
}

nonisolated enum PlatformIntegrationReconciler {
    static func reconcile(assignments: [AgentAssignment], validProfileIDs: Set<String>) -> [AgentAssignment] {
        assignments.map { assignment in
            guard let profileID = assignment.profileID, !validProfileIDs.contains(profileID) else { return assignment }
            var repaired = assignment
            repaired.profileID = nil
            return repaired
        }
    }
}
