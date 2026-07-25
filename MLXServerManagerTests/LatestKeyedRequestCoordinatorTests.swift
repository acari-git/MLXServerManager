import XCTest
@testable import MLXServerManager

@MainActor
final class LatestKeyedRequestCoordinatorTests: XCTestCase {
    func testDifferentKeysRunIndependently() async {
        let firstStarted = expectation(description: "First request started")
        let secondStarted = expectation(description: "Second request started")
        var firstContinuation: CheckedContinuation<Void, Never>?
        var secondContinuation: CheckedContinuation<Void, Never>?
        let coordinator = LatestKeyedRequestCoordinator<String>()

        coordinator.start("first") { _ in
            firstStarted.fulfill()
            await withCheckedContinuation { continuation in
                firstContinuation = continuation
            }
        }
        coordinator.start("second") { _ in
            secondStarted.fulfill()
            await withCheckedContinuation { continuation in
                secondContinuation = continuation
            }
        }

        await fulfillment(of: [firstStarted, secondStarted], timeout: 1)
        XCTAssertTrue(coordinator.isRunning("first"))
        XCTAssertTrue(coordinator.isRunning("second"))

        firstContinuation?.resume()

        let firstFinished = await waitUntil { !coordinator.isRunning("first") }
        XCTAssertTrue(
            firstFinished,
            "The completed first request should clear its key."
        )
        XCTAssertTrue(coordinator.isRunning("second"))

        secondContinuation?.resume()
        let secondFinished = await waitUntil { !coordinator.isRunning("second") }
        XCTAssertTrue(
            secondFinished,
            "The completed second request should clear its key."
        )
    }

    func testReplacingOneKeyKeepsReplacementCurrentAndDoesNotAffectOtherKey() async {
        let staleStarted = expectation(description: "Stale request started")
        let replacementStarted = expectation(description: "Replacement request started")
        let independentStarted = expectation(description: "Independent request started")
        var staleContinuation: CheckedContinuation<Void, Never>?
        var replacementContinuation: CheckedContinuation<Void, Never>?
        var independentContinuation: CheckedContinuation<Void, Never>?
        var replacementGeneration: LatestKeyedRequestCoordinator<String>.Generation?
        let coordinator = LatestKeyedRequestCoordinator<String>()

        coordinator.start("shared") { _ in
            staleStarted.fulfill()
            await withCheckedContinuation { continuation in
                staleContinuation = continuation
            }
        }
        coordinator.start("independent") { _ in
            independentStarted.fulfill()
            await withCheckedContinuation { continuation in
                independentContinuation = continuation
            }
        }
        await fulfillment(of: [staleStarted, independentStarted], timeout: 1)

        coordinator.start("shared") { generation in
            replacementGeneration = generation
            replacementStarted.fulfill()
            await withCheckedContinuation { continuation in
                replacementContinuation = continuation
            }
        }
        await fulfillment(of: [replacementStarted], timeout: 1)

        staleContinuation?.resume()
        await Task.yield()

        XCTAssertTrue(coordinator.isRunning("shared"))
        XCTAssertTrue(coordinator.isRunning("independent"))
        XCTAssertEqual(
            replacementGeneration.map {
                coordinator.isCurrent("shared", generation: $0)
            },
            true
        )

        replacementContinuation?.resume()
        independentContinuation?.resume()

        let requestsFinished = await waitUntil {
            !coordinator.isRunning("shared")
                && !coordinator.isRunning("independent")
        }
        XCTAssertTrue(
            requestsFinished,
            "Completed requests should clear both active keys."
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !condition() {
            guard clock.now < deadline else {
                return false
            }
            await Task.yield()
        }
        return true
    }
}
