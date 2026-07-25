import Foundation

extension AppViewModel {
    var latestSpeedTestSummary: String {
        latestBenchmarkResult?.summary ?? latestSpeedTestMessage
    }

    var latestAgenticBenchmarkSummary: String {
        latestAgenticBenchmarkResult?.summary
            ?? Self.localizedText(
                language: settings.uiLanguage,
                english: "Optional Agent Readiness has not run yet.",
                japanese: "任意のAgent Readinessはまだ実行されていません。"
            )
    }

    func benchmarkResult(for model: ModelConfig) -> BenchmarkResult? {
        if latestBenchmarkResult?.profileID == model.id {
            return latestBenchmarkResult
        }
        return benchmarkResultsByProfileID[model.id]
    }

    func benchmarkSession(for model: ModelConfig) -> BenchmarkSessionResult? {
        benchmarkSessionsByProfileID[model.id]
    }

    var benchmarkComparisonRows: [BenchmarkComparisonRow] {
        benchmarkComparisonProjection.rows
    }

    func rankedBenchmarkRows(for useCase: BenchmarkUseCase) -> [BenchmarkComparisonRow] {
        benchmarkComparisonProjection.rankedRows(for: useCase)
    }

    func benchmarkComparisonRow(for model: ModelConfig) -> BenchmarkComparisonRow? {
        benchmarkComparisonProjection.row(for: model.id)
    }

    var comparableBenchmarkRowCount: Int {
        benchmarkComparisonProjection.comparableRowCount
    }

    private var benchmarkComparisonProjection: BenchmarkComparisonProjection {
        let cacheKey = BenchmarkComparisonProjectionCacheKey(
            models: models,
            sessionsByProfileID: benchmarkSessionsByProfileID,
            currentChipName: systemProfilerHardwareInfo["Chip"],
            mlxServerExecutablePath: settings.mlxServerExecutablePath,
            rapidMLXExecutablePath: settings.rapidMLXExecutablePath
        )
        if let cacheEntry = benchmarkComparisonProjectionCacheEntry,
           cacheEntry.key == cacheKey {
            return cacheEntry.projection
        }

        let executionFingerprints = Dictionary(
            uniqueKeysWithValues: models.map { model in
                (
                    model.id,
                    BenchmarkExecutionFingerprint.make(
                        model: model,
                        executablePath: executablePath(for: model)
                    )
                )
            }
        )
        let projection = BenchmarkComparisonProjection(
            models: models,
            sessionsByProfileID: benchmarkSessionsByProfileID,
            currentChipName: systemProfilerHardwareInfo["Chip"],
            currentExecutionFingerprintsByProfileID: executionFingerprints
        )
        benchmarkComparisonProjectionCacheEntry = BenchmarkComparisonProjectionCacheEntry(
            key: cacheKey,
            projection: projection
        )
        return projection
    }

    func setBenchmarkPreset(_ preset: BenchmarkPreset) {
        guard settings.benchmarkPreset != preset else { return }
        var nextSettings = settings
        nextSettings.benchmarkPreset = preset
        do {
            let outcome = try settingsStore.save(settings: nextSettings, models: models)
            settings = nextSettings
            appendLog("[benchmark] preset changed to \(preset.rawValue).")
            appendSettingsSaveWarnings(outcome)
        } catch {
            appendLog("[benchmark] failed to save preset: \(error.localizedDescription)")
        }
    }

    var benchmarkProgressText: String {
        guard isSpeedTestRunning, benchmarkSampleCount > 0 else { return "" }
        return Self.localizedText(
            language: settings.uiLanguage,
            english: "Sample \(benchmarkSampleIndex) of \(benchmarkSampleCount)",
            japanese: "\(benchmarkSampleIndex)/\(benchmarkSampleCount)回目"
        )
    }

    static func benchmarkSessionSummary(
        _ session: BenchmarkSessionResult,
        language: AppLanguage
    ) -> String {
        let aggregate = session.aggregate
        let preset = session.preset.localizedTitle(language: language)
        let speed = aggregate.medianOutputTokensPerSecond.map { String(format: "%.1f tok/s", $0) } ?? "-"
        let ttft = aggregate.medianTTFTMS.map { String(format: "%.0f ms", $0) } ?? "-"
        let stability = aggregate.stabilityPercent.map { "\($0)%" }
            ?? aggregate.stabilityLevel.localizedTitle(language: language)
        return localizedText(
            language: language,
            english: "\(preset): \(aggregate.successfulSampleCount)/\(aggregate.sampleCount) samples succeeded — Median speed \(speed), TTFT \(ttft), stability \(stability).",
            japanese: "\(preset): \(aggregate.sampleCount)回中\(aggregate.successfulSampleCount)回成功 — 中央値 速度 \(speed)、TTFT \(ttft)、安定度 \(stability)。"
        )
    }

