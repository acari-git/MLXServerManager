import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

private enum ProfileValidationResult {
    case valid(ModelConfig)
    case invalid(String)
}

private enum AdvancedLaunchOptionsValidationResult {
    case valid(AdvancedLaunchOptions?)
    case invalid(String)
}

struct ModelProfileImportSelectionUpdate: Equatable {
    let selectedModelID: ModelConfig.ID?
    let preservedThroughReplacement: Bool

    static func preservingSelection(
        previousSelectedModelID: ModelConfig.ID?,
        nextModels: [ModelConfig],
        replacedProfiles: [ImportReplacedProfileSummary]
    ) -> ModelProfileImportSelectionUpdate {
        guard let previousSelectedModelID,
              !nextModels.contains(where: { $0.id == previousSelectedModelID }),
              let replacement = replacedProfiles.first(where: { $0.previousModelID == previousSelectedModelID }) else {
            return ModelProfileImportSelectionUpdate(
                selectedModelID: previousSelectedModelID,
                preservedThroughReplacement: false
            )
        }

        return ModelProfileImportSelectionUpdate(
            selectedModelID: replacement.replacementModelID,
            preservedThroughReplacement: true
        )
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: AppSettings = .defaults
    @Published var models: [ModelConfig] = ModelConfig.defaults
    @Published var selectedModelID: ModelConfig.ID? {
        didSet {
            handleSelectedModelChange(from: oldValue)
        }
    }
    @Published private(set) var runningModelID: ModelConfig.ID?
    @Published private(set) var runtimeState: ModelRuntimeState = .stopped
    @Published private(set) var memoryUsageGB: Double?
    @Published private(set) var logText: String
    @Published private(set) var logEntries: [LogEntry]
    @Published private(set) var diagnosticsResults: [DiagnosticsResult] = []
    @Published private(set) var diagnosticsDidRun = false
    @Published private var selectedModelAvailabilitySummary: ModelAvailabilitySummary = .noSelection
    @Published var profileEditorDraft: ModelProfileDraft = .empty
    @Published private(set) var isProfileEditorPresented = false
    @Published private(set) var profileEditorMessage: String?
    @Published var addProfileDraft: ModelProfileDraft = .empty
    @Published private(set) var isAddProfilePresented = false
    @Published private(set) var addProfileMessage: String?
    @Published var isDeleteProfileConfirmationPresented = false
    @Published private(set) var profileDeletionMessage: String?
    @Published private(set) var modelProfileExportMessage: String?
    @Published private(set) var modelProfileImportMessage: String?
    @Published var isImportPreviewPresented = false
    @Published private(set) var importPreviewResult: ImportPreviewResult?
    @Published var huggingFaceDownloadDraft: HuggingFaceDownloadDraft = .defaults(
        defaultHost: AppSettings.defaults.defaultHost,
        defaultPort: AppSettings.defaults.defaultPort
    )
    @Published private(set) var huggingFaceDownloadStatus: HuggingFaceDownloadStatus = .waiting
    @Published private(set) var huggingFaceDownloadQueue: [HuggingFaceDownloadQueueEntry] = []
    @Published private(set) var isHuggingFaceCLIAvailable = false
    @Published private(set) var huggingFaceCLIPath = "Not checked"
    @Published private(set) var huggingFaceCLIMessage = "Check Hugging Face CLI before downloading."
    @Published var localModelPath = ""
    @Published var localModelDisplayName = ""
    @Published var localModelPortText = String(AppSettings.defaults.defaultPort)
    @Published var localModelEnableThinking = false
    @Published private(set) var localModelMessage = "Paste an existing local model folder path, then add it to the model list."
    @Published var huggingFaceSearchQuery = ""
    @Published var showOnlyMLXLikelySearchResults = false
    @Published private(set) var huggingFaceSearchMessage = "Search Hugging Face explicitly, then choose a result for the download form."
    @Published private(set) var huggingFaceSearchResults: [HuggingFaceSearchResult] = []
    @Published private(set) var selectedHuggingFaceSearchResult: HuggingFaceSearchResult?
    @Published private(set) var isHuggingFaceSearching = false

    private let settingsStore: SettingsStore
    private let portChecker: PortChecker
    private let readyChecker: ReadyChecker
    private let processManager: ModelProcessManager
    private let memoryMonitor: MemoryMonitor
    private let setupDiagnostics: SetupDiagnostics
    private let modelProfileExportService: ModelProfileExportService
    private let modelProfileImportPreviewService: ModelProfileImportPreviewService
    private let modelAvailabilityChecker: LocalModelAvailabilityChecking
    private let huggingFaceDownloadManager: HuggingFaceModelDownloading
    private let huggingFaceSearchService: HuggingFaceModelSearching
    private var logBuffer: LogBuffer
    private var memoryMonitorTask: Task<Void, Never>?
    private var huggingFaceDownloadTask: Task<Void, Never>?
    private var huggingFaceDownloadCancellationRequested = false
    private var pendingDeleteModelID: ModelConfig.ID?

    private static let initialLogLines = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Start, Stop, and Restart are available.",
        "[info] Memory monitoring starts after managed process launch."
    ]

    init(
        settingsStore: SettingsStore? = nil,
        portChecker: PortChecker? = nil,
        readyChecker: ReadyChecker? = nil,
        processManager: ModelProcessManager? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        setupDiagnostics: SetupDiagnostics? = nil,
        modelProfileExportService: ModelProfileExportService? = nil,
        modelProfileImportPreviewService: ModelProfileImportPreviewService? = nil,
        modelAvailabilityChecker: LocalModelAvailabilityChecking? = nil,
        huggingFaceDownloadManager: HuggingFaceModelDownloading? = nil,
        huggingFaceSearchService: HuggingFaceModelSearching? = nil
    ) {
        self.settingsStore = settingsStore ?? SettingsStore()
        self.portChecker = portChecker ?? PortChecker()
        self.readyChecker = readyChecker ?? ReadyChecker()
        self.processManager = processManager ?? ModelProcessManager()
        self.memoryMonitor = memoryMonitor ?? MemoryMonitor()
        self.setupDiagnostics = setupDiagnostics ?? SetupDiagnostics(
            settingsStore: self.settingsStore,
            portChecker: self.portChecker,
            readyChecker: self.readyChecker
        )
        self.modelProfileExportService = modelProfileExportService ?? ModelProfileExportService()
        self.modelProfileImportPreviewService = modelProfileImportPreviewService ?? ModelProfileImportPreviewService()
        self.modelAvailabilityChecker = modelAvailabilityChecker ?? FileSystemLocalModelAvailabilityChecker()
        self.huggingFaceDownloadManager = huggingFaceDownloadManager ?? HuggingFaceDownloadManager()
        self.huggingFaceSearchService = huggingFaceSearchService ?? HuggingFaceSearchService()
        self.logBuffer = LogBuffer(initialLines: Self.initialLogLines)
        self.logText = logBuffer.text
        self.logEntries = logBuffer.entries
        loadSettings()
        huggingFaceDownloadDraft = .defaults(
            defaultHost: settings.defaultHost,
            defaultPort: settings.defaultPort
        )
        refreshHuggingFaceCLIStatus(logResult: false)
        localModelPortText = String(settings.defaultPort)
        selectedModelID = models.first?.id
        resetModelAvailabilityForCurrentSelection()
    }

    var selectedModel: ModelConfig? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    var huggingFaceDownloadPreview: HuggingFaceDownloadPreview {
        HuggingFaceDownloadPreview.make(draft: huggingFaceDownloadDraft)
    }

    var isHuggingFaceDownloadRunning: Bool {
        huggingFaceDownloadTask != nil
    }

    var canStartHuggingFaceDownload: Bool {
        huggingFaceDownloadPreview.canDownload && isHuggingFaceCLIAvailable && !isHuggingFaceDownloadRunning
    }

    var visibleHuggingFaceSearchResults: [HuggingFaceSearchResult] {
        showOnlyMLXLikelySearchResults
            ? huggingFaceSearchResults.filter(\.isMLXLikely)
            : huggingFaceSearchResults
    }

    var modelAvailabilitySummary: ModelAvailabilitySummary {
        if runtimeState.isExternalServerContext {
            return ModelAvailabilitySummary.external(for: selectedModel)
        }

        return selectedModelAvailabilitySummary
    }

    var baseURL: String {
        connectionConfigBuilder.baseURL
    }

