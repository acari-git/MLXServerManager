import Foundation

extension AppViewModel {
    var visibleModels: [ModelConfig] {
        models
    }

    func modelListRowStates(from models: [ModelConfig]) -> [ModelListRowState] {
        models.map(makeModelListRowState(for:))
    }

    private func makeModelListRowState(for model: ModelConfig) -> ModelListRowState {
        let isRunning = runningModelIDs.contains(model.id)
        let modelRuntimeState = runtimeState(for: model)
        let hasRuntimeContext = isRunning || runtimeStatesByModelID[model.id] != nil
        let isTransitioning = Self.isTransitioningRuntimeState(
            modelRuntimeState,
            hasRuntimeContext: hasRuntimeContext
        )
        let isDegraded = isRunning && modelRuntimeState.isDegraded
        let isLoaded = isRunning && !isTransitioning && !isDegraded
        let portCheckResult = isRunning
            ? nil
            : cachedPortCheck(host: model.host, port: model.serverPort)
        let isPortBusy: Bool
        if let portCheckResult, case .busy = portCheckResult {
            isPortBusy = true
        } else {
            isPortBusy = false
        }
        let canUseStatusAction = isRunning
            ? serverLifecycleCoordinator.processIdentifier(for: model.id) != nil
            : blockingStartIssue(for: model, knownPortCheckResult: portCheckResult) == nil
        let sizeGigabytes = modelSizeGigabytes(for: model)
        let displayedMemoryGigabytes = isRunning ? memoryUsageByModelID[model.id] : nil
        let memorySortValue = memoryUsageByModelID[model.id] ?? -1
        let isAutoUnloadEnabled = autoUnloadEnabledByModelID[model.id] ?? false
        let autoUnloadMinutes = autoUnloadMinutesByModelID[model.id] ?? 30

        return ModelListRowState(
            model: model,
            sizeText: sizeGigabytes.map(Self.formatMemoryGigabytes) ?? "-",
            memoryText: displayedMemoryGigabytes.map(Self.formatMemoryGigabytes) ?? "-",
            normalStatusText: interactiveStatusText(
                isHovered: false,
                isPortBusy: isPortBusy,
                isRunning: isRunning,
                runtimeState: modelRuntimeState
            ),
            hoveredStatusText: interactiveStatusText(
                isHovered: true,
                isPortBusy: isPortBusy,
                isRunning: isRunning,
                runtimeState: modelRuntimeState
            ),
            isTransitioning: isTransitioning,
            isLoaded: isLoaded,
            isDegraded: isDegraded,
            isPortBusy: isPortBusy,
            canUseStatusAction: canUseStatusAction,
            isRecentlyAdded: lastAddedDownloadedModelID == model.id,
            nameSortValue: model.displayName,
            sizeSortValue: sizeGigabytes ?? -1,
            statusSortValue: isTransitioning ? 0 : (isDegraded ? 1 : (isRunning ? 2 : (isPortBusy ? 3 : 4))),
            endpointSortValue: "\(model.host):\(String(format: "%05d", model.serverPort))",
            memorySortValue: memorySortValue,
            autoUnloadSortValue: isAutoUnloadEnabled ? autoUnloadMinutes : Int.max,
            reasoningSortValue: model.enableThinking ? 1 : 0
        )
    }

    func moveModel(withID draggedModelID: ModelConfig.ID, before targetModelID: ModelConfig.ID) {
        guard draggedModelID != targetModelID,
              let sourceIndex = models.firstIndex(where: { $0.id == draggedModelID }),
              let targetIndex = models.firstIndex(where: { $0.id == targetModelID }) else {
            return
        }

        var nextModels = models
        let movedModel = nextModels.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        nextModels.insert(movedModel, at: adjustedTargetIndex)
        persistModelOrder(nextModels, movedModel: movedModel)
    }

