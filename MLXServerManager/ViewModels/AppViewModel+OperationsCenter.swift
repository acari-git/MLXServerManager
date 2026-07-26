import Foundation

extension AppViewModel {
    var launchPlans: [LaunchPlanDefinition] {
        settings.launchPlans
    }

    var defaultOperationsLaunchPlan: LaunchPlanDefinition {
        LaunchPlanDefinition(
            name: Self.localizedText(
                language: settings.uiLanguage,
                english: "All Profiles",
                japanese: "すべてのプロファイル"
            ),
            steps: models.map { LaunchPlanStep(profileID: $0.id, isRequired: true) }
        )
    }

    var activeOperationsLaunchPlan: LaunchPlanDefinition {
        settings.launchPlans.first ?? defaultOperationsLaunchPlan
    }

    func openOperationsCenterRequested() {
        operationsCenterViewState.isPresented = true
        refreshOperationsCenterRequested()
    }

    func dismissOperationsCenterRequested() {
        operationsCenterRunCoordinator.cancel()
        launchStabilityRunCoordinator.cancel()
        launchPlanRunCoordinator.cancel()
        operationsCenterViewState.isPresented = false
        operationsCenterViewState.isChecking = false
    }

    func cancelOperationsCenterRequested() {
        operationsCenterRunCoordinator.cancel()
        operationsCenterViewState.cancel()
    }

