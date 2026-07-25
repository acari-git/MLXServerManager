import Foundation

nonisolated struct ManagedTerminationTarget: Identifiable, Equatable, Sendable {
    let profileID: ModelConfig.ID
    let displayName: String
    let modelID: String
    let host: String
    let port: Int
    let processIdentifier: Int32

    var id: ModelConfig.ID { profileID }
    var endpoint: String { "\(host):\(port)" }
}

nonisolated struct ManagedTerminationFailure: Identifiable, Equatable, Sendable {
    let target: ManagedTerminationTarget
    let message: String

    var id: ModelConfig.ID { target.profileID }
}

nonisolated enum ApplicationTerminationPhase: Equatable, Sendable {
    case idle
    case prompting(targets: [ManagedTerminationTarget])
    case stopping(completed: Int, total: Int)
    case failed(failures: [ManagedTerminationFailure])

    var isPrompting: Bool {
        if case .prompting = self { return true }
        return false
    }

    var isStopping: Bool {
        if case .stopping = self { return true }
        return false
    }
}

nonisolated enum ApplicationTerminationChoice: Equatable, Sendable {
    case stopAllAndQuit
    case leaveRunningAndQuit
    case cancel
}

nonisolated enum ApplicationTerminationPolicy {
    static func targets(
        models: [ModelConfig],
        runningProfileIDs: Set<ModelConfig.ID>,
        processIdentifier: (ModelConfig.ID) -> Int32?
    ) -> [ManagedTerminationTarget] {
        models.compactMap { model in
            guard runningProfileIDs.contains(model.id),
                  let processIdentifier = processIdentifier(model.id) else {
                return nil
            }
            return ManagedTerminationTarget(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                host: model.host,
                port: model.serverPort,
                processIdentifier: processIdentifier
            )
        }
    }
}
