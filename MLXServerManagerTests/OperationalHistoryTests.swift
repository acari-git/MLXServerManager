import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class OperationalHistoryTests: XCTestCase {
    func testRuntimeEventDefaultsPreserveExistingCallSites() {
        let event = RuntimeEvent(category: "Ready", message: "Check started")

        XCTAssertEqual(event.category, "Ready")
        XCTAssertEqual(event.severity, .info)
        XCTAssertEqual(event.message, "Check started")
        XCTAssertNil(event.modelID)
        XCTAssertNil(event.endpoint)
        XCTAssertTrue(event.summary.contains("[info]"))
    }

    func testProjectionFiltersCategoryAndSeverityDeterministically() {
        let events = [
            makeEvent(category: "Lifecycle", severity: .info, message: "Start"),
            makeEvent(category: "Download", severity: .failure, message: "Failed"),
            makeEvent(category: "Download", severity: .success, message: "Completed"),
            makeEvent(category: "Ready", severity: .failure, message: "Timed out")
        ]

        XCTAssertEqual(
            OperationalHistoryProjection.availableCategories(events: events),
            ["All", "Download", "Lifecycle", "Ready"]
        )
        XCTAssertEqual(
            OperationalHistoryProjection.project(
                events: events,
                category: "Download",
                severity: .all
            ).map(\.message),
            ["Failed", "Completed"]
        )
        XCTAssertEqual(
            OperationalHistoryProjection.project(
                events: events,
                category: "All",
                severity: .failure
            ).map(\.message),
            ["Failed", "Timed out"]
        )
    }

    func testCopyTextIncludesTimestampContextAndNoEmptyPlaceholders() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let event = RuntimeEvent(
            timestamp: date,
            category: "Lifecycle",
            severity: .success,
            message: "Model became ready.",
            modelID: "owner/model",
            endpoint: "127.0.0.1:8080"
        )

        let text = OperationalHistoryProjection.copyText(events: [event])

        XCTAssertTrue(text.contains("MLX Server Manager Operational History"))
        XCTAssertTrue(text.contains("[success]"))
        XCTAssertTrue(text.contains("owner/model"))
        XCTAssertTrue(text.contains("127.0.0.1:8080"))
        XCTAssertFalse(text.contains("Optional("))
    }

    func testAppViewModelHistoryIsBoundedToNewestOneHundredEvents() {
        let viewModel = makeViewModel()

        for index in 0..<125 {
            viewModel.appendRuntimeEvent(
                category: index.isMultiple(of: 2) ? "Even" : "Odd",
                message: "Event \(index)"
            )
        }

        XCTAssertEqual(viewModel.runtimeEvents.count, AppViewModel.maximumRuntimeEventHistory)
        XCTAssertEqual(viewModel.runtimeEvents.first?.message, "Event 124")
        XCTAssertEqual(viewModel.runtimeEvents.last?.message, "Event 25")
    }

    func testViewModelFiltersCopyAndClearOperateOnInMemoryHistoryOnly() {
        let viewModel = makeViewModel()
        viewModel.appendRuntimeEvent(
            category: "Download",
            severity: .success,
            message: "Completed",
            modelID: "owner/model"
        )
        viewModel.appendRuntimeEvent(
            category: "Ready",
            severity: .failure,
            message: "Timed out"
        )
        viewModel.operationalHistoryCategoryFilter = "Download"
        viewModel.operationalHistorySeverityFilter = .success

        XCTAssertEqual(viewModel.visibleOperationalHistoryEvents.map(\.message), ["Completed"])
        XCTAssertEqual(viewModel.operationalHistoryCategories, ["All", "Download", "Ready"])

        viewModel.clearOperationalHistoryRequested()

        XCTAssertTrue(viewModel.runtimeEvents.isEmpty)
        XCTAssertEqual(viewModel.operationalHistoryCategoryFilter, "All")
        XCTAssertEqual(viewModel.operationalHistorySeverityFilter, .all)
    }

    func testSeverityLocalizationExistsInEnglishAndJapanese() {
        for severity in RuntimeEventSeverity.allCases {
            XCTAssertFalse(severity.localizedTitle(language: .english).isEmpty)
            XCTAssertFalse(severity.localizedTitle(language: .japanese).isEmpty)
        }
        for filter in OperationalHistorySeverityFilter.allCases {
            XCTAssertFalse(filter.localizedTitle(language: .english).isEmpty)
            XCTAssertFalse(filter.localizedTitle(language: .japanese).isEmpty)
        }
    }

    private func makeEvent(
        category: String,
        severity: RuntimeEventSeverity,
        message: String
    ) -> RuntimeEvent {
        RuntimeEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            category: category,
            severity: severity,
            message: message
        )
    }

    private func makeViewModel() -> AppViewModel {
        AppViewModel(
            settingsStore: SettingsStore(
                appDirectoryName: "OperationalHistoryTests-\(UUID().uuidString)"
            )
        )
    }
}
