import XCTest
@testable import MLXServerManager

final class DiagnosticsViewStateTests: XCTestCase {
    func testBeginRunPreservesPreviousResultsWhileMarkingRunning() {
        let previous = makeResult(message: "previous")
        var state = DiagnosticsViewState.notRun
        state.completeRun(with: [previous])

        state.beginRun()

        XCTAssertEqual(state.results, [previous])
        XCTAssertTrue(state.didRun)
        XCTAssertTrue(state.isRunning)
    }

    func testCompleteRunPublishesResultsAndLifecycleTogether() {
        let result = makeResult(message: "complete")
        var state = DiagnosticsViewState.notRun
        state.beginRun()

        state.completeRun(with: [result])

        XCTAssertEqual(state.results, [result])
        XCTAssertTrue(state.didRun)
        XCTAssertFalse(state.isRunning)
    }

    func testCancelAndResetReturnToCoherentStates() {
        let result = makeResult(message: "retained")
        var state = DiagnosticsViewState.notRun
        state.completeRun(with: [result])
        state.beginRun()

        state.cancelRun()
        XCTAssertEqual(state.results, [result])
        XCTAssertTrue(state.didRun)
        XCTAssertFalse(state.isRunning)

        state.reset()
        XCTAssertEqual(state, .notRun)
    }

    private func makeResult(message: String) -> DiagnosticsResult {
        DiagnosticsResult(
            check: .hostConfigured,
            status: .pass,
            message: message
        )
    }
}
