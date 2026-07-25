import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class SharedKeyedTaskCoordinatorTests: XCTestCase {
    func testRepeatedBeginSharesOneTaskAndGeneration() async {
        let counter = LockedCounter()
        let coordinator = SharedKeyedTaskCoordinator<String, Int>()

        let first = coordinator.begin("model") {
            counter.increment()
            Thread.sleep(forTimeInterval: 0.03)
            return 42
        }
        let second = coordinator.begin("model") {
            counter.increment()
            return 99
        }

        XCTAssertTrue(first.startedNewTask)
        XCTAssertFalse(second.startedNewTask)
        XCTAssertEqual(first.handle.generation, second.handle.generation)

        let firstValue = await first.handle.task.value
        let secondValue = await second.handle.task.value

        XCTAssertEqual(firstValue, 42)
        XCTAssertEqual(secondValue, 42)
        XCTAssertEqual(counter.value, 1)
        XCTAssertTrue(coordinator.complete(
            "model",
            generation: first.handle.generation
        ))
        XCTAssertFalse(coordinator.isRunning("model"))
        XCTAssertFalse(coordinator.complete(
            "model",
            generation: second.handle.generation
        ))
    }

    func testCancelledGenerationCannotCompleteReplacementTask() async {
        let coordinator = SharedKeyedTaskCoordinator<String, Int>()
        let stale = coordinator.begin("model") {
            Thread.sleep(forTimeInterval: 0.05)
            return 1
        }

        XCTAssertTrue(coordinator.cancel("model"))

        let replacement = coordinator.begin("model") {
            2
        }
        let replacementValue = await replacement.handle.task.value
        let staleValue = await stale.handle.task.value

        XCTAssertEqual(replacementValue, 2)
        XCTAssertEqual(staleValue, 1)
        XCTAssertNotEqual(stale.handle.generation, replacement.handle.generation)
        XCTAssertFalse(coordinator.complete(
            "model",
            generation: stale.handle.generation
        ))
        XCTAssertTrue(coordinator.isCurrent(
            "model",
            generation: replacement.handle.generation
        ))
        XCTAssertTrue(coordinator.complete(
            "model",
            generation: replacement.handle.generation
        ))
        XCTAssertFalse(coordinator.isRunning("model"))
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func increment() {
        lock.lock()
        storedValue += 1
        lock.unlock()
    }
}
