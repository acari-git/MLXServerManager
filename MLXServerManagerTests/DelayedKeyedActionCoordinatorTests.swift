import XCTest
@testable import MLXServerManager

@MainActor
final class DelayedKeyedActionCoordinatorTests: XCTestCase {
    func testScheduleIfAbsentRunsOnlyOneActionPerKey() async {
        let coordinator = DelayedKeyedActionCoordinator<String>()
        var executions = 0

        XCTAssertTrue(coordinator.scheduleIfAbsent("output", delayNanoseconds: 1_000_000) {
            executions += 1
        })
        XCTAssertFalse(coordinator.scheduleIfAbsent("output", delayNanoseconds: 1_000_000) {
            executions += 1
        })

        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(executions, 1)
        XCTAssertFalse(coordinator.isScheduled("output"))
    }

    func testCancelSuppressesScheduledAction() async {
        let coordinator = DelayedKeyedActionCoordinator<String>()
        var executions = 0

        coordinator.scheduleIfAbsent("output", delayNanoseconds: 20_000_000) {
            executions += 1
        }
        XCTAssertTrue(coordinator.cancel("output"))

        try? await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(executions, 0)
        XCTAssertFalse(coordinator.isScheduled("output"))
    }
}