    func refreshOperationsCenterRequested() {
        operationsCenterViewState.begin()
        let requestedSettings = settings
        let requestedModels = models
        let requestedSelectedModelID = selectedModelID
        let requestedSelectedModel = selectedModel
        let requestedBenchmarkSession = requestedSelectedModel.flatMap {
            benchmarkSessionsByProfileID[$0.id]
        }
        let previousEvidence = operationsCenterViewState.capturedEvidence

        operationsCenterRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let platform = platformCompatibilityService.assess()
            let memorySnapshot = systemMemorySnapshotProvider()

            async let runtimeDoctorTask = runtimeEnvironmentDoctorService.assess(
                settings: requestedSettings
            )
            async let runtimeReadinessTask = runtimeReadinessService.assess(
                settings: requestedSettings
            )
            async let compatibilityTask = runtimeCompatibilityService.assess(
                settings: requestedSettings
            )
            async let healthTask = registeredModelHealthService.assess(
                models: requestedModels
            )
            async let metadataTask: ModelMetadataReport? = {
                guard let requestedSelectedModel else { return nil }
                return await self.modelMetadataInspectionService.inspect(model: requestedSelectedModel)
            }()

            let runtimeDoctorReports = await runtimeDoctorTask
            let readinessReports = await runtimeReadinessTask
            let compatibilityReports = await compatibilityTask
            let healthReports = await healthTask
            let metadata = await metadataTask

            guard operationsCenterRunCoordinator.isCurrent(generation: generation),
                  settings == requestedSettings,
                  models == requestedModels,
                  selectedModelID == requestedSelectedModelID else {
                return
            }

            runtimeReadinessViewState.complete(readinessReports)
            runtimeCompatibilityViewState.complete(compatibilityReports)
            registeredModelHealthViewState.complete(healthReports)

            let operationalReport = makeOperationsReadinessReport(
                selected: requestedSelectedModel,
                readinessReports: readinessReports,
                compatibilityReports: compatibilityReports,
                healthReports: healthReports
            )
            let plan = settings.launchPlans.first ?? defaultOperationsLaunchPlan
            let capacity = await capacityAssessment(for: plan)
            guard operationsCenterRunCoordinator.isCurrent(generation: generation) else {
                return
            }

            let captured = evidenceFreshnessService.capture(
                settings: requestedSettings,
                model: requestedSelectedModel,
                benchmarkSession: requestedBenchmarkSession,
                systemMemory: memorySnapshot
            )
            let baseline = previousEvidence.isEmpty ? captured : previousEvidence
            let evidence = evidenceFreshnessService.compare(
                captured: baseline,
                current: captured
            )

            operationsCenterViewState.platform = platform
            operationsCenterViewState.runtimeReports = runtimeDoctorReports
            operationsCenterViewState.operationalReadiness = operationalReport
            operationsCenterViewState.modelMetadata = metadata
            operationsCenterViewState.capacity = capacity
            operationsCenterViewState.capturedEvidence = captured
            operationsCenterViewState.evidence = evidence
            operationsCenterViewState.calibrationRecords = settings.resourceCalibrationRecords
            operationsCenterViewState.isChecking = false
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Operations Center checks completed without generation or configuration changes.",
                japanese: "生成や設定変更を行わず、Operations Centerの確認が完了しました。"
            )
            appendRuntimeEvent(
                category: "Operations Center",
                severity: (operationalReport?.blockingCount ?? 0) > 0 ? .warning : .success,
                message: "Operations Center checks completed.",
                japaneseMessage: "Operations Centerの確認が完了しました。",
                modelID: requestedSelectedModel?.modelID,
                endpoint: requestedSelectedModel.map { "\($0.host):\($0.serverPort)" }
            )
        }
    }

    func refreshOperationsEvidenceFreshness() {
        let current = evidenceFreshnessService.capture(
            settings: settings,
            model: selectedModel,
            benchmarkSession: selectedModel.flatMap { benchmarkSessionsByProfileID[$0.id] },
            systemMemory: systemMemorySnapshotProvider()
        )
        operationsCenterViewState.evidence = evidenceFreshnessService.compare(
            captured: operationsCenterViewState.capturedEvidence,
            current: current
        )
    }

    func runLaunchStabilityCheckRequested() {
        guard let model = selectedModel,
              let initialPID = serverLifecycleCoordinator.processIdentifier(for: model.id) else {
            operationsCenterViewState.stability = LaunchStabilityReport(
                profileID: selectedModel?.id ?? "none",
                status: .notRunning,
                samples: [],
                startedAt: Date(),
                completedAt: Date()
            )
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Stability verification requires a running app-managed server.",
                japanese: "安定性確認には、実行中のアプリ管理サーバーが必要です。"
            )
            return
        }

        let startedAt = Date()
        operationsCenterViewState.stability = LaunchStabilityReport(
            profileID: model.id,
            status: .stabilizing,
            samples: [],
            startedAt: startedAt,
            completedAt: startedAt
        )
        launchStabilityRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            var samples: [LaunchStabilitySample] = []
            var status: LaunchStabilityStatus = .stable

            for index in 0..<5 {
                guard !Task.isCancelled,
                      launchStabilityRunCoordinator.isCurrent(generation: generation) else {
                    return
                }
                let currentPID = serverLifecycleCoordinator.processIdentifier(for: model.id)
                guard currentPID == initialPID else {
                    status = currentPID == nil ? .exited : .unstable
                    samples.append(LaunchStabilitySample(
                        timestamp: Date(),
                        ready: false,
                        processIdentifier: currentPID,
                        managedMemoryGigabytes: memoryUsageByModelID[model.id],
                        message: "The managed process identifier changed during stability verification."
                    ))
                    break
                }
                let readyResult = await operationsReadyChecker.check(
                    host: model.host,
                    port: model.serverPort,
                    expectedModelID: model.modelID
                )
                let ready: Bool
                let message: String?
                switch readyResult {
                case .ready:
                    ready = true
                    message = nil
                case let .notReady(_, statusCode):
                    ready = false
                    message = "Ready check returned HTTP \(statusCode)."
                case let .invalidInput(errorMessage):
                    ready = false
                    message = errorMessage
                case let .failed(_, errorMessage):
                    ready = false
                    message = errorMessage
                case .timedOut:
                    ready = false
                    message = "Ready check timed out."
                }
                if runtimeState(for: model).isDegraded {
                    status = .degraded
                } else if !ready, status == .stable {
                    status = .unstable
                }
                samples.append(LaunchStabilitySample(
                    timestamp: Date(),
                    ready: ready,
                    processIdentifier: currentPID,
                    managedMemoryGigabytes: memoryUsageByModelID[model.id],
                    message: message
                ))
                operationsCenterViewState.stability = LaunchStabilityReport(
                    profileID: model.id,
                    status: .stabilizing,
                    samples: samples,
                    startedAt: startedAt,
                    completedAt: Date()
                )
                if index < 4 {
                    try? await Task.sleep(for: .seconds(1))
                }
            }

            guard launchStabilityRunCoordinator.isCurrent(generation: generation) else { return }
            operationsCenterViewState.stability = LaunchStabilityReport(
                profileID: model.id,
                status: status,
                samples: samples,
                startedAt: startedAt,
                completedAt: Date()
            )
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Launch stability verification completed with status: \(status.localizedTitle(language: .english)).",
                japanese: "起動安定性の確認が完了しました。状態: \(status.localizedTitle(language: .japanese))。"
            )
        }
    }

    func cancelLaunchStabilityCheckRequested() {
        launchStabilityRunCoordinator.cancel()
        if let current = operationsCenterViewState.stability,
           current.status == .stabilizing {
            operationsCenterViewState.stability = LaunchStabilityReport(
                profileID: current.profileID,
                status: .unstable,
                samples: current.samples,
                startedAt: current.startedAt,
                completedAt: Date()
            )
        }
    }

    func recordResourceCalibrationRequested() {
        guard let model = selectedModel,
              serverLifecycleCoordinator.processIdentifier(for: model.id) != nil else {
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Resource calibration requires a running app-managed profile.",
                japanese: "リソース実測の記録には、実行中のアプリ管理プロファイルが必要です。"
            )
            return
        }
        let memory = systemMemorySnapshotProvider()
        let forecast = startResourceForecast(for: model)
        let benchmark = benchmarkSessionsByProfileID[model.id]?.aggregate
        let record = ResourceCalibrationRecord(
            profileID: model.id,
            modelID: model.modelID,
            backend: model.resolvedBackend,
            executionFingerprint: BenchmarkExecutionFingerprint.make(
                model: model,
                executablePath: executablePath(for: model)
            ),
            totalMemoryGigabytes: memory.totalGigabytes,
            availableMemoryGigabytes: memory.availableGigabytes,
            predictedManagedMemoryGigabytes: forecast.assessment.candidateFootprintGigabytes,
            observedManagedMemoryGigabytes: memoryUsageByModelID[model.id],
            benchmarkTTFTMS: benchmark?.medianTTFTMS,
            benchmarkTokensPerSecond: benchmark?.medianOutputTokensPerSecond,
            benchmarkStabilityPercent: benchmark?.stabilityPercent
        )
        var nextSettings = settings
        nextSettings.resourceCalibrationRecords = Array(
            (nextSettings.resourceCalibrationRecords + [record]).suffix(100)
        )
        if saveSettingsRequested(nextSettings) {
            operationsCenterViewState.calibrationRecords = nextSettings.resourceCalibrationRecords
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Recorded a local resource calibration snapshot. No profile setting was changed.",
                japanese: "ローカルのリソース実測スナップショットを記録しました。プロファイル設定は変更していません。"
            )
        }
    }

    func createLaunchPlanFromSelectedRequested() {
        guard let model = selectedModel else { return }
        let plan = LaunchPlanDefinition(
            name: model.displayName,
            steps: [LaunchPlanStep(profileID: model.id, isRequired: true)]
        )
        appendLaunchPlan(plan)
    }

    func createLaunchPlanFromAllProfilesRequested() {
        let plan = defaultOperationsLaunchPlan
        appendLaunchPlan(plan)
    }

    func saveLaunchPlanRequested(_ plan: LaunchPlanDefinition) {
        let normalizedName = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let validProfileIDs = Set(models.map(\.id))
        let normalizedSteps = plan.steps.filter { validProfileIDs.contains($0.profileID) }
        guard !normalizedName.isEmpty,
              !normalizedSteps.isEmpty,
              Set(normalizedSteps.map(\.profileID)).count == normalizedSteps.count else {
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "The launch plan must have a name and at least one unique registered profile.",
                japanese: "起動プランには名前と、重複のない登録済みプロファイルが1件以上必要です。"
            )
            return
        }
        var normalizedPlan = plan
        normalizedPlan.name = normalizedName
        normalizedPlan.steps = normalizedSteps
        normalizedPlan.updatedAt = Date()
        var nextSettings = settings
        if let index = nextSettings.launchPlans.firstIndex(where: { $0.id == normalizedPlan.id }) {
            nextSettings.launchPlans[index] = normalizedPlan
        } else {
            nextSettings.launchPlans.append(normalizedPlan)
        }
        if saveSettingsRequested(nextSettings) {
            refreshCapacityForLaunchPlanRequested(normalizedPlan)
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Saved the launch plan definition. No server was started or stopped.",
                japanese: "起動プランの定義を保存しました。サーバーの起動・停止は行っていません。"
            )
        }
    }

    func deleteLaunchPlanRequested(_ plan: LaunchPlanDefinition) {
        var nextSettings = settings
        nextSettings.launchPlans.removeAll { $0.id == plan.id }
        if saveSettingsRequested(nextSettings) {
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Deleted the launch plan definition. Running servers were not changed.",
                japanese: "起動プランの定義を削除しました。実行中のサーバーは変更していません。"
            )
        }
    }

    func setLaunchPlanStepRequiredRequested(
        _ plan: LaunchPlanDefinition,
        profileID: String,
        isRequired: Bool
    ) {
        guard let planIndex = settings.launchPlans.firstIndex(where: { $0.id == plan.id }),
              let stepIndex = settings.launchPlans[planIndex].steps.firstIndex(where: { $0.profileID == profileID }) else {
            return
        }
        var nextSettings = settings
        nextSettings.launchPlans[planIndex].steps[stepIndex].isRequired = isRequired
        nextSettings.launchPlans[planIndex].updatedAt = Date()
        if saveSettingsRequested(nextSettings) {
            refreshCapacityForLaunchPlanRequested(nextSettings.launchPlans[planIndex])
        }
    }

    func moveLaunchPlanStepRequested(
        _ plan: LaunchPlanDefinition,
        profileID: String,
        offset: Int
    ) {
        guard offset != 0,
              let planIndex = settings.launchPlans.firstIndex(where: { $0.id == plan.id }),
              let sourceIndex = settings.launchPlans[planIndex].steps.firstIndex(where: { $0.profileID == profileID }) else {
            return
        }
        let destinationIndex = sourceIndex + offset
        guard settings.launchPlans[planIndex].steps.indices.contains(destinationIndex) else {
            return
        }
        var nextSettings = settings
        let step = nextSettings.launchPlans[planIndex].steps.remove(at: sourceIndex)
        nextSettings.launchPlans[planIndex].steps.insert(step, at: destinationIndex)
        nextSettings.launchPlans[planIndex].updatedAt = Date()
        if saveSettingsRequested(nextSettings) {
            refreshCapacityForLaunchPlanRequested(nextSettings.launchPlans[planIndex])
        }
    }

    func runLaunchPlanRequested(_ plan: LaunchPlanDefinition) {
        launchPlanRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            operationsCenterViewState.launchPlanExecution = LaunchPlanExecutionState(
                planID: plan.id,
                phase: .validating,
                currentProfileID: nil,
                completedProfileIDs: [],
                startedByPlanProfileIDs: [],
                message: nil
            )
            guard let validationMessage = await validateLaunchPlan(plan) else {
                operationsCenterViewState.launchPlanExecution.phase = .failed
                operationsCenterViewState.launchPlanExecution.message = Self.localizedText(
                    language: settings.uiLanguage,
                    english: "The launch plan could not be validated.",
                    japanese: "起動プランを検証できませんでした。"
                )
                return
            }
            if !validationMessage.isEmpty {
                operationsCenterViewState.launchPlanExecution.phase = .failed
                operationsCenterViewState.launchPlanExecution.message = validationMessage
                return
            }

            let modelByID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
            for step in plan.steps {
                guard !Task.isCancelled,
                      launchPlanRunCoordinator.isCurrent(generation: generation) else {
                    operationsCenterViewState.launchPlanExecution.phase = .cancelled
                    return
                }
                guard let model = modelByID[step.profileID] else {
                    if step.isRequired {
                        operationsCenterViewState.launchPlanExecution.phase = .failed
                        operationsCenterViewState.launchPlanExecution.message = "A required profile is missing."
                        return
                    }
                    continue
                }
                operationsCenterViewState.launchPlanExecution.currentProfileID = model.id
                if runningModelIDs.contains(model.id) {
                    operationsCenterViewState.launchPlanExecution.completedProfileIDs.append(model.id)
                    continue
                }
                operationsCenterViewState.launchPlanExecution.phase = .starting
                startRequested(for: model)
                let didStart = await waitForLaunchPlanProfile(
                    model,
                    generation: generation,
                    timeout: 120
                )
                if didStart {
                    operationsCenterViewState.launchPlanExecution.completedProfileIDs.append(model.id)
                    operationsCenterViewState.launchPlanExecution.startedByPlanProfileIDs.append(model.id)
                } else if step.isRequired {
                    operationsCenterViewState.launchPlanExecution.phase = .failed
                    operationsCenterViewState.launchPlanExecution.message = Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Required profile \(model.displayName) did not become ready. Already-running profiles were left unchanged.",
                        japanese: "必須プロファイル「\(model.displayName)」が準備完了になりませんでした。既に実行中だったプロファイルは変更していません。"
                    )
                    return
                }
            }
            operationsCenterViewState.launchPlanExecution.currentProfileID = nil
            operationsCenterViewState.launchPlanExecution.phase = .completed
            operationsCenterViewState.launchPlanExecution.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Launch plan completed.",
                japanese: "起動プランが完了しました。"
            )
        }
    }

    func cancelLaunchPlanRequested() {
        launchPlanRunCoordinator.cancel()
        operationsCenterViewState.launchPlanExecution.phase = .cancelled
        operationsCenterViewState.launchPlanExecution.currentProfileID = nil
    }

    func stopServersStartedByLaunchPlanRequested() {
        let profileIDs = operationsCenterViewState.launchPlanExecution.startedByPlanProfileIDs
        operationsCenterViewState.launchPlanExecution.phase = .stopping
        for profileID in profileIDs.reversed() {
            guard let model = models.first(where: { $0.id == profileID }),
                  runningModelIDs.contains(profileID) else {
                continue
            }
            stopRequested(for: model)
        }
        operationsCenterViewState.launchPlanExecution.phase = .completed
        operationsCenterViewState.launchPlanExecution.currentProfileID = nil
        operationsCenterViewState.launchPlanExecution.message = Self.localizedText(
            language: settings.uiLanguage,
            english: "Stop was requested only for app-owned profiles started by this launch-plan run.",
            japanese: "この起動プラン実行で開始したアプリ所有プロファイルだけに停止を要求しました。"
        )
    }

    func refreshCapacityForLaunchPlanRequested(_ plan: LaunchPlanDefinition) {
        operationsCenterRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let capacity = await capacityAssessment(for: plan)
            guard operationsCenterRunCoordinator.isCurrent(generation: generation) else { return }
            operationsCenterViewState.capacity = capacity
        }
    }

    func generateSupportBundleRequested() {
        let report = supportBundleService.makeReport(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            platform: operationsCenterViewState.platform,
            runtimeReports: operationsCenterViewState.runtimeReports,
            modelMetadata: operationsCenterViewState.modelMetadata,
            evidence: operationsCenterViewState.evidence,
            stability: operationsCenterViewState.stability,
            capacity: operationsCenterViewState.capacity,
            launchDiagnosis: selectedModel.flatMap { launchFailureDiagnosesByModelID[$0.id] },
            operationalHistory: runtimeEvents
        )
        operationsCenterViewState.supportBundle = report
        operationsCenterViewState.message = Self.localizedText(
            language: settings.uiLanguage,
            english: "Generated a memory-only redacted support bundle.",
            japanese: "メモリ上にマスキング済みSupport Bundleを生成しました。"
        )
    }

    func copySupportBundleRequested() {
        if operationsCenterViewState.supportBundle == nil {
            generateSupportBundleRequested()
        }
        guard let report = operationsCenterViewState.supportBundle else { return }
        if copyToPasteboard(report.text) {
            appendLog("[support] copied redacted Operations Center support bundle.")
        }
    }

    private func appendLaunchPlan(_ plan: LaunchPlanDefinition) {
        guard !plan.steps.isEmpty else { return }
        var nextSettings = settings
        nextSettings.launchPlans.append(plan)
        if saveSettingsRequested(nextSettings) {
            refreshCapacityForLaunchPlanRequested(plan)
            operationsCenterViewState.message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Saved the launch plan definition. No server was started.",
                japanese: "起動プランの定義を保存しました。サーバーは起動していません。"
            )
        }
    }

    private func makeOperationsReadinessReport(
        selected: ModelConfig?,
        readinessReports: [RuntimeReadinessReport],
        compatibilityReports: [RuntimeCompatibilityReport],
        healthReports: [RegisteredModelHealthReport]
    ) -> OperationalReadinessReport? {
        guard let selected else { return nil }
        let runtimeReport = readinessReports.first { $0.backend == selected.resolvedBackend }
        let compatibilityReport = compatibilityReports.first { $0.backend == selected.resolvedBackend }
        let request = ModelLaunchRequest(
            executablePath: executablePath(for: selected),
            backend: selected.resolvedBackend,
            modelID: selected.modelID,
            host: selected.host,
            port: selected.serverPort,
            enableThinking: selected.enableThinking,
            advancedLaunchOptions: selected.advancedLaunchOptions
        )
        let compatibility = RuntimeProfileCompatibilityAdvisor.assess(
            request: request,
            report: compatibilityReport
        )
        let endpointActive = serverLifecycleCoordinator.isRunning(selected.id)
            || runtimeState.isExternalServerContext
        return OperationalReadinessProjector.makeReport(
            selectedModel: selected,
            runtimeReadiness: runtimeReport,
            compatibility: compatibility,
            healthReports: healthReports,
            portCheckResult: freshPortCheck(host: selected.host, port: selected.serverPort),
            selectedEndpointIsActive: endpointActive,
            resourceForecast: startResourceForecast(for: selected),
            sessionRecoveryCandidateCount: sessionRecoveryViewState.candidates.filter { !$0.isAdopted }.count,
            tuningRecommendations: benchmarkTuningRecommendations(for: selected),
            hermesConfigPath: settings.hermesConfigPath,
            launchFailureDiagnosis: launchFailureDiagnosesByModelID[selected.id]
        )
    }

    private func capacityAssessment(
        for plan: LaunchPlanDefinition
    ) async -> CapacityPlanAssessment {
        var estimates: [String: Double] = [:]
        for step in plan.steps {
            guard let model = models.first(where: { $0.id == step.profileID }) else { continue }
            if let value = await resolvedModelSizeGigabytes(for: model) {
                estimates[model.id] = value
            }
        }
        let managedMemory = runningModelIDs.reduce(0.0) {
            $0 + max(memoryUsageByModelID[$1] ?? 0, 0)
        }
        return capacityPlanningService.assess(
            plan: plan,
            models: models,
            estimatedGigabytesByProfileID: estimates,
            runningProfileIDs: runningModelIDs,
            managedMemoryGigabytes: managedMemory,
            systemMemory: systemMemorySnapshotProvider()
        )
    }

    private func validateLaunchPlan(_ plan: LaunchPlanDefinition) async -> String? {
        guard !plan.steps.isEmpty else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "The launch plan has no profiles.",
                japanese: "起動プランにプロファイルがありません。"
            )
        }
        let identifiers = plan.steps.map(\.profileID)
        guard Set(identifiers).count == identifiers.count else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "The launch plan contains duplicate profiles.",
                japanese: "起動プランに同じプロファイルが重複しています。"
            )
        }
        let planModels = plan.steps.compactMap { step in models.first { $0.id == step.profileID } }
        let requiredMissing = plan.steps.contains { step in
            step.isRequired && !models.contains(where: { $0.id == step.profileID })
        }
        guard !requiredMissing else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "A required profile no longer exists.",
                japanese: "必須プロファイルが削除されています。"
            )
        }
        let endpoints = planModels.map { "\($0.host.lowercased()):\($0.serverPort)" }
        guard Set(endpoints).count == endpoints.count else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Two launch-plan profiles use the same endpoint.",
                japanese: "起動プラン内の複数プロファイルが同じエンドポイントを使用しています。"
            )
        }
        guard planModels.allSatisfy({ !NetworkExposureAdvisor.assess(host: $0.host).requiresExplicitStartConfirmation }) else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Launch plans do not bypass network-exposure confirmation. Start non-loopback profiles individually.",
                japanese: "起動プランはネットワーク公開確認を省略しません。ループバック以外のプロファイルは個別に起動してください。"
            )
        }
        for model in planModels where !runningModelIDs.contains(model.id) {
            let forecast = startResourceForecast(for: model)
            if forecast.assessment.requiresConfirmation {
                return Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Launch plans do not bypass critical memory confirmation. Review \(model.displayName) individually.",
                    japanese: "起動プランは重大なメモリ確認を省略しません。「\(model.displayName)」を個別に確認してください。"
                )
            }
            if profileCompatibilityAssessment(for: model).level == .blocked {
                return Self.localizedText(
                    language: settings.uiLanguage,
                    english: "\(model.displayName) requests options known to be unsupported by its configured runtime.",
                    japanese: "「\(model.displayName)」には、設定済みランタイムで未対応と判明しているオプションがあります。"
                )
            }
        }
        let capacity = await capacityAssessment(for: plan)
        operationsCenterViewState.capacity = capacity
        if capacity.level == .critical {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "The launch plan is projected to cross the emergency memory floor.",
                japanese: "起動プランは緊急メモリ下限を下回ると予測されています。"
            )
        }
        return ""
    }

    private func waitForLaunchPlanProfile(
        _ model: ModelConfig,
        generation: LatestRequestCoordinator.Generation,
        timeout: TimeInterval
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard !Task.isCancelled,
                  launchPlanRunCoordinator.isCurrent(generation: generation) else {
                return false
            }
            switch runtimeState(for: model) {
            case .ready:
                return true
            case .degraded, .readyCheckFailed, .portBusy, .portCheckFailed, .error:
                return false
            default:
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }
}