    func moveModelToEnd(withID draggedModelID: ModelConfig.ID) {
        guard !models.isEmpty,
              let sourceIndex = models.firstIndex(where: { $0.id == draggedModelID }),
              sourceIndex != models.index(before: models.endIndex) else {
            return
        }

        var nextModels = models
        let movedModel = nextModels.remove(at: sourceIndex)
        nextModels.append(movedModel)
        persistModelOrder(nextModels, movedModel: movedModel)
    }

    func canMoveModelUp(withID modelID: ModelConfig.ID) -> Bool {
        guard let index = models.firstIndex(where: { $0.id == modelID }) else {
            return false
        }
        return index > models.startIndex
    }

    func canMoveModelDown(withID modelID: ModelConfig.ID) -> Bool {
        guard !models.isEmpty,
              let index = models.firstIndex(where: { $0.id == modelID }) else {
            return false
        }
        return index < models.index(before: models.endIndex)
    }

    func moveModelUp(withID modelID: ModelConfig.ID) {
        guard let index = models.firstIndex(where: { $0.id == modelID }),
              index > models.startIndex else {
            return
        }
        var nextModels = models
        nextModels.swapAt(index, nextModels.index(before: index))
        persistModelOrder(nextModels, movedModel: models[index])
    }

    func moveModelDown(withID modelID: ModelConfig.ID) {
        guard !models.isEmpty,
              let index = models.firstIndex(where: { $0.id == modelID }),
              index < models.index(before: models.endIndex) else {
            return
        }
        var nextModels = models
        nextModels.swapAt(index, nextModels.index(after: index))
        persistModelOrder(nextModels, movedModel: models[index])
    }

    private func persistModelOrder(_ nextModels: [ModelConfig], movedModel: ModelConfig) {
        do {
            let outcome = try settingsStore.save(models: nextModels)
            models = nextModels
            invalidatePortCheckCache()
            appendLog("[model] reordered \(movedModel.displayName).")
            appendSettingsSaveWarnings(outcome)
        } catch {
            appendLog("[model] warning: failed to save model order: \(error.localizedDescription)")
        }
    }

    func isAutoUnloadEnabled(for model: ModelConfig) -> Bool {
        autoUnloadEnabledByModelID[model.id] ?? false
    }

    func setAutoUnloadEnabled(_ isEnabled: Bool, for model: ModelConfig) {
        var nextSettings = settings
        nextSettings.autoUnloadEnabledByModelID[model.id] = isEnabled
        persistAutoUnloadSettings(nextSettings)
    }

    func autoUnloadMinutes(for model: ModelConfig) -> Int {
        autoUnloadMinutesByModelID[model.id] ?? 30
    }

    func setAutoUnloadMinutes(_ minutes: Int, for model: ModelConfig) {
        let clampedMinutes = min(max(minutes, 1), 999)
        var nextSettings = settings
        nextSettings.autoUnloadMinutesByModelID[model.id] = clampedMinutes
        persistAutoUnloadSettings(nextSettings)
    }

    private func persistAutoUnloadSettings(_ nextSettings: AppSettings) {
        do {
            let outcome = try settingsStore.save(settings: nextSettings, models: models)
            settings = nextSettings
            autoUnloadEnabledByModelID = nextSettings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = nextSettings.autoUnloadMinutesByModelID
            appendSettingsSaveWarnings(outcome)
        } catch {
            appendLog("[settings] failed to save auto-unload settings: \(error.localizedDescription)")
        }
    }

    func autoUnloadText(for model: ModelConfig) -> String {
        guard isAutoUnloadEnabled(for: model) else { return "OFF" }
        return Self.localizedText(language: settings.uiLanguage, english: "\(autoUnloadMinutes(for: model)) min", japanese: "\(autoUnloadMinutes(for: model))分")
    }

    func reasoningText(for model: ModelConfig) -> String {
        model.enableThinking ? "ON" : "OFF"
    }
}
