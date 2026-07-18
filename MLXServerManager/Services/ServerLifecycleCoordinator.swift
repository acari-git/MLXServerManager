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

@MainActor
final class ServerLifecycleCoordinator {
    typealias ReadyCheckOperation = @MainActor (
        _ host: String,
        _ port: Int,
        _ expectedModelID: String?
    ) async -> ReadyCheckResult
    typealias SleepOperation = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private let processRegistry: ModelProcessRegistry
    private let maximumReadyAttempts: Int
    private let readyRetryDelayNanoseconds: UInt64
    private let readyCheckOperation: ReadyCheckOperation
    private let sleepOperation: SleepOperation

    init(
        processRegistry: ModelProcessRegistry,
        readyChecker: ReadyChecker? = nil,
        maximumReadyAttempts: Int = 10,
        readyRetryDelayNanoseconds: UInt64 = 1_000_000_000,
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
}
