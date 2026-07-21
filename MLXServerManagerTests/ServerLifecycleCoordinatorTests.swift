import XCTest
@testable import MLXServerManager

@MainActor
final class ServerLifecycleCoordinatorTests: XCTestCase {
    func testWaitForReadyRetriesUntilReady() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(initialManager: manager)
        var responses: [ReadyCheckResult] = [
            .notReady(url: Self.modelsURL, statusCode: 503),
            .ready(url: Self.modelsURL, statusCode: 200)
        ]
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: registry,
            maximumReadyAttempts: 3,
            readyRetryDelayNanoseconds: 25,
            readyCheckOperation: { _, _, _ in responses.removeFirst() },
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        var events: [ServerReadyWaitEvent] = []

        let outcome = await coordinator.waitForReadyAfterStart(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 101,
            expectedModelID: "owner/model",
            isStopRequested: { false },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(delays, [25])
        XCTAssertEqual(
            events,
            [
                .waiting,
                .notReady(attempt: 1, url: Self.modelsURL, statusCode: 503),
                .ready(url: Self.modelsURL, statusCode: 200)
            ]
        )
    }

    func testWaitStopsBeforeReadyProbeWhenStopWasRequested() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(initialManager: manager)
        var readyCheckCount = 0
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: registry,
            readyCheckOperation: { _, _, _ in
                readyCheckCount += 1
                return .ready(url: Self.modelsURL, statusCode: 200)
            }
        )
        try startProfile(using: coordinator)
        var events: [ServerReadyWaitEvent] = []

        let outcome = await coordinator.waitForReadyAfterStart(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 101,
            expectedModelID: "owner/model",
            isStopRequested: { true },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .stopRequested)
        XCTAssertEqual(readyCheckCount, 0)
        XCTAssertEqual(events, [.waiting, .stopRequested])
    }

    func testReadyResponseIsIgnoredAfterManagedProcessExits() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(initialManager: manager)
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: registry,
            readyCheckOperation: { _, _, _ in
                manager.simulateExit()
                return .ready(url: Self.modelsURL, statusCode: 200)
            }
        )
        try startProfile(using: coordinator)
        var events: [ServerReadyWaitEvent] = []

        let outcome = await coordinator.waitForReadyAfterStart(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 101,
            expectedModelID: "owner/model",
            isStopRequested: { false },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .processNoLongerRunning)
        XCTAssertEqual(events, [.waiting, .readyResponseIgnored])
    }

    func testInvalidReadyInputStopsWithoutRetrying() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(initialManager: manager)
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: registry,
            maximumReadyAttempts: 3,
            readyCheckOperation: { _, _, _ in .invalidInput(message: "Invalid host") },
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        var events: [ServerReadyWaitEvent] = []

        let outcome = await coordinator.waitForReadyAfterStart(
            profileID: "profile",
            host: "",
            port: 8080,
            processIdentifier: 101,
            expectedModelID: "owner/model",
            isStopRequested: { false },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .invalidInput(message: "Invalid host"))
        XCTAssertTrue(delays.isEmpty)
        XCTAssertEqual(events, [.waiting, .invalidInput(message: "Invalid host")])
    }

    func testExhaustionPreservesConfiguredAttemptAndDelayCounts() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let registry = ModelProcessRegistry(initialManager: manager)
        var readyCheckCount = 0
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: registry,
            maximumReadyAttempts: 2,
            readyRetryDelayNanoseconds: 50,
            readyCheckOperation: { _, _, _ in
                readyCheckCount += 1
                return .failed(url: Self.modelsURL, message: "Not ready")
            },
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        var events: [ServerReadyWaitEvent] = []

        let outcome = await coordinator.waitForReadyAfterStart(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 101,
            expectedModelID: "owner/model",
            isStopRequested: { false },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .exhausted)
        XCTAssertEqual(readyCheckCount, 2)
        XCTAssertEqual(delays, [50, 50])
        XCTAssertEqual(events.last, .exhausted)
    }

    func testStopWaitsForPortToBecomeAvailable() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        var portResults: [PortCheckResult] = [
            .busy(host: "127.0.0.1", port: 8080, pid: nil),
            .busy(host: "127.0.0.1", port: 8080, pid: nil),
            .available(host: "127.0.0.1", port: 8080)
        ]
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager),
            maximumPortReleaseAttempts: 4,
            shortPortReleaseDelayNanoseconds: 10,
            longPortReleaseDelayNanoseconds: 20,
            longPortReleaseDelayStartAttempt: 2,
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        var events: [ServerStopEvent] = []

        let outcome = await coordinator.stopAndWaitForPortRelease(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            portCheckOperation: { _, _ in portResults.removeFirst() },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .released)
        XCTAssertEqual(delays, [10, 10])
        XCTAssertEqual(
            events,
            [
                .processResult(.stopped(
                    processIdentifier: 101,
                    terminationStatus: 0,
                    stopMethod: .terminate
                )),
                .checkingPortRelease,
                .portCheck(
                    result: .busy(host: "127.0.0.1", port: 8080, pid: nil),
                    announceBusy: true
                ),
                .portCheck(
                    result: .busy(host: "127.0.0.1", port: 8080, pid: nil),
                    announceBusy: false
                ),
                .portCheck(
                    result: .available(host: "127.0.0.1", port: 8080),
                    announceBusy: false
                )
            ]
        )
    }

    func testNotRunningChecksPortOnceAndReportsManagedProcessState() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager),
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        manager.simulateExit()
        var portCheckCount = 0
        var events: [ServerStopEvent] = []

        let outcome = await coordinator.stopAndWaitForPortRelease(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            portCheckOperation: { host, port in
                portCheckCount += 1
                return .available(host: host, port: port)
            },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .released)
        XCTAssertEqual(portCheckCount, 1)
        XCTAssertTrue(delays.isEmpty)
        XCTAssertEqual(
            events,
            [
                .processResult(.notRunning),
                .portCheck(
                    result: .available(host: "127.0.0.1", port: 8080),
                    announceBusy: true
                ),
                .managedProcessNotRunning
            ]
        )
    }

    func testStopTimeoutDoesNotProbePort() async throws {
        let manager = LifecycleFakeProcessManager(
            processIdentifier: 101,
            stopResult: .timedOut(processIdentifier: 101)
        )
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager)
        )
        try startProfile(using: coordinator)
        var portCheckCount = 0
        var events: [ServerStopEvent] = []

        let outcome = await coordinator.stopAndWaitForPortRelease(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            portCheckOperation: { host, port in
                portCheckCount += 1
                return .available(host: host, port: port)
            },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .timedOut(processIdentifier: 101))
        XCTAssertEqual(portCheckCount, 0)
        XCTAssertEqual(events, [.processResult(.timedOut(processIdentifier: 101))])
    }

    func testPortCheckFailureStopsReleaseWaitImmediately() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager),
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        var events: [ServerStopEvent] = []

        let outcome = await coordinator.stopAndWaitForPortRelease(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            portCheckOperation: { host, port in
                .failed(host: host, port: port, message: "socket failed")
            },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .failed)
        XCTAssertTrue(delays.isEmpty)
        XCTAssertEqual(
            events.suffix(2),
            [
                .checkingPortRelease,
                .portCheck(
                    result: .failed(host: "127.0.0.1", port: 8080, message: "socket failed"),
                    announceBusy: true
                )
            ]
        )
    }

    func testPortReleaseWaitCancellationIsReported() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager),
            sleepOperation: { _ in throw CancellationError() }
        )
        try startProfile(using: coordinator)
        var events: [ServerStopEvent] = []

        let outcome = await coordinator.stopAndWaitForPortRelease(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            portCheckOperation: { host, port in .busy(host: host, port: port, pid: nil) },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(events.suffix(2).first, .portCheck(
            result: .busy(host: "127.0.0.1", port: 8080, pid: nil),
            announceBusy: true
        ))
        XCTAssertEqual(events.last, .portReleaseWaitCancelled)
    }

    func testPortReleaseWaitExhaustionPreservesAttemptAndDelayCounts() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        var delays: [UInt64] = []
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager),
            maximumPortReleaseAttempts: 3,
            shortPortReleaseDelayNanoseconds: 10,
            longPortReleaseDelayNanoseconds: 20,
            longPortReleaseDelayStartAttempt: 1,
            sleepOperation: { delays.append($0) }
        )
        try startProfile(using: coordinator)
        var portCheckCount = 0
        var events: [ServerStopEvent] = []

        let outcome = await coordinator.stopAndWaitForPortRelease(
            profileID: "profile",
            host: "127.0.0.1",
            port: 8080,
            portCheckOperation: { host, port in
                portCheckCount += 1
                return .busy(host: host, port: port, pid: nil)
            },
            eventHandler: { events.append($0) }
        )

        XCTAssertEqual(outcome, .busy)
        XCTAssertEqual(portCheckCount, 3)
        XCTAssertEqual(delays, [10, 20])
        XCTAssertEqual(events.last, .portReleaseWaitExhausted)
    }

    func testStartStopAndRunningQueriesAreForwarded() async throws {
        let manager = LifecycleFakeProcessManager(processIdentifier: 101)
        let coordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: manager)
        )

        try startProfile(using: coordinator)

        XCTAssertEqual(coordinator.processIdentifier(for: "profile"), 101)
        XCTAssertTrue(coordinator.isRunning("profile"))
        XCTAssertTrue(coordinator.isAnyProcessRunning)
        XCTAssertEqual(coordinator.runningProfileIDs, ["profile"])

        let result = await coordinator.stop(profileID: "profile")

        XCTAssertEqual(
            result,
            .stopped(processIdentifier: 101, terminationStatus: 0, stopMethod: .terminate)
        )
        XCTAssertFalse(coordinator.isRunning("profile"))
    }

    private func startProfile(using coordinator: ServerLifecycleCoordinator) throws {
        _ = try coordinator.start(
            profileID: "profile",
            request: ModelLaunchRequest(
                executablePath: "/usr/bin/true",
                modelID: "owner/model",
                host: "127.0.0.1",
                port: 8080,
                enableThinking: false,
                advancedLaunchOptions: nil
            ),
            outputHandler: { _ in },
            terminationHandler: { _ in }
        )
    }

    private static let modelsURL = URL(string: "http://127.0.0.1:8080/v1/models")!
}

private final class LifecycleFakeProcessManager: ModelProcessManaging {
    private(set) var managedProcessIdentifier: Int32?
    private let stopResult: ModelStopResult?

    init(processIdentifier: Int32, stopResult: ModelStopResult? = nil) {
        managedProcessIdentifier = processIdentifier
        self.stopResult = stopResult
    }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        guard let managedProcessIdentifier else {
            throw ModelProcessManagerError.launchFailed("Missing fake process identifier")
        }
        return ModelLaunchResult(
            processIdentifier: managedProcessIdentifier,
            commandSummary: "fake launch"
        )
    }

    func stop(
        gracefulTimeout: TimeInterval,
        interruptTimeout: TimeInterval
    ) async -> ModelStopResult {
        if let stopResult {
            switch stopResult {
            case .notRunning, .stopped:
                managedProcessIdentifier = nil
            case .timedOut:
                break
            }
            return stopResult
        }

        guard let processIdentifier = managedProcessIdentifier else {
            return .notRunning
        }
        managedProcessIdentifier = nil
        return .stopped(
            processIdentifier: processIdentifier,
            terminationStatus: 0,
            stopMethod: .terminate
        )
    }

    func simulateExit() {
        managedProcessIdentifier = nil
    }
}
