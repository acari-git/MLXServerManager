import XCTest
@testable import MLXServerManager

@MainActor
final class ManagedServerOutputCoordinatorTests: XCTestCase {
    func testReplacementHandlerRejectsStaleOutput() async {
        let coordinator = ManagedServerOutputCoordinator()
        var received: [String] = []
        let first = coordinator.begin(modelID: "owner/model", backend: .mlxLM) { line, _ in
            received.append("first:\(line)")
        }
        let second = coordinator.begin(modelID: "owner/model", backend: .mlxLM) { line, _ in
            received.append("second:\(line)")
        }

        first("stale")
        second("current")
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(received, ["second:current"])
        XCTAssertTrue(coordinator.isActive("owner/model"))
    }

    func testFaultIsDetectedOnceAndClearedByInvalidate() async {
        let coordinator = ManagedServerOutputCoordinator()
        var detectedFaults: [ManagedServerRuntimeFault] = []
        let handler = coordinator.begin(modelID: "owner/model", backend: .mlxLM) { _, fault in
            if let fault { detectedFaults.append(fault) }
        }

        let faultLine = "[process:stderr] generation worker stopped unexpectedly"
        handler(faultLine)
        handler(faultLine)
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(detectedFaults.count, 1)
        XCTAssertTrue(coordinator.hasFault(for: "owner/model"))
        XCTAssertEqual(coordinator.fault(for: "owner/model")?.kind, .generationWorkerTerminated)

        coordinator.invalidate("owner/model")

        XCTAssertFalse(coordinator.isActive("owner/model"))
        XCTAssertFalse(coordinator.hasFault(for: "owner/model"))
    }
}
