import XCTest
@testable import MLXServerManager

@MainActor
final class HuggingFaceOutputStateCoordinatorTests: XCTestCase {
    func testPendingOutputFlushesImmediatelyForErrorsAndBoundsHistory() {
        let coordinator = HuggingFaceOutputStateCoordinator()
        let id = UUID()

        coordinator.selectPrimaryIfNeeded(id)
        XCTAssertEqual(coordinator.primaryID, id)
        XCTAssertFalse(coordinator.appendPending(
            "10% downloaded",
            queueEntryID: id,
            flushDelayNanoseconds: 1_000_000_000,
            onDelayedFlush: {}
        ))
        XCTAssertTrue(coordinator.appendPending(
            "ERROR: download failed",
            queueEntryID: id,
            flushDelayNanoseconds: 1_000_000_000,
            onDelayedFlush: {}
        ))

        let lines = coordinator.drainPending(queueEntryID: id, cancelScheduledFlush: true)
        XCTAssertEqual(lines, ["10% downloaded", "ERROR: download failed"])

        coordinator.appendHistory(lines, queueEntryID: id, maximumCount: 1)
        XCTAssertEqual(coordinator.outputLinesByID[id], ["ERROR: download failed"])
    }

    func testDiscardClearsPendingHistoryAndPrimarySelection() {
        let coordinator = HuggingFaceOutputStateCoordinator()
        let id = UUID()
        coordinator.setPrimary(id)
        _ = coordinator.appendPending(
            "progress",
            queueEntryID: id,
            flushDelayNanoseconds: 1_000_000_000,
            onDelayedFlush: {}
        )
        coordinator.appendHistory(["old"], queueEntryID: id, maximumCount: 10)

        coordinator.discard(queueEntryID: id)

        XCTAssertNil(coordinator.primaryID)
        XCTAssertNil(coordinator.outputLinesByID[id])
        XCTAssertTrue(coordinator.drainPending(queueEntryID: id, cancelScheduledFlush: true).isEmpty)
    }
}