    var connectionTargetSummary: ConnectionTargetSummary {
        let targetType: String
        let ownershipNote: String
        let readinessSummary: String
        let isActiveTarget: Bool

        switch runtimeState {
        case .externalServerDetected:
            targetType = "External Server Detected"
            ownershipNote = "External server detected. Not managed by MLX Server Manager."
            readinessSummary = "Ready via /v1/models"
            isActiveTarget = true
        case .adoptedExternalServer:
            targetType = "Adopted External Server"
            ownershipNote = "Connection context only. Not managed by MLX Server Manager."
            readinessSummary = "Ready via /v1/models"
            isActiveTarget = true
        default:
            if isManagedProcessRunning {
                targetType = "Managed Server"
                ownershipNote = "Managed by MLX Server Manager"
                readinessSummary = managedReadinessSummary
                isActiveTarget = true
            } else {
                targetType = "Not Running / Not Connected"
                ownershipNote = "No active connection target."
                readinessSummary = "Not currently running"
                isActiveTarget = false
            }
        }

        return ConnectionTargetSummary(
            targetType: targetType,
            baseURL: baseURL,
            modelID: selectedModelIdentifier,
            apiKeyPlaceholder: apiKeyPlaceholder,
            readinessSummary: readinessSummary,
            ownershipNote: ownershipNote,
            directModeNote: "OpenAI-compatible client -> server -> MLX model",
            isActiveTarget: isActiveTarget
        )
    }

    var onboardingGuidance: OnboardingGuidance {
        let executablePathMissing = settings.mlxServerExecutablePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let modelIDMissing = selectedModel?.modelID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true

        switch runtimeState {
        case .externalServerDetected:
            return OnboardingGuidance(
                title: "External Server Detected",
                tone: .warning,
                messages: [
                    "A compatible external server was detected.",
                    "Adopt it as connection context, or leave it unmanaged.",
                    "Stop and Restart do not apply to external servers."
                ],
                actionHints: [
                    "Adopt External Server if you want connection context.",
                    "Use Connection Settings to copy client values."
                ]
            )
        case .adoptedExternalServer:
            return OnboardingGuidance(
                title: "Adopted External Server",
                tone: .warning,
                messages: [
                    "This server is adopted as connection context only.",
                    "It is not managed by MLX Server Manager.",
                    "Forget removes app-side context only."
                ],
                actionHints: [
                    "Copy Base URL, Model ID, and API key placeholder.",
                    "Use Forget External Server when this context is no longer needed."
                ]
            )
        default:
            if isManagedProcessRunning {
                return OnboardingGuidance(
                    title: "Managed Server Running",
                    tone: .ready,
                    messages: [
                        "Use Connection Settings to copy Base URL, Model ID, and local API key placeholder.",
                        "Ready and diagnostics use /v1/models.",
                        "Stop and Restart apply only to this managed process."
                    ],
                    actionHints: [
                        "Copy connection settings.",
                        "Paste them into an OpenAI-compatible client."
                    ]
                )
            }

            if executablePathMissing || modelIDMissing {
                var messages: [String] = []
                var hints: [String] = []

                if executablePathMissing {
                    messages.append("Set the mlx_lm.server executable path to start a managed server.")
                    hints.append("Set executable path")
                }

                if modelIDMissing {
                    messages.append("Add or select a model profile before starting a managed server.")
                    hints.append("Select model profile")
                }

                messages.append("Run Diagnostics before Start when setup is ready.")
                hints.append("Run Diagnostics")

                return OnboardingGuidance(
                    title: "Setup Needed",
                    tone: .setup,
                    messages: messages,
                    actionHints: hints
                )
            }

            return OnboardingGuidance(
                title: "Not Running / Not Connected",
                tone: .neutral,
                messages: [
                    "Start a managed server, or connect to an already-running OpenAI-compatible server on the selected host and port.",
                    "Use Diagnostics if setup or readiness is unclear."
                ],
                actionHints: [
                    "Start server",
                    "Or connect to an external server",
                    "Copy connection settings after ready"
                ]
            )
        }
    }

    var selectedModelIdentifier: String {
        selectedModel?.modelID ?? "No model selected"
    }

    var selectedModelText: String {
        "Selected Model: \(selectedModelIdentifier)"
    }

    var runningModelText: String {
        guard let runningModelID else {
            return "Running Model: Not running"
        }

        return "Running Model: \(runningModelID)"
    }

    var restartRequired: Bool {
        guard isManagedProcessRunning,
              let runningModelID,
              let selectedModelID = selectedModel?.id else {
            return false
        }

        return selectedModelID != runningModelID
    }

    var apiKeyPlaceholder: String {
        settings.apiKeyPlaceholder
    }

    var modelProfileExportSummaryText: String {
        let advancedCount = models.filter { $0.advancedLaunchOptions?.normalized() != nil }.count
        let advancedText = advancedCount == 0
            ? "Advanced Launch Options: not included"
            : "Advanced Launch Options: included for \(advancedCount) profile(s)"

        return "\(models.count) profile(s). \(advancedText). Export does not start or stop servers."
    }

    var memoryUsageText: String {
        if runtimeState.isExternalServerContext {
            return "Memory: Not available for external server"
        }

        guard let memoryUsageGB else {
            return "Memory: Not running"
        }

        return String(format: "Memory: %.2f GB", memoryUsageGB)
    }

    private var managedReadinessSummary: String {
        switch runtimeState {
        case .ready:
            "Ready via /v1/models"
        case .starting, .loading:
            "Starting"
        case .checkingReady:
            "Checking /v1/models"
        case .readyCheckFailed:
            "Ready check failed"
        case .stopping:
            "Stopping"
        default:
            "Managed process active"
        }
    }

    var copyableConfig: String {
        connectionConfigBuilder.configText(modelID: selectedModelIdentifier)
    }

    var modelsCurlCommand: String {
        connectionConfigBuilder.modelsCurlCommand()
    }

    var chatCompletionsCurlCommand: String {
        connectionConfigBuilder.chatCompletionsCurlCommand(modelID: selectedModelIdentifier)
    }

    var allConnectionSettingsText: String {
        connectionConfigBuilder.allConnectionSettingsText(summary: connectionTargetSummary)
    }

    var hermesAgentConfigText: String {
        connectionConfigBuilder.hermesAgentConfigText(summary: connectionTargetSummary)
    }

    var settingsDirectoryPath: String {
        do {
            return try settingsStore.settingsDirectoryURL.path
        } catch {
            return "Application Support directory unavailable"
        }
    }

    var diagnosticsSummaryText: String {
        guard diagnosticsDidRun else {
            return "Not run"
        }

        let passCount = diagnosticsResults.filter { $0.status == .pass }.count
        let failureCount = diagnosticsResults.filter { $0.status == .fail }.count
        let warningCount = diagnosticsResults.filter { $0.status == .warning }.count
        return "\(passCount) pass(es), \(warningCount) warning(s), \(failureCount) failure(s)"
    }

    var menuBarTitle: String {
        if restartRequired {
            return "MLX: \(runtimeState.menuBarStatus) - restart required"
        }

        return "MLX: \(runtimeState.menuBarStatus)"
    }

    var isManagedProcessRunning: Bool {
        processManager.managedProcessIdentifier != nil
    }

    var isExternalServerDetected: Bool {
        runtimeState.isExternalServerDetected
    }

    var isAdoptedExternalServer: Bool {
        runtimeState.isAdoptedExternalServer
    }

    var canStopManagedServer: Bool {
        processManager.managedProcessIdentifier != nil
    }

    var canRestartManagedServer: Bool {
        processManager.managedProcessIdentifier != nil && !runtimeState.isExternalServerContext
    }

    var canAdoptExternalServer: Bool {
        runtimeState.isExternalServerDetected
    }

    var canForgetExternalServer: Bool {
        runtimeState.isAdoptedExternalServer
    }

    func startRequested() {
        Task {
            _ = await startManagedServer(logPrefix: "start")
        }
    }

    func stopRequested() {
        guard let processIdentifier = processManager.managedProcessIdentifier else {
            clearRunningModel(logPrefix: "stop")
            if runtimeState.isExternalServerContext {
                appendLog("[stop] managed process is not running. External servers are not stopped by this app.")
            } else {
                runtimeState = .stopped
                appendLog("[stop] managed process is not running.")
            }
            return
        }

        let endpoint = endpointForCurrentRuntimeState()
        runtimeState = .stopping(processIdentifier: processIdentifier)
        appendLog("[stop] requested for managed pid \(processIdentifier)")

        Task {
            let result = await processManager.stop()
            _ = await handleStopResult(result, host: endpoint.host, port: endpoint.port)
        }
    }

    func restartRequested() {
        guard !runtimeState.isExternalServerContext else {
            appendLog("[restart] unavailable for external servers. Start a managed server only after the port is available.")
            return
        }

        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[restart] failed: \(message)")
            return
        }

