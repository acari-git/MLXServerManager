import Foundation

extension AppViewModel {
    func copyBaseURL() {
        copyToPasteboard(baseURL)
        appendLog("[ui] Copied Base URL.")
    }

    func copyModelID() {
        copyToPasteboard(selectedModelIdentifier)
        appendLog("[ui] Copied Model ID.")
    }

    func copyConfig() {
        copyToPasteboard(copyableConfig)
        appendLog("[ui] Copied OpenAI-compatible config.")
    }

    func copyAPIKeyPlaceholder() {
        copyToPasteboard(apiKeyPlaceholder)
        appendLog("[ui] Copied API key placeholder.")
    }

    func copyAllConnectionSettings() {
        copyToPasteboard(allConnectionSettingsText)
        appendLog("[ui] Copied all connection settings.")
    }

    func copyHermesAgentConfig() {
        copyToPasteboard(hermesAgentConfigText)
        appendLog("[ui] Copied Hermes Agent connection config.")
    }

    @discardableResult
    func applyHermesAgentConfigRequested() -> Bool {
        guard canApplyHermesAgentConfig else {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Select a model and configure the Hermes Agent config file path first.",
                japanese: "先にモデルを選択し、Hermes Agent設定ファイルのパスを設定してください。"
            )
            appendLog("[hermes] apply skipped: missing selected model or config path.")
            return false
        }

        let connection = HermesAgentConnectionSettings(
            baseURL: baseURL,
            modelID: selectedModelIdentifier,
            apiKey: apiKeyPlaceholder
        )

