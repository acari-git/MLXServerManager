import Foundation

extension AppViewModel {
    func runtimeCompatibilityReport(for backend: InferenceBackend) -> RuntimeCompatibilityReport? {
        runtimeCompatibilityViewState.reports.first { $0.backend == backend }
    }

    func profileCompatibilityAssessment(for draft: ModelProfileDraft) -> ProfileCompatibilityAssessment? {
        guard let request = launchRequest(for: draft) else { return nil }
        return RuntimeProfileCompatibilityAdvisor.assess(
            request: request,
            report: runtimeCompatibilityReport(for: draft.backend)
        )
    }

    func profileCompatibilityAssessment(for model: ModelConfig) -> ProfileCompatibilityAssessment {
        let request = ModelLaunchRequest(
            executablePath: executablePath(for: model),
            backend: model.resolvedBackend,
            modelID: model.modelID,
            host: model.host,
            port: model.serverPort,
            enableThinking: model.enableThinking,
            advancedLaunchOptions: model.advancedLaunchOptions
        )
        return RuntimeProfileCompatibilityAdvisor.assess(
            request: request,
            report: runtimeCompatibilityReport(for: model.resolvedBackend)
        )
    }

    func startResourceForecast(for draft: ModelProfileDraft) -> StartResourceForecast? {
        guard let model = modelConfig(from: draft) else { return nil }
        return startResourceForecast(for: model)
    }

    func startResourceForecast(for model: ModelConfig) -> StartResourceForecast {
        let assessment = memorySafetyAssessment(for: model)
        let systemMemory = systemMemorySnapshotProvider()
        let safeMode = kvCacheSafeModeResult(
            for: model,
            options: model.advancedLaunchOptions,
            candidateModelGigabytes: modelSizeGigabytes(for: model),
            systemMemory: systemMemory
        )
        return StartResourceForecastAdvisor.make(
            profileID: model.id,
            assessment: assessment,
            currentOptions: model.advancedLaunchOptions ?? .empty,
            safeModeResult: safeMode
        )
    }

    func benchmarkTuningRecommendations(
        for model: ModelConfig
    ) -> [BenchmarkProfileTuningRecommendation] {
        BenchmarkProfileTuningAdvisor.recommendations(
            row: benchmarkComparisonRow(for: model)
        )
    }

    func benchmarkTuningRecommendation(
        for draft: ModelProfileDraft,
        useCase: BenchmarkUseCase
    ) -> BenchmarkProfileTuningRecommendation? {
        let lookupID = draft.originalModelID.isEmpty ? draft.modelID : draft.originalModelID
        guard let model = models.first(where: { $0.id == lookupID }) else { return nil }
        return BenchmarkProfileTuningAdvisor.recommendation(
            row: benchmarkComparisonRow(for: model),
            useCase: useCase
        )
    }

