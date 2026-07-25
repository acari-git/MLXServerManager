import Foundation

extension AppViewModel {
    func refreshDefaultUserFacingMessagesForCurrentLanguage() {
        let language = settings.uiLanguage
        huggingFaceCLIPath = Self.notCheckedText(language: language)
        huggingFaceCLIMessage = Self.defaultHuggingFaceCLIMessage(language: language)
        localModelMessage = Self.defaultLocalModelMessage(language: language)
        updateHuggingFaceSearchViewState { state in
            state.setMessage(Self.defaultHuggingFaceSearchMessage(language: language))
        }
        benchmarkViewState.setLatestSpeedTestMessage(Self.defaultSpeedTestMessage(language: language))
        hermesAgentConfigMessage = Self.defaultHermesAgentConfigMessage(language: language)
        if huggingFaceDownloadQueue.isEmpty, huggingFaceDownloadStatus.phase == .waiting {
            setHuggingFaceDownloadStatus(Self.waitingHuggingFaceDownloadStatus(language: language))
        }
    }

    func toggleReasoning(for model: ModelConfig, isEnabled: Bool) {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return }
        var nextModels = models
        nextModels[index].enableThinking = isEnabled
        do {
            let outcome = try settingsStore.save(models: nextModels)
            models = nextModels
            appendLog("[model] reasoning \(isEnabled ? "enabled" : "disabled") for \(model.displayName).")
            appendSettingsSaveWarnings(outcome)
        } catch {
            appendLog("[model] warning: failed to save reasoning setting: \(error.localizedDescription)")
        }
    }

    func canStartModel(_ model: ModelConfig) -> Bool {
        blockingStartIssue(for: model) == nil
    }

    func startRequested(for model: ModelConfig) {
        selectedModelID = model.id

        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "start") else {
            return
        }
        guard canRequestManagedStart(for: model) else {
            appendLog("[start] ignored duplicate or unavailable start request for \(model.displayName).")
            return
        }

        let exposureAssessment = NetworkExposureAdvisor.assess(host: model.host)
        if exposureAssessment.requiresExplicitStartConfirmation {
            pendingNetworkExposureModelID = model.id
            pendingNetworkExposureAssessment = exposureAssessment
            isNetworkExposureStartConfirmationPresented = true
            appendLog("[start] network exposure warning for host \(model.host).")
            return
        }

        continueStartRequest(for: model)
    }

    func confirmNetworkExposureStart() {
        guard let modelID = pendingNetworkExposureModelID,
              let model = models.first(where: { $0.id == modelID }) else {
            clearPendingNetworkExposureStart()
            appendLog("[start] cancelled because the pending model profile is no longer available.")
            return
        }

        clearPendingNetworkExposureStart()
        appendLog("[start] continuing after explicit network-exposure confirmation for \(model.displayName).")
        continueStartRequest(for: model)
    }

    func cancelNetworkExposureStart() {
        let displayName = pendingNetworkExposureModelID
            .flatMap { modelID in models.first(where: { $0.id == modelID })?.displayName }
        clearPendingNetworkExposureStart()
        appendLog("[start] cancelled at network-exposure confirmation\(displayName.map { " for \($0)" } ?? "").")
    }

    var networkExposureConfirmationTitle: String {
        (pendingNetworkExposureAssessment ?? .localOnly)
            .confirmationTitle(language: settings.uiLanguage)
    }

    var networkExposureConfirmationDetail: String {
        (pendingNetworkExposureAssessment ?? .localOnly)
            .confirmationDetail(language: settings.uiLanguage)
    }

    private func continueStartRequest(for model: ModelConfig) {
        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "start") else {
            return
        }

        guard !modelStartPreparationCoordinator.isRunning(model.id),
              !managedStartRunCoordinator.isRunning(model.id) else {
            appendLog("[start] ignored because start preparation is already active for \(model.displayName).")
            return
        }

        modelStartPreparationCoordinator.start(model.id) { [weak self] generation in
            guard let self else { return }

            let candidateModelGigabytes = await self.resolvedModelSizeGigabytes(for: model)
            guard !Task.isCancelled,
                  self.modelStartPreparationCoordinator.isCurrent(
                    model.id,
                    generation: generation
                  ),
                  self.models.first(where: { $0.id == model.id }) == model else {
                return
            }

            self.continueStartRequest(
                for: model,
                candidateModelGigabytes: candidateModelGigabytes
            )
        }
    }

    private func continueStartRequest(
        for model: ModelConfig,
        candidateModelGigabytes: Double?
    ) {
        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "start") else {
            return
        }

        if serverLifecycleCoordinator.processIdentifier(for: model.id) == nil {
            let assessment = memorySafetyAssessment(
                for: model,
                candidateModelGigabytes: candidateModelGigabytes
            )
            if assessment.requiresConfirmation {
                pendingMemoryRiskModelID = model.id
                pendingMemoryRiskAssessment = assessment
                isMemoryRiskStartConfirmationPresented = true
                appendLog("[start] memory warning: \(assessment.title(language: settings.uiLanguage)). \(assessment.detail(language: settings.uiLanguage))")
                return
            }

            if assessment.level == .caution || assessment.level == .unavailable {
                appendLog("[start] memory advisory: \(assessment.title(language: settings.uiLanguage)). \(assessment.detail(language: settings.uiLanguage))")
            }
        }

        performStartRequest(for: model)
    }

    func cancelModelStartPreparation(modelID: ModelConfig.ID) {
        modelStartPreparationCoordinator.cancel(modelID)
    }

    func cancelManagedStartTask(modelID: ModelConfig.ID) {
        managedStartRunCoordinator.cancel(modelID)
    }

    func canRequestManagedStart(for model: ModelConfig) -> Bool {
        guard models.contains(model),
              serverLifecycleCoordinator.processIdentifier(for: model.id) == nil,
              !runningModelIDs.contains(model.id),
              !modelStartPreparationCoordinator.isRunning(model.id),
              !managedStartRunCoordinator.isRunning(model.id),
              pendingNetworkExposureModelID != model.id,
              pendingMemoryRiskModelID != model.id else {
            return false
        }
        return !isModelTransitioning(model)
    }

    func confirmMemoryRiskStart() {
        guard let modelID = pendingMemoryRiskModelID,
              let model = models.first(where: { $0.id == modelID }) else {
            clearPendingMemoryRiskStart()
            appendLog("[start] cancelled because the pending model profile is no longer available.")
            return
        }

        clearPendingMemoryRiskStart()
        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "start") else {
            return
        }
        appendLog("[start] continuing after explicit memory-risk confirmation for \(model.displayName).")
        performStartRequest(for: model)
    }

    func cancelMemoryRiskStart() {
        let displayName = pendingMemoryRiskModelID
            .flatMap { modelID in models.first(where: { $0.id == modelID })?.displayName }
        clearPendingMemoryRiskStart()
        appendLog("[start] cancelled at memory-risk confirmation\(displayName.map { " for \($0)" } ?? "").")
    }

    var memoryRiskConfirmationTitle: String {
        pendingMemoryRiskAssessment?.title(language: settings.uiLanguage)
            ?? Self.localizedText(
                language: settings.uiLanguage,
                english: "Confirm model start",
                japanese: "モデルの起動を確認"
            )
    }

    var memoryRiskConfirmationDetail: String {
        pendingMemoryRiskAssessment?.detail(language: settings.uiLanguage)
            ?? Self.localizedText(
                language: settings.uiLanguage,
                english: "Current memory capacity could not be evaluated.",
                japanese: "現在のメモリ容量を評価できませんでした。"
            )
    }

    func memorySafetyAssessment(for model: ModelConfig) -> MultiModelMemoryAssessment {
        memorySafetyAssessment(
            for: model,
            candidateModelGigabytes: modelSizeGigabytes(for: model)
        )
    }

    private func memorySafetyAssessment(
        for model: ModelConfig,
        candidateModelGigabytes: Double?
    ) -> MultiModelMemoryAssessment {
        let systemMemory = systemMemorySnapshotProvider()
        let managedMemory = runningModelIDs.reduce(0.0) { partialResult, modelID in
            partialResult + max(memoryUsageByModelID[modelID] ?? 0, 0)
        }
        let cacheSafeMode = kvCacheSafeModeResult(
            for: model,
            options: model.advancedLaunchOptions,
            candidateModelGigabytes: candidateModelGigabytes,
            systemMemory: systemMemory
        )

        return MultiModelMemoryAdvisor.assess(
            environment: MultiModelMemoryEnvironment(
                totalMemoryGigabytes: systemMemory.totalGigabytes,
                availableMemoryGigabytes: systemMemory.availableGigabytes,
                managedMemoryGigabytes: managedMemory,
                runningModelCount: runningModelIDs.count,
                candidateModelGigabytes: candidateModelGigabytes,
                candidateCacheBytes: cacheSafeMode.advancedLaunchOptions?
                    .promptCacheBytes
                    .flatMap(UInt64.init)
            )
        )
    }

    func kvCacheSafeModeResult(
        for model: ModelConfig,
        options: AdvancedLaunchOptions?,
        candidateModelGigabytes: Double?,
        systemMemory: SystemMemorySnapshot
    ) -> KVCacheSafeModeResult {
        KVCacheSafeMode.apply(
            options: options,
            environment: KVCacheEnvironment(
                totalMemoryGigabytes: systemMemory.totalGigabytes,
                availableMemoryGigabytes: systemMemory.availableGigabytes,
                modelStorageGigabytes: candidateModelGigabytes,
                isModelLoaded: runningModelIDs.contains(model.id)
            ),
            backend: model.resolvedBackend
        )
    }

    private func performStartRequest(for model: ModelConfig) {
        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "start") else {
            return
        }
        guard !managedStartRunCoordinator.isRunning(model.id),
              serverLifecycleCoordinator.processIdentifier(for: model.id) == nil else {
            appendLog("[start] ignored because a managed start is already active for \(model.displayName).")
            return
        }

        setRuntimeState(.starting(host: model.host, port: model.serverPort), for: model.id)
        managedStartRunCoordinator.start(model.id) { [weak self] generation in
            guard let self else { return }
            guard !Task.isCancelled,
                  self.managedStartRunCoordinator.isCurrent(
                    model.id,
                    generation: generation
                  ) else {
                self.setRuntimeState(.stopped, for: model.id)
                return
            }
            _ = await self.startManagedServer(model: model, logPrefix: "start")
        }
    }

    private func clearPendingMemoryRiskStart() {
        isMemoryRiskStartConfirmationPresented = false
        pendingMemoryRiskAssessment = nil
        pendingMemoryRiskModelID = nil
    }

    private func clearPendingNetworkExposureStart() {
        isNetworkExposureStartConfirmationPresented = false
        pendingNetworkExposureAssessment = nil
        pendingNetworkExposureModelID = nil
    }

    func stopRequested(for model: ModelConfig) {
        selectedModelID = model.id
        cancelModelStartPreparation(modelID: model.id)
        requestStop(for: model, logPrefix: "stop")
    }

    func restartRequested(for model: ModelConfig) {
        selectedModelID = model.id
        restartRequested()
    }
}
