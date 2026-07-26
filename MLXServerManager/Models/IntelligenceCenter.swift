import Foundation

nonisolated enum IntelligenceSeverity: String, Equatable, CaseIterable, Identifiable {
    case critical
    case attention
    case opportunity
    case healthy

    var id: String { rawValue }
}

nonisolated enum IntelligenceDestination: String, Equatable, Identifiable {
    case dashboard
    case profiles
    case diagnostics
    case automation
    case agents
    case workspace
    case settings
    case logs

    var id: String { rawValue }
}

nonisolated struct IntelligenceInsight: Identifiable, Equatable {
    let id: String
    let severity: IntelligenceSeverity
    let titleKey: String
    let detailKey: String
    let evidence: String
    let confidence: Int
    let destination: IntelligenceDestination
    let priority: Int
}

nonisolated struct IntelligenceOverview: Equatable {
    let score: Int
    let insights: [IntelligenceInsight]
    let profileCount: Int
    let sessionCount: Int
    let enabledAgentCount: Int
    let diagnosticsSampleCount: Int

    init(
        rows: [ModelListRowState],
        diagnostics: [DiagnosticsResult],
        diagnosticsHistory: [DiagnosticsSnapshot],
        sessions: [HermesAgentSessionSummary],
        assignments: [AgentAssignment],
        hermesInspected: Bool,
        hermesMatchesSelectedModel: Bool
    ) {
        profileCount = rows.count
        sessionCount = sessions.count
        enabledAgentCount = assignments.filter(\.isEnabled).count
        diagnosticsSampleCount = diagnosticsHistory.count

        let failures = diagnostics.filter { $0.status == .fail }.count
        let warnings = diagnostics.filter { $0.status == .warning }.count
        let degraded = rows.filter(\.isDegraded).count
        let busyPorts = rows.filter(\.isPortBusy).count
        let transitioning = rows.filter(\.isTransitioning).count
        let loaded = rows.filter(\.isLoaded).count
        let recentSessions = sessions.filter { Date().timeIntervalSince1970 - $0.startedAt < 86_400 * 7 }.count
        let configuredAssignments = assignments.filter { $0.isEnabled && $0.profileID != nil }.count

        var value = 100
        value -= failures * 20
        value -= warnings * 7
        value -= degraded * 15
        value -= busyPorts * 10
        value -= transitioning * 3
        if hermesInspected && !hermesMatchesSelectedModel { value -= 12 }
        if rows.isEmpty { value -= 25 }
        if diagnosticsHistory.isEmpty { value -= 5 }
        score = min(100, max(0, value))

        var generated: [IntelligenceInsight] = []
        if failures > 0 {
            generated.append(Self.insight("diagnosticFailures", .critical, "diagnosticFailuresTitle", "diagnosticFailuresDetail", "\(failures) failed diagnostic check(s)", 100, .diagnostics, 100))
        }
        if degraded > 0 || busyPorts > 0 {
            generated.append(Self.insight("runtimeInstability", .critical, "runtimeInstabilityTitle", "runtimeInstabilityDetail", "\(degraded) degraded profile(s), \(busyPorts) busy port(s)", 95, .logs, 95))
        }
        if hermesInspected && !hermesMatchesSelectedModel {
            generated.append(Self.insight("hermesMismatch", .attention, "hermesMismatchTitle", "hermesMismatchDetail", "Hermes Agent configuration differs from the selected profile", 100, .settings, 90))
        }
        if warnings > 0 {
            generated.append(Self.insight("diagnosticWarnings", .attention, "diagnosticWarningsTitle", "diagnosticWarningsDetail", "\(warnings) diagnostic warning(s)", 90, .diagnostics, 80))
        }
        if rows.isEmpty {
            generated.append(Self.insight("noProfiles", .attention, "noProfilesTitle", "noProfilesDetail", "No model profiles are registered", 100, .profiles, 85))
        }
        if diagnosticsHistory.count < 2 {
            generated.append(Self.insight("insufficientTrend", .opportunity, "insufficientTrendTitle", "insufficientTrendDetail", "\(diagnosticsHistory.count) diagnostics snapshot(s) available", 100, .automation, 55))
        }
        if enabledAgentCount > 1 && configuredAssignments < enabledAgentCount {
            generated.append(Self.insight("agentAssignments", .opportunity, "agentAssignmentsTitle", "agentAssignmentsDetail", "\(configuredAssignments) of \(enabledAgentCount) enabled agents have a profile assignment", 90, .agents, 50))
        }
        if sessions.isEmpty {
            generated.append(Self.insight("noSessionEvidence", .opportunity, "noSessionEvidenceTitle", "noSessionEvidenceDetail", "No Hermes Agent sessions are loaded", 100, .workspace, 45))
        } else if recentSessions == 0 {
            generated.append(Self.insight("staleActivity", .opportunity, "staleActivityTitle", "staleActivityDetail", "No session activity in the last 7 days", 85, .workspace, 40))
        }
        if !rows.isEmpty && loaded == 0 && failures == 0 && degraded == 0 {
            generated.append(Self.insight("readyToLaunch", .healthy, "readyToLaunchTitle", "readyToLaunchDetail", "\(rows.count) profile(s) registered and no critical readiness issue detected", 75, .dashboard, 20))
        }
        if generated.isEmpty {
            generated.append(Self.insight("healthy", .healthy, "healthyTitle", "healthyDetail", "No actionable issue detected from the available evidence", 80, .dashboard, 10))
        }
        insights = generated.sorted {
            if $0.priority == $1.priority { return $0.id < $1.id }
            return $0.priority > $1.priority
        }
    }

    var criticalCount: Int { insights.filter { $0.severity == .critical }.count }
    var attentionCount: Int { insights.filter { $0.severity == .attention }.count }
    var opportunityCount: Int { insights.filter { $0.severity == .opportunity }.count }

    private static func insight(_ id: String, _ severity: IntelligenceSeverity, _ titleKey: String, _ detailKey: String, _ evidence: String, _ confidence: Int, _ destination: IntelligenceDestination, _ priority: Int) -> IntelligenceInsight {
        IntelligenceInsight(id: id, severity: severity, titleKey: titleKey, detailKey: detailKey, evidence: evidence, confidence: confidence, destination: destination, priority: priority)
    }
}