        let endpoint = endpointForCurrentRuntimeState()
        appendLog("[restart] requested for \(selectedModel.modelID) at \(selectedModel.host):\(selectedModel.serverPort)")

        Task {
            if let processIdentifier = processManager.managedProcessIdentifier {
                runtimeState = .stopping(processIdentifier: processIdentifier)
                appendLog("[restart] stopping managed pid \(processIdentifier)")

                let stopResult = await processManager.stop()
                let didStop = await handleStopResult(
                    stopResult,
                    host: endpoint.host,
                    port: endpoint.port,
                    logPrefix: "restart"
                )

                guard didStop else {
                    appendLog("[restart] cancelled because stop did not complete cleanly.")
                    return
                }
            } else {
                appendLog("[restart] managed process is not running. Starting a new managed server.")
            }

            let didStart = await startManagedServer(logPrefix: "restart")
            if didStart {
                appendLog("[restart] completed.")
            }
        }
    }

    func checkPortRequested() {
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        runtimeState = .checkingPort(host: host, port: port)

        switch portChecker.check(host: host, port: port) {
        case let .available(host, port):
            runtimeState = .portAvailable(host: host, port: port)
            appendLog("[port] port available: \(host):\(port)")
        case let .busy(host, port):
            runtimeState = .portBusy(host: host, port: port)
            appendLog("[port] port busy: \(host):\(port)")
        case let .invalidInput(message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[port] port check failed: \(message)")
        case let .failed(host, port, message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[port] port check failed for \(host):\(port): \(message)")
        }
    }

    func checkReadyRequested() {
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        if !runtimeState.isExternalServerContext {
            runtimeState = .checkingReady(host: host, port: port)
        }
        appendLog("[ready] checking: http://\(host):\(port)/v1/models")

        Task {
            let result = await readyChecker.check(host: host, port: port)
            handleReadyCheckResult(result, fallbackHost: host, fallbackPort: port)
        }
    }

    func saveSettingsRequested() {
        do {
            try settingsStore.save(settings: settings, models: models)
            appendLog("[settings] Saved settings.json and models.json to \(settingsDirectoryPath).")
        } catch {
            appendLog("[settings] Failed to save settings: \(error.localizedDescription)")
        }
    }

    func startHuggingFaceDownloadRequested() {
        refreshHuggingFaceCLIStatus(logResult: false)
        guard isHuggingFaceCLIAvailable else {
            huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
                phase: .failed,
                message: huggingFaceCLIMessage,
                repositoryID: nil,
                destinationPath: nil,
                progress: nil,
                outputLines: []
            )
            appendLog("[hf] download not started: hf CLI is not available.")
            return
        }

        let preview = huggingFaceDownloadPreview
        guard let reference = preview.reference,
              let destinationPath = preview.destinationPath else {
            huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
                phase: .failed,
                message: preview.message,
                repositoryID: nil,
                destinationPath: nil,
                progress: nil,
                outputLines: []
            )
            appendLog("[hf] download not started: \(preview.message)")
            return
        }

        guard huggingFaceDownloadTask == nil else {
            appendLog("[hf] download already running.")
            return
        }

        let displayName = preview.displayName
        let draft = huggingFaceDownloadDraft
        let queueEntryID = UUID()
        huggingFaceDownloadQueue.insert(
            HuggingFaceDownloadQueueEntry(
                id: queueEntryID,
                repositoryID: reference.repositoryID,
                destinationPath: destinationPath,
                phase: .preparing,
                message: "Preparing"
            ),
            at: 0
        )
        huggingFaceDownloadCancellationRequested = false
        huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
            phase: .preparing,
            message: "Preparing destination: \(ModelAvailabilityPathFormatter.compact(path: destinationPath))",
            repositoryID: reference.repositoryID,
            destinationPath: destinationPath,
            progress: nil,
            outputLines: []
        )
        appendLog("[hf] starting Hugging Face download for \(reference.repositoryID).")
        appendLog("[hf] destination: \(ModelAvailabilityPathFormatter.compact(path: destinationPath))")

        huggingFaceDownloadTask = Task { [weak self] in
            await self?.runHuggingFaceDownload(
                reference: reference,
                destinationPath: destinationPath,
                displayName: displayName,
                draft: draft,
                queueEntryID: queueEntryID
            )
        }
    }

    func cancelHuggingFaceDownloadRequested() {
        guard huggingFaceDownloadTask != nil else {
            appendLog("[hf] no active download to cancel.")
            return
        }

        huggingFaceDownloadCancellationRequested = true
        huggingFaceDownloadStatus.phase = .cancelled
        huggingFaceDownloadStatus.message = "Cancelling download. The model will not be added."
        huggingFaceDownloadManager.cancel()
        huggingFaceDownloadTask?.cancel()
        appendLog("[hf] cancel requested.")
    }

    func resetHuggingFaceDownloadStatus() {
        guard huggingFaceDownloadTask == nil else {
            return
        }

        huggingFaceDownloadStatus = .waiting
    }

    func refreshHuggingFaceCLIRequested() {
        refreshHuggingFaceCLIStatus(logResult: true)
    }

    private func refreshHuggingFaceCLIStatus(logResult: Bool) {
        if let resolution = HuggingFaceDownloadManager.resolveCLI() {
            isHuggingFaceCLIAvailable = true
            huggingFaceCLIPath = resolution.displayPath
            huggingFaceCLIMessage = "Available"
            if logResult {
                appendLog("[hf] CLI detected at \(resolution.displayPath).")
            }
        } else {
            let candidates = HuggingFaceDownloadManager.candidateExecutablePaths()
            let checked = candidates
                .map { ModelAvailabilityPathFormatter.compact(path: $0) }
                .joined(separator: ", ")
            isHuggingFaceCLIAvailable = false
            huggingFaceCLIPath = "Not found"
            huggingFaceCLIMessage = "Install Hugging Face CLI, then press Retry CLI or restart the app."
            if logResult {
                appendLog("[hf] CLI not found. Checked: \(checked)")
            }
        }
    }

    func performHuggingFaceSearchRequested() {
        let query = huggingFaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            huggingFaceSearchResults = []
            selectedHuggingFaceSearchResult = nil
            huggingFaceSearchMessage = "Enter a search term before searching."
            appendLog("[hf] search skipped: empty query.")
            return
        }

        isHuggingFaceSearching = true
        huggingFaceSearchMessage = "Searching Hugging Face for: \(query)"
        appendLog("[hf] search started: \(query)")

        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await huggingFaceSearchService.search(query: query, limit: 10)
                huggingFaceSearchResults = results
                selectedHuggingFaceSearchResult = nil
                huggingFaceSearchMessage = results.isEmpty
                    ? "No matching models found. Try another query or paste an exact ID / URL."
                    : "Found \(results.count) models. Choose one to fill the download form."
                appendLog("[hf] search completed with \(results.count) results.")
            } catch {
                huggingFaceSearchResults = []
                selectedHuggingFaceSearchResult = nil
                huggingFaceSearchMessage = error.localizedDescription
                appendLog("[hf] search failed: \(error.localizedDescription)")
            }
            isHuggingFaceSearching = false
        }
    }

    func selectHuggingFaceSearchResult(_ result: HuggingFaceSearchResult) {
        selectedHuggingFaceSearchResult = result
        huggingFaceDownloadDraft.source = result.id
        if huggingFaceDownloadDraft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            huggingFaceDownloadDraft.displayName = result.name
        }
        huggingFaceSearchMessage = result.selectionWarning
        appendLog("[hf] search result selected for download: \(result.id) — \(result.qualitySummary)")
    }

    func copySelectedHuggingFaceModelURL() {
        guard let selectedHuggingFaceSearchResult else {
            appendLog("[hf] no selected search result URL to copy.")
            return
        }
        copyToPasteboard(selectedHuggingFaceSearchResult.webURL)
        appendLog("[hf] copied Hugging Face URL for \(selectedHuggingFaceSearchResult.id).")
    }

    func registerLocalModelRequested() {
        let trimmedPath = localModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expandedPath = HuggingFaceDownloadPlanner.expandedLocalPath(from: trimmedPath) else {
            localModelMessage = "Enter a local folder path such as ~/Models/mlx/model-name."
            appendLog("[profile] local model add failed: invalid local path.")
            return
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            localModelMessage = "Local model folder was not found."
            appendLog("[profile] local model add failed: folder not found at \(ModelAvailabilityPathFormatter.compact(path: expandedPath)).")
            return
        }

        if models.contains(where: { $0.modelID == expandedPath }) {
            selectedModelID = expandedPath
            localModelMessage = "Existing local model profile selected."
            appendLog("[profile] existing local model profile selected: \(ModelAvailabilityPathFormatter.compact(path: expandedPath)).")
            return
        }

        let displayName = localModelDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? URL(fileURLWithPath: expandedPath, isDirectory: true).lastPathComponent
            : localModelDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(localModelPortText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings.defaultPort
        let model = ModelConfig(
            modelID: expandedPath,
            displayName: displayName,
            family: "Local",
            quantization: "Existing Folder",
            localName: URL(fileURLWithPath: expandedPath, isDirectory: true).lastPathComponent,
            host: settings.defaultHost,
            serverPort: port,
            enableThinking: localModelEnableThinking,
            notes: "Registered from an existing local model folder.",
            advancedLaunchOptions: nil
        )

        let nextModels = models + [model]
        do {
            try settingsStore.save(models: nextModels)
            models = nextModels
            selectedModelID = model.id
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(
                for: model,
                result: .present(path: expandedPath)
            )
            localModelMessage = "Local model added and selected."
            appendLog("[profile] local model added: \(displayName).")
        } catch {
            localModelMessage = "Could not save local model profile: \(error.localizedDescription)"
            appendLog("[profile] local model add failed: \(error.localizedDescription)")
        }
    }

    func checkModelAvailabilityRequested() {
        guard let selectedModel else {
            selectedModelAvailabilitySummary = .noSelection
            appendLog("[availability] check skipped: no selected profile.")
            return
        }

        guard !runtimeState.isExternalServerContext else {
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.external(for: selectedModel)
            appendLog("[availability] check skipped: external targets are not managed by MLX Server Manager.")
            return
        }

        guard let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: selectedModel) else {
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.initial(
                for: selectedModel,
                isExternalTarget: false
            )
            appendLog("[availability] check skipped: selected profile uses a model identifier, not a local path.")
            return
        }

        let result = modelAvailabilityChecker.check(path: localPath)
        selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(for: selectedModel, result: result)

        switch result {
        case .present:
            appendLog("[availability] configured local path appears present for selected profile. Compatibility is not verified.")
        case .missing:
            appendLog("[availability] configured local path was not found for selected profile.")
        case let .notInspectable(message):
            appendLog("[availability] check unavailable: \(message)")
        }
    }

    func runDiagnosticsRequested() {
        let selectedModel = selectedModel
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort

        appendLog("[diagnostics] running setup diagnostics for \(host):\(port)")

        Task {
            let results = await setupDiagnostics.run(
                settings: settings,
                selectedModel: selectedModel,
                managedProcessIdentifier: processManager.managedProcessIdentifier
            )

            diagnosticsResults = results
            diagnosticsDidRun = true

            for result in results {
                appendLog(result.logLine)
            }

            let failedCount = results.filter { $0.status == .fail }.count
            let warningCount = results.filter { $0.status == .warning }.count
            appendLog("[diagnostics] completed with \(failedCount) failure(s), \(warningCount) warning(s).")
        }
    }

    func editProfileRequested() {
        guard let selectedModel else {
            profileEditorMessage = "No model is selected."
            appendLog("[profile] edit failed: No model is selected.")
            return
        }

        addProfileDraft = .empty
        addProfileMessage = nil
        isAddProfilePresented = false
        profileEditorDraft = ModelProfileDraft(model: selectedModel)
        profileEditorMessage = nil
        isProfileEditorPresented = true
        appendLog("[profile] editing \(selectedModel.modelID)")
    }

    func cancelProfileEditing() {
        profileEditorDraft = .empty
        profileEditorMessage = nil
        isProfileEditorPresented = false
        appendLog("[profile] edit cancelled.")
    }

    func addProfileRequested() {
        profileEditorDraft = .empty
        profileEditorMessage = nil
        isProfileEditorPresented = false
        addProfileDraft = ModelProfileDraft.newProfile(
            defaultHost: settings.defaultHost,
            defaultPort: settings.defaultPort
        )
        addProfileMessage = nil
        isAddProfilePresented = true
        appendLog("[profile] adding new model profile.")
    }

    func exportProfilesRequested() {
        guard !models.isEmpty else {
            let message = "No model profiles are available to export."
            modelProfileExportMessage = message
            appendLog("[profile] export failed: \(message)")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Model Profiles"
        panel.nameFieldStringValue = "MLXServerManager-Profiles.json"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            modelProfileExportMessage = "Export cancelled."
            appendLog("[profile] export cancelled.")
            return
        }

        do {
            let data = try modelProfileExportService.exportData(from: models)
            try data.write(to: url, options: [.atomic])

            let message = "Exported \(models.count) profile(s) to \(url.lastPathComponent)."
            modelProfileExportMessage = message
            appendLog("[profile] \(message)")
            appendLog("[profile] export includes profile metadata only. It does not include API keys, tokens, model weights, caches, logs, executable paths, or runtime state.")
        } catch {
            let message = error.localizedDescription
            modelProfileExportMessage = "Export failed: \(message)"
            appendLog("[profile] export failed: \(message)")
        }
    }

    func importProfilesPreviewRequested() {
        let panel = NSOpenPanel()
        panel.title = "Import Model Profiles Preview"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            modelProfileImportMessage = "Import preview cancelled."
            appendLog("[profile] import preview cancelled.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let result = modelProfileImportPreviewService.preview(
                data: data,
                sourceFileName: url.lastPathComponent,
                existingModels: models
            )

            importPreviewResult = result
            isImportPreviewPresented = true
            modelProfileImportMessage = "Previewed \(result.totalProfiles) profile row(s) from \(result.sourceFileName)."
            appendLog("[profile] import preview loaded \(result.sourceFileName): \(result.validProfilesCount) valid, \(result.invalidProfilesCount) invalid, \(result.warningCount) warning(s).")
            appendLog("[profile] import preview only. No profiles were saved, no server lifecycle action was taken, and no external request was made.")
        } catch {
            let result = modelProfileImportPreviewService.preview(
                data: Data(),
                sourceFileName: url.lastPathComponent,
                existingModels: models
            )

            importPreviewResult = result
            isImportPreviewPresented = true
            modelProfileImportMessage = "Import preview failed: \(error.localizedDescription)"
            appendLog("[profile] import preview failed: \(error.localizedDescription)")
        }
    }

    func dismissImportPreview() {
        isImportPreviewPresented = false
    }

    func importSelectedProfilesRequested(requests: [ImportSelectedProfileRequest]) {
        guard let importPreviewResult else {
            let message = "No import preview is available."
            modelProfileImportMessage = message
            appendLog("[profile] import failed: \(message)")
            return
        }

        let importResult = modelProfileImportPreviewService.importSelectedProfiles(
            from: importPreviewResult,
            requests: requests,
            existingModels: models
        )

        for message in importResult.messages {
            appendLog("[profile] \(message)")
        }

        guard importResult.didChangeModels else {
            let message = importResult.messages.last ?? "No profiles were imported or replaced."
            modelProfileImportMessage = message
            return
        }

        let previousSelectedModelID = selectedModelID
        let nextModels = importResult.modelsAfterImport

        do {
            try settingsStore.save(models: nextModels)
            models = nextModels

            let selectionUpdate = ModelProfileImportSelectionUpdate.preservingSelection(
                previousSelectedModelID: previousSelectedModelID,
                nextModels: nextModels,
                replacedProfiles: importResult.replacedProfiles
            )
            if selectionUpdate.preservedThroughReplacement {
                selectedModelID = selectionUpdate.selectedModelID
                appendLog("[profile] selected profile identity updated from \(previousSelectedModelID ?? "unknown") to \(selectionUpdate.selectedModelID ?? "unknown") after Replace.")
            }

            modelProfileImportMessage = "Imported \(importResult.importedCount) profile(s). Renamed \(importResult.renamedCount) profile(s). Replaced \(importResult.replacedCount) profile(s). Skipped \(importResult.skippedCount) profile(s)."
            appendLog("[profile] profile metadata changes saved to models.json.")
            if selectionUpdate.preservedThroughReplacement {
                appendLog("[profile] selected profile was preserved through the explicit Replace action. No server lifecycle action was taken.")
            } else {
                appendLog("[profile] selected profile was not changed. No server lifecycle action was taken.")
            }
            isImportPreviewPresented = false
        } catch {
            modelProfileImportMessage = "Import failed: \(error.localizedDescription)"
            appendLog("[profile] import failed: \(error.localizedDescription)")
        }
    }

    func cancelAddProfile() {
        addProfileDraft = .empty
        addProfileMessage = nil
        isAddProfilePresented = false
        appendLog("[profile] add cancelled.")
    }

    func saveNewProfile() {
        guard isAddProfilePresented else {
            return
        }

        switch validatedNewProfileDraft(addProfileDraft) {
        case let .valid(newModel):
            let nextModels = models + [newModel]

            do {
                try settingsStore.save(models: nextModels)
                models = nextModels
                addProfileDraft = .empty
                addProfileMessage = nil
                isAddProfilePresented = false

                if isManagedProcessRunning {
                    appendLog("[profile] added \(newModel.modelID) to models.json.")
                    appendLog("[profile] Profile added. Stop the managed server before switching runtime profile.")
                } else {
                    selectedModelID = newModel.id
                    appendLog("[profile] added and selected \(newModel.modelID).")
                }
            } catch {
                addProfileMessage = error.localizedDescription
                appendLog("[profile] add failed: \(error.localizedDescription)")
            }
        case let .invalid(message):
            addProfileMessage = message
            appendLog("[profile] add failed: \(message)")
        }
    }

    func deleteProfileRequested() {
        guard let selectedModel else {
            let message = "No model is selected."
            profileDeletionMessage = message
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard models.count > 1 else {
            let message = "At least one model profile is required."
            profileDeletionMessage = message
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard !isManagedProcessRunning else {
            let message = "Stop the managed server before deleting profiles."
            profileDeletionMessage = message
            appendLog("[profile] delete failed: \(message)")
            return
        }

        pendingDeleteModelID = selectedModel.id
        profileDeletionMessage = nil
        isDeleteProfileConfirmationPresented = true
        appendLog("[profile] delete confirmation requested for \(selectedModel.modelID).")
    }

    func cancelDeleteProfile() {
        pendingDeleteModelID = nil
        isDeleteProfileConfirmationPresented = false
        appendLog("[profile] delete cancelled.")
    }

    func confirmDeleteProfile() {
        guard let pendingDeleteModelID else {
            let message = "No model profile is pending deletion."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard models.count > 1 else {
            let message = "At least one model profile is required."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard !isManagedProcessRunning else {
            let message = "Stop the managed server before deleting profiles."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard let index = models.firstIndex(where: { $0.id == pendingDeleteModelID }) else {
            let message = "Selected model profile no longer exists."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        let deletedModel = models[index]
        var nextModels = models
        nextModels.remove(at: index)

        guard let fallbackModel = nextModels.first else {
            let message = "At least one model profile is required."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        do {
            try settingsStore.save(models: nextModels)
            models = nextModels

            let shouldSelectFallback = selectedModelID == deletedModel.id
                || selectedModelID.map { selectedID in
                    !nextModels.contains { $0.id == selectedID }
                } ?? true

            if shouldSelectFallback {
                selectedModelID = fallbackModel.id
                appendLog("[profile] deleted \(deletedModel.modelID) from models.json.")
                appendLog("[profile] selected fallback profile \(fallbackModel.modelID).")
            } else {
                appendLog("[profile] deleted \(deletedModel.modelID) from models.json.")
            }

            profileEditorDraft = .empty
            profileEditorMessage = nil
            isProfileEditorPresented = false
            addProfileDraft = .empty
            addProfileMessage = nil
            isAddProfilePresented = false
            profileDeletionMessage = nil
            self.pendingDeleteModelID = nil
            isDeleteProfileConfirmationPresented = false
        } catch {
            profileDeletionMessage = error.localizedDescription
            self.pendingDeleteModelID = nil
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(error.localizedDescription)")
        }
    }

    func saveProfileEditing() {
        guard isProfileEditorPresented else {
            return
        }

        guard let index = models.firstIndex(where: { $0.modelID == profileEditorDraft.originalModelID }) else {
            let message = "Selected model profile no longer exists."
            profileEditorMessage = message
            appendLog("[profile] save failed: \(message)")
            return
        }

        let existingModel = models[index]

        switch validatedProfileDraft(profileEditorDraft, existingModel: existingModel) {
        case let .valid(updatedModel):
            models[index] = updatedModel
            selectedModelID = updatedModel.id

            do {
                try settingsStore.save(models: models)
                profileEditorDraft = ModelProfileDraft(model: updatedModel)
                profileEditorMessage = nil
                isProfileEditorPresented = false
                appendLog("[profile] saved \(updatedModel.modelID) to models.json.")
            } catch {
                profileEditorMessage = error.localizedDescription
                appendLog("[profile] save failed: \(error.localizedDescription)")
            }
        case let .invalid(message):
            profileEditorMessage = message
            appendLog("[profile] save failed: \(message)")
        }
    }

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

    func copyModelsCurl() {
        copyToPasteboard(modelsCurlCommand)
        appendLog("[ui] Copied OpenAI-compatible curl /v1/models command.")
    }

    func copyChatCompletionsCurl() {
        copyToPasteboard(chatCompletionsCurlCommand)
        appendLog("[ui] Copied OpenAI-compatible curl /v1/chat/completions command.")
    }

    func copyLaunchCommandPreview(_ preview: String) {
        if copyToPasteboard(preview) {
            appendLog("[profile] copied launch command preview to clipboard.")
        } else {
            appendLog("[profile] failed to copy launch command preview.")
        }
    }

    func clearLogsRequested() {
        logBuffer.clear()
        syncLogText()
        appendLog("[info] logs cleared")
    }

    func copyLogsRequested() {
        guard !logBuffer.isEmpty else {
            appendLog("[warning] No logs to copy.")
            return
        }

        if copyToPasteboard(logBuffer.text) {
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

        stopMemoryMonitoring()
        clearRunningModel(logPrefix: "external")
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

        if let processIdentifier = processManager.managedProcessIdentifier {
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

    private func runHuggingFaceDownload(
        reference: HuggingFaceModelReference,
        destinationPath: String,
        displayName: String,
        draft: HuggingFaceDownloadDraft,
        queueEntryID: UUID
    ) async {
        do {
            huggingFaceDownloadStatus.phase = .downloading
            huggingFaceDownloadStatus.message = "Downloading \(reference.repositoryID)..."
            updateHuggingFaceQueueEntry(queueEntryID, phase: .downloading, message: "Downloading")

            let result = try await huggingFaceDownloadManager.download(
                request: HuggingFaceDownloadRequest(
                    repositoryID: reference.repositoryID,
                    destinationPath: destinationPath
                ),
                outputHandler: { [weak self] line in
                    Task { @MainActor in
                        self?.appendHuggingFaceOutputLine(line)
                    }
                }
            )

            guard !huggingFaceDownloadCancellationRequested else {
                huggingFaceDownloadStatus.phase = .cancelled
                huggingFaceDownloadStatus.message = "Download cancelled. The model was not added."
                updateHuggingFaceQueueEntry(queueEntryID, phase: .cancelled, message: "Cancelled")
                appendLog("[hf] download cancelled for \(reference.repositoryID).")
                huggingFaceDownloadTask = nil
                return
            }

            huggingFaceDownloadStatus.phase = .finalizing
            huggingFaceDownloadStatus.message = "Finalizing downloaded model profile..."
            huggingFaceDownloadStatus.progress = 1

            if draft.autoAddToModelList {
                let didAddProfile = addDownloadedHuggingFaceModelProfile(
                    reference: reference,
                    destinationPath: result.destinationPath,
                    displayName: displayName,
                    draft: draft
                )

                guard didAddProfile else {
                    huggingFaceDownloadTask = nil
                    return
                }
            }

            huggingFaceDownloadStatus.phase = .completed
            huggingFaceDownloadStatus.message = draft.autoAddToModelList
                ? "Download completed. Added to model list and selected. Ready to start."
                : "Download completed. Auto-add was disabled."
            huggingFaceDownloadStatus.progress = 1
            updateHuggingFaceQueueEntry(queueEntryID, phase: .completed, message: "Completed")
            appendLog("[hf] download completed for \(reference.repositoryID).")
            appendLog("[hf] saved to \(ModelAvailabilityPathFormatter.compact(path: result.destinationPath)).")
            huggingFaceDownloadTask = nil
        } catch {
            if huggingFaceDownloadCancellationRequested {
                huggingFaceDownloadStatus.phase = .cancelled
                huggingFaceDownloadStatus.message = "Download cancelled. The model was not added."
                updateHuggingFaceQueueEntry(queueEntryID, phase: .cancelled, message: "Cancelled")
                appendLog("[hf] download cancelled.")
            } else {
                huggingFaceDownloadStatus.phase = .failed
                huggingFaceDownloadStatus.message = error.localizedDescription
                updateHuggingFaceQueueEntry(queueEntryID, phase: .failed, message: error.localizedDescription)
                appendLog("[hf] download failed: \(error.localizedDescription)")
            }
            huggingFaceDownloadTask = nil
        }
    }

    private func updateHuggingFaceQueueEntry(_ id: UUID, phase: HuggingFaceDownloadPhase, message: String) {
        guard let index = huggingFaceDownloadQueue.firstIndex(where: { $0.id == id }) else {
            return
        }
        huggingFaceDownloadQueue[index].phase = phase
        huggingFaceDownloadQueue[index].message = message
    }

    private func appendHuggingFaceOutputLine(_ line: String) {
        let sanitizedLine = HuggingFaceDownloadPlanner.sanitizedOutputLine(line)
        guard !sanitizedLine.isEmpty else {
            return
        }

        var outputLines = huggingFaceDownloadStatus.outputLines
        outputLines.append(sanitizedLine)
        if outputLines.count > 24 {
            outputLines.removeFirst(outputLines.count - 24)
        }
        huggingFaceDownloadStatus.outputLines = outputLines

        if let progress = HuggingFaceDownloadPlanner.progressFraction(from: sanitizedLine) {
            huggingFaceDownloadStatus.progress = progress
            huggingFaceDownloadStatus.message = "Downloading... \(Int(progress * 100))%"
        }

        appendLog(sanitizedLine)
    }

    private func addDownloadedHuggingFaceModelProfile(
        reference: HuggingFaceModelReference,
        destinationPath: String,
        displayName: String,
        draft: HuggingFaceDownloadDraft
    ) -> Bool {
        if models.contains(where: { $0.modelID == destinationPath }) {
            selectedModelID = destinationPath
            appendLog("[hf] existing profile selected for \(ModelAvailabilityPathFormatter.compact(path: destinationPath)).")
            return true
        }

        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? settings.defaultHost
            : draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings.defaultPort

        let model = ModelConfig(
            modelID: destinationPath,
            displayName: displayName,
            family: "Downloaded",
            quantization: "Hugging Face",
            localName: reference.name,
            host: host,
            serverPort: port,
            enableThinking: draft.enableThinking,
            notes: "Downloaded from \(reference.repositoryID).",
            advancedLaunchOptions: nil
        )

        let nextModels = models + [model]
        do {
            try settingsStore.save(models: nextModels)
            models = nextModels
            if draft.autoSelectAfterAdd {
                selectedModelID = model.id
            }
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(
                for: model,
                result: .present(path: destinationPath)
            )
            appendLog("[hf] added downloaded model to list: \(displayName).")
            return true
        } catch {
            huggingFaceDownloadStatus.phase = .failed
            huggingFaceDownloadStatus.message = "Downloaded, but profile add failed: \(error.localizedDescription)"
            appendLog("[hf] profile add failed after download: \(error.localizedDescription)")
            return false
        }
    }

    private func startManagedServer(logPrefix: String) async -> Bool {
        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[\(logPrefix)] failed: \(message)")
            return false
        }

        let host = selectedModel.host
        let port = selectedModel.serverPort
        if let processIdentifier = processManager.managedProcessIdentifier {
            let message = "A managed mlx_lm.server process is already running with pid \(processIdentifier)."
            runtimeState = .ready(
                host: host,
                port: port,
                processIdentifier: processIdentifier
            )
            appendLog("[\(logPrefix)] failed: \(message)")
            return false
        }

        let advancedValidation = validatedAdvancedLaunchOptions(selectedModel.advancedLaunchOptions ?? .empty)
        guard case let .valid(advancedLaunchOptions) = advancedValidation else {
            if case let .invalid(message) = advancedValidation {
                runtimeState = .error(message: message)
                appendLog("[\(logPrefix)] failed: \(message)")
            }
            return false
        }

        let executablePath = settings.mlxServerExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else {
            let message = "mlx_lm.server executable path is not configured. Set it in Settings before starting."
            runtimeState = .error(message: message)
            appendLog("[\(logPrefix)] preflight failed: \(message)")
            return false
        }

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            let message = "mlx_lm.server executable was not found or is not executable: \(ModelAvailabilityPathFormatter.compact(path: executablePath))."
            runtimeState = .error(message: message)
            appendLog("[\(logPrefix)] preflight failed: \(message)")
            return false
        }

        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: selectedModel) {
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                let message = "Model path is missing: \(ModelAvailabilityPathFormatter.compact(path: localPath))."
                runtimeState = .error(message: message)
                appendLog("[\(logPrefix)] preflight failed: \(message)")
                return false
            }
        }

        appendLog("[\(logPrefix)] preflight passed for selected profile.")
        appendLog("[\(logPrefix)] starting \(selectedModel.modelID) at \(host):\(port)")
        appendLog("[\(logPrefix)] checking port before launch: \(host):\(port)")
        runtimeState = .checkingPort(host: host, port: port)

        switch portChecker.check(host: host, port: port) {
        case .available:
            appendLog("[\(logPrefix)] port available: \(host):\(port)")
        case .busy:
            appendLog("[\(logPrefix)] port occupied: \(host):\(port)")
            if await detectExternalServer(host: host, port: port, logPrefix: logPrefix) {
                return false
            }

            runtimeState = .portBusy(host: host, port: port)
            appendLog("[\(logPrefix)] port occupied and no compatible /v1/models endpoint detected.")
            return false
        case let .invalidInput(message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[\(logPrefix)] port check failed: \(message)")
            return false
        case let .failed(_, _, message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[\(logPrefix)] port check failed for \(host):\(port): \(message)")
            return false
        }

        let request = ModelLaunchRequest(
            executablePath: settings.mlxServerExecutablePath,
            modelID: selectedModel.modelID,
            host: host,
            port: port,
            advancedLaunchOptions: advancedLaunchOptions
        )

        runtimeState = .starting(host: host, port: port)

        do {
            let launchResult = try processManager.start(
                request: request,
                outputHandler: { [weak self] line in
                    Task { @MainActor in
                        self?.appendLog(line)
                    }
                },
                terminationHandler: { [weak self] status in
                    Task { @MainActor in
                        self?.appendLog("[process] managed server exited with status \(status)")
                    }
                }
            )

            appendLog("[\(logPrefix)] command: \(launchResult.commandSummary)")
            appendLog("[\(logPrefix)] pid: \(launchResult.processIdentifier)")
            startMemoryMonitoring(processIdentifier: launchResult.processIdentifier)
            setRunningModelID(selectedModel.id, logPrefix: logPrefix)
            runtimeState = .loading(
                host: host,
                port: port,
                processIdentifier: launchResult.processIdentifier
            )

            let ready = await waitForReadyAfterStart(
                host: host,
                port: port,
                processIdentifier: launchResult.processIdentifier
            )
            if ready {
                appendLog("[\(logPrefix)] ready check succeeded for pid \(launchResult.processIdentifier).")
            } else {
                appendLog("[\(logPrefix)] ready check did not complete successfully for pid \(launchResult.processIdentifier).")
            }

            return ready
        } catch {
            runtimeState = .error(message: error.localizedDescription)
            appendLog("[\(logPrefix)] failed: \(error.localizedDescription)")
            return false
        }
    }

    private func loadSettings() {
        do {
            let snapshot = try settingsStore.load()
            settings = snapshot.settings
            models = snapshot.models

            if snapshot.usedDefaults {
                appendLog("[settings] settings.json or models.json not found. Using defaults until saved.")
            } else {
                appendLog("[settings] Loaded settings.json and models.json from \(settingsDirectoryPath).")
            }
        } catch {
            settings = .defaults
            models = ModelConfig.defaults
            appendLog("[settings] Failed to load settings. Using defaults: \(error.localizedDescription)")
        }
    }

    private func handleReadyCheckResult(
        _ result: ReadyCheckResult,
        fallbackHost: String,
        fallbackPort: Int
    ) {
        switch result {
        case let .ready(url, statusCode):
            if runtimeState.isAdoptedExternalServer {
                runtimeState = .adoptedExternalServer(
                    host: fallbackHost,
                    port: fallbackPort,
                    baseURL: "http://\(fallbackHost):\(fallbackPort)/v1",
                    message: "This server is adopted for connection context only."
                )
            } else if runtimeState.isExternalServerDetected {
                runtimeState = .externalServerDetected(
                    host: fallbackHost,
                    port: fallbackPort,
                    baseURL: "http://\(fallbackHost):\(fallbackPort)/v1",
                    message: "An OpenAI-compatible server appears to be running on this host/port."
                )
            } else {
                runtimeState = .ready(
                    host: fallbackHost,
                    port: fallbackPort,
                    processIdentifier: processManager.managedProcessIdentifier
                )
            }
            appendLog("[ready] ready: \(url.absoluteString) returned HTTP \(statusCode)")
        case let .notReady(url, statusCode):
            setReadyFailureState(
                host: fallbackHost,
                port: fallbackPort,
                message: "HTTP \(statusCode)"
            )
            appendLog("[ready] not ready: \(url.absoluteString) returned HTTP \(statusCode)")
        case let .invalidInput(message):
            setReadyFailureState(host: fallbackHost, port: fallbackPort, message: message)
            appendLog("[ready] ready check failed: \(message)")
        case let .failed(url, message):
            setReadyFailureState(host: fallbackHost, port: fallbackPort, message: message)
            appendLog("[ready] ready check failed for \(url?.absoluteString ?? "\(fallbackHost):\(fallbackPort)"): \(message)")
        case let .timedOut(url):
            setReadyFailureState(host: fallbackHost, port: fallbackPort, message: "Timed out")
            appendLog("[ready] timed out: \(url.absoluteString)")
        }
    }

    private func setReadyFailureState(host: String, port: Int, message: String) {
        if runtimeState.isAdoptedExternalServer {
            runtimeState = .adoptedExternalServer(
                host: host,
                port: port,
                baseURL: "http://\(host):\(port)/v1",
                message: "Adopted external server is not ready: \(message)"
            )
            return
        }

        runtimeState = .readyCheckFailed(
            host: host,
            port: port,
            message: message
        )
    }

    private func waitForReadyAfterStart(
        host: String,
        port: Int,
        processIdentifier: Int32
    ) async -> Bool {
        appendLog("[ready] waiting for http://\(host):\(port)/v1/models")

        for attempt in 1...10 {
            guard processManager.managedProcessIdentifier == processIdentifier else {
                appendLog("[ready] wait ended because managed process is no longer running.")
                return false
            }

            if case .stopping = runtimeState {
                appendLog("[ready] wait cancelled because stop was requested.")
                return false
            }

            let result = await readyChecker.check(host: host, port: port)

            switch result {
            case let .ready(url, statusCode):
                guard processManager.managedProcessIdentifier == processIdentifier else {
                    appendLog("[ready] ready response ignored because managed process is no longer running.")
                    return false
                }

                runtimeState = .ready(
                    host: host,
                    port: port,
                    processIdentifier: processIdentifier
                )
                appendLog("[ready] ready after start: \(url.absoluteString) returned HTTP \(statusCode)")
                return true
            case let .notReady(url, statusCode):
                appendLog("[ready] attempt \(attempt) not ready: \(url.absoluteString) returned HTTP \(statusCode)")
            case let .invalidInput(message):
                runtimeState = .readyCheckFailed(host: host, port: port, message: message)
                appendLog("[ready] ready check failed: \(message)")
                return false
            case let .failed(url, message):
                appendLog("[ready] attempt \(attempt) failed for \(url?.absoluteString ?? "\(host):\(port)"): \(message)")
            case let .timedOut(url):
                appendLog("[ready] attempt \(attempt) timed out: \(url.absoluteString)")
            }

            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                runtimeState = .unknown(message: "Ready wait was cancelled.")
                appendLog("[ready] wait cancelled.")
                return false
            }
        }

        let message = "Ready check did not succeed after launch."
        runtimeState = .unknown(message: message)
        appendLog("[ready] \(message)")
        return false
    }

    private func handleStopResult(
        _ result: ModelStopResult,
        host: String,
        port: Int,
        logPrefix: String = "stop"
    ) async -> Bool {
        switch result {
        case .notRunning:
            stopMemoryMonitoring()
            clearRunningModel(logPrefix: logPrefix)
            runtimeState = .stopped
            appendLog("[\(logPrefix)] managed process is not running.")
            return true
        case let .stopped(processIdentifier, terminationStatus, usedInterrupt):
            stopMemoryMonitoring()
            clearRunningModel(logPrefix: logPrefix)
            if usedInterrupt {
                appendLog("[\(logPrefix)] interrupt was sent after graceful timeout for pid \(processIdentifier).")
            }
            appendLog("[\(logPrefix)] stopped managed pid \(processIdentifier) with status \(terminationStatus).")

            if await waitForPortRelease(host: host, port: port, logPrefix: logPrefix) {
                runtimeState = .stopped
                return true
            } else {
                runtimeState = .portBusy(host: host, port: port)
                appendLog("[\(logPrefix)] warning: port still busy after waiting for release: \(host):\(port)")
                return false
            }
        case let .timedOut(processIdentifier):
            let message = "Stop timed out for managed pid \(processIdentifier)."
            runtimeState = .error(message: message)
            appendLog("[\(logPrefix)] \(message)")
            return false
        }
    }

    private func waitForPortRelease(
        host: String,
        port: Int,
        logPrefix: String = "stop"
    ) async -> Bool {
        appendLog("[\(logPrefix)] waiting for port release: \(host):\(port)")

        for _ in 1...20 {
            switch portChecker.check(host: host, port: port) {
            case .available:
                appendLog("[\(logPrefix)] port released: \(host):\(port)")
                return true
            case .busy:
                break
            case let .invalidInput(message):
                appendLog("[\(logPrefix)] warning: port release check failed: \(message)")
                return false
            case let .failed(_, _, message):
                appendLog("[\(logPrefix)] warning: port release check failed for \(host):\(port): \(message)")
                return false
            }

            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                appendLog("[\(logPrefix)] warning: port release wait cancelled.")
                return false
            }
        }

        switch portChecker.check(host: host, port: port) {
        case .available:
            appendLog("[\(logPrefix)] port released: \(host):\(port)")
            return true
        case .busy:
            return false
        case let .invalidInput(message):
            appendLog("[\(logPrefix)] warning: final port release check failed: \(message)")
            return false
        case let .failed(_, _, message):
            appendLog("[\(logPrefix)] warning: final port release check failed for \(host):\(port): \(message)")
            return false
        }
    }

    private func endpointForCurrentRuntimeState() -> (host: String, port: Int) {
        switch runtimeState {
        case let .starting(host, port),
             let .checkingPort(host, port),
             let .portAvailable(host, port),
             let .portBusy(host, port),
             let .checkingReady(host, port):
            return (host, port)
        case let .externalServerDetected(host, port, _, _):
            return (host, port)
        case let .adoptedExternalServer(host, port, _, _):
            return (host, port)
        case let .loading(host, port, _),
             let .ready(host, port, _):
            return (host, port)
        case let .portCheckFailed(host, port, _),
             let .readyCheckFailed(host, port, _):
            return (host, port)
        case .stopped, .stopping, .error, .unknown:
            return (
                selectedModel?.host ?? settings.defaultHost,
                selectedModel?.serverPort ?? settings.defaultPort
            )
        }
    }

    private func handleSelectedModelChange(from oldValue: ModelConfig.ID?) {
        guard oldValue != selectedModelID else {
            return
        }

        guard let selectedModel else {
            appendLog("[model] selected model cleared.")
            return
        }

        appendLog("[model] selected modelID: \(selectedModel.modelID)")
        resetModelAvailabilityForCurrentSelection()
        if runtimeState.isExternalServerContext {
            runtimeState = .stopped
            appendLog("[model] external server context cleared after model selection changed.")
        }
        logRestartRequiredIfNeeded()
    }

    private func resetModelAvailabilityForCurrentSelection() {
        selectedModelAvailabilitySummary = ModelAvailabilitySummary.initial(
            for: selectedModel,
            isExternalTarget: runtimeState.isExternalServerContext
        )
    }

    private func detectExternalServer(
        host: String,
        port: Int,
        logPrefix: String
    ) async -> Bool {
        let baseURL = "http://\(host):\(port)/v1"
        appendLog("[\(logPrefix)] checking for external OpenAI-compatible server at \(baseURL)/models")

        let result = await readyChecker.check(host: host, port: port)

        switch result {
        case let .ready(url, statusCode):
            stopMemoryMonitoring()
            clearRunningModel(logPrefix: logPrefix)
            let message = "An OpenAI-compatible server appears to be running on this host/port."
            runtimeState = .externalServerDetected(
                host: host,
                port: port,
                baseURL: baseURL,
                message: message
            )
            appendLog("[\(logPrefix)] external server detected: \(url.absoluteString) returned HTTP \(statusCode)")
            appendLog("[\(logPrefix)] not launching managed process.")
            return true
        case let .notReady(url, statusCode):
            appendLog("[\(logPrefix)] external server check not ready: \(url.absoluteString) returned HTTP \(statusCode)")
            return false
        case let .invalidInput(message):
            appendLog("[\(logPrefix)] external server check failed: \(message)")
            return false
        case let .failed(url, message):
            appendLog("[\(logPrefix)] external server check failed for \(url?.absoluteString ?? "\(host):\(port)"): \(message)")
            return false
        case let .timedOut(url):
            appendLog("[\(logPrefix)] external server check timed out: \(url.absoluteString)")
            return false
        }
    }

    private func setRunningModelID(_ modelID: ModelConfig.ID, logPrefix: String) {
        runningModelID = modelID
        appendLog("[\(logPrefix)] running modelID: \(modelID)")
        logRestartRequiredIfNeeded()
    }

    private func clearRunningModel(logPrefix: String) {
        guard runningModelID != nil else {
            return
        }

        runningModelID = nil
        appendLog("[\(logPrefix)] running model cleared.")
    }

    private func logRestartRequiredIfNeeded() {
        guard restartRequired,
              let runningModelID,
              let selectedModel else {
            return
        }

        appendLog("[model] selected model differs from running model. Restart required to apply selected model. selected: \(selectedModel.modelID), running: \(runningModelID)")
    }

    private func startMemoryMonitoring(processIdentifier: Int32) {
        stopMemoryMonitoring(resetUsage: true)

        appendLog("[memory] monitoring managed pid \(processIdentifier).")
        let monitor = memoryMonitor

        memoryMonitorTask = Task { [weak self, monitor] in
            while !Task.isCancelled {
                let result = await monitor.currentUsage(processIdentifier: processIdentifier)
                let shouldContinue = await MainActor.run {
                    self?.handleMemoryMonitorResult(
                        result,
                        processIdentifier: processIdentifier
                    ) ?? false
                }

                guard shouldContinue, !Task.isCancelled else {
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: 4_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func stopMemoryMonitoring(resetUsage: Bool = true) {
        memoryMonitorTask?.cancel()
        memoryMonitorTask = nil

        if resetUsage {
            memoryUsageGB = nil
        }
    }

    private func handleMemoryMonitorResult(
        _ result: MemoryMonitorResult,
        processIdentifier: Int32
    ) -> Bool {
        guard processManager.managedProcessIdentifier == processIdentifier else {
            memoryUsageGB = nil
            appendLog("[memory] monitoring stopped because managed pid changed.")
            return false
        }

        switch result {
        case let .usage(snapshot):
            memoryUsageGB = snapshot.gigabytes
            return true
        case let .notRunning(processIdentifier):
            memoryUsageGB = nil
            appendLog("[memory] warning: managed pid \(processIdentifier) is no longer reporting RSS.")
            return false
        case let .invalidInput(message):
            memoryUsageGB = nil
            appendLog("[memory] warning: \(message)")
            return false
        case let .failed(processIdentifier, message):
            appendLog("[memory] warning: failed to read RSS for pid \(processIdentifier): \(message)")
            return true
        }
    }

    private func validatedProfileDraft(
        _ draft: ModelProfileDraft,
        existingModel: ModelConfig
    ) -> ProfileValidationResult {
        let modelID = draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !modelID.isEmpty else {
            return .invalid("Model ID is required.")
        }

        guard !host.isEmpty else {
            return .invalid("Host is required.")
        }

        guard let port = Int(portText), (1...65_535).contains(port) else {
            return .invalid("Port must be between 1 and 65535.")
        }

        let advancedValidation = validatedAdvancedLaunchOptions(draft.advancedLaunchOptions)
        if case let .invalid(message) = advancedValidation {
            return .invalid(message)
        }

        guard case let .valid(advancedLaunchOptions) = advancedValidation else {
            return .invalid("Advanced Launch Options validation failed.")
        }

        let changesRuntimeTarget = modelID != existingModel.modelID
            || host != existingModel.host
            || port != existingModel.serverPort
            || advancedLaunchOptions != existingModel.advancedLaunchOptions?.normalized()

        if isManagedProcessRunning && changesRuntimeTarget {
            return .invalid("Stop the managed server before changing modelID, host, port, or advanced launch options.")
        }

        var updatedModel = existingModel
        updatedModel.displayName = displayName.isEmpty ? modelID : displayName
        updatedModel.modelID = modelID
        updatedModel.host = host
        updatedModel.serverPort = port
        updatedModel.enableThinking = draft.enableThinking
        updatedModel.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedModel.advancedLaunchOptions = advancedLaunchOptions
        return .valid(updatedModel)
    }

    private func validatedNewProfileDraft(_ draft: ModelProfileDraft) -> ProfileValidationResult {
        let modelID = draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !modelID.isEmpty else {
            return .invalid("Model ID is required.")
        }

        guard !host.isEmpty else {
            return .invalid("Host is required.")
        }

        guard let port = Int(portText), (1...65_535).contains(port) else {
            return .invalid("Port must be between 1 and 65535.")
        }

        guard !models.contains(where: { $0.modelID == modelID }) else {
            return .invalid("A model profile with this Model ID already exists.")
        }

        let advancedValidation = validatedAdvancedLaunchOptions(draft.advancedLaunchOptions)
        if case let .invalid(message) = advancedValidation {
            return .invalid(message)
        }

        guard case let .valid(advancedLaunchOptions) = advancedValidation else {
            return .invalid("Advanced Launch Options validation failed.")
        }

        let localName = modelID.split(separator: "/").last.map(String.init) ?? modelID
        return .valid(
            ModelConfig(
                modelID: modelID,
                displayName: displayName.isEmpty ? modelID : displayName,
                family: "Custom",
                quantization: "User configured",
                localName: localName,
                host: host,
                serverPort: port,
                enableThinking: draft.enableThinking,
                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                advancedLaunchOptions: advancedLaunchOptions
            )
        )
    }

    private func validatedAdvancedLaunchOptions(_ options: AdvancedLaunchOptions) -> AdvancedLaunchOptionsValidationResult {
        guard let normalizedOptions = options.normalized() else {
            return .valid(nil)
        }

        let boundedDoubleFields: [(String, String?)] = [
            ("Default Temperature", normalizedOptions.defaultTemperature),
            ("Default Top P", normalizedOptions.defaultTopP),
            ("Default Min P", normalizedOptions.defaultMinP)
        ]

        for (label, value) in boundedDoubleFields {
            guard let value else {
                continue
            }

            guard let doubleValue = Double(value), (0...1).contains(doubleValue) else {
                return .invalid("\(label) must be between 0 and 1.")
            }
        }

        let positiveIntegerFields: [(String, String?)] = [
            ("Default Top K", normalizedOptions.defaultTopK),
            ("Default Max Tokens", normalizedOptions.defaultMaxTokens),
            ("Decode Concurrency", normalizedOptions.decodeConcurrency),
            ("Prompt Concurrency", normalizedOptions.promptConcurrency),
            ("Prefill Step Size", normalizedOptions.prefillStepSize),
            ("Prompt Cache Size", normalizedOptions.promptCacheSize),
            ("Prompt Cache Bytes", normalizedOptions.promptCacheBytes)
        ]

        for (label, value) in positiveIntegerFields {
            guard let value else {
                continue
            }

            guard let integerValue = Int(value), integerValue > 0 else {
                return .invalid("\(label) must be a positive integer.")
            }
        }

        if let chatTemplateArgs = normalizedOptions.chatTemplateArgs {
            guard let data = chatTemplateArgs.data(using: .utf8) else {
                return .invalid("Chat Template Args must be valid JSON.")
            }

            do {
                _ = try JSONSerialization.jsonObject(with: data)
            } catch {
                return .invalid("Chat Template Args must be valid JSON.")
            }
        }

        return .valid(normalizedOptions)
    }

    private var connectionConfigBuilder: ConnectionConfigBuilder {
        ConnectionConfigBuilder(
            scheme: "http",
            host: selectedModel?.host ?? settings.defaultHost,
            port: selectedModel?.serverPort ?? settings.defaultPort,
            apiBasePath: "/v1",
            apiKeyPlaceholder: settings.apiKeyPlaceholder
        )
    }

    private func appendLog(_ line: String) {
        logBuffer.append(line)
        syncLogText()
    }

    private func syncLogText() {
        logText = logBuffer.text
        logEntries = logBuffer.entries
    }

    private func diagnosticsSummaryCopyText() -> String {
        var lines = [
            "MLX Server Manager Diagnostics Summary",
            diagnosticsSummaryText,
            "",
            "Checks:"
        ]

        lines.append(
            contentsOf: diagnosticsResults.map { result in
                var line = "- [\(result.status.rawValue)] \(result.check.title): \(result.message)"

                if let detail = result.detail, !detail.isEmpty {
                    line += " (\(detail))"
                }

                return line
            }
        )

        return lines.joined(separator: "\n")
    }

    @discardableResult
    private func copyToPasteboard(_ value: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
    }
}
