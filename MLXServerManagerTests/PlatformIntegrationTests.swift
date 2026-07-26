import XCTest
@testable import MLXServerManager

final class PlatformIntegrationTests: XCTestCase {
    func testCompleteEvidenceProducesReadySnapshot() {
        let snapshot = PlatformIntegrationSnapshot(
            profileIDs: ["p1"],
            diagnosticsHistoryCount: 2,
            sessionCount: 3,
            runbooks: AutomationRunbook.defaults,
            assignments: [AgentAssignment(provider: .hermes, role: .coordinator, profileID: "p1")],
            hermesConfigPath: "~/.hermes/config.yaml"
        )

        XCTAssertEqual(snapshot.state, .ready)
        XCTAssertEqual(snapshot.completionPercent, 100)
        XCTAssertEqual(snapshot.orphanAssignmentCount, 0)
    }

    func testMissingCoreConfigurationIsIncomplete() {
        let snapshot = PlatformIntegrationSnapshot(
            profileIDs: [],
            diagnosticsHistoryCount: 0,
            sessionCount: 0,
            runbooks: [],
            assignments: [],
            hermesConfigPath: ""
        )

        XCTAssertEqual(snapshot.state, .incomplete)
        XCTAssertLessThan(snapshot.completionPercent, 50)
    }

    func testOrphanAssignmentProducesAttention() {
        let snapshot = PlatformIntegrationSnapshot(
            profileIDs: ["p1"],
            diagnosticsHistoryCount: 1,
            sessionCount: 1,
            runbooks: AutomationRunbook.defaults,
            assignments: [AgentAssignment(provider: .hermes, role: .coordinator, profileID: "missing")],
            hermesConfigPath: "config.yaml"
        )

        XCTAssertEqual(snapshot.state, .attention)
        XCTAssertEqual(snapshot.orphanAssignmentCount, 1)
    }

    func testReconcilerOnlyClearsInvalidProfileReferences() {
        let valid = AgentAssignment(provider: .hermes, role: .coordinator, profileID: "p1", notes: "keep")
        let orphan = AgentAssignment(provider: .codex, role: .coding, profileID: "old", notes: "preserve", isEnabled: false)

        let repaired = PlatformIntegrationReconciler.reconcile(assignments: [valid, orphan], validProfileIDs: ["p1"])

        XCTAssertEqual(repaired[0], valid)
        XCTAssertNil(repaired[1].profileID)
        XCTAssertEqual(repaired[1].notes, "preserve")
        XCTAssertFalse(repaired[1].isEnabled)
        XCTAssertEqual(repaired[1].role, .coding)
    }

    func testMarkdownReportContainsIntegrationEvidence() {
        let snapshot = PlatformIntegrationSnapshot(
            profileIDs: ["p1"],
            diagnosticsHistoryCount: 2,
            sessionCount: 3,
            runbooks: AutomationRunbook.defaults,
            assignments: [AgentAssignment(provider: .hermes, role: .coordinator, profileID: "p1")],
            hermesConfigPath: "config.yaml"
        )

        let report = snapshot.markdownReport(generatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(report.contains("Platform Integration Report"))
        XCTAssertTrue(report.contains("Completion: 100%"))
        XCTAssertTrue(report.contains("Diagnostics history: 2"))
        XCTAssertTrue(report.contains("Hermes sessions: 3"))
    }
}
