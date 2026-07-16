import XCTest
@testable import MLXServerManager

final class AutoUnloadPlannerTests: XCTestCase {
    func testExpiresAtExactConfiguredLimit() {
        let now = Date(timeIntervalSince1970: 10_000)
        let candidate = AutoUnloadCandidate(
            modelID: "model-a",
            startedAt: now.addingTimeInterval(-30 * 60),
            limitMinutes: 30,
            isEnabled: true,
            isTransitioning: false
        )

        XCTAssertEqual(
            AutoUnloadPlanner.expiredModelIDs(from: [candidate], now: now),
            ["model-a"]
        )
    }

    func testDoesNotExpireBeforeConfiguredLimit() {
        let now = Date(timeIntervalSince1970: 10_000)
        let candidate = AutoUnloadCandidate(
            modelID: "model-a",
            startedAt: now.addingTimeInterval(-(30 * 60 - 1)),
            limitMinutes: 30,
            isEnabled: true,
            isTransitioning: false
        )

        XCTAssertTrue(AutoUnloadPlanner.expiredModelIDs(from: [candidate], now: now).isEmpty)
    }

    func testIgnoresDisabledAndTransitioningModels() {
        let now = Date(timeIntervalSince1970: 10_000)
        let expiredStart = now.addingTimeInterval(-60 * 60)
        let candidates = [
            AutoUnloadCandidate(
                modelID: "disabled",
                startedAt: expiredStart,
                limitMinutes: 30,
                isEnabled: false,
                isTransitioning: false
            ),
            AutoUnloadCandidate(
                modelID: "transitioning",
                startedAt: expiredStart,
                limitMinutes: 30,
                isEnabled: true,
                isTransitioning: true
            )
        ]

        XCTAssertTrue(AutoUnloadPlanner.expiredModelIDs(from: candidates, now: now).isEmpty)
    }

    func testReturnsMultipleExpiredModelsInDeterministicOrder() {
        let now = Date(timeIntervalSince1970: 10_000)
        let candidates = [
            AutoUnloadCandidate(
                modelID: "model-c",
                startedAt: now.addingTimeInterval(-45 * 60),
                limitMinutes: 30,
                isEnabled: true,
                isTransitioning: false
            ),
            AutoUnloadCandidate(
                modelID: "model-b",
                startedAt: now.addingTimeInterval(-60 * 60),
                limitMinutes: 30,
                isEnabled: true,
                isTransitioning: false
            ),
            AutoUnloadCandidate(
                modelID: "model-a",
                startedAt: now.addingTimeInterval(-60 * 60),
                limitMinutes: 30,
                isEnabled: true,
                isTransitioning: false
            )
        ]

        XCTAssertEqual(
            AutoUnloadPlanner.expiredModelIDs(from: candidates, now: now),
            ["model-a", "model-b", "model-c"]
        )
    }
}
