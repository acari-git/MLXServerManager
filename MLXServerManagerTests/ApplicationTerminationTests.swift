import XCTest
@testable import MLXServerManager

@MainActor
final class ApplicationTerminationTests: XCTestCase {
    func testPolicyIncludesOnlyRunningProfilesWithOwnedProcessIdentifiers() {
        let first = makeModel(id: "model/first", port: 8080)
        let second = makeModel(id: "model/second", port: 8081)
        let third = makeModel(id: "model/third", port: 8082)
        let identifiers: [ModelConfig.ID: Int32] = [
            first.id: 111,
            third.id: 333
        ]

        let targets = ApplicationTerminationPolicy.targets(
            models: [first, second, third],
            runningProfileIDs: [first.id, second.id, third.id],
            processIdentifier: { identifiers[$0] }
        )

        XCTAssertEqual(targets.map(\.profileID), [first.id, third.id])
        XCTAssertEqual(targets.map(\.processIdentifier), [111, 333])
        XCTAssertEqual(targets.map(\.endpoint), ["127.0.0.1:8080", "127.0.0.1:8082"])
    }

    func testPolicyDoesNotTreatExternalOrUntrackedProfilesAsOwnedTargets() {
        let model = makeModel(id: "model/external", port: 8080)

        let targets = ApplicationTerminationPolicy.targets(
            models: [model],
            runningProfileIDs: [],
            processIdentifier: { _ in 900 }
        )

        XCTAssertTrue(targets.isEmpty)
    }

    func testCoordinatorReportsProgressAndCompletesWithoutFailures() async {
        let targets = [
            makeTarget(id: "model/one", port: 8080, processIdentifier: 11),
            makeTarget(id: "model/two", port: 8081, processIdentifier: 22)
        ]
        let coordinator = ApplicationTerminationCoordinator()
        var progress: [(Int, Int)] = []
        var completedFailures: [ManagedTerminationFailure]?

        coordinator.stopAll(
            targets: targets,
            stopOperation: { _ in true },
            progressHandler: { progress.append(($0, $1)) },
            completionHandler: { completedFailures = $0 }
        )
        await waitUntil { completedFailures != nil }

        XCTAssertEqual(progress.map(\.0), [1, 2])
        XCTAssertEqual(progress.map(\.1), [2, 2])
        XCTAssertEqual(completedFailures, [])
        XCTAssertFalse(coordinator.isRunning)
    }

    func testCoordinatorKeepsFailedTargetForTerminationCancellation() async {
        let first = makeTarget(id: "model/one", port: 8080, processIdentifier: 11)
        let second = makeTarget(id: "model/two", port: 8081, processIdentifier: 22)
        let coordinator = ApplicationTerminationCoordinator()
        var completedFailures: [ManagedTerminationFailure]?

        coordinator.stopAll(
            targets: [first, second],
            stopOperation: { target in target.id != second.id },
            progressHandler: { _, _ in },
            completionHandler: { completedFailures = $0 }
        )
        await waitUntil { completedFailures != nil }

        XCTAssertEqual(completedFailures?.map(\.target.id), [second.id])
        XCTAssertFalse(coordinator.isRunning)
    }

    func testTerminationPhaseDistinguishesPromptingAndStopping() {
        let target = ManagedTerminationTarget(
            profileID: "model/one",
            displayName: "One",
            modelID: "model/one",
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 42
        )

        XCTAssertTrue(ApplicationTerminationPhase.prompting(targets: [target]).isPrompting)
        XCTAssertFalse(ApplicationTerminationPhase.prompting(targets: [target]).isStopping)
        XCTAssertTrue(ApplicationTerminationPhase.stopping(completed: 0, total: 1).isStopping)
    }

    private func makeTarget(
        id: String,
        port: Int,
        processIdentifier: Int32
    ) -> ManagedTerminationTarget {
        ManagedTerminationTarget(
            profileID: id,
            displayName: id,
            modelID: id,
            host: "127.0.0.1",
            port: port,
            processIdentifier: processIdentifier
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            await Task.yield()
        }
    }

    private func makeModel(id: String, port: Int) -> ModelConfig {
        ModelConfig(
            modelID: id,
            displayName: id,
            family: "Test",
            quantization: "4-bit",
            localName: id.replacingOccurrences(of: "/", with: "-"),
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
    }
}
