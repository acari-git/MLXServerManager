import XCTest
@testable import MLXServerManager

@MainActor
final class SystemUsageMonitoringCoordinatorTests: XCTestCase {
    func testHandlerCanStopMonitoringWithoutSleeping() async {
        var sleepIntervals: [UInt64] = []
        let receivedSample = expectation(description: "Received system usage sample")
        let sample = Self.sample(cpuPercent: 25)
        let coordinator = SystemUsageMonitoringCoordinator(
            intervalNanoseconds: 25,
            sampleOperation: { sample },
            sleepOperation: { sleepIntervals.append($0) }
        )

        coordinator.start { received in
            XCTAssertEqual(received, sample)
            receivedSample.fulfill()
            return false
        }

        await fulfillment(of: [receivedSample], timeout: 1)
        await Task.yield()

        XCTAssertTrue(sleepIntervals.isEmpty)
        XCTAssertFalse(coordinator.isMonitoring)
    }

    func testMonitoringUsesConfiguredInterval() async {
        let samples = SampleQueue(samples: [
            Self.sample(cpuPercent: nil),
            Self.sample(cpuPercent: 42)
        ])
        var receivedSamples: [SystemUsageMonitorSample] = []
        var sleepIntervals: [UInt64] = []
        let receivedBothSamples = expectation(description: "Received both system usage samples")
        receivedBothSamples.expectedFulfillmentCount = 2
        let coordinator = SystemUsageMonitoringCoordinator(
            intervalNanoseconds: 50,
            sampleOperation: { await samples.next() },
            sleepOperation: { sleepIntervals.append($0) }
        )

        coordinator.start { sample in
            receivedSamples.append(sample)
            receivedBothSamples.fulfill()
            return receivedSamples.count < 2
        }

        await fulfillment(of: [receivedBothSamples], timeout: 1)
        await Task.yield()

        XCTAssertEqual(receivedSamples, [
            Self.sample(cpuPercent: nil),
            Self.sample(cpuPercent: 42)
        ])
        XCTAssertEqual(sleepIntervals, [50])
        XCTAssertFalse(coordinator.isMonitoring)
    }

    func testReplacingMonitorDoesNotLetCancelledGenerationRemoveReplacement() async {
        let firstSample = expectation(description: "First monitor sampled")
        let replacementSample = expectation(description: "Replacement monitor sampled")
        let sample = Self.sample(cpuPercent: 10)
        let coordinator = SystemUsageMonitoringCoordinator(
            sampleOperation: { sample }
        )

        coordinator.start { _ in
            firstSample.fulfill()
            return true
        }
        await fulfillment(of: [firstSample], timeout: 1)

        coordinator.start { _ in
            replacementSample.fulfill()
            return true
        }
        await fulfillment(of: [replacementSample], timeout: 1)
        await Task.yield()

        XCTAssertTrue(coordinator.isMonitoring)

        coordinator.stop()
        XCTAssertFalse(coordinator.isMonitoring)
    }

    func testStopSuppressesSampleThatFinishesAfterCancellation() async {
        let source = DeferredSampleSource()
        var handledSampleCount = 0
        let coordinator = SystemUsageMonitoringCoordinator(
            sampleOperation: { await source.next() }
        )

        coordinator.start { _ in
            handledSampleCount += 1
            return true
        }

        await source.waitUntilRequested()
        coordinator.stop()
        await source.resume(returning: Self.sample(cpuPercent: 75))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(handledSampleCount, 0)
        XCTAssertFalse(coordinator.isMonitoring)
    }

    private static func sample(cpuPercent: Double?) -> SystemUsageMonitorSample {
        SystemUsageMonitorSample(
            cpuPercent: cpuPercent,
            gpuPercent: nil,
            systemMemorySnapshot: SystemMemorySnapshot(
                totalBytes: 64 * 1_073_741_824,
                availableBytes: 32 * 1_073_741_824
            )
        )
    }
}

private actor SampleQueue {
    private var samples: [SystemUsageMonitorSample]

    init(samples: [SystemUsageMonitorSample]) {
        self.samples = samples
    }

    func next() -> SystemUsageMonitorSample {
        samples.removeFirst()
    }
}

private actor DeferredSampleSource {
    private var sampleContinuation: CheckedContinuation<SystemUsageMonitorSample, Never>?
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var didRequestSample = false

    func next() async -> SystemUsageMonitorSample {
        didRequestSample = true
        requestContinuation?.resume()
        requestContinuation = nil
        return await withCheckedContinuation { continuation in
            sampleContinuation = continuation
        }
    }

    func waitUntilRequested() async {
        guard !didRequestSample else {
            return
        }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
    }

    func resume(returning sample: SystemUsageMonitorSample) {
        sampleContinuation?.resume(returning: sample)
        sampleContinuation = nil
    }
}