    func refreshRegisteredModelHealthRequested() {
        registeredModelHealthViewState.begin()
        registeredModelHealthRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let reports = await registeredModelHealthService.assess(models: models)
            guard registeredModelHealthRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            registeredModelHealthViewState.complete(reports)
            appendRuntimeEvent(
                category: "Model Health",
                severity: reports.contains(where: { $0.status == .incomplete || $0.status == .missing })
                    ? .warning
                    : .success,
                message: "Registered model health inspection completed for \(reports.count) profile(s).",
                japaneseMessage: "登録済みモデル\(reports.count)件の健全性確認が完了しました。"
            )
        }
    }

    func cancelRegisteredModelHealthRequested() {
        registeredModelHealthRunCoordinator.cancel()
        registeredModelHealthViewState.cancel()
    }

    func openOperationalReadinessRequested() {
        operationalReadinessViewState.isPresented = true
        refreshOperationalReadinessRequested()
    }

    func refreshOperationalReadinessRequested() {
        operationalReadinessViewState.begin()
        let requestedSettings = settings
        let requestedModels = models
        let requestedSelectedModelID = selectedModelID

        operationalReadinessRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            async let readinessTask = runtimeReadinessService.assess(settings: requestedSettings)
            async let compatibilityTask = runtimeCompatibilityService.assess(settings: requestedSettings)
            async let healthTask = registeredModelHealthService.assess(models: requestedModels)
            let readinessReports = await readinessTask
            let compatibilityReports = await compatibilityTask
            let healthReports = await healthTask

            guard operationalReadinessRunCoordinator.isCurrent(generation: generation),
                  settings == requestedSettings,
                  models == requestedModels,
                  selectedModelID == requestedSelectedModelID else {
                return
            }

            runtimeReadinessViewState.complete(readinessReports)
            runtimeCompatibilityViewState.complete(compatibilityReports)
            registeredModelHealthViewState.complete(healthReports)

            let selected = selectedModel
            let runtimeReport = selected.flatMap { model in
                readinessReports.first { $0.backend == model.resolvedBackend }
            }
            let compatibilityReport = selected.flatMap { model in
                compatibilityReports.first { $0.backend == model.resolvedBackend }
            }
            let compatibilityAssessment = selected.map { model in
                let request = ModelLaunchRequest(
                    executablePath: self.executablePath(for: model),
                    backend: model.resolvedBackend,
                    modelID: model.modelID,
                    host: model.host,
                    port: model.serverPort,
                    enableThinking: model.enableThinking,
                    advancedLaunchOptions: model.advancedLaunchOptions
                )
                return RuntimeProfileCompatibilityAdvisor.assess(
                    request: request,
                    report: compatibilityReport
                )
            }
            let portResult = selected.map { self.freshPortCheck(host: $0.host, port: $0.serverPort) }
            let selectedEndpointIsActive = selected.map { model in
                self.serverLifecycleCoordinator.isRunning(model.id)
                    || self.runtimeState.isExternalServerContext
            } ?? false
            let forecast = selected.map { self.startResourceForecast(for: $0) }
            let recommendations = selected.map { self.benchmarkTuningRecommendations(for: $0) } ?? []
            let diagnosis = selected.flatMap { self.launchFailureDiagnosesByModelID[$0.id] }
            let unresolvedRecoveryCount = sessionRecoveryViewState.candidates.filter { !$0.isAdopted }.count

            let report = OperationalReadinessProjector.makeReport(
                selectedModel: selected,
                runtimeReadiness: runtimeReport,
                compatibility: compatibilityAssessment,
                healthReports: healthReports,
                portCheckResult: portResult,
                selectedEndpointIsActive: selectedEndpointIsActive,
                resourceForecast: forecast,
                sessionRecoveryCandidateCount: unresolvedRecoveryCount,
                tuningRecommendations: recommendations,
                hermesConfigPath: requestedSettings.hermesConfigPath,
                launchFailureDiagnosis: diagnosis
            )
            operationalReadinessViewState.complete(report)
            appendRuntimeEvent(
                category: "Operational Readiness",
                severity: report.blockingCount > 0 ? .warning : .success,
                message: "Operational readiness completed with \(report.blockingCount) blocking and \(report.attentionCount) review item(s).",
                japaneseMessage: "運用準備確認が完了しました。起動不可\(report.blockingCount)件、要確認\(report.attentionCount)件です。",
                modelID: selected?.modelID,
                endpoint: selected.map { "\($0.host):\($0.serverPort)" }
            )
        }
    }

    func cancelOperationalReadinessRequested() {
        operationalReadinessRunCoordinator.cancel()
        operationalReadinessViewState.cancel()
    }

    func dismissOperationalReadinessRequested() {
        operationalReadinessRunCoordinator.cancel()
        operationalReadinessViewState.isPresented = false
        operationalReadinessViewState.isChecking = false
    }

    func reviewUnsupportedProfileOptionsRequested() {
        guard let model = selectedModel else { return }
        let assessment = profileCompatibilityAssessment(for: model)
        guard assessment.canClearUnsupportedOptions else {
            editProfileRequested(for: model)
            return
        }
        guard !runningModelIDs.contains(model.id) else {
            appendLog("[compatibility] stop \(model.displayName) before clearing unsupported options.")
            editProfileRequested(for: model)
            return
        }
        let draft = RuntimeProfileCompatibilityAdvisor.clearingUnsupportedOptions(
            in: ModelProfileDraft(model: model),
            flags: assessment.unsupportedFlags
        )
        updateProfileEditorViewState { state in
            state.present(
                draft: draft,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Unsupported options were removed from this unsaved draft. Review the command preview, then save explicitly.",
                    japanese: "未対応オプションを未保存の編集案から解除しました。起動コマンドを確認し、明示的に保存してください。"
                )
            )
        }
    }

    func reviewResourceForecastRequested() {
        guard let model = selectedModel else { return }
        guard !runningModelIDs.contains(model.id) else {
            editProfileRequested(for: model)
            return
        }
        let forecast = startResourceForecast(for: model)
        var draft = ModelProfileDraft(model: model)
        draft.advancedLaunchOptions = forecast.suggestedOptions
        if let template = forecast.recommendedTemplate {
            draft = template.applying(to: draft)
        }
        updateProfileEditorViewState { state in
            state.present(
                draft: draft,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Resource-safe values were placed in this unsaved draft. Review all differences before saving.",
                    japanese: "リソース安全性を考慮した値を未保存の編集案へ反映しました。保存前にすべての差分を確認してください。"
                )
            )
        }
    }

    func reviewBenchmarkTuningRequested(_ recommendation: BenchmarkProfileTuningRecommendation) {
        guard let model = models.first(where: { $0.id == recommendation.profileID }) else { return }
        selectedModelID = model.id
        guard !runningModelIDs.contains(model.id) else {
            editProfileRequested(for: model)
            return
        }
        let draft = recommendation.template.applying(to: ModelProfileDraft(model: model))
        updateProfileEditorViewState { state in
            state.present(
                draft: draft,
                message: recommendation.localizedReason(language: settings.uiLanguage)
            )
        }
    }

    func copyOperationalReadinessRequested() {
        guard let report = operationalReadinessViewState.report else {
            appendLog("[readiness] no operational readiness report to copy.")
            return
        }
        if copyToPasteboard(report.copyText(language: settings.uiLanguage)) {
            appendLog("[readiness] copied operational readiness report.")
        } else {
            appendLog("[readiness] failed to copy operational readiness report.")
        }
    }

    func recoveryIssue(from diagnosis: LaunchFailureDiagnosis) -> RecoveryIssue {
        let category: RecoveryIssueCategory
        switch diagnosis.category {
        case .executable:
            category = .executableMissing
        case .dependency, .unsupportedOption, .chatTemplate, .reasoningParser, .toolCallParser, .memory:
            category = .unknown
        case .modelFiles:
            category = .modelPathMissing
        case .port:
            category = .portBusy
        case .permission:
            category = .permissionDenied
        case .readiness:
            category = .readinessTimeout
        case .processExit:
            category = .processExitedEarly
        case .unknown:
            category = .unknown
        }
        return RecoveryIssue(
            category: category,
            severity: diagnosis.category == .unknown ? .review : .failed,
            title: diagnosis.category.localizedTitle(language: .english),
            detail: diagnosis.category.localizedGuidance(language: settings.uiLanguage),
            relatedLogLine: diagnosis.evidenceLines.last,
            actions: []
        )
    }

    func recordLaunchFailureDiagnosis(
        for model: ModelConfig,
        fallbackMessage: String
    ) {
        let diagnosis = launchFailureDiagnosticCoordinator.diagnose(
            modelID: model.id,
            backend: model.resolvedBackend,
            fallbackMessage: fallbackMessage
        )
        launchFailureDiagnosesByModelID[model.id] = diagnosis
        appendRuntimeEvent(
            category: "Launch Diagnosis",
            severity: .failure,
            message: diagnosis.localizedSummary(language: .english),
            japaneseMessage: diagnosis.localizedSummary(language: .japanese),
            modelID: model.modelID,
            endpoint: "\(model.host):\(model.serverPort)"
        )
    }

    func clearLaunchFailureDiagnosis(for modelID: ModelConfig.ID) {
        launchFailureDiagnosticCoordinator.clear(modelID: modelID)
        launchFailureDiagnosesByModelID[modelID] = nil
    }

    private func launchRequest(for draft: ModelProfileDraft) -> ModelLaunchRequest? {
        let modelID = draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty,
              !host.isEmpty,
              let port = Int(draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return ModelLaunchRequest(
            executablePath: settings.executablePath(for: draft.backend),
            backend: draft.backend,
            modelID: modelID,
            host: host,
            port: port,
            enableThinking: draft.enableThinking,
            advancedLaunchOptions: draft.advancedLaunchOptions
        )
    }

    private func modelConfig(from draft: ModelProfileDraft) -> ModelConfig? {
        let modelID = draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty,
              !host.isEmpty,
              let port = Int(draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return ModelConfig(
            modelID: modelID,
            displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? modelID
                : draft.displayName,
            family: "",
            quantization: "",
            localName: URL(fileURLWithPath: modelID).lastPathComponent,
            host: host,
            serverPort: port,
            enableThinking: draft.enableThinking,
            notes: draft.notes,
            advancedLaunchOptions: draft.advancedLaunchOptions.normalized(),
            backend: draft.backend
        )
    }
}
