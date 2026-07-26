import XCTest
@testable import MLXServerManager

final class DiagnosticsHistoryTests: XCTestCase {
    func testComparisonDetectsImprovementAndWorsening() {
        let previous = DiagnosticsSnapshot(
            targetKey: "model",
            targetName: "Model",
            results: [
                DiagnosticsResult(check: .readyCheck, status: .fail, message: "failed"),
                DiagnosticsResult(check: .portAvailability, status: .pass, message: "free")
            ]
        )
        let improved = DiagnosticsSnapshot(
            targetKey: "model",
            targetName: "Model",
            results: [
                DiagnosticsResult(check: .readyCheck, status: .pass, message: "ready"),
                DiagnosticsResult(check: .portAvailability, status: .pass, message: "free")
            ]
        )
        let worsened = DiagnosticsSnapshot(
            targetKey: "model",
            targetName: "Model",
            results: [
                DiagnosticsResult(check: .readyCheck, status: .warning, message: "slow"),
                DiagnosticsResult(check: .portAvailability, status: .fail, message: "occupied")
            ]
        )

        let improvement = DiagnosticsComparison.compare(current: improved, previous: previous)
        XCTAssertEqual(improvement.trend, .improved)
        XCTAssertEqual(improvement.improvedCount, 1)
        XCTAssertEqual(improvement.worsenedCount, 0)

        let worsening = DiagnosticsComparison.compare(current: worsened, previous: improved)
        XCTAssertEqual(worsening.trend, .worsened)
        XCTAssertEqual(worsening.worsenedCount, 2)
    }

    func testDetailedRowsAndMarkdownReport() {
        let previous = DiagnosticsSnapshot(
            targetKey: "model",
            targetName: "Model",
            createdAt: Date(timeIntervalSince1970: 1),
            results: [DiagnosticsResult(check: .readyCheck, status: .fail, message: "offline")]
        )
        let current = DiagnosticsSnapshot(
            targetKey: "model",
            targetName: "Model",
            createdAt: Date(timeIntervalSince1970: 2),
            results: [DiagnosticsResult(check: .readyCheck, status: .pass, message: "ready", detail: "127.0.0.1:8000")]
        )

        let rows = DiagnosticsComparison.rows(current: current, previous: previous)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].previousStatusRawValue, DiagnosticsStatus.fail.rawValue)
        XCTAssertEqual(rows[0].currentStatusRawValue, DiagnosticsStatus.pass.rawValue)

        let markdown = DiagnosticsReportBuilder.markdown(current: current, previous: previous)
        XCTAssertTrue(markdown.contains("# Diagnostics Report"))
        XCTAssertTrue(markdown.contains("| readyCheck | pass | ready | 127.0.0.1:8000 |"))
        XCTAssertTrue(markdown.contains("## Comparison"))
    }

    func testHistoryRemovalOnlyAffectsSelectedTarget() {
        let suiteName = "DiagnosticsHistoryRemovalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let history = [
            DiagnosticsSnapshot(targetKey: "a", targetName: "A", results: []),
            DiagnosticsSnapshot(targetKey: "b", targetName: "B", results: [])
        ]
        let remaining = DiagnosticsHistoryStore.removeSnapshots(for: "a", history: history, defaults: defaults)
        XCTAssertEqual(remaining.map(\.targetKey), ["b"])
        XCTAssertEqual(DiagnosticsHistoryStore.load(defaults: defaults).map(\.targetKey), ["b"])
    }

    func testHistoryIsSeparatedAndCappedPerTarget() {
        let suiteName = "DiagnosticsHistoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var history: [DiagnosticsSnapshot] = []
        for index in 0..<(DiagnosticsHistoryStore.maximumPerTarget + 3) {
            let snapshot = DiagnosticsSnapshot(
                targetKey: "a",
                targetName: "A",
                createdAt: Date(timeIntervalSince1970: Double(index)),
                results: []
            )
            history = DiagnosticsHistoryStore.record(snapshot, history: history, defaults: defaults)
        }
        history = DiagnosticsHistoryStore.record(
            DiagnosticsSnapshot(targetKey: "b", targetName: "B", results: []),
            history: history,
            defaults: defaults
        )

        XCTAssertEqual(DiagnosticsHistoryStore.snapshots(for: "a", in: history).count, DiagnosticsHistoryStore.maximumPerTarget)
        XCTAssertEqual(DiagnosticsHistoryStore.snapshots(for: "b", in: history).count, 1)
        XCTAssertEqual(DiagnosticsHistoryStore.load(defaults: defaults).count, DiagnosticsHistoryStore.maximumPerTarget + 1)
    }
}
