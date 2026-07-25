import Foundation

extension AppViewModel {
    func startMemoryMonitoring(processIdentifier: Int32, model: ModelConfig) {
        stopMemoryMonitoring(for: model.id, resetUsage: true)

        appendLog("[memory] monitoring managed pid \(processIdentifier) every 1 second.")
        let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model)
        let modelEstimateGigabytes = modelSizeGigabytes(modelDirectoryPath: modelDirectoryPath)
        let modelEstimateSource = modelDirectoryPath.map { ModelAvailabilityPathFormatter.compact(path: $0) }

        if let modelEstimateGigabytes, let modelEstimateSource {
            appendLog("[memory] model estimate: \(Self.formatMemoryGigabytes(modelEstimateGigabytes)) from \(modelEstimateSource).")
        } else {
            appendLog("[memory] model estimate unavailable. A local model folder is required for the model segment.")
        }

        modelMemoryMonitoringCoordinator.start(
            profileID: model.id,
            processIdentifier: processIdentifier,
            modelEstimateGigabytes: modelEstimateGigabytes,
            modelEstimateSource: modelEstimateSource
        ) { [weak self] result, modelID, monitoredProcessIdentifier in
            self?.handleMemoryMonitorResult(
                result,
                modelID: modelID,
                processIdentifier: monitoredProcessIdentifier
            ) ?? false
        }
    }

    func stopMemoryMonitoring(for modelID: ModelConfig.ID, resetUsage: Bool = true) {
        modelMemoryMonitoringCoordinator.stop(profileID: modelID)

        if resetUsage {
            setMonitoredModelMemory(nil, for: modelID)
        }
    }

    func setMonitoredModelMemory(
        _ snapshot: MemoryBreakdownSnapshot?,
        for modelID: ModelConfig.ID
    ) {
        let nextState = monitoringStateCoordinator.setModelMemory(snapshot, for: modelID)
        guard nextState != monitoringViewState else {
            return
        }
        monitoringViewState = nextState
    }

    func handleMemoryMonitorResult(
        _ result: MemoryBreakdownMonitorResult,
        modelID: ModelConfig.ID,
        processIdentifier: Int32
    ) -> Bool {
        guard serverLifecycleCoordinator.processIdentifier(for: modelID) == processIdentifier else {
            setMonitoredModelMemory(nil, for: modelID)
            appendLog("[memory] monitoring stopped because managed pid changed for \(modelID).")
            return false
        }

        switch result {
        case let .usage(snapshot):
            setMonitoredModelMemory(snapshot, for: modelID)
            return true
        case let .notRunning(processIdentifier):
            setMonitoredModelMemory(nil, for: modelID)
            appendLog("[memory] warning: managed pid \(processIdentifier) is no longer reporting RSS.")
            return false
        case let .invalidInput(message):
            setMonitoredModelMemory(nil, for: modelID)
            appendLog("[memory] warning: \(message)")
            return false
        case let .failed(processIdentifier, message):
            appendLog("[memory] warning: failed to read RSS for pid \(processIdentifier): \(message)")
            return true
        }
    }

    func startSystemUsageMonitoring() {
        systemUsageMonitoringCoordinator.start { [weak self] sample in
            guard let self else {
                return false
            }
            applySystemUsageSample(sample)
            return true
        }
    }

    func applySystemUsageSample(_ sample: SystemUsageMonitorSample) {
        let assessment = RuntimeMemoryHeadroomAdvisor.assess(
            environment: RuntimeMemoryHeadroomEnvironment(
                totalMemoryGigabytes: sample.systemMemorySnapshot.totalGigabytes,
                availableMemoryGigabytes: sample.systemMemorySnapshot.availableGigabytes
            )
        )
        let update = monitoringStateCoordinator.applySystemUsage(
            sample,
            assessment: assessment
        )
        if update.state != monitoringViewState {
            monitoringViewState = update.state
        }
        guard update.didChangeProtectionLevel else {
            return
        }
        logRuntimeMemoryProtectionTransition(
            from: update.previousProtectionState,
            to: update.nextProtectionState,
            assessment: assessment
        )
    }

    func logRuntimeMemoryProtectionTransition(
        from previousState: RuntimeMemoryProtectionState,
        to nextState: RuntimeMemoryProtectionState,
        assessment: RuntimeMemoryHeadroomAssessment
    ) {
        guard previousState.level != nextState.level else {
            return
        }

        switch nextState.level {
        case .normal:
            if previousState.level == .emergency {
                appendLog("[memory-guard] runtime memory emergency cleared after sustained recovery.")
            } else {
                appendLog("[memory-guard] runtime memory caution cleared.")
            }
        case .caution:
            appendLog("[memory-guard] runtime memory caution: \(assessment.detail(language: settings.uiLanguage))")
        case .emergency:
            appendLog("[memory-guard] runtime memory emergency engaged: \(assessment.detail(language: settings.uiLanguage)) Managed Start and Restart are blocked. Running servers are not stopped automatically.")
        }
    }

    func startAutoUnloadMonitoring() {
        autoUnloadMonitoringCoordinator.start { [weak self] in
            guard let self else {
                return false
            }
            await evaluateAutoUnload()
            return true
        }
    }

    func evaluateAutoUnload() async {
        let now = Date()
        let candidates = runningModelIDs.compactMap { modelID -> AutoUnloadCandidate? in
            guard let runningModel = models.first(where: { $0.id == modelID }),
                  let startedAt = managedServerStartedAtByModelID[modelID] else {
                return nil
            }

            return AutoUnloadCandidate(
                modelID: modelID,
                startedAt: startedAt,
                limitMinutes: autoUnloadMinutes(for: runningModel),
                isEnabled: isAutoUnloadEnabled(for: runningModel),
                isTransitioning: isModelTransitioning(runningModel)
            )
        }

        for modelID in AutoUnloadPlanner.expiredModelIDs(from: candidates, now: now) {
            guard let runningModel = models.first(where: { $0.id == modelID }),
                  let startedAt = managedServerStartedAtByModelID[modelID] else {
                continue
            }

            let elapsedSeconds = now.timeIntervalSince(startedAt)
            appendLog("[auto-unload] elapsed \(Int(elapsedSeconds))s reached \(autoUnloadMinutes(for: runningModel)) minute limit. Unloading \(runningModel.displayName).")
            requestStop(for: runningModel, logPrefix: "auto-unload")
        }
    }
}
