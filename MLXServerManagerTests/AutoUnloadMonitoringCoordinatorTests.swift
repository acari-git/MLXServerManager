import XCTest
@testable import MLXServerManager

@MainActor
final class AutoUnloadMonitoringCoordinatorTests: XCTestCase {
    func testTickCanStopMonitoringWithoutSleeping() async {
        var tickCount = 0
        var sleepIntervals: [UInt64] = []
        let receivedTick = expectation(description: "Received auto-unload tick")
        let coordinator = AutoUnloadMonitoringCoordinator(
            intervalNanoseconds: 25,
            sleepOperation: { sleepIntervals.append($0) }
        )

        coordinator.start {
            tickCount += 1
            receivedTick.fulfill()
            return false
        }

        await fulfillment(of: [receivedTick], timeout: 1)
        await Task.yield()

        XCTAssertEqual(tickCount, 1)
        XCTAssertTrue(sleepIntervals.isEmpty)
        XCTAssertFalse(coordinator.isMonitoring)
    }

    func testMonitoringUsesConfiguredInterval() async {
        var tickCount = 0
        var sleepIntervals: [UInt64] = []
        let receivedTicks = expectation(description: "Received both auto-unload ticks")
        receivedTicks.expectedFulfillmentCount = 2
        let coordinator = AutoUnloadMonitoringCoordinator(
            intervalNanoseconds: 50,
            sleepOperation: { sleepIntervals.append($0) }
        )

        coordinator.start {
            tickCount += 1
            receivedTicks.fulfill()
            return tickCount < 2
        }

        await fulfillment(of: [receivedTicks], timeout: 1)
        await Task.yield()

        XCTAssertEqual(tickCount, 2)
        XCTAssertEqual(sleepIntervals, [50])
        XCTAssertFalse(coordinator.isMonitoring)
    }

    func testReplacingMonitorDoesNotLetCancelledGenerationRemoveReplacement() async {
        let firstTick = expectation(description: "First monitor ticked")
        let replacementTick = expectation(description: "Replacement monitor ticked")
        let coordinator = AutoUnloadMonitoringCoordinator()

        coordinator.start {
            firstTick.fulfill()
            return true
        }
        await fulfillment(of: [firstTick], timeout: 1)

        coordinator.start {
            replacementTick.fulfill()
            return true
        }
        await fulfillment(of: [replacementTick], timeout: 1)
        await Task.yield()

        XCTAssertTrue(coordinator.isMonitoring)

        coordinator.stop()
        XCTAssertFalse(coordinator.isMonitoring)
    }

    func testStopCancelsPendingSleepBeforeAnotherTick() async {
        var tickCount = 0
        let sleepStarted = expectation(description: "Auto-unload sleep started")
        let coordinator = AutoUnloadMonitoringCoordinator(
            sleepOperation: { nanoseconds in
                sleepStarted.fulfill()
                try await Task.sleep(nanoseconds: nanoseconds)
            }
        )

        coordinator.start {
            tickCount += 1
            return true
        }

        await fulfillment(of: [sleepStarted], timeout: 1)
        coordinator.stop()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(tickCount, 1)
        XCTAssertFalse(coordinator.isMonitoring)
    }
}
