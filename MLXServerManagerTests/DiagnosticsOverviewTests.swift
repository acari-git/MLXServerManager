import XCTest
@testable import MLXServerManager

final class DiagnosticsOverviewTests: XCTestCase {
    func testCountsAndStatusFiltering() {
        let results = [
            DiagnosticsResult(check: .hostConfigured, status: .pass, message: "Host configured"),
            DiagnosticsResult(check: .portAvailability, status: .warning, message: "Port may be occupied"),
            DiagnosticsResult(check: .readyCheck, status: .fail, message: "Endpoint unavailable")
        ]
        let overview = DiagnosticsOverview(results: results)

        XCTAssertEqual(overview.passCount, 1)
        XCTAssertEqual(overview.warningCount, 1)
        XCTAssertEqual(overview.failureCount, 1)
        XCTAssertEqual(overview.issueCount, 2)
        XCTAssertEqual(overview.filtered(status: .fail, searchText: "").map(\.check), [.readyCheck])
        XCTAssertEqual(overview.filtered(status: .warning, searchText: "").map(\.check), [.portAvailability])
    }

    func testIssuesSortBeforePassingResultsAndUseGuidanceDestinations() {
        let results = [
            DiagnosticsResult(check: .readyCheck, status: .pass, message: "Ready"),
            DiagnosticsResult(check: .portAvailability, status: .warning, message: "Occupied"),
            DiagnosticsResult(check: .executablePathExists, status: .fail, message: "Missing")
        ]
        let overview = DiagnosticsOverview(results: results)
        let sorted = overview.filtered(status: .all, searchText: "")

        XCTAssertEqual(sorted.map(\.check), [.executablePathExists, .portAvailability, .readyCheck])
        XCTAssertEqual(overview.guidance(for: sorted[0]).priority, .critical)
        XCTAssertEqual(overview.guidance(for: sorted[0]).destination, .settings)
        XCTAssertEqual(overview.guidance(for: sorted[1]).priority, .high)
        XCTAssertEqual(overview.guidance(for: sorted[1]).destination, .dashboard)
        XCTAssertEqual(overview.guidance(for: sorted[2]).priority, .informational)
    }

    func testGuidanceCoversEveryDiagnosticsCheck() {
        let overview = DiagnosticsOverview(results: [])
        for check in DiagnosticsCheck.allCases {
            let result = DiagnosticsResult(check: check, status: .warning, message: "Issue")
            let guidance = overview.guidance(for: result)
            XCTAssertFalse(guidance.recommendationKey.isEmpty)
            XCTAssertNotEqual(guidance.destination, .none)
        }
    }

    func testSearchMatchesTitleMessageAndDetail() {
        let results = [
            DiagnosticsResult(check: .executablePathExists, status: .pass, message: "Executable found", detail: "/usr/local/bin/mlx_lm.server"),
            DiagnosticsResult(check: .readyCheck, status: .fail, message: "Connection refused", detail: "127.0.0.1:8000")
        ]
        let overview = DiagnosticsOverview(results: results)

        XCTAssertEqual(overview.filtered(status: .all, searchText: "executable").map(\.check), [.executablePathExists])
        XCTAssertEqual(overview.filtered(status: .all, searchText: "refused").map(\.check), [.readyCheck])
        XCTAssertEqual(overview.filtered(status: .all, searchText: "8000").map(\.check), [.readyCheck])
        XCTAssertTrue(overview.filtered(status: .pass, searchText: "refused").isEmpty)
    }
}
