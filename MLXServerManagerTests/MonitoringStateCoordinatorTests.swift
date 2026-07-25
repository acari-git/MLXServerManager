import XCTest
@testable import MLXServerManager

final class MonitoringStateCoordinatorTests: XCTestCase {
    func testModelMemoryUpdatesRemainCoherentAcrossProfiles() {
        let system = SystemMemorySnapshot(
            totalBytes: 64 * 1_073_741_824,
            availableBytes: 48 * 1_073_741_824
        )
        let first = MemoryBreakdownSnapshot(
            processIdentifier: 101,
            rssKilobytes: 2 * 1_048_576,
            system: system,
            modelEstimateGigabytes: 1.5,
            modelEstimateSource: "first",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = MemoryBreakdownSnapshot(
            processIdentifier: 202,
            rssKilobytes: 3 * 1_048_576,
            system: system,
            modelEstimateGigabytes: 2.5,
            modelEstimateSource: "second",
            updatedAt: Date(timeIntervalSince1970: 1_001)
        )
        var coordinator = MonitoringStateCoordinator()

        _ = coordinator.setModelMemory(first, for: "first")
        let combined = coordinator.setModelMemory(second, for: "second")

        XCTAssertEqual(combined.memoryUsageGB ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(combined.memoryUsageByModelID.count, 2)
        XCTAssertEqual(combined.memoryBreakdown?.managedProcessGigabytes ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(coordinator.state, combined)

        let remaining = coordinator.setModelMemory(nil, for: "first")

        XCTAssertEqual(remaining.memoryUsageGB ?? 0, 3, accuracy: 0.001)
        XCTAssertEqual(remaining.memoryUsageByModelID, ["second": 3])
        XCTAssertEqual(coordinator.state, remaining)
    }

    func testSystemUsageUpdatePublishesGuardStateWithEachSample() {
        var coordinator = MonitoringStateCoordinator(
            criticalSamplesRequired: 2,
            recoverySamplesRequired: 2
        )
        let critical = makeAssessment(level: .critical, availableGigabytes: 1)
        let normal = makeAssessment(level: .normal, availableGigabytes: 32)
        let sample = makeSample(availableGigabytes: 1)

        let firstCritical = coordinator.applySystemUsage(
            sample,
            assessment: critical,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(firstCritical.previousProtectionState.level, .normal)
        XCTAssertEqual(firstCritical.nextProtectionState.level, .caution)
        XCTAssertTrue(firstCritical.didChangeProtectionLevel)
        XCTAssertEqual(firstCritical.state.runtimeMemoryProtectionState.level, .caution)

        let secondCritical = coordinator.applySystemUsage(
            sample,
            assessment: critical,
            timestamp: Date(timeIntervalSince1970: 2)
        )
        XCTAssertEqual(secondCritical.previousProtectionState.level, .caution)
        XCTAssertEqual(secondCritical.nextProtectionState.level, .emergency)
        XCTAssertTrue(secondCritical.didChangeProtectionLevel)
        XCTAssertEqual(secondCritical.state.runtimeMemoryProtectionState.level, .emergency)

        let firstRecovery = coordinator.applySystemUsage(
            makeSample(availableGigabytes: 32),
            assessment: normal,
            timestamp: Date(timeIntervalSince1970: 3)
        )
        XCTAssertEqual(firstRecovery.nextProtectionState.level, .emergency)
        XCTAssertFalse(firstRecovery.didChangeProtectionLevel)

        let secondRecovery = coordinator.applySystemUsage(
            makeSample(availableGigabytes: 32),
            assessment: normal,
            timestamp: Date(timeIntervalSince1970: 4)
        )
        XCTAssertEqual(secondRecovery.previousProtectionState.level, .emergency)
        XCTAssertEqual(secondRecovery.nextProtectionState.level, .normal)
        XCTAssertTrue(secondRecovery.didChangeProtectionLevel)
        XCTAssertEqual(secondRecovery.state.runtimeMemoryProtectionState.level, .normal)
        XCTAssertEqual(secondRecovery.state.memoryHistory.count, 4)
        XCTAssertEqual(secondRecovery.state.systemUsageHistory.count, 4)
        XCTAssertEqual(coordinator.state, secondRecovery.state)
    }

    func testUnavailableAssessmentPreservesEmergencyProtection() {
        var coordinator = MonitoringStateCoordinator(
            criticalSamplesRequired: 1,
            recoverySamplesRequired: 1
        )
        let criticalUpdate = coordinator.applySystemUsage(
            makeSample(availableGigabytes: 1),
            assessment: makeAssessment(level: .critical, availableGigabytes: 1)
        )
        XCTAssertEqual(criticalUpdate.nextProtectionState.level, .emergency)

        let unavailableUpdate = coordinator.applySystemUsage(
            makeSample(availableGigabytes: nil),
            assessment: makeAssessment(level: .unavailable, availableGigabytes: nil)
        )

        XCTAssertEqual(unavailableUpdate.previousProtectionState.level, .emergency)
        XCTAssertEqual(unavailableUpdate.nextProtectionState.level, .emergency)
        XCTAssertFalse(unavailableUpdate.didChangeProtectionLevel)
        XCTAssertEqual(unavailableUpdate.state.runtimeMemoryProtectionState.level, .emergency)
    }

    private func makeSample(availableGigabytes: Double?) -> SystemUsageMonitorSample {
        let totalBytes = UInt64(64) * 1_073_741_824
        let availableBytes = availableGigabytes.map { UInt64($0 * 1_073_741_824) }
        return SystemUsageMonitorSample(
            cpuPercent: 25,
            gpuPercent: 40,
            systemMemorySnapshot: SystemMemorySnapshot(
                totalBytes: totalBytes,
                availableBytes: availableBytes
            )
        )
    }

    private func makeAssessment(
        level: RuntimeMemoryHeadroomLevel,
        availableGigabytes: Double?
    ) -> RuntimeMemoryHeadroomAssessment {
        RuntimeMemoryHeadroomAssessment(
            level: level,
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: availableGigabytes,
            cautionThresholdGigabytes: availableGigabytes == nil ? nil : 9.6,
            criticalThresholdGigabytes: availableGigabytes == nil ? nil : 3.2
        )
    }
}