    func agenticBenchmarkResult(for model: ModelConfig) -> AgenticBenchmarkResult? {
        if latestAgenticBenchmarkResult?.profileID == model.id {
            return latestAgenticBenchmarkResult
        }
        return agenticBenchmarkResultsByProfileID[model.id]
    }

    func benchmarkSummary(for model: ModelConfig) -> String {
        benchmarkResult(for: model)?.localizedSummary(language: settings.uiLanguage) ?? latestSpeedTestMessage
    }

    func agenticBenchmarkSummary(for model: ModelConfig) -> String {
        agenticBenchmarkResult(for: model)?.localizedSummary(language: settings.uiLanguage)
            ?? Self.localizedText(
                language: settings.uiLanguage,
                english: "Optional Agent Readiness has not run yet.",
                japanese: "任意のAgent Readinessはまだ実行されていません。"
            )
    }

    var benchmarkSummaryText: String {
        let successfulLatencies = benchmarkHistory.compactMap { result in
            result.phase == .success ? result.readinessLatencyMS : nil
        }
        let failedCount = benchmarkHistory.filter { $0.phase == .failed }.count
        let best = successfulLatencies.min().map { "\(Int($0)) ms" } ?? "-"
        let average = successfulLatencies.isEmpty
            ? "-"
            : "\(Int(successfulLatencies.reduce(0, +) / Double(successfulLatencies.count))) ms"
        return Self.localizedText(language: settings.uiLanguage, english: "Runs: \(benchmarkHistory.count), best \(best), average \(average), failed \(failedCount)", japanese: "実行: \(benchmarkHistory.count)回、最良 \(best)、平均 \(average)、失敗 \(failedCount)回")
    }

    var selectedLaunchCommandPreview: String {
        guard let selectedModel else {
            return Self.localizedText(language: settings.uiLanguage, english: "Select a profile to preview the launch command.", japanese: "起動コマンドをプレビューするにはプロファイルを選択してください。")
        }
        return LaunchCommandBuilder.command(
            executablePath: executablePath(for: selectedModel),
            model: selectedModel
        )
    }

    var selectedAdvancedLaunchOptionsSummary: String {
        guard let options = selectedModel?.advancedLaunchOptions, !options.isEmpty else {
            return Self.localizedText(language: settings.uiLanguage, english: "No advanced launch options configured.", japanese: "詳細起動オプションは設定されていません。")
        }
        let fields: [(String, String?)] = [
            ("Raw extra args", options.rawExtraArgs),
            ("Chat template args", options.chatTemplateArgs),
            ("Temperature", options.defaultTemperature),
            ("Top P", options.defaultTopP),
            ("Top K", options.defaultTopK),
            ("Min P", options.defaultMinP),
            ("Max tokens", options.defaultMaxTokens),
            ("Allowed origins", options.allowedOrigins),
            ("Log level", options.logLevel),
            ("Decode concurrency", options.decodeConcurrency),
            ("Prompt concurrency", options.promptConcurrency),
            ("Prefill step size", options.prefillStepSize),
            ("Prompt cache size", options.promptCacheSize),
            ("Prompt cache bytes", options.promptCacheBytes)
        ]
        return fields.compactMap { label, value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return "\(label): \(value)"
        }.joined(separator: "\n")
    }

    var diagnosticsBenchmarkCorrelationSummary: String {
        let latest = latestBenchmarkResult?.summary ?? "No benchmark result"
        let mismatch = runtimeSelectionWarning == nil ? "No selected/running mismatch" : "Selected/running mismatch"
        let restart = restartRequired ? "Restart required" : "No restart required"
        return "\(runtimeState.localizedTitle(language: settings.uiLanguage)) · \(mismatch) · \(restart) · \(latest)"
    }

