import Darwin
import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class ModelMemoryMonitoringCoordinatorTests: XCTestCase {
    func testMemorySamplingDoesNotBlockMainActorResponsiveness() async {
        let samplingStarted = expectation(description: "Memory sampling started")
        let resultHandled = expectation(description: "Memory result handled")
        let clock = ContinuousClock()
        let coordinator = ModelMemoryMonitoringCoordinator(
            monitorOperation: { processIdentifier, _, _ in
                samplingStarted.fulfill()
                Darwin.usleep(300_000)
                return .notRunning(processIdentifier: processIdentifier)
            }
        )

        let startedAt = clock.now
        coordinator.start(
            profileID: "profile",
            processIdentifier: 101,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { _, _, _ in
            resultHandled.fulfill()
            return false
        }

        await fulfillment(of: [samplingStarted], timeout: 1)
        let mainActorResponseTime = startedAt.duration(to: clock.now)
        XCTAssertLessThan(mainActorResponseTime, .milliseconds(150))
        await fulfillment(of: [resultHandled], timeout: 1)
    }

    func testHandlerCanStopMonitoringWithoutSleeping() async {
        let monitorCallCount = ThreadSafeBox(0)
        let sleepIntervals = ThreadSafeBox<[UInt64]>([])
        let receivedResult = expectation(description: "Received memory result")
        let coordinator = ModelMemoryMonitoringCoordinator(
            intervalNanoseconds: 25,
            monitorOperation: { processIdentifier, _, _ in
                monitorCallCount.withValue { $0 += 1 }
                return .notRunning(processIdentifier: processIdentifier)
            },
            sleepOperation: { interval in
                sleepIntervals.withValue { $0.append(interval) }
            }
        )

        coordinator.start(
            profileID: "profile",
            processIdentifier: 101,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { result, profileID, processIdentifier in
            XCTAssertEqual(result, .notRunning(processIdentifier: 101))
            XCTAssertEqual(profileID, "profile")
            XCTAssertEqual(processIdentifier, 101)
            receivedResult.fulfill()
            return false
        }

        await fulfillment(of: [receivedResult], timeout: 1)
        await Task.yield()

        XCTAssertEqual(monitorCallCount.snapshot, 1)
        XCTAssertTrue(sleepIntervals.snapshot.isEmpty)
        XCTAssertFalse(coordinator.isMonitoring(profileID: "profile"))
    }

    func testMonitoringForwardsEstimateAndUsesConfiguredInterval() async {
        let records = ThreadSafeBox(
            MemoryMonitoringRecords(
                results: [
                    .usage(Self.snapshot(processIdentifier: 202)),
                    .notRunning(processIdentifier: 202)
                ]
            )
        )
        let receivedResults = expectation(description: "Received both memory results")
        receivedResults.expectedFulfillmentCount = 2
        let coordinator = ModelMemoryMonitoringCoordinator(
            intervalNanoseconds: 50,
            monitorOperation: { processIdentifier, estimateGigabytes, estimateSource in
                records.withValue { records in
                    records.processIdentifiers.append(processIdentifier)
                    records.estimateGigabytes.append(estimateGigabytes)
                    records.estimateSources.append(estimateSource)
                    return records.results.removeFirst()
                }
            },
            sleepOperation: { interval in
                records.withValue { $0.sleepIntervals.append(interval) }
            }
        )

        coordinator.start(
            profileID: "profile",
            processIdentifier: 202,
            modelEstimateGigabytes: 18.5,
            modelEstimateSource: "~/Models/model"
        ) { result, _, _ in
            receivedResults.fulfill()
            if case .usage = result {
                return true
            }
            return false
        }

        await fulfillment(of: [receivedResults], timeout: 1)
        await Task.yield()

        let snapshot = records.snapshot
        XCTAssertEqual(snapshot.processIdentifiers, [202, 202])
        XCTAssertEqual(snapshot.estimateGigabytes.compactMap { $0 }, [18.5, 18.5])
        XCTAssertEqual(snapshot.estimateSources.compactMap { $0 }, ["~/Models/model", "~/Models/model"])
        XCTAssertEqual(snapshot.sleepIntervals, [50])
        XCTAssertFalse(coordinator.isMonitoring(profileID: "profile"))
    }

    func testReplacingMonitorDoesNotLetCancelledGenerationRemoveReplacement() async {
        let firstSample = expectation(description: "First monitor sampled")
        let replacementSample = expectation(description: "Replacement monitor sampled")
        let coordinator = ModelMemoryMonitoringCoordinator(
            monitorOperation: { processIdentifier, _, _ in
                .failed(processIdentifier: processIdentifier, message: "retry")
            },
            sleepOperation: { nanoseconds in
                try await Task.sleep(nanoseconds: nanoseconds)
            }
        )

        coordinator.start(
            profileID: "profile",
            processIdentifier: 101,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { _, _, _ in
            firstSample.fulfill()
            return true
        }
        await fulfillment(of: [firstSample], timeout: 1)

        coordinator.start(
            profileID: "profile",
            processIdentifier: 202,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { _, _, processIdentifier in
            XCTAssertEqual(processIdentifier, 202)
            replacementSample.fulfill()
            return true
        }
        await fulfillment(of: [replacementSample], timeout: 1)
        await Task.yield()

        XCTAssertTrue(coordinator.isMonitoring(profileID: "profile"))
        XCTAssertEqual(coordinator.activeProfileIDs, ["profile"])

        coordinator.stop(profileID: "profile")
        XCTAssertFalse(coordinator.isMonitoring(profileID: "profile"))
    }

    func testStopSuppressesResultThatFinishesAfterCancellation() async {
        let continuation = ThreadSafeBox<CheckedContinuation<MemoryBreakdownMonitorResult, Never>?>(nil)
        var handledResultCount = 0
        let operationStarted = expectation(description: "Memory operation started")
        let coordinator = ModelMemoryMonitoringCoordinator(
            monitorOperation: { _, _, _ in
                await withCheckedContinuation { pendingContinuation in
                    continuation.withValue { $0 = pendingContinuation }
                    operationStarted.fulfill()
                }
            }
        )

        coordinator.start(
            profileID: "profile",
            processIdentifier: 101,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { _, _, _ in
            handledResultCount += 1
            return true
        }

        await fulfillment(of: [operationStarted], timeout: 1)
        coordinator.stop(profileID: "profile")
        let pendingContinuation = continuation.withValue { value in
            defer { value = nil }
            return value
        }
        pendingContinuation?.resume(returning: .usage(Self.snapshot(processIdentifier: 101)))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(handledResultCount, 0)
        XCTAssertFalse(coordinator.isMonitoring(profileID: "profile"))
    }

    func testStoppingOneProfileKeepsOtherProfileActive() async {
        let firstSample = expectation(description: "First profile sampled")
        let secondSample = expectation(description: "Second profile sampled")
        let coordinator = ModelMemoryMonitoringCoordinator(
            monitorOperation: { processIdentifier, _, _ in
                .failed(processIdentifier: processIdentifier, message: "retry")
            },
            sleepOperation: { nanoseconds in
                try await Task.sleep(nanoseconds: nanoseconds)
            }
        )

        coordinator.start(
            profileID: "first",
            processIdentifier: 101,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { _, _, _ in
            firstSample.fulfill()
            return true
        }
        coordinator.start(
            profileID: "second",
            processIdentifier: 202,
            modelEstimateGigabytes: nil,
            modelEstimateSource: nil
        ) { _, _, _ in
            secondSample.fulfill()
            return true
        }

        await fulfillment(of: [firstSample, secondSample], timeout: 1)
        XCTAssertEqual(coordinator.activeProfileIDs, ["first", "second"])

        coordinator.stop(profileID: "first")

        XCTAssertFalse(coordinator.isMonitoring(profileID: "first"))
        XCTAssertTrue(coordinator.isMonitoring(profileID: "second"))

        coordinator.stopAll()
        XCTAssertTrue(coordinator.activeProfileIDs.isEmpty)
    }

    private static func snapshot(processIdentifier: Int32) -> MemoryBreakdownSnapshot {
        MemoryBreakdownSnapshot(
            processIdentifier: processIdentifier,
            rssKilobytes: 1_048_576,
            system: SystemMemorySnapshot(
                totalBytes: 64 * 1_073_741_824,
                availableBytes: 32 * 1_073_741_824
            ),
            modelEstimateGigabytes: 18.5,
            modelEstimateSource: "~/Models/model",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private struct MemoryMonitoringRecords {
    var processIdentifiers: [Int32] = []
    var estimateGigabytes: [Double?] = []
    var estimateSources: [String?] = []
    var results: [MemoryBreakdownMonitorResult]
    var sleepIntervals: [UInt64] = []
}

private final class ThreadSafeBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var snapshot: Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    @discardableResult
    func withValue<Result>(_ operation: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return operation(&value)
    }
}
