import XCTest
@testable import MLXServerManager

@MainActor
final class HuggingFaceRequestCoordinatorTests: XCTestCase {
    func testCompletedRequestStopsRunning() async {
        let completed = expectation(description: "Search completed")
        let coordinator = HuggingFaceRequestCoordinator()

        coordinator.start(.search) { generation in
            XCTAssertTrue(coordinator.isCurrent(.search, generation: generation))
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1)
        await Task.yield()

        XCTAssertFalse(coordinator.isRunning(.search))
    }

    func testReplacingRequestKeepsReplacementCurrentAfterStaleRequestFinishes() async {
        let firstStarted = expectation(description: "First search started")
        let replacementStarted = expectation(description: "Replacement search started")
        var firstContinuation: CheckedContinuation<Void, Never>?
        var replacementContinuation: CheckedContinuation<Void, Never>?
        var replacementGeneration: HuggingFaceRequestCoordinator.Generation?
        let coordinator = HuggingFaceRequestCoordinator()

        coordinator.start(.search) { _ in
            firstStarted.fulfill()
            await withCheckedContinuation { continuation in
                firstContinuation = continuation
            }
        }
        await fulfillment(of: [firstStarted], timeout: 1)

        coordinator.start(.search) { generation in
            replacementGeneration = generation
            replacementStarted.fulfill()
            await withCheckedContinuation { continuation in
                replacementContinuation = continuation
            }
        }
        await fulfillment(of: [replacementStarted], timeout: 1)

        firstContinuation?.resume()
        await Task.yield()

        XCTAssertTrue(coordinator.isRunning(.search))
        XCTAssertEqual(
            replacementGeneration.map { coordinator.isCurrent(.search, generation: $0) },
            true
        )

        replacementContinuation?.resume()
        await Task.yield()
        XCTAssertFalse(coordinator.isRunning(.search))
    }

    func testSearchAndFilePreviewRequestsAreIndependent() async {
        let searchStarted = expectation(description: "Search started")
        let previewStarted = expectation(description: "File preview started")
        var searchContinuation: CheckedContinuation<Void, Never>?
        var previewContinuation: CheckedContinuation<Void, Never>?
        let coordinator = HuggingFaceRequestCoordinator()

        coordinator.start(.search) { _ in
            searchStarted.fulfill()
            await withCheckedContinuation { continuation in
                searchContinuation = continuation
            }
        }
        coordinator.start(.filePreview) { _ in
            previewStarted.fulfill()
            await withCheckedContinuation { continuation in
                previewContinuation = continuation
            }
        }

        await fulfillment(of: [searchStarted, previewStarted], timeout: 1)
        coordinator.cancel(.search)

        XCTAssertFalse(coordinator.isRunning(.search))
        XCTAssertTrue(coordinator.isRunning(.filePreview))

        searchContinuation?.resume()
        previewContinuation?.resume()
        await Task.yield()
    }

    func testCancelledGenerationIsNoLongerCurrent() async {
        let started = expectation(description: "Search started")
        var continuation: CheckedContinuation<Void, Never>?
        var generation: HuggingFaceRequestCoordinator.Generation?
        let coordinator = HuggingFaceRequestCoordinator()

        coordinator.start(.search) { activeGeneration in
            generation = activeGeneration
            started.fulfill()
            await withCheckedContinuation { pendingContinuation in
                continuation = pendingContinuation
            }
        }
        await fulfillment(of: [started], timeout: 1)

        coordinator.cancel(.search)

        XCTAssertFalse(coordinator.isRunning(.search))
        XCTAssertEqual(
            generation.map { coordinator.isCurrent(.search, generation: $0) },
            false
        )

        continuation?.resume()
        await Task.yield()
    }
}