    var benchmarkFailureGuidance: String? {
        guard let latestBenchmarkResult, latestBenchmarkResult.phase == .failed else {
            return nil
        }
        let message = latestBenchmarkResult.message.lowercased()
        if !connectionTargetSummary.isActiveTarget {
            return Self.localizedText(language: settings.uiLanguage, english: "Server is not running. Press Start before Benchmark.", japanese: "サーバーは実行されていません。ベンチマーク前に起動してください。")
        }
        if runtimeSelectionWarning != nil {
            return Self.localizedText(language: settings.uiLanguage, english: "Selected profile differs from the running profile. Stop → Start or Restart before measuring.", japanese: "選択プロファイルが実行中プロファイルと異なります。測定前に停止→起動、または再起動してください。")
        }
        if message.contains("timed out") {
            return Self.localizedText(language: settings.uiLanguage, english: "The server may still be loading the model or the model may be too heavy. Wait, then retry.", japanese: "サーバーがまだモデルをロード中、またはモデルが重すぎる可能性があります。少し待ってから再試行してください。")
        }
        if message.contains("http") {
            return Self.localizedText(language: settings.uiLanguage, english: "The endpoint responded but was not ready. Confirm the port and run Ready Check again.", japanese: "エンドポイントは応答しましたがReadyではありません。ポートを確認し、Ready確認を再実行してください。")
        }
        return Self.localizedText(language: settings.uiLanguage, english: "Check runtime diagnostics and logs, then retry Benchmark.", japanese: "ランタイム診断とログを確認してから、ベンチマークを再試行してください。")
    }

    func runSpeedTestRequested() {
        guard canRunSpeedTest else {
            benchmarkViewState.setLatestSpeedTestMessage(
                Self.localizedText(language: settings.uiLanguage, english: "Start the server before running Benchmark.", japanese: "ベンチマーク前にサーバーを起動してください。")
            )
            appendLog("[benchmark] speed test skipped: no active connection target.")
            return
        }

        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        let profileID = selectedModel?.id ?? selectedModelIdentifier
        let selectedProfileName = selectedModel?.displayName ?? selectedModelIdentifier
        let runningProfileID = selectedModel.flatMap { model in
            runningModelIDs.contains(model.id) ? model.id : nil
        }
        let modelID = selectedModelIdentifier
        let targetBaseURL = baseURL
        let managedProcessID = selectedModel.flatMap { serverLifecycleCoordinator.processIdentifier(for: $0.id) }
        let chipName = systemProfilerHardwareInfo["Chip"] ?? "Apple Silicon"
        let memoryText = systemProfilerHardwareInfo["Memory"] ?? Self.formatMemoryGigabytes(Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
        let sessionRunner = benchmarkSessionRunner
        let preset = settings.benchmarkPreset
        let benchmarkModel = selectedModel
        let serverExecutablePath = benchmarkModel.map(executablePath(for:)) ?? settings.mlxServerExecutablePath
        let executionFingerprint = benchmarkModel.map {
            BenchmarkExecutionFingerprint.make(model: $0, executablePath: serverExecutablePath)
        }
        let configuration = BenchmarkRunConfiguration(
            host: host,
            port: port,
            baseURL: targetBaseURL,
            profileID: profileID,
            modelID: modelID,
            selectedProfileName: selectedProfileName,
            runningProfileID: runningProfileID,
            managedProcessID: managedProcessID,
            chipName: chipName,
            memoryText: memoryText,
            backend: benchmarkModel?.resolvedBackend ?? .mlxLM,
            serverExecutablePath: serverExecutablePath,
            includesAgentProbes: preset.includesAgentProbes
        )
        let runningMessage = Self.localizedText(
            language: settings.uiLanguage,
            english: "Running \(preset.localizedTitle(language: .english)) Benchmark...",
            japanese: "\(preset.localizedTitle(language: .japanese))ベンチマークを実行中..."
        )
        benchmarkViewState.beginBenchmark(sampleCount: preset.sampleCount, message: runningMessage)
        appendRuntimeEvent(
            category: "Benchmark",
            message: "\(preset.rawValue) benchmark started.",
            japaneseMessage: "\(preset.localizedTitle(language: .japanese))ベンチマークを開始しました。",
            modelID: modelID,
            endpoint: "\(host):\(port)"
        )
        appendLog("[benchmark] \(preset.rawValue) benchmark started: \(targetBaseURL), samples=\(preset.sampleCount)")

        benchmarkRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let outcome = await sessionRunner.run(
                configuration: configuration,
                preset: preset,
                executionFingerprint: executionFingerprint
            ) { event in
                switch event {
                case .warmUpStarted:
                    self.appendLog("[benchmark] warm-up started; this request is excluded from measured samples.")
                case let .warmUpCompleted(succeeded):
                    self.appendLog("[benchmark] warm-up \(succeeded ? "completed" : "did not complete cleanly"); measured samples will continue.")
                case let .sampleStarted(index, _):
                    self.benchmarkViewState.beginBenchmarkSample(index: index)
                case let .sampleCompleted(index, total, result):
                    self.benchmarkViewState.recordBenchmarkSample(result)
                    self.appendLog("[benchmark] sample \(index)/\(total) \(result.phase.rawValue.lowercased()): \(result.message)")
                }
            }

            guard self.benchmarkRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            guard let session = outcome.session,
                  let benchmarkResult = outcome.representativeResult else {
                let cancellationMessage = Self.localizedText(
                    language: self.settings.uiLanguage,
                    english: "Benchmark was cancelled before a sample completed.",
                    japanese: "測定が完了する前にベンチマークがキャンセルされました。"
                )
                self.benchmarkViewState.cancelBenchmark(message: cancellationMessage)
                return
            }

            let elapsedMS = outcome.elapsedMilliseconds
            let completionMessage = Self.benchmarkSessionSummary(
                session,
                language: self.settings.uiLanguage
            )
            self.benchmarkViewState.recordBenchmarkCompletion(
                result: benchmarkResult,
                session: session,
                durationMS: elapsedMS,
                message: completionMessage
            )
            self.savePersistedBenchmarkResults()
            self.appendRuntimeEvent(
                category: "Benchmark",
                severity: benchmarkResult.phase == .success ? .success : .failure,
                message: Self.benchmarkSessionSummary(session, language: .english),
                japaneseMessage: Self.benchmarkSessionSummary(session, language: .japanese),
                modelID: modelID,
                endpoint: "\(host):\(port)"
            )
            self.appendLog("[benchmark] \(preset.rawValue) benchmark completed in \(Int(elapsedMS)) ms: \(completionMessage)")
            self.benchmarkViewState.endBenchmark()
        }
    }

