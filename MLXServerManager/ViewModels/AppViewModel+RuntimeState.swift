extension AppViewModel {
    var isManagedProcessRunning: Bool {
        serverLifecycleCoordinator.isAnyProcessRunning
    }

    var isSelectedModelManagedProcessRunning: Bool {
        selectedModelID.map { serverLifecycleCoordinator.isRunning($0) } ?? false
    }

    var isProfileEditorRuntimeLocked: Bool {
        let originalModelID = profileEditorDraft.originalModelID
        guard !originalModelID.isEmpty else { return false }
        return serverLifecycleCoordinator.isRunning(originalModelID)
    }

    var isExternalServerDetected: Bool {
        runtimeState.isExternalServerDetected
    }

    var isAdoptedExternalServer: Bool {
        runtimeState.isAdoptedExternalServer
    }

    var canStopManagedServer: Bool {
        guard let selectedModel,
              isSelectedModelManagedProcessRunning else {
            return false
        }
        if case .stopping = runtimeState(for: selectedModel) {
            return false
        }
        return true
    }

    var canRestartManagedServer: Bool {
        guard let selectedModel else {
            return false
        }
        return isSelectedModelManagedProcessRunning
            && !runtimeState.isExternalServerContext
            && !isModelTransitioning(selectedModel)
            && !isRuntimeMemoryEmergencyActive
    }

    var canAdoptExternalServer: Bool {
        runtimeState.isExternalServerDetected
    }

    var canForgetExternalServer: Bool {
        runtimeState.isAdoptedExternalServer
    }

    func runtimeState(for model: ModelConfig) -> ModelRuntimeState {
        runtimeStatesByModelID[model.id] ?? .stopped
    }

    func setRuntimeState(_ state: ModelRuntimeState, for modelID: ModelConfig.ID) {
        var nextState = runtimeViewState
        nextState.setRuntimeState(
            state,
            for: modelID,
            selectedModelID: selectedModelID
        )
        guard nextState != runtimeViewState else {
            return
        }
        runtimeViewState = nextState
    }

    func setRuntimeState(_ state: ModelRuntimeState, forOptionalModelID modelID: ModelConfig.ID?) {
        if let modelID {
            setRuntimeState(state, for: modelID)
        } else {
            runtimeState = state
        }
    }

    func projectSelectedRuntimeState() {
        var nextState = runtimeViewState
        nextState.projectSelectedRuntimeState(
            selectedModelID: selectedModelID,
            runningProfileIDs: serverLifecycleCoordinator.runningProfileIDs,
            orderedModelIDs: models.map(\.id)
        )
        guard nextState != runtimeViewState else {
            return
        }
        runtimeViewState = nextState
    }
}
