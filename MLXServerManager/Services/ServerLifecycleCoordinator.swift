import Foundation

nonisolated enum ServerReadyWaitEvent: Equatable {
    case waiting
    case processNoLongerRunning
    case stopRequested
    case readyResponseIgnored
    case ready(url: URL, statusCode: Int)
    case notReady(attempt: Int, url: URL, statusCode: Int)
    case invalidInput(message: String)
    case failed(attempt: Int, url: URL?, message: String)
    case timedOut(attempt: Int, url: URL)
    case cancelled
    case exhausted
}

nonisolated enum ServerReadyWaitOutcome: Equatable {
    case ready
    case processNoLongerRunning
    case stopRequested
    case invalidInput(message: String)
    case cancelled
    case exhausted

    var isReady: Bool {
        self == .ready
    }
}

nonisolated enum ServerPortReleaseOutcome: Equatable {
    case released
    case busy
    case failed
}

nonisolated enum ServerStopEvent: Equatable {
    case processResult(ModelStopResult)
    case checkingPortRelease
    case portCheck(result: PortCheckResult, announceBusy: Bool)
    case portReleaseWaitCancelled
    case portReleaseWaitExhausted
    case managedProcessNotRunning
}

nonisolated enum ServerStopOutcome: Equatable {
    case released
    case busy
    case failed
    case timedOut(processIdentifier: Int32)
    case cancelled
}

@MainActor
final class ServerLifecycleCoordinator {
    typealias ReadyCheckOperation = @MainActor (
        _ host: String,
        _ port: Int,
        _ expectedModelID: String?
    ) async -> ReadyCheckResult
    typealias PortCheckOperation = @MainActor (_ host: String, _ port: Int) -> PortCheckResult
    typealias SleepOperation = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private let processRegistry: ModelProcessRegistry
    private let maximumReadyAttempts: Int
    private let readyRetryDelayNanoseconds: UInt64
    private let readyCheckOperation: ReadyCheckOperation
    private let sleepOperation: SleepOperation
    private let maximumPortReleaseAttempts: Int
    private let shortPortReleaseDelayNanoseconds: UInt64
    private let longPortReleaseDelayNanoseconds: UInt64
    private let longPortReleaseDelayStartAttempt: Int

