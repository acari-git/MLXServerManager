import Foundation

nonisolated struct RuntimeViewState: Equatable, Sendable {
    private(set) var runningModelID: ModelConfig.ID?
    private(set) var runningModelIDs: Set<ModelConfig.ID>
    private(set) var managedServerStartedAt: Date?
    private(set) var managedServerStartedAtByModelID: [ModelConfig.ID: Date]
    private(set) var selectedRuntimeState: ModelRuntimeState
    private(set) var runtimeStatesByModelID: [ModelConfig.ID: ModelRuntimeState]

    static let empty = RuntimeViewState(
        runningModelID: nil,
        runningModelIDs: [],
        managedServerStartedAt: nil,
        managedServerStartedAtByModelID: [:],
        selectedRuntimeState: .stopped,
        runtimeStatesByModelID: [:]
    )

    mutating func setSelectedRuntimeState(
        _ state: ModelRuntimeState,
        selectedModelID: ModelConfig.ID?
    ) {
        selectedRuntimeState = state
        if let selectedModelID {
            runtimeStatesByModelID[selectedModelID] = state
        }
    }

    mutating func setRuntimeState(
        _ state: ModelRuntimeState,
        for modelID: ModelConfig.ID,
        selectedModelID: ModelConfig.ID?
    ) {
        runtimeStatesByModelID[modelID] = state
        if selectedModelID == modelID {
            selectedRuntimeState = state
        }
    }

    mutating func projectSelectedRuntimeState(
        selectedModelID: ModelConfig.ID?,
        runningProfileIDs: Set<ModelConfig.ID>,
        orderedModelIDs: [ModelConfig.ID]
    ) {
        if let selectedModelID {
            selectedRuntimeState = runtimeStatesByModelID[selectedModelID] ?? .stopped
        } else {
            selectedRuntimeState = .stopped
        }
        refreshRunningProjection(
            runningProfileIDs: runningProfileIDs,
            selectedModelID: selectedModelID,
            orderedModelIDs: orderedModelIDs
        )
    }

    mutating func clearExternalRuntimeContext(
        for modelID: ModelConfig.ID,
        selectedModelID: ModelConfig.ID?,
        runningProfileIDs: Set<ModelConfig.ID>,
        orderedModelIDs: [ModelConfig.ID]
    ) {
        runtimeStatesByModelID[modelID] = .stopped
        projectSelectedRuntimeState(
            selectedModelID: selectedModelID,
            runningProfileIDs: runningProfileIDs,
            orderedModelIDs: orderedModelIDs
        )
    }

    mutating func markRunning(
        modelID: ModelConfig.ID,
        startedAt: Date,
        runningProfileIDs: Set<ModelConfig.ID>,
        selectedModelID: ModelConfig.ID?,
        orderedModelIDs: [ModelConfig.ID]
    ) {
        managedServerStartedAtByModelID[modelID] = startedAt
        refreshRunningProjection(
            runningProfileIDs: runningProfileIDs,
            selectedModelID: selectedModelID,
            orderedModelIDs: orderedModelIDs
        )
    }

    mutating func clearRunning(
        modelID: ModelConfig.ID,
        runningProfileIDs: Set<ModelConfig.ID>,
        selectedModelID: ModelConfig.ID?,
        orderedModelIDs: [ModelConfig.ID]
    ) {
        managedServerStartedAtByModelID[modelID] = nil
        refreshRunningProjection(
            runningProfileIDs: runningProfileIDs,
            selectedModelID: selectedModelID,
            orderedModelIDs: orderedModelIDs
        )
    }

    mutating func refreshRunningProjection(
        runningProfileIDs: Set<ModelConfig.ID>,
        selectedModelID: ModelConfig.ID?,
        orderedModelIDs: [ModelConfig.ID]
    ) {
        runningModelIDs = runningProfileIDs
        if let selectedModelID, runningProfileIDs.contains(selectedModelID) {
            runningModelID = selectedModelID
        } else {
            runningModelID = orderedModelIDs.first(where: runningProfileIDs.contains)
        }
        managedServerStartedAt = runningModelID.flatMap { managedServerStartedAtByModelID[$0] }
    }
}
