import XCTest
@testable import MLXServerManager

final class RuntimeMemoryHeadroomAdvisorTests: XCTestCase {
    func testNormalWhenAvailableMemoryExceedsReserveTarget() {
        let assessment = assess(totalGigabytes: 64, availableGigabytes: 20)

        XCTAssertEqual(assessment.level, .normal)
        XCTAssertFalse(assessment.needsAttention)
        XCTAssertEqual(assessment.cautionThresholdGigabytes ?? 0, 9.6, accuracy: 0.001)
        XCTAssertEqual(assessment.criticalThresholdGigabytes ?? 0, 3.2, accuracy: 0.001)
    }

    func testCautionWhenAvailableMemoryFallsBelowReserveTarget() {
        let assessment = assess(totalGigabytes: 64, availableGigabytes: 8)

        XCTAssertEqual(assessment.level, .caution)
        XCTAssertTrue(assessment.needsAttention)
        XCTAssertTrue(assessment.detail(language: .japanese).contains("KVキャッシュ"))
    }

    func testCriticalWhenAvailableMemoryFallsBelowEmergencyFloor() {
        let assessment = assess(totalGigabytes: 64, availableGigabytes: 3)

        XCTAssertEqual(assessment.level, .critical)
        XCTAssertTrue(assessment.needsAttention)
        XCTAssertTrue(assessment.detail(language: .english).contains("out-of-memory"))
    }

    func testUnavailableWhenAvailableMemoryCannotBeMeasured() {
        let assessment = RuntimeMemoryHeadroomAdvisor.assess(
            environment: RuntimeMemoryHeadroomEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: nil
            )
        )

        XCTAssertEqual(assessment.level, .unavailable)
        XCTAssertFalse(assessment.needsAttention)
        XCTAssertTrue(assessment.detail(language: .japanese).contains("自動停止"))
    }

    func testSmallMemoryMacUsesAbsoluteMinimumThresholds() {
        let assessment = assess(totalGigabytes: 16, availableGigabytes: 5)

        XCTAssertEqual(assessment.level, .caution)
        XCTAssertEqual(assessment.cautionThresholdGigabytes ?? 0, 6, accuracy: 0.001)
        XCTAssertEqual(assessment.criticalThresholdGigabytes ?? 0, 2, accuracy: 0.001)
    }

    func testDetailIncludesMeasuredValuesInBothLanguages() {
        let assessment = assess(totalGigabytes: 64, availableGigabytes: 8)

        XCTAssertEqual(assessment.level, .caution)
        XCTAssertTrue(assessment.detail(language: .english).contains("8.0 GB"))
        XCTAssertTrue(assessment.detail(language: .japanese).contains("8.0 GB"))
        XCTAssertFalse(assessment.detail(language: .english).contains("(available)"))
    }

    func testEmergencyGuardRequiresThreeConsecutiveCriticalSamples() {
        var guardState = RuntimeMemoryEmergencyGuard()
        let critical = assess(totalGigabytes: 64, availableGigabytes: 2)

        XCTAssertEqual(guardState.observe(critical).level, .caution)
        XCTAssertEqual(guardState.observe(critical).level, .caution)
        XCTAssertEqual(guardState.observe(critical).level, .emergency)
        XCTAssertTrue(guardState.state.blocksManagedStart)
    }

    func testEmergencyGuardDoesNotClearUntilThreeConsecutiveNormalSamples() {
        var guardState = RuntimeMemoryEmergencyGuard()
        let critical = assess(totalGigabytes: 64, availableGigabytes: 2)
        let caution = assess(totalGigabytes: 64, availableGigabytes: 8)
        let normal = assess(totalGigabytes: 64, availableGigabytes: 20)

        _ = guardState.observe(critical)
        _ = guardState.observe(critical)
        _ = guardState.observe(critical)
        XCTAssertEqual(guardState.state.level, .emergency)

        XCTAssertEqual(guardState.observe(caution).level, .emergency)
        XCTAssertEqual(guardState.observe(normal).level, .emergency)
        XCTAssertEqual(guardState.observe(normal).level, .emergency)
        XCTAssertEqual(guardState.observe(normal).level, .normal)
        XCTAssertFalse(guardState.state.blocksManagedStart)
    }

    func testUnavailableSampleDoesNotClearActiveEmergencyProtection() {
        var guardState = RuntimeMemoryEmergencyGuard()
        let critical = assess(totalGigabytes: 64, availableGigabytes: 2)
        let unavailable = RuntimeMemoryHeadroomAdvisor.assess(
            environment: RuntimeMemoryHeadroomEnvironment(
                totalMemoryGigabytes: 64,
                availableMemoryGigabytes: nil
            )
        )

        _ = guardState.observe(critical)
        _ = guardState.observe(critical)
        _ = guardState.observe(critical)

        XCTAssertEqual(guardState.observe(unavailable).level, .emergency)
        XCTAssertEqual(guardState.state.assessment?.level, .critical)
    }

    private func assess(
        totalGigabytes: Double,
        availableGigabytes: Double
    ) -> RuntimeMemoryHeadroomAssessment {
        RuntimeMemoryHeadroomAdvisor.assess(
            environment: RuntimeMemoryHeadroomEnvironment(
                totalMemoryGigabytes: totalGigabytes,
                availableMemoryGigabytes: availableGigabytes
            )
        )
    }
}
