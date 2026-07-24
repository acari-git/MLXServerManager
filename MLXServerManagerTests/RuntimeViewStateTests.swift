import XCTest
@testable import MLXServerManager

final class RuntimeViewStateTests: XCTestCase {
    func testModelRuntimeUpdateProjectsSelectedStateCoherently() {
        var state = RuntimeViewState.empty
        let runtimeState = ModelRuntimeState.loading(
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 123
        )

        state.setRuntimeState(
            runtimeState,
            for: "selected",
            selectedModelID: "selected"
        )

        XCTAssertEqual(state.selectedRuntimeState, runtimeState)
        XCTAssertEqual(state.runtimeStatesByModelID["selected"], runtimeState)
    }

    func testMarkRunningPublishesSelectedProjectionAndStartTimeTogether() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var state = RuntimeViewState.empty

        state.markRunning(
            modelID: "second",
            startedAt: startedAt,
            runningProfileIDs: ["first", "second"],
            selectedModelID: "second",
            orderedModelIDs: ["first", "second"]
        )

        XCTAssertEqual(state.runningModelIDs, ["first", "second"])
        XCTAssertEqual(state.runningModelID, "second")
        XCTAssertEqual(state.managedServerStartedAtByModelID["second"], startedAt)
        XCTAssertEqual(state.managedServerStartedAt, startedAt)
    }

    func testClearRunningFallsBackToModelOrderAndMatchingStartTime() {
        let firstStartedAt = Date(timeIntervalSince1970: 1_000)
        let secondStartedAt = Date(timeIntervalSince1970: 2_000)
        var state = RuntimeViewState.empty
        state.markRunning(
            modelID: "first",
            startedAt: firstStartedAt,
            runningProfileIDs: ["first"],
            selectedModelID: nil,
            orderedModelIDs: ["first", "second"]
        )
        state.markRunning(
            modelID: "second",
            startedAt: secondStartedAt,
            runningProfileIDs: ["first", "second"],
            selectedModelID: "second",
            orderedModelIDs: ["first", "second"]
        )

        state.clearRunning(
            modelID: "second",
            runningProfileIDs: ["first"],
            selectedModelID: "second",
            orderedModelIDs: ["first", "second"]
        )

        XCTAssertEqual(state.runningModelIDs, ["first"])
        XCTAssertEqual(state.runningModelID, "first")
        XCTAssertNil(state.managedServerStartedAtByModelID["second"])
        XCTAssertEqual(state.managedServerStartedAt, firstStartedAt)
    }

    func testProjectSelectedRuntimeUsesStoredStateAndRefreshesRunningProjection() {
        let firstStartedAt = Date(timeIntervalSince1970: 1_000)
        var state = RuntimeViewState.empty
        state.setRuntimeState(
            .ready(host: "127.0.0.1", port: 8080, processIdentifier: 101),
            for: "first",
            selectedModelID: nil
        )
        state.markRunning(
            modelID: "first",
            startedAt: firstStartedAt,
            runningProfileIDs: ["first"],
            selectedModelID: nil,
            orderedModelIDs: ["first", "second"]
        )

        state.projectSelectedRuntimeState(
            selectedModelID: "first",
            runningProfileIDs: ["first"],
            orderedModelIDs: ["first", "second"]
        )

        XCTAssertEqual(
            state.selectedRuntimeState,
            .ready(host: "127.0.0.1", port: 8080, processIdentifier: 101)
        )
        XCTAssertEqual(state.runningModelID, "first")
        XCTAssertEqual(state.managedServerStartedAt, firstStartedAt)
    }
}
