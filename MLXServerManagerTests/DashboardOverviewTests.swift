import XCTest
@testable import MLXServerManager

final class DashboardOverviewTests: XCTestCase {
    func testHealthyOverviewProvidesReadinessAction() {
        let overview = DashboardOverview(
            rows: [row(id: "model", loaded: true)],
            diagnostics: [DiagnosticsResult(check: .readyCheck, status: .pass, message: "ready")],
            diagnosticsHistoryCount: 3,
            hermesInspected: true,
            hermesMatchesSelectedModel: true
        )

        XCTAssertEqual(overview.health, .healthy)
        XCTAssertEqual(overview.profileCount, 1)
        XCTAssertEqual(overview.loadedCount, 1)
        XCTAssertEqual(overview.issueCount, 0)
        XCTAssertEqual(overview.actions.first?.destination, .diagnostics)
        XCTAssertEqual(overview.actions.first?.titleKey, "verifyReadiness")
    }

    func testCriticalOverviewPrioritizesDiagnosticsAndRuntimeIssues() {
        let overview = DashboardOverview(
            rows: [row(id: "model", degraded: true, busyPort: true)],
            diagnostics: [
                DiagnosticsResult(check: .readyCheck, status: .fail, message: "failed"),
                DiagnosticsResult(check: .portAvailability, status: .warning, message: "busy")
            ],
            diagnosticsHistoryCount: 2,
            hermesInspected: true,
            hermesMatchesSelectedModel: false
        )

        XCTAssertEqual(overview.health, .critical)
        XCTAssertEqual(overview.degradedCount, 1)
        XCTAssertEqual(overview.busyPortCount, 1)
        XCTAssertEqual(overview.diagnosticsFailureCount, 1)
        XCTAssertEqual(overview.diagnosticsWarningCount, 1)
        XCTAssertEqual(overview.actions.map(\.destination), [.diagnostics, .logs, .settings])
    }

    func testMissingProfilesProducesProfileAction() {
        let overview = DashboardOverview(
            rows: [],
            diagnostics: [],
            diagnosticsHistoryCount: 0,
            hermesInspected: false,
            hermesMatchesSelectedModel: true
        )

        XCTAssertEqual(overview.actions.first?.destination, .profiles)
        XCTAssertEqual(overview.actions.first?.priority, 100)
    }

    func testTransitionAndHermesMismatchRequireAttention() {
        let overview = DashboardOverview(
            rows: [row(id: "model", transitioning: true)],
            diagnostics: [],
            diagnosticsHistoryCount: 0,
            hermesInspected: true,
            hermesMatchesSelectedModel: false
        )

        XCTAssertEqual(overview.health, .attention)
        XCTAssertEqual(overview.transitioningCount, 1)
        XCTAssertTrue(overview.actions.contains { $0.destination == .settings })
    }

    private func row(
        id: String,
        loaded: Bool = false,
        transitioning: Bool = false,
        degraded: Bool = false,
        busyPort: Bool = false
    ) -> ModelListRowState {
        let model = ModelConfig(
            modelID: id,
            displayName: id,
            family: "Test",
            quantization: "4-bit",
            localName: id,
            host: "127.0.0.1",
            serverPort: 8000,
            enableThinking: true,
            notes: "",
            advancedLaunchOptions: nil
        )
        return ModelListRowState(
            model: model,
            sizeText: "1 GB",
            memoryText: "—",
            normalStatusText: "Ready",
            hoveredStatusText: "Ready",
            isTransitioning: transitioning,
            isLoaded: loaded,
            isDegraded: degraded,
            isPortBusy: busyPort,
            canUseStatusAction: true,
            isRecentlyAdded: false,
            nameSortValue: id,
            sizeSortValue: 1,
            statusSortValue: 0,
            endpointSortValue: "127.0.0.1:8000",
            memorySortValue: 0,
            autoUnloadSortValue: 0,
            reasoningSortValue: 1
        )
    }
}
