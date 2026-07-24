import XCTest
@testable import MLXServerManager

final class LogStateCoordinatorTests: XCTestCase {
    func testInitialStateBuildsFilterOptionsAndVisibleEntries() {
        let coordinator = LogStateCoordinator(
            initialLines: [
                "[info] ready",
                "[download] queued"
            ]
        )

        XCTAssertEqual(coordinator.state.text, "[info] ready\n[download] queued")
        XCTAssertEqual(coordinator.state.categoryFilterOptions, ["All", "download", "info"])
        XCTAssertEqual(coordinator.state.visibleEntries.map(\.line), ["[info] ready", "[download] queued"])
        XCTAssertNil(coordinator.state.latestImportantEntry)
    }

    func testFilterAndAppendPublishOneCoherentState() {
        var coordinator = LogStateCoordinator(
            initialLines: [
                "[info] ready",
                "[download] queued"
            ]
        )

        let filteredState = coordinator.setFilter("download")
        XCTAssertEqual(filteredState.visibleEntries.map(\.line), ["[download] queued"])

        let appendedState = coordinator.append(contentsOf: [
            "[download] warning: retrying",
            "[error] failed to start"
        ])

        XCTAssertEqual(
            appendedState.visibleEntries.map(\.line),
            ["[download] queued", "[download] warning: retrying"]
        )
        XCTAssertEqual(appendedState.categoryFilterOptions, ["All", "download", "error", "info"])
        XCTAssertEqual(appendedState.latestImportantEntry?.line, "[error] failed to start")
        XCTAssertEqual(coordinator.text, appendedState.text)
    }

    func testClearCanInstallReplacementLineWithoutResettingFilter() {
        var coordinator = LogStateCoordinator(
            initialLines: ["[download] queued"],
            filter: "download"
        )

        let state = coordinator.clear(replacementLine: "[info] logs cleared")

        XCTAssertEqual(state.entries.map(\.line), ["[info] logs cleared"])
        XCTAssertEqual(state.categoryFilterOptions, ["All", "info"])
        XCTAssertTrue(state.visibleEntries.isEmpty)
        XCTAssertFalse(coordinator.isEmpty)
    }

    func testEmptyAppendReturnsExistingState() {
        var coordinator = LogStateCoordinator(initialLines: ["[info] ready"])
        let originalState = coordinator.state

        let state = coordinator.append(contentsOf: [])

        XCTAssertEqual(state, originalState)
        XCTAssertEqual(coordinator.state, originalState)
    }
}
