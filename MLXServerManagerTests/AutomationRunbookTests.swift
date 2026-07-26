import XCTest
@testable import MLXServerManager

final class AutomationRunbookTests: XCTestCase {
    func testDefaultRunbooksCoverDiagnosticsAndHermesInspection() {
        XCTAssertEqual(AutomationRunbook.defaults.count, 3)
        XCTAssertTrue(AutomationRunbook.defaults.allSatisfy(\.isEnabled))
        XCTAssertTrue(AutomationRunbook.defaults.contains { $0.steps.contains(.diagnostics) })
        XCTAssertTrue(AutomationRunbook.defaults.contains { $0.steps.contains(.hermesInspection) })
    }

    func testRunbookPreferencesPersistAndMergeWithDefaults() {
        let suite = "AutomationRunbookTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var runbooks = AutomationRunbook.defaults
        runbooks[0].isEnabled = false
        AutomationStore.saveRunbooks(runbooks, defaults: defaults)

        let loaded = AutomationStore.loadRunbooks(defaults: defaults)
        XCTAssertEqual(loaded.map(\.id), AutomationRunbook.defaults.map(\.id))
        XCTAssertFalse(loaded[0].isEnabled)
        XCTAssertTrue(loaded[1].isEnabled)
    }

    func testHistoryIsNewestFirstAndCapped() {
        let suite = "AutomationHistoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var history: [AutomationRunRecord] = []

        for index in 0..<(AutomationStore.maximumHistory + 5) {
            let date = Date(timeIntervalSince1970: Double(index))
            let record = AutomationRunRecord(
                runbookID: "audit",
                runbookName: "Audit",
                targetName: "Model",
                startedAt: date,
                completedAt: date,
                status: .succeeded,
                completedSteps: [.diagnostics],
                summary: "Done"
            )
            history = AutomationStore.record(record, history: history, defaults: defaults)
        }

        XCTAssertEqual(history.count, AutomationStore.maximumHistory)
        XCTAssertEqual(history.first?.startedAt, Date(timeIntervalSince1970: Double(AutomationStore.maximumHistory + 4)))
        XCTAssertEqual(AutomationStore.loadHistory(defaults: defaults), history)
    }

    func testClearHistoryDoesNotChangeRunbookPreferences() {
        let suite = "AutomationClearTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var runbooks = AutomationRunbook.defaults
        runbooks[1].isEnabled = false
        AutomationStore.saveRunbooks(runbooks, defaults: defaults)

        let record = AutomationRunRecord(
            runbookID: "audit",
            runbookName: "Audit",
            targetName: "Model",
            startedAt: Date(),
            status: .cancelled,
            completedSteps: [],
            summary: "Cancelled"
        )
        _ = AutomationStore.record(record, history: [], defaults: defaults)
        AutomationStore.clearHistory(defaults: defaults)

        XCTAssertTrue(AutomationStore.loadHistory(defaults: defaults).isEmpty)
        XCTAssertFalse(AutomationStore.loadRunbooks(defaults: defaults)[1].isEnabled)
    }
}
