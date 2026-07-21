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

        XCTAssertEqual(result, .stopped(processIdentifier: 101, terminationStatus: 0, stopMethod: .terminate))
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

    func testStartingDifferentProfilesOnTheSameEndpointIsRejected() throws {
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

        XCTAssertThrowsError(
            try registry.start(
                profileID: "second",
                request: Self.request(modelID: "second", port: 8000),
                outputHandler: { _ in },
                terminationHandler: { _ in }
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelProcessRegistryError,
                .endpointAlreadyManaged(
                    ManagedProcessEndpoint(
                        profileID: "first",
                        host: "127.0.0.1",
                        port: 8000,
                        processIdentifier: 101
                    )
                )
            )
        }
        XCTAssertEqual(registry.runningProfileIDs, ["first"])
        XCTAssertEqual(managers.count, 1)
    }

    func testEndpointMatchingTreatsLocalhostAsLoopback() throws {
        let manager = FakeModelProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(managerFactory: { manager })
        let request = ModelLaunchRequest(
            executablePath: "/usr/bin/true",
            modelID: "first",
            host: "localhost",
            port: 8000,
            enableThinking: false,
            advancedLaunchOptions: nil
        )

        _ = try registry.start(
            profileID: "first",
            request: request,
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )

        XCTAssertEqual(
            registry.runningEndpoint(host: "127.0.0.1", port: 8000),
            ManagedProcessEndpoint(
                profileID: "first",
                host: "localhost",
                port: 8000,
                processIdentifier: 101
            )
        )
    }

    func testEndpointMatchingTreatsWildcardHostAsConflicting() throws {
        let manager = FakeModelProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(managerFactory: { manager })
        let request = ModelLaunchRequest(
            executablePath: "/usr/bin/true",
            modelID: "first",
            host: "0.0.0.0",
            port: 8000,
            enableThinking: false,
            advancedLaunchOptions: nil
        )

        _ = try registry.start(
            profileID: "first",
            request: request,
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )

        XCTAssertEqual(
            registry.runningEndpoint(host: "127.0.0.1", port: 8000)?.profileID,
            "first"
        )
    }

    func testStoppedEndpointCanBeReusedByAnotherProfile() async throws {
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

        _ = await registry.stop(profileID: "first")

        _ = try registry.start(
            profileID: "second",
            request: Self.request(modelID: "second", port: 8000),
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )

        XCTAssertNil(registry.processIdentifier(for: "first"))
        XCTAssertEqual(registry.processIdentifier(for: "second"), 202)
        XCTAssertEqual(registry.runningProfileIDs, ["second"])
    }

    func testDelayedTerminationFromPreviousLaunchDoesNotRemoveRestartedProfile() throws {
        let manager = FakeModelProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(managerFactory: { manager })
        var deliveredTerminations: [(launch: String, status: Int32)] = []

        _ = try registry.start(
            profileID: "first",
            request: Self.request(modelID: "first", host: "127.0.0.1", port: 8000),
            outputHandler: { _ in },
            terminationHandler: { status in
                deliveredTerminations.append(("previous", status))
            }
        )

        manager.prepareNextStart(processIdentifier: 202)
        _ = try registry.start(
            profileID: "first",
            request: Self.request(modelID: "first", host: "localhost", port: 8100),
            outputHandler: { _ in },
            terminationHandler: { status in
                deliveredTerminations.append(("current", status))
            }
        )

        manager.deliverTermination(forLaunchAt: 0, status: 0)

        XCTAssertTrue(deliveredTerminations.isEmpty)
        XCTAssertEqual(registry.processIdentifier(for: "first"), 202)
        XCTAssertEqual(
            registry.runningEndpoint(host: "127.0.0.1", port: 8100),
            ManagedProcessEndpoint(
                profileID: "first",
                host: "localhost",
                port: 8100,
                processIdentifier: 202
            )
        )

        manager.deliverTermination(forLaunchAt: 1, status: 9)

        XCTAssertEqual(deliveredTerminations.count, 1)
        XCTAssertEqual(deliveredTerminations.first?.launch, "current")
        XCTAssertEqual(deliveredTerminations.first?.status, 9)
        XCTAssertNil(registry.processIdentifier(for: "first"))
    }

    private static func request(modelID: String, port: Int) -> ModelLaunchRequest {
        request(modelID: modelID, host: "127.0.0.1", port: port)
    }

    private static func request(modelID: String, host: String, port: Int) -> ModelLaunchRequest {
        ModelLaunchRequest(
            executablePath: "/usr/bin/true",
            modelID: modelID,
            host: host,
            port: port,
            enableThinking: false,
            advancedLaunchOptions: nil
        )
    }
}

private final class FakeModelProcessManager: ModelProcessManaging {
    private(set) var managedProcessIdentifier: Int32?
    private var nextProcessIdentifier: Int32?
    private var terminationHandlers: [@MainActor @Sendable (Int32) -> Void] = []

    init(processIdentifier: Int32) {
        managedProcessIdentifier = processIdentifier
    }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        if let nextProcessIdentifier {
            managedProcessIdentifier = nextProcessIdentifier
            self.nextProcessIdentifier = nil
        }
        terminationHandlers.append(terminationHandler)
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
            stopMethod: .terminate
        )
    }

    @MainActor
    func terminate(status: Int32) {
        managedProcessIdentifier = nil
        terminationHandlers.last?(status)
    }

    func prepareNextStart(processIdentifier: Int32) {
        managedProcessIdentifier = nil
        nextProcessIdentifier = processIdentifier
    }

    @MainActor
    func deliverTermination(forLaunchAt index: Int, status: Int32) {
        terminationHandlers[index](status)
    }
}