        do {
            let result = try hermesAgentConfigService.apply(
                connection: connection,
                configPath: hermesAgentConfigPathText
            )
            if result.didChange {
                let backupPath = result.backupURL.map { ModelAvailabilityPathFormatter.compact(path: $0.path) } ?? "-"
                hermesAgentConfigMessage = Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Applied to Hermes Agent config. Backup: \(backupPath)",
                    japanese: "Hermes Agent設定へ反映しました。バックアップ: \(backupPath)"
                )
                appendLog("[hermes] applied selected model connection to \(ModelAvailabilityPathFormatter.compact(path: result.configURL.path)). Backup: \(backupPath). Keys: \(result.changedKeys.joined(separator: ", "))")
            } else {
                hermesAgentConfigMessage = Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Hermes Agent config already matches the selected model.",
                    japanese: "Hermes Agent設定はすでに選択モデルと一致しています。"
                )
                appendLog("[hermes] config already matched selected model connection.")
            }
            return true
        } catch {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not apply Hermes Agent config: \(error.localizedDescription)",
                japanese: "Hermes Agent設定を反映できませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] apply failed: \(error.localizedDescription)")
            return false
        }
    }

    func copyModelsCurl() {
        copyToPasteboard(modelsCurlCommand)
        appendLog("[ui] Copied OpenAI-compatible curl /v1/models command.")
    }

    func copyBenchmarkSummary() {
        copyToPasteboard(benchmarkCopyText)
        appendLog("[benchmark] copied benchmark history summary.")
    }

    func copyLatestBenchmark() {
        copyToPasteboard(latestBenchmarkCopyText)
        appendLog("[benchmark] copied latest benchmark.")
    }

    func copyBenchmark(for model: ModelConfig) {
        guard let result = benchmarkResult(for: model) else {
            copyToPasteboard(Self.localizedText(language: settings.uiLanguage, english: "No benchmark result for this model.", japanese: "このモデルのベンチマーク結果はありません。"))
            appendLog("[benchmark] no benchmark result to copy for \(model.id).")
            return
        }
        let title = Self.localizedText(language: settings.uiLanguage, english: "Benchmark", japanese: "ベンチマーク")
        if let session = benchmarkSession(for: model) {
            let sampleTitle = Self.localizedText(language: settings.uiLanguage, english: "Sample", japanese: "測定")
            let sampleDetails = session.samples.enumerated().map { index, sample in
                "\(sampleTitle) \(index + 1)/\(session.samples.count)\n\(sample.localizedDetailedText(language: settings.uiLanguage))"
            }.joined(separator: "\n\n")
            copyToPasteboard(
                "\(title)\n\(Self.benchmarkSessionSummary(session, language: settings.uiLanguage))\n\n\(sampleDetails)"
            )
        } else {
            copyToPasteboard("\(title)\n\(result.localizedDetailedText(language: settings.uiLanguage))")
        }
        appendLog("[benchmark] copied benchmark for \(model.id).")
    }

    func copyLatestAgenticBenchmark() {
        copyToPasteboard(latestAgenticBenchmarkCopyText)
        appendLog("[agent-readiness] copied latest agent readiness.")
    }

    func copyAgenticBenchmark(for model: ModelConfig) {
        guard let result = agenticBenchmarkResult(for: model) else {
            copyToPasteboard(Self.localizedText(language: settings.uiLanguage, english: "No Agent Readiness result for this model.", japanese: "このモデルのAgent Readiness結果はありません。"))
            appendLog("[agent-readiness] no result to copy for \(model.id).")
            return
        }
        copyToPasteboard("Agent Readiness\n\(result.localizedDetailedText(language: settings.uiLanguage))")
        appendLog("[agent-readiness] copied result for \(model.id).")
    }

    func copyBenchmarkTroubleshooting() {
        copyToPasteboard(benchmarkTroubleshootingCopyText)
        appendLog("[benchmark] copied troubleshooting context.")
    }

    func copySafetySummary() {
        copyToPasteboard(copyableSafetySummary)
        appendLog("[safety] copied model operations safety summary.")
    }

    var copyableTroubleshootingSummary: String {
        let recentLogs = visibleLogEntries.suffix(20).map { $0.line }.joined(separator: "\n")
        return [
            Self.localizedText(language: settings.uiLanguage, english: "MLX Server Manager Troubleshooting Summary", japanese: "MLX Server Manager トラブルシューティング概要"),
            Self.localizedText(
                language: settings.uiLanguage,
                english: "Runtime: \(runtimeState.localizedTitle(language: .english))",
                japanese: "ランタイム: \(runtimeState.localizedTitle(language: .japanese))"
            ),
            Self.localizedText(language: settings.uiLanguage, english: "Target: \(connectionTargetSummary.baseURL)", japanese: "接続先: \(connectionTargetSummary.baseURL)"),
            Self.localizedText(language: settings.uiLanguage, english: "Selected model: \(selectedModelIdentifier)", japanese: "選択モデル: \(selectedModelIdentifier)"),
            Self.localizedText(
                language: settings.uiLanguage,
                english: "Recovery: \(currentRecoveryIssue.localizedTitle(language: .english)) / \(currentRecoveryIssue.localizedDetail(language: .english))",
                japanese: "復旧: \(currentRecoveryIssue.localizedTitle(language: .japanese)) / \(currentRecoveryIssue.localizedDetail(language: .japanese))"
            ),
            Self.localizedText(language: settings.uiLanguage, english: "Safety:", japanese: "安全性:"),
            copyableSafetySummary,
            Self.localizedText(language: settings.uiLanguage, english: "Recent logs:", japanese: "最近のログ:"),
            recentLogs.isEmpty
                ? Self.localizedText(language: settings.uiLanguage, english: "No logs", japanese: "ログなし")
                : recentLogs
        ].joined(separator: "\n")
    }

    func copyTroubleshootingSummary() {
        copyToPasteboard(copyableTroubleshootingSummary)
        appendLog("[recovery] copied troubleshooting summary.")
    }

    func refreshIntegratedSafetyRequested() {
        resetModelAvailabilityForCurrentSelection()
        checkPortRequested()
        appendLog("[safety] refreshed selected model safety state.")
    }

    func performRecoveryAction(_ action: RecoveryAction) {
        switch action.kind {
        case .openSettings, .openModels, .openDownloads, .openLogs:
            appendLog("[recovery] navigation requested: \(action.title)")
        case .editProfile:
            editProfileRequested()
        case .checkPort:
            checkPortRequested()
        case .runDiagnostics:
            runDiagnosticsRequested()
        case .runReadyCheck:
            checkReadyRequested()
        case .retryDownload, .retryProfileRegistration:
            if let entryID = action.downloadQueueEntryID {
                retryHuggingFaceDownload(id: entryID)
            }
        case .restoreDownloadForm:
            if let entryID = action.downloadQueueEntryID,
               let entry = huggingFaceDownloadQueue.first(where: { $0.id == entryID }) {
                restoreHuggingFaceDownloadForm(from: entry)
            }
        case .copyURL:
            if let entryID = action.downloadQueueEntryID,
               let entry = huggingFaceDownloadQueue.first(where: { $0.id == entryID }) {
                copyHuggingFaceDownloadURL(from: entry)
            }
        case .copyTroubleshooting:
            copyTroubleshootingSummary()
        case .copySafety:
            copySafetySummary()
        }
    }

    func copyChatCompletionsCurl() {
        copyToPasteboard(chatCompletionsCurlCommand)
        appendLog("[ui] Copied OpenAI-compatible curl /v1/chat/completions command.")
    }

    func copySelectedLaunchCommandPreview() {
        copyLaunchCommandPreview(selectedLaunchCommandPreview)
    }

    func copyModelID(for model: ModelConfig) {
        if copyToPasteboard(model.modelID) {
            appendLog("[profile] copied model id for \(model.displayName).")
        } else {
            appendLog("[profile] failed to copy model id for \(model.displayName).")
        }
    }

    func copyBaseURL(for model: ModelConfig) {
        let baseURL = "http://\(model.host):\(model.serverPort)/v1"
        if copyToPasteboard(baseURL) {
            appendLog("[profile] copied base URL for \(model.displayName).")
        } else {
            appendLog("[profile] failed to copy base URL for \(model.displayName).")
        }
    }

    func copyLocalPath(for model: ModelConfig) {
        guard let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
            appendLog("[profile] local path is not available for \(model.displayName).")
            return
        }

        if copyToPasteboard(localPath) {
            appendLog("[profile] copied local path for \(model.displayName).")
        } else {
            appendLog("[profile] failed to copy local path for \(model.displayName).")
        }
    }

    func copyLaunchCommandPreview(for model: ModelConfig) {
        copyLaunchCommandPreview(launchCommandPreview(for: model))
    }

    func launchCommandPreview(for model: ModelConfig) -> String {
        LaunchCommandBuilder.command(
            executablePath: executablePath(for: model),
            model: model
        )
    }

    func copyLaunchCommandPreview(_ preview: String) {
        if copyToPasteboard(preview) {
            appendLog("[profile] copied launch command preview to clipboard.")
        } else {
            appendLog("[profile] failed to copy launch command preview.")
        }
    }

    func clearLogsRequested() {
        logViewState = logStateCoordinator.clear(replacementLine: "[info] logs cleared")
    }

    func copyLogsRequested() {
        guard !logStateCoordinator.isEmpty else {
            appendLog("[warning] No logs to copy.")
            return
        }

        if copyToPasteboard(logStateCoordinator.text) {
            appendLog("[info] copied logs to clipboard")
        } else {
            appendLog("[error] failed to copy logs to clipboard")
        }
    }

    func copyDiagnosticsSummaryRequested() {
        guard diagnosticsDidRun, !diagnosticsResults.isEmpty else {
            appendLog("[warning] No diagnostics results to copy.")
            return
        }

        if copyToPasteboard(diagnosticsSummaryCopyText()) {
            appendLog("[info] copied diagnostics summary to clipboard")
        } else {
            appendLog("[error] failed to copy diagnostics summary to clipboard")
        }
    }

    func adoptExternalServerRequested() {
        guard case let .externalServerDetected(host, port, baseURL, _) = runtimeState else {
            appendLog("[external] adopt unavailable: no detected external server.")
            return
        }

        if let selectedModelID {
            stopMemoryMonitoring(for: selectedModelID)
            clearRunningModel(modelID: selectedModelID, logPrefix: "external")
        }
        runtimeState = .adoptedExternalServer(
            host: host,
            port: port,
            baseURL: baseURL,
            message: "This server is adopted for connection context only."
        )
        appendLog("[external] adopted external server for connection context: \(baseURL)")
        appendLog("[external] not managed by MLX Server Manager. Stop and Restart remain unavailable.")
    }

    func forgetExternalServerRequested() {
        guard runtimeState.isAdoptedExternalServer else {
            appendLog("[external] forget unavailable: no adopted external server.")
            return
        }

        appendLog("[external] forgot adopted external server. External process was not modified.")

        if let selectedModelID,
           let processIdentifier = serverLifecycleCoordinator.processIdentifier(for: selectedModelID) {
            let endpoint = endpointForCurrentRuntimeState()
            runtimeState = .ready(
                host: endpoint.host,
                port: endpoint.port,
                processIdentifier: processIdentifier
            )
        } else {
            runtimeState = .stopped
        }
    }

    var connectionConfigBuilder: ConnectionConfigBuilder {
        ConnectionConfigBuilder(
            scheme: "http",
            host: selectedModel?.host ?? settings.defaultHost,
            port: selectedModel?.serverPort ?? settings.defaultPort,
            apiBasePath: "/v1",
            apiKeyPlaceholder: settings.apiKeyPlaceholder
        )
    }
}