    func runAgenticBenchmarkRequested() {
        guard canRunAgenticBenchmark else {
            appendLog("[agent-readiness] skipped: \(agenticBenchmarkDisabledReason)")
            return
        }

        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        let profileID = selectedModel?.id ?? selectedModelIdentifier
        let selectedProfileName = selectedModel?.displayName ?? selectedModelIdentifier
        let modelID = selectedModelIdentifier
        let targetBaseURL = baseURL
        let service = agenticBenchmarkService

        benchmarkViewState.beginAgenticBenchmark()
        appendRuntimeEvent(
            category: "Benchmark",
            message: "Agent Readiness started.",
            japaneseMessage: "Agent Readinessを開始しました。",
            modelID: modelID,
            endpoint: "\(host):\(port)"
        )
        appendLog("[agent-readiness] started: \(targetBaseURL)")

        agenticBenchmarkRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let startedAt = Date()
            let configuration = AgenticBenchmarkRunConfiguration(
                host: host,
                port: port,
                baseURL: targetBaseURL,
                profileID: profileID,
                modelID: modelID,
                selectedProfileName: selectedProfileName
            )
            let result = await service.run(configuration: configuration)
            guard self.agenticBenchmarkRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            let elapsedMS = Date().timeIntervalSince(startedAt) * 1000
            self.benchmarkViewState.recordAgenticBenchmarkCompletion(result)
            self.savePersistedBenchmarkResults()
            self.appendRuntimeEvent(
                category: "Benchmark",
                severity: result.phase == .success ? .success : .failure,
                message: result.localizedSummary(language: .english),
                japaneseMessage: result.localizedSummary(language: .japanese),
                modelID: modelID,
                endpoint: "\(host):\(port)"
            )
            self.appendLog("[agent-readiness] \(result.phase.rawValue.lowercased()) in \(Int(elapsedMS)) ms: \(result.message)")
            self.benchmarkViewState.endAgenticBenchmark()
        }
    }
}
