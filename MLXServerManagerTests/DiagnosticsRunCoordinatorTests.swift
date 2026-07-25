import XCTest
@testable import MLXServerManager

@MainActor
final class DiagnosticsRunCoordinatorTests: XCTestCase {
    func testCompletedRunStopsRunning() async {
        let completed = expectation(description: "Diagnostics completed")
        let coordinator = DiagnosticsRunCoordinator()

        coordinator.start { generation in
            XCTAssertTrue(coordinator.isCurrent(generation: generation))
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1)
        await Task.yield()

        XCTAssertFalse(coordinator.isRunning)
    }

    func testReplacingRunKeepsReplacementCurrentAfterStaleRunFinishes() async {
        let firstStarted = expectation(description: "First diagnostics run started")
        let replacementStarted = expectation(description: "Replacement diagnostics run started")
        var firstContinuation: CheckedContinuation<Void, Never>?
        var replacementContinuation: CheckedContinuation<Void, Never>?
        var firstGeneration: DiagnosticsRunCoordinator.Generation?
        var replacementGeneration: DiagnosticsRunCoordinator.Generation?
        let coordinator = DiagnosticsRunCoordinator()

        coordinator.start { generation in
            firstGeneration = generation
            firstStarted.fulfill()
            await withCheckedContinuation { continuation in
                firstContinuation = continuation
            }
        }
        await fulfillment(of: [firstStarted], timeout: 1)

        coordinator.start { generation in
            replacementGeneration = generation
            replacementStarted.fulfill()
            await withCheckedContinuation { continuation in
                replacementContinuation = continuation
            }
        }
        await fulfillment(of: [replacementStarted], timeout: 1)

        firstContinuation?.resume()
        await Task.yield()

        XCTAssertTrue(coordinator.isRunning)
        XCTAssertEqual(
            firstGeneration.map { coordinator.isCurrent(generation: $0) },
            false
        )
        XCTAssertEqual(
            replacementGeneration.map { coordinator.isCurrent(generation: $0) },
            true
        )

        replacementContinuation?.resume()
        await Task.yield()
        XCTAssertFalse(coordinator.isRunning)
    }

    func testCancelClearsCurrentGenerationAndReportsWhetherRunExisted() async {
        let started = expectation(description: "Diagnostics run started")
        var continuation: CheckedContinuation<Void, Never>?
        var generation: DiagnosticsRunCoordinator.Generation?
        let coordinator = DiagnosticsRunCoordinator()

        coordinator.start { activeGeneration in
            generation = activeGeneration
            started.fulfill()
            await withCheckedContinuation { pendingContinuation in
                continuation = pendingContinuation
            }
        }
        await fulfillment(of: [started], timeout: 1)

        XCTAssertTrue(coordinator.cancel())
        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(
            generation.map { coordinator.isCurrent(generation: $0) },
            false
        )
        XCTAssertFalse(coordinator.cancel())

        continuation?.resume()
        await Task.yield()
    }
}
