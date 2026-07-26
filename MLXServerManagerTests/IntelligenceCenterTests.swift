import XCTest
@testable import MLXServerManager

final class IntelligenceCenterTests: XCTestCase {
    func testCriticalEvidenceProducesLowScoreAndPrioritizedInsights() {
        let diagnostics = [
            DiagnosticsResult(check: .readyCheck, status: .fail, message: "failed"),
            DiagnosticsResult(check: .portAvailability, status: .warning, message: "busy")
        ]
        let overview = IntelligenceOverview(
            rows: [],
            diagnostics: diagnostics,
            diagnosticsHistory: [],
            sessions: [],
            assignments: AgentAssignmentStore.defaultsValue,
            hermesInspected: true,
            hermesMatchesSelectedModel: false
        )

        XCTAssertLessThan(overview.score, 60)
        XCTAssertEqual(overview.insights.first?.id, "diagnosticFailures")
        XCTAssertGreaterThan(overview.criticalCount, 0)
        XCTAssertTrue(overview.insights.contains { $0.id == "hermesMismatch" })
    }

    func testInsufficientEvidenceCreatesOpportunities() {
        let overview = IntelligenceOverview(
            rows: [],
            diagnostics: [],
            diagnosticsHistory: [],
            sessions: [],
            assignments: AgentAssignmentStore.defaultsValue,
            hermesInspected: false,
            hermesMatchesSelectedModel: true
        )

        XCTAssertTrue(overview.insights.contains { $0.id == "insufficientTrend" })
        XCTAssertTrue(overview.insights.contains { $0.id == "noSessionEvidence" })
        XCTAssertTrue(overview.insights.contains { $0.destination == .profiles })
    }

    func testAgentAssignmentGapIsDetected() {
        let assignments = [
            AgentAssignment(provider: .hermes, role: .coordinator, profileID: "profile-a", isEnabled: true),
            AgentAssignment(provider: .codex, role: .coding, profileID: nil, isEnabled: true)
        ]
        let overview = IntelligenceOverview(
            rows: [],
            diagnostics: [],
            diagnosticsHistory: [],
            sessions: [],
            assignments: assignments,
            hermesInspected: false,
            hermesMatchesSelectedModel: true
        )

        XCTAssertEqual(overview.enabledAgentCount, 2)
        XCTAssertTrue(overview.insights.contains { $0.id == "agentAssignments" && $0.destination == .agents })
    }

    func testInsightsAreDeterministicallySortedByPriority() {
        let overview = IntelligenceOverview(
            rows: [],
            diagnostics: [DiagnosticsResult(check: .readyCheck, status: .fail, message: "failed")],
            diagnosticsHistory: [],
            sessions: [],
            assignments: AgentAssignmentStore.defaultsValue,
            hermesInspected: true,
            hermesMatchesSelectedModel: false
        )
        let priorities = overview.insights.map(\.priority)
        XCTAssertEqual(priorities, priorities.sorted(by: >))
        XCTAssertTrue(overview.insights.allSatisfy { (0...100).contains($0.confidence) })
    }
}
