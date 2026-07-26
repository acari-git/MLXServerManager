import AppKit
import Foundation
import UniformTypeIdentifiers

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

    func selectHermesAgentMessage(_ message: HermesAgentSessionMessage) {
        selectedHermesAgentMessageID = message.id
    }

    func copyHermesAgentMessageContent(_ message: HermesAgentSessionMessage) {
        copyToPasteboard(hermesAgentTranscriptContent(message))
        appendLog("[hermes] copied transcript content for message \(message.id).")
    }

    func copyHermesAgentMessageDetails(_ message: HermesAgentSessionMessage) {
        copyToPasteboard(hermesAgentTranscriptCopyText(message))
        appendLog("[hermes] copied transcript details for message \(message.id).")
    }

    func exportHermesAgentTranscriptRequested() {
        guard let session = selectedHermesAgentSession else {
            hermesAgentTranscriptExportMessage = Self.localizedText(language: settings.uiLanguage, english: "No Hermes Agent session is selected.", japanese: "Hermes Agentセッションが選択されていません。")
            return
        }
        guard !sortedHermesAgentSessionMessages.isEmpty else {
            hermesAgentTranscriptExportMessage = Self.localizedText(language: settings.uiLanguage, english: "No transcript items match the current filters.", japanese: "現在のフィルターに該当するトランスクリプトがありません。")
            return
        }

        let panel = NSSavePanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Export Hermes Agent Transcript", japanese: "Hermes Agentトランスクリプトを書き出し")
        let safeTitle = (session.title?.isEmpty == false ? session.title! : session.id)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "\(safeTitle).\(hermesAgentTranscriptExportFormat.fileExtension)"
        panel.canCreateDirectories = true
        let markdownType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = hermesAgentTranscriptExportFormat == .markdown ? [markdownType] : [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            hermesAgentTranscriptExportMessage = Self.localizedText(language: settings.uiLanguage, english: "Transcript export cancelled.", japanese: "トランスクリプトの書き出しをキャンセルしました。")
            return
        }

        do {
            let text = hermesAgentTranscriptExportText(format: hermesAgentTranscriptExportFormat)
            try text.write(to: url, atomically: true, encoding: .utf8)
            hermesAgentTranscriptExportMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Exported \(sortedHermesAgentSessionMessages.count) transcript item(s) to \(url.lastPathComponent).",
                japanese: "トランスクリプト\(sortedHermesAgentSessionMessages.count)件を\(url.lastPathComponent)へ書き出しました。"
            )
            appendLog("[hermes] exported filtered transcript to \(url.path).")
        } catch {
            hermesAgentTranscriptExportMessage = Self.localizedText(language: settings.uiLanguage, english: "Transcript export failed: \(error.localizedDescription)", japanese: "トランスクリプトの書き出しに失敗しました: \(error.localizedDescription)")
            appendLog("[hermes] transcript export failed: \(error.localizedDescription)")
        }
    }

    func refreshHermesAgentSessions() {
        do {
            hermesAgentSessions = try hermesAgentConfigService.listSessions(
                configPath: hermesAgentConfigPathText
            )
            if !hermesAgentSessions.contains(where: { $0.id == selectedHermesAgentSessionID }) {
                selectedHermesAgentSessionID = hermesAgentSessions.first?.id
            }
            refreshSelectedHermesAgentTranscript()
            hermesAgentSessionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Loaded \(hermesAgentSessions.count) recent Hermes Agent session(s).",
                japanese: "最近のHermes Agentセッションを\(hermesAgentSessions.count)件読み込みました。"
            )
            appendLog("[hermes] loaded \(hermesAgentSessions.count) recent session summaries from state.db.")
        } catch {
            hermesAgentSessions = []
            selectedHermesAgentSessionID = nil
            hermesAgentSessionMessages = []
            hermesAgentSessionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not load Hermes Agent sessions: \(error.localizedDescription)",
                japanese: "Hermes Agentセッションを読み込めませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] session list failed: \(error.localizedDescription)")
        }
    }

    func refreshSelectedHermesAgentTranscript() {
        resetHermesAgentTranscriptDisplayLimit()
        selectedHermesAgentMessageID = nil
        guard let session = selectedHermesAgentSession else {
            hermesAgentSessionMessages = []
            return
        }
        do {
            hermesAgentSessionMessages = try hermesAgentConfigService.listSessionMessages(
                configPath: hermesAgentConfigPathText,
                sessionID: session.id
            )
            hermesAgentSessionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Loaded \(hermesAgentSessionMessages.count) transcript item(s).",
                japanese: "トランスクリプトを\(hermesAgentSessionMessages.count)件読み込みました。"
            )
            appendLog("[hermes] loaded \(hermesAgentSessionMessages.count) transcript item(s) for \(session.id).")
        } catch {
            hermesAgentSessionMessages = []
            selectedHermesAgentMessageID = nil
            hermesAgentSessionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not load Hermes Agent transcript: \(error.localizedDescription)",
                japanese: "Hermes Agentトランスクリプトを読み込めませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] transcript load failed: \(error.localizedDescription)")
        }
    }

    func refreshHermesAgentBackups() {
        let backups = (try? hermesAgentConfigService.listBackups(
            configPath: hermesAgentConfigPathText
        )) ?? []
        hermesAgentConfigBackups = backups
        if !backups.contains(where: { $0.id == selectedHermesAgentBackupID }) {
            selectedHermesAgentBackupID = backups.first?.id
        }
    }

    @discardableResult
    func inspectHermesAgentConfigRequested() -> Bool {
        do {
            hermesAgentConfigInspection = try hermesAgentConfigService.inspect(
                configPath: hermesAgentConfigPathText
            )
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Read the current Hermes Agent model connection values.",
                japanese: "現在のHermes Agentモデル接続値を読み取りました。"
            )
            refreshHermesAgentBackups()
            appendLog("[hermes] inspected configured model connection and backup history.")
            return true
        } catch {
            hermesAgentConfigInspection = nil
            refreshHermesAgentBackups()
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not inspect Hermes Agent config: \(error.localizedDescription)",
                japanese: "Hermes Agent設定を確認できませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] inspection failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func selectHermesAgentMatchingModelRequested() -> Bool {
        guard let matchingModel = hermesAgentMatchingModel else {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "No registered profile matches the model in the Hermes Agent config.",
                japanese: "Hermes Agent設定のモデルに一致する登録済みプロファイルがありません。"
            )
            appendLog("[hermes] no registered profile matched the inspected model.")
            return false
        }

        selectedModelID = matchingModel.id
        hermesAgentConfigMessage = Self.localizedText(
            language: settings.uiLanguage,
            english: "Selected the profile referenced by the Hermes Agent config.",
            japanese: "Hermes Agent設定で参照されているプロファイルを選択しました。"
        )
        appendLog("[hermes] selected matching profile \(matchingModel.id).")
        return true
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
            hermesAgentConfigInspection = try? hermesAgentConfigService.inspect(
                configPath: hermesAgentConfigPathText
            )
            refreshHermesAgentBackups()
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
