import Foundation

nonisolated struct ManagedProcessEndpoint: Equatable {
    let profileID: ModelConfig.ID
    let host: String
    let port: Int
    let processIdentifier: Int32
}

nonisolated enum ModelProcessRegistryError: LocalizedError, Equatable {
    case endpointAlreadyManaged(ManagedProcessEndpoint)

    var errorDescription: String? {
        switch self {
        case let .endpointAlreadyManaged(endpoint):
            "The endpoint \(endpoint.host):\(endpoint.port) is already managed by profile \(endpoint.profileID) with pid \(endpoint.processIdentifier)."
        }
    }
}

@MainActor
final class ModelProcessRegistry {
    typealias ManagerFactory = @MainActor () -> any ModelProcessManaging

    private struct Entry {
        let token: UUID
        let manager: any ModelProcessManaging
        let host: String
        let port: Int
    }

    private var entries: [ModelConfig.ID: Entry] = [:]
    private var initialManager: (any ModelProcessManaging)?
    private let managerFactory: ManagerFactory

    init(
        initialManager: (any ModelProcessManaging)? = nil,
        managerFactory: @escaping ManagerFactory = { ModelProcessManager() }
    ) {
        self.initialManager = initialManager
        self.managerFactory = managerFactory
    }

    var runningProfileIDs: Set<ModelConfig.ID> {
        Set(entries.compactMap { profileID, entry in
            entry.manager.managedProcessIdentifier == nil ? nil : profileID
        })
    }

    var isAnyProcessRunning: Bool {
        !runningProfileIDs.isEmpty
    }

    func processIdentifier(for profileID: ModelConfig.ID) -> Int32? {
        entries[profileID]?.manager.managedProcessIdentifier
    }

    func isRunning(_ profileID: ModelConfig.ID) -> Bool {
        processIdentifier(for: profileID) != nil
    }

    func runningEndpoint(
        host: String,
        port: Int,
        excluding excludedProfileID: ModelConfig.ID? = nil
    ) -> ManagedProcessEndpoint? {
        return entries.compactMap { profileID, entry -> ManagedProcessEndpoint? in
            guard profileID != excludedProfileID,
                  entry.port == port,
                  EndpointHostMatcher.conflicts(entry.host, host),
                  let processIdentifier = entry.manager.managedProcessIdentifier else {
                return nil
            }

            return ManagedProcessEndpoint(
                profileID: profileID,
                host: entry.host,
                port: entry.port,
                processIdentifier: processIdentifier
            )
        }
        .first
    }

    func start(
        profileID: ModelConfig.ID,
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult {
        if let processIdentifier = processIdentifier(for: profileID) {
            throw ModelProcessManagerError.alreadyRunning(processIdentifier: processIdentifier)
        }

        if let endpoint = runningEndpoint(
            host: request.host,
            port: request.port,
            excluding: profileID
        ) {
            throw ModelProcessRegistryError.endpointAlreadyManaged(endpoint)
        }

        let entry: Entry
        if let existingEntry = entries[profileID] {
            entry = existingEntry
        } else {
            let manager = makeManager()
            entry = Entry(
                token: UUID(),
                manager: manager,
                host: request.host,
                port: request.port
            )
            entries[profileID] = entry
        }

        do {
            return try entry.manager.start(
                request: request,
                outputHandler: outputHandler,
                terminationHandler: { [weak self] terminationStatus in
                    guard let self else { return }
                    if self.entries[profileID]?.token == entry.token {
                        self.entries[profileID] = nil
                    }
                    terminationHandler(terminationStatus)
                }
            )
        } catch {
            if entry.manager.managedProcessIdentifier == nil,
               entries[profileID]?.token == entry.token {
                entries[profileID] = nil
            }
            throw error
        }
    }

    func stop(
        profileID: ModelConfig.ID,
        gracefulTimeout: TimeInterval = 5,
        interruptTimeout: TimeInterval = 2
    ) async -> ModelStopResult {
        guard let entry = entries[profileID] else {
            return .notRunning
        }

        let result = await entry.manager.stop(
            gracefulTimeout: gracefulTimeout,
            interruptTimeout: interruptTimeout
        )
        if entry.manager.managedProcessIdentifier == nil,
           entries[profileID]?.token == entry.token {
            entries[profileID] = nil
        }
        return result
    }

    private func makeManager() -> any ModelProcessManaging {
        if let initialManager {
            self.initialManager = nil
            return initialManager
        }
        return managerFactory()
    }

}
