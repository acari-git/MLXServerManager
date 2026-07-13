import XCTest
@testable import MLXServerManager

@MainActor
final class ModelProcessRegistryTests: XCTestCase {
    func testStartsAndTracksIndependentProfiles() throws {
        let first = FakeModelProcessManager(processIdentifier: 101)
        let second = FakeModelProcessManager(processIdentifier: 202)
        var managers = [first, second]
        let registry = ModelProcessRegistry(managerFactory: { managers.removeFirst() })

        _ = try registry.start(
            profileID: "first",
            request: Self.request(modelID: "first", port: 8000),
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )
        _ = try registry.start(
            profileID: "second",
            request: Self.request(modelID: "second", port: 8001),
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )

        XCTAssertEqual(registry.processIdentifier(for: "first"), 101)
        XCTAssertEqual(registry.processIdentifier(for: "second"), 202)
        XCTAssertEqual(registry.runningProfileIDs, ["first", "second"])
    }

    func testStoppingOneProfileKeepsTheOtherRunning() async throws {
        let first = FakeModelProcessManager(processIdentifier: 101)
        let second = FakeModelProcessManager(processIdentifier: 202)
        var managers = [first, second]
        let registry = ModelProcessRegistry(managerFactory: { managers.removeFirst() })

        for (profileID, port) in [("first", 8000), ("second", 8001)] {
            _ = try registry.start(
                profileID: profileID,
                request: Self.request(modelID: profileID, port: port),
                outputHandler: { _ in },
                terminationHandler: { _ in }
            )
        }

        let result = await registry.stop(profileID: "first")

        XCTAssertEqual(result, .stopped(processIdentifier: 101, terminationStatus: 0, usedInterrupt: false))
        XCTAssertNil(registry.processIdentifier(for: "first"))
        XCTAssertEqual(registry.processIdentifier(for: "second"), 202)
    }

    func testTerminationRemovesOnlyMatchingProfile() throws {
        let first = FakeModelProcessManager(processIdentifier: 101)
        let second = FakeModelProcessManager(processIdentifier: 202)
        var managers = [first, second]
        let registry = ModelProcessRegistry(managerFactory: { managers.removeFirst() })

        for (profileID, port) in [("first", 8000), ("second", 8001)] {
            _ = try registry.start(
                profileID: profileID,
                request: Self.request(modelID: profileID, port: port),
                outputHandler: { _ in },
                terminationHandler: { _ in }
            )
        }

        first.terminate(status: 9)

        XCTAssertNil(registry.processIdentifier(for: "first"))
        XCTAssertEqual(registry.processIdentifier(for: "second"), 202)
    }

    func testStartingTheSameProfileTwiceIsRejected() throws {
        let manager = FakeModelProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(managerFactory: { manager })

        _ = try registry.start(
            profileID: "first",
            request: Self.request(modelID: "first", port: 8000),
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )

        XCTAssertThrowsError(
            try registry.start(
                profileID: "first",
                request: Self.request(modelID: "first", port: 8000),
                outputHandler: { _ in },
                terminationHandler: { _ in }
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelProcessManagerError,
                .alreadyRunning(processIdentifier: 101)
            )
        }
    }

    private static func request(modelID: String, port: Int) -> ModelLaunchRequest {
        ModelLaunchRequest(
            executablePath: "/usr/bin/true",
            modelID: modelID,
            host: "127.0.0.1",
            port: port,
            enableThinking: false,
            advancedLaunchOptions: nil
        )
    }
}

private final class FakeModelProcessManager: ModelProcessManaging {
    private(set) var managedProcessIdentifier: Int32?
    private var terminationHandler: ((Int32) -> Void)?

    init(processIdentifier: Int32) {
        managedProcessIdentifier = processIdentifier
    }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (Int32) -> Void
    ) throws -> ModelLaunchResult {
        self.terminationHandler = terminationHandler
        guard let managedProcessIdentifier else {
            throw ModelProcessManagerError.launchFailed("No fake process identifier.")
        }
        return ModelLaunchResult(
            processIdentifier: managedProcessIdentifier,
            commandSummary: request.modelID
        )
    }

    func stop(
        gracefulTimeout: TimeInterval,
        interruptTimeout: TimeInterval
    ) async -> ModelStopResult {
        guard let managedProcessIdentifier else {
            return .notRunning
        }
        self.managedProcessIdentifier = nil
        return .stopped(
            processIdentifier: managedProcessIdentifier,
            terminationStatus: 0,
            usedInterrupt: false
        )
    }

    func terminate(status: Int32) {
        managedProcessIdentifier = nil
        terminationHandler?(status)
    }
}