    init(
        processRegistry: ModelProcessRegistry,
        readyChecker: ReadyChecker? = nil,
        maximumReadyAttempts: Int = 10,
        readyRetryDelayNanoseconds: UInt64 = 1_000_000_000,
        maximumPortReleaseAttempts: Int = 40,
        shortPortReleaseDelayNanoseconds: UInt64 = 100_000_000,
        longPortReleaseDelayNanoseconds: UInt64 = 250_000_000,
        longPortReleaseDelayStartAttempt: Int = 20,
        readyCheckOperation: ReadyCheckOperation? = nil,
        sleepOperation: SleepOperation? = nil
    ) {
        self.processRegistry = processRegistry
        self.maximumReadyAttempts = max(maximumReadyAttempts, 1)
        self.readyRetryDelayNanoseconds = readyRetryDelayNanoseconds
        if let readyCheckOperation {
            self.readyCheckOperation = readyCheckOperation
        } else {
            let resolvedReadyChecker = readyChecker ?? ReadyChecker()
            self.readyCheckOperation = { host, port, expectedModelID in
                await resolvedReadyChecker.check(
                    host: host,
                    port: port,
                    expectedModelID: expectedModelID
                )
            }
        }
        self.maximumPortReleaseAttempts = max(maximumPortReleaseAttempts, 1)
        self.shortPortReleaseDelayNanoseconds = shortPortReleaseDelayNanoseconds
        self.longPortReleaseDelayNanoseconds = longPortReleaseDelayNanoseconds
        self.longPortReleaseDelayStartAttempt = max(longPortReleaseDelayStartAttempt, 0)
        self.sleepOperation = sleepOperation ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    var runningProfileIDs: Set<ModelConfig.ID> {
        processRegistry.runningProfileIDs
    }

    var isAnyProcessRunning: Bool {
        processRegistry.isAnyProcessRunning
    }

    func processIdentifier(for profileID: ModelConfig.ID) -> Int32? {
        processRegistry.processIdentifier(for: profileID)
    }

    func isRunning(_ profileID: ModelConfig.ID) -> Bool {
        processRegistry.isRunning(profileID)
    }

    func runningEndpoint(
        host: String,
        port: Int,
        excluding excludedProfileID: ModelConfig.ID? = nil
    ) -> ManagedProcessEndpoint? {
        processRegistry.runningEndpoint(
            host: host,
            port: port,
            excluding: excludedProfileID
        )
    }

    func start(
        profileID: ModelConfig.ID,
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        try processRegistry.start(
            profileID: profileID,
            request: request,
            outputHandler: outputHandler,
            terminationHandler: terminationHandler
        )
    }

    func stop(
        profileID: ModelConfig.ID,
        gracefulTimeout: TimeInterval = 5,
        interruptTimeout: TimeInterval = 2
    ) async -> ModelStopResult {
        await processRegistry.stop(
            profileID: profileID,
            gracefulTimeout: gracefulTimeout,
            interruptTimeout: interruptTimeout
        )
    }

    func checkReady(
        host: String,
        port: Int,
        expectedModelID: String? = nil
    ) async -> ReadyCheckResult {
        await readyCheckOperation(host, port, expectedModelID)
    }

    func checkPortRelease(
        host: String,
        port: Int,
        announceBusy: Bool,
        portCheckOperation: PortCheckOperation,
        eventHandler: (ServerStopEvent) -> Void
    ) -> ServerPortReleaseOutcome {
        let result = portCheckOperation(host, port)
        eventHandler(.portCheck(result: result, announceBusy: announceBusy))

        switch result {
        case .available:
            return .released
        case .busy:
            return .busy
        case .invalidInput, .failed:
            return .failed
        }
    }

    func stopAndWaitForPortRelease(
        profileID: ModelConfig.ID,
        host: String,
        port: Int,
        gracefulTimeout: TimeInterval = 5,
        interruptTimeout: TimeInterval = 2,
        portCheckOperation: PortCheckOperation,
        eventHandler: (ServerStopEvent) -> Void
    ) async -> ServerStopOutcome {
        let result = await stop(
            profileID: profileID,
            gracefulTimeout: gracefulTimeout,
            interruptTimeout: interruptTimeout
        )
        eventHandler(.processResult(result))

        switch result {
        case .notRunning:
            let outcome = checkPortRelease(
                host: host,
                port: port,
                announceBusy: true,
                portCheckOperation: portCheckOperation,
                eventHandler: eventHandler
            )
            eventHandler(.managedProcessNotRunning)
            return Self.stopOutcome(for: outcome)
        case .stopped:
            eventHandler(.checkingPortRelease)
            return await waitForPortRelease(
                host: host,
                port: port,
                portCheckOperation: portCheckOperation,
                eventHandler: eventHandler
            )
        case let .timedOut(processIdentifier):
            return .timedOut(processIdentifier: processIdentifier)
        }
    }

    func waitForReadyAfterStart(
        profileID: ModelConfig.ID,
        host: String,
        port: Int,
        processIdentifier: Int32,
        expectedModelID: String,
        isStopRequested: () -> Bool,
        eventHandler: (ServerReadyWaitEvent) -> Void
    ) async -> ServerReadyWaitOutcome {
        eventHandler(.waiting)

        for attempt in 1...maximumReadyAttempts {
            guard processRegistry.processIdentifier(for: profileID) == processIdentifier else {
                eventHandler(.processNoLongerRunning)
                return .processNoLongerRunning
            }

            guard !isStopRequested() else {
                eventHandler(.stopRequested)
                return .stopRequested
            }

            let result = await readyCheckOperation(host, port, expectedModelID)

            switch result {
            case let .ready(url, statusCode):
                guard processRegistry.processIdentifier(for: profileID) == processIdentifier else {
                    eventHandler(.readyResponseIgnored)
                    return .processNoLongerRunning
                }
                eventHandler(.ready(url: url, statusCode: statusCode))
                return .ready
            case let .notReady(url, statusCode):
                eventHandler(.notReady(attempt: attempt, url: url, statusCode: statusCode))
            case let .invalidInput(message):
                eventHandler(.invalidInput(message: message))
                return .invalidInput(message: message)
            case let .failed(url, message):
                eventHandler(.failed(attempt: attempt, url: url, message: message))
            case let .timedOut(url):
                eventHandler(.timedOut(attempt: attempt, url: url))
            }

            do {
                try await sleepOperation(readyRetryDelayNanoseconds)
            } catch {
                eventHandler(.cancelled)
                return .cancelled
            }
        }

        eventHandler(.exhausted)
        return .exhausted
    }

    private func waitForPortRelease(
        host: String,
        port: Int,
        portCheckOperation: PortCheckOperation,
        eventHandler: (ServerStopEvent) -> Void
    ) async -> ServerStopOutcome {
        for attempt in 0..<maximumPortReleaseAttempts {
            let outcome = checkPortRelease(
                host: host,
                port: port,
                announceBusy: attempt == 0,
                portCheckOperation: portCheckOperation,
                eventHandler: eventHandler
            )

            switch outcome {
            case .released:
                return .released
            case .failed:
                return .failed
            case .busy:
                break
            }

            guard attempt < maximumPortReleaseAttempts - 1 else {
                eventHandler(.portReleaseWaitExhausted)
                return .busy
            }

            let delayNanoseconds = attempt < longPortReleaseDelayStartAttempt
                ? shortPortReleaseDelayNanoseconds
                : longPortReleaseDelayNanoseconds
            do {
                try await sleepOperation(delayNanoseconds)
            } catch {
                eventHandler(.portReleaseWaitCancelled)
                return .cancelled
            }
        }

        eventHandler(.portReleaseWaitExhausted)
        return .busy
    }

    private static func stopOutcome(for outcome: ServerPortReleaseOutcome) -> ServerStopOutcome {
        switch outcome {
        case .released:
            .released
        case .busy:
            .busy
        case .failed:
            .failed
        }
    }
}
