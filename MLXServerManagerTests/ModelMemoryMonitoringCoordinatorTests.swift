import Darwin
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
        var monitorCallCount = 0
        var sleepIntervals: [UInt64] = []
        let receivedResult = expectation(description: "Received memory result")
        let coordinator = ModelMemoryMonitoringCoordinator(
            intervalNanoseconds: 25,
            monitorOperation: { processIdentifier, _, _ in
                monitorCallCount += 1
                return .notRunning(processIdentifier: processIdentifier)
            },
            sleepOperation: { sleepIntervals.append($0) }
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

        XCTAssertEqual(monitorCallCount, 1)
        XCTAssertTrue(sleepIntervals.isEmpty)
        XCTAssertFalse(coordinator.isMonitoring(profileID: "profile"))
    }

    func testMonitoringForwardsEstimateAndUsesConfiguredInterval() async {
        var observedProcessIdentifiers: [Int32] = []
        var observedEstimateGigabytes: [Double?] = []
        var observedEstimateSources: [String?] = []
        var results: [MemoryBreakdownMonitorResult] = [
            .usage(Self.snapshot(processIdentifier: 202)),
            .notRunning(processIdentifier: 202)
        ]
        var sleepIntervals: [UInt64] = []
        let receivedResults = expectation(description: "Received both memory results")
        receivedResults.expectedFulfillmentCount = 2
        let coordinator = ModelMemoryMonitoringCoordinator(
            intervalNanoseconds: 50,
            monitorOperation: { processIdentifier, estimateGigabytes, estimateSource in
                observedProcessIdentifiers.append(processIdentifier)
                observedEstimateGigabytes.append(estimateGigabytes)
                observedEstimateSources.append(estimateSource)
                return results.removeFirst()
            },
            sleepOperation: { sleepIntervals.append($0) }
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

        XCTAssertEqual(observedProcessIdentifiers, [202, 202])
        XCTAssertEqual(observedEstimateGigabytes.compactMap { $0 }, [18.5, 18.5])
        XCTAssertEqual(observedEstimateSources.compactMap { $0 }, ["~/Models/model", "~/Models/model"])
        XCTAssertEqual(sleepIntervals, [50])
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
        var continuation: CheckedContinuation<MemoryBreakdownMonitorResult, Never>?
        var handledResultCount = 0
        let operationStarted = expectation(description: "Memory operation started")
        let coordinator = ModelMemoryMonitoringCoordinator(
            monitorOperation: { _, _, _ in
                await withCheckedContinuation { pendingContinuation in
                    continuation = pendingContinuation
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
        continuation?.resume(returning: .usage(Self.snapshot(processIdentifier: 101)))
        continuation = nil
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
