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
    private var terminationHandler: (@MainActor @Sendable (Int32) -> Void)?

    init(processIdentifier: Int32) {
        managedProcessIdentifier = processIdentifier
    }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
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
            stopMethod: .terminate
        )
    }

    @MainActor
    func terminate(status: Int32) {
        managedProcessIdentifier = nil
        terminationHandler?(status)
    }
}
