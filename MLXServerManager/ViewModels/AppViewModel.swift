import AppKit
import Darwin
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

struct MemoryHistorySample: Equatable, Sendable {
    let usedFraction: Double
    let managedProcessFraction: Double
    let timestamp: Date
}

struct SystemUsageHistorySample: Equatable, Sendable {
    let cpuFraction: Double
    let gpuFraction: Double?
    let timestamp: Date
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
    @Published private(set) var managedServerStartedAt: Date?
    @Published private(set) var runtimeState: ModelRuntimeState = .stopped
    @Published private(set) var memoryUsageGB: Double?
    @Published private(set) var memoryBreakdown: MemoryBreakdownSnapshot?
    @Published private(set) var systemMemorySnapshot: SystemMemorySnapshot?
    @Published private(set) var memoryHistory: [MemoryHistorySample] = []
    @Published private(set) var cpuUsagePercent: Double?
    @Published private(set) var gpuUsagePercent: Double?
    @Published private(set) var systemUsageHistory: [SystemUsageHistorySample] = []
    @Published var autoUnloadEnabledByModelID: [ModelConfig.ID: Bool] = [:]
    @Published var autoUnloadMinutesByModelID: [ModelConfig.ID: Int] = [:]
    @Published private(set) var modelSortKey: String?
    @Published private(set) var isModelSortAscending = true
    @Published private(set) var logText: String
    @Published private(set) var logEntries: [LogEntry]
    @Published var logCategoryFilter = "All"
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
    @Published var modelListSourceFilter = "All"
    @Published var modelListSearchText = ""
    @Published var isImportPreviewPresented = false
    @Published private(set) var importPreviewResult: ImportPreviewResult?
    @Published var huggingFaceDownloadDraft: HuggingFaceDownloadDraft = .defaults(
        defaultHost: AppSettings.defaults.defaultHost,
        defaultPort: AppSettings.defaults.defaultPort
    )
    @Published private(set) var huggingFaceDownloadStatus: HuggingFaceDownloadStatus = .waiting
    @Published private(set) var huggingFaceDownloadQueue: [HuggingFaceDownloadQueueEntry] = []
    @Published private(set) var huggingFaceFilePreview: HuggingFaceDownloadFilePreviewState = .waiting
    @Published var selectedHuggingFacePreviewFileIDs: Set<String> = []
    @Published var huggingFaceAccessInput = ""
    @Published private(set) var isHuggingFaceAccessSaved = false
    @Published private(set) var huggingFaceAccessMessage = "No saved Hugging Face access value. Public repos can still be previewed."
    @Published private(set) var isHuggingFaceCLIAvailable = false
    @Published private(set) var huggingFaceCLIPath = "Not checked"
    @Published private(set) var huggingFaceCLIMessage = "Check Hugging Face CLI before downloading."
    @Published private(set) var aria2Availability = Aria2AvailabilityChecker.check()
    @Published var enableDownloadAutoRestart = false
    @Published var lowSpeedRestartThresholdText = "50K"
    @Published var localModelPath = ""
    @Published var localModelDisplayName = ""
    @Published var localModelPortText = String(AppSettings.defaults.defaultPort)
    @Published var localModelEnableThinking = false
    @Published private(set) var localModelMessage = "Paste an existing local model folder path, then add it to the model list."
    @Published var huggingFaceSearchQuery = ""
    @Published var showOnlyMLXLikelySearchResults = false
    @Published private(set) var huggingFaceSearchMessage = "Search Hugging Face explicitly, then choose a result for the download form."
    @Published private(set) var huggingFaceSearchResults: [HuggingFaceSearchResult] = []
    private let systemProfilerHardwareInfo = AppViewModel.loadSystemProfilerHardwareInfo()
    @Published private(set) var selectedHuggingFaceSearchResult: HuggingFaceSearchResult?
    @Published private(set) var isHuggingFaceSearching = false
    @Published private(set) var isSpeedTestRunning = false
    @Published private(set) var latestSpeedTestMessage = "Speed Test has not run yet."
    @Published private(set) var latestSpeedTestDurationMS: Double?
    @Published private(set) var latestBenchmarkResult: BenchmarkResult?
    @Published private(set) var benchmarkHistory: [BenchmarkResult] = []
    @Published private(set) var runtimeEvents: [RuntimeEvent] = []

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
    private let huggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing
    private let huggingFaceCredentialStore: HuggingFaceCredentialStoring
    private var logBuffer: LogBuffer
    private var memoryMonitorTask: Task<Void, Never>?
    private var systemUsageMonitorTask: Task<Void, Never>?
    private var autoUnloadTask: Task<Void, Never>?
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
        huggingFaceSearchService: HuggingFaceModelSearching? = nil,
        huggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing? = nil,
        huggingFaceCredentialStore: HuggingFaceCredentialStoring? = nil
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
        self.huggingFaceRepositoryFileService = huggingFaceRepositoryFileService ?? HuggingFaceRepositoryFileService()
        self.huggingFaceCredentialStore = huggingFaceCredentialStore ?? HuggingFaceCredentialStore()
        self.logBuffer = LogBuffer(initialLines: Self.initialLogLines)
        self.logText = logBuffer.text
        self.logEntries = logBuffer.entries
        loadSettings()
        huggingFaceDownloadDraft = .defaults(
            defaultHost: settings.defaultHost,
            defaultPort: settings.defaultPort
        )
        refreshHuggingFaceAccessStatus()
        refreshHuggingFaceCLIStatus(logResult: false)
        refreshAria2Status()
        localModelPortText = String(settings.defaultPort)
        selectedModelID = models.first?.id
        resetModelAvailabilityForCurrentSelection()
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            startSystemUsageMonitoring()
            startAutoUnloadMonitoring()
        }
    }

    var selectedModel: ModelConfig? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    var initialModelNameColumnWidth: CGFloat {
        let longestDisplayNameCount = models.map { $0.displayName.count }.max() ?? 0
        let estimatedWidth = CGFloat(longestDisplayNameCount * 8 + 28)
        return min(max(estimatedWidth, 210), 420)
    }

    var systemInfoRows: [(String, String)] {
        [
            ("機種", systemProfilerHardwareInfo["Model Name"] ?? Self.sysctlString("hw.model") ?? "不明"),
            ("macOS", Self.macOSVersionNumberText),
            ("チップ", systemProfilerHardwareInfo["Chip"] ?? Self.sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"),
            ("処理能力", Self.processingCapabilityText(from: systemProfilerHardwareInfo)),
            ("メモリ", systemProfilerHardwareInfo["Memory"] ?? Self.formatMemoryGigabytes(Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)),
            ("ストレージ", Self.storageUsageText())
        ]
    }

    var modelListSourceFilterOptions: [String] {
        ["All", "Downloaded", "Local", "HF ID", "Advanced"]
    }

    var visibleModels: [ModelConfig] {
        let sourceFiltered = modelListSourceFilter == "All"
            ? models
            : models.filter { sourceLabel(for: $0) == modelListSourceFilter }
        let query = modelListSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty
            ? sourceFiltered
            : sourceFiltered.filter { model in
                model.displayName.localizedCaseInsensitiveContains(query)
                    || model.modelID.localizedCaseInsensitiveContains(query)
                    || model.family.localizedCaseInsensitiveContains(query)
                    || model.quantization.localizedCaseInsensitiveContains(query)
                    || model.notes.localizedCaseInsensitiveContains(query)
            }

        return sortedModels(filtered)
    }

    func sourceLabel(for model: ModelConfig) -> String {
        if ModelAvailabilityPathFormatter.localPathCandidate(for: model) != nil {
            return model.notes.localizedCaseInsensitiveContains("downloaded") ? "Downloaded" : "Local"
        }
        return model.modelID.contains("/") ? "HF ID" : "Advanced"
    }

    func sortModelsRequested(by key: String) {
        if modelSortKey == key {
            isModelSortAscending.toggle()
        } else {
            modelSortKey = key
            isModelSortAscending = true
        }
    }

    func sortIndicator(for key: String) -> String {
        guard modelSortKey == key else { return "" }
        return isModelSortAscending ? " ▲" : " ▼"
    }

    func toggleReasoning(for model: ModelConfig, isEnabled: Bool) {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[index].enableThinking = isEnabled
        do {
            try settingsStore.save(models: models)
            appendLog("[model] reasoning \(isEnabled ? "enabled" : "disabled") for \(model.displayName).")
        } catch {
            appendLog("[model] warning: failed to save reasoning setting: \(error.localizedDescription)")
        }
    }

    func canStartModel(_ model: ModelConfig) -> Bool {
        blockingStartIssue(for: model) == nil
    }

    func startRequested(for model: ModelConfig) {
        selectedModelID = model.id
        startRequested()
    }

    func restartRequested(for model: ModelConfig) {
        selectedModelID = model.id
        restartRequested()
    }

    func moveModelUp(_ model: ModelConfig) {
        moveModel(model, offset: -1)
    }

    func moveModelDown(_ model: ModelConfig) {
        moveModel(model, offset: 1)
    }

    func canMoveModelUp(_ model: ModelConfig) -> Bool {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return false }
        return index > 0
    }

    func canMoveModelDown(_ model: ModelConfig) -> Bool {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return false }
        return index < models.index(before: models.endIndex)
    }

    func moveModel(withID draggedModelID: ModelConfig.ID, before targetModelID: ModelConfig.ID) {
        guard draggedModelID != targetModelID,
              let sourceIndex = models.firstIndex(where: { $0.id == draggedModelID }),
              let targetIndex = models.firstIndex(where: { $0.id == targetModelID }) else {
            return
        }

        let movedModel = models.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        models.insert(movedModel, at: adjustedTargetIndex)
        do {
            try settingsStore.save(models: models)
            appendLog("[model] reordered \(movedModel.displayName).")
        } catch {
            appendLog("[model] warning: failed to save model order: \(error.localizedDescription)")
        }
    }

    func isAutoUnloadEnabled(for model: ModelConfig) -> Bool {
        autoUnloadEnabledByModelID[model.id] ?? false
    }

    func setAutoUnloadEnabled(_ isEnabled: Bool, for model: ModelConfig) {
        autoUnloadEnabledByModelID[model.id] = isEnabled
    }

    func autoUnloadMinutes(for model: ModelConfig) -> Int {
        autoUnloadMinutesByModelID[model.id] ?? 30
    }

    func setAutoUnloadMinutes(_ minutes: Int, for model: ModelConfig) {
        autoUnloadMinutesByModelID[model.id] = min(max(minutes, 1), 999)
    }

    func autoUnloadText(for model: ModelConfig) -> String {
        isAutoUnloadEnabled(for: model) ? "\(autoUnloadMinutes(for: model))分" : "OFF"
    }

    func reasoningText(for model: ModelConfig) -> String {
        model.enableThinking ? "ON" : "OFF"
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

    var filteredHuggingFacePreviewFiles: [HuggingFaceDownloadPreviewFile] {
        huggingFaceFilePreview.files.filter { file in
            Self.shouldIncludePreviewFile(
                file.path,
                includePatterns: Self.patternList(from: huggingFaceDownloadDraft.includePatterns),
                excludePatterns: Self.patternList(from: huggingFaceDownloadDraft.excludePatterns)
            )
        }
    }

    var selectedHuggingFacePreviewFiles: [HuggingFaceDownloadPreviewFile] {
        filteredHuggingFacePreviewFiles.filter { selectedHuggingFacePreviewFileIDs.contains($0.id) }
    }

    var huggingFaceSelectedPreviewSummary: String {
        let files = huggingFaceDownloadDraft.useSelectedPreviewFiles ? selectedHuggingFacePreviewFiles : filteredHuggingFacePreviewFiles
        if files.isEmpty { return "No preview files selected." }
        let total = files.compactMap(\.size).reduce(Int64(0), +)
        let hasUnknown = files.contains { $0.size == nil }
        let sizeText = hasUnknown ? "unknown size" : ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return "\(files.count) files • \(sizeText)"
    }

    var visibleHuggingFaceSearchResults: [HuggingFaceSearchResult] {
        showOnlyMLXLikelySearchResults
            ? huggingFaceSearchResults.filter(\.isMLXLikely)
            : huggingFaceSearchResults
    }

    var canRunSpeedTest: Bool {
        connectionTargetSummary.isActiveTarget && !isSpeedTestRunning
    }

    var speedTestDisabledReason: String {
        if isSpeedTestRunning { return "Speed Test is already running." }
        if !connectionTargetSummary.isActiveTarget { return "Start or adopt a server before running Speed Test." }
        return "Ready."
    }

    var stopDisabledReason: String {
        canStopManagedServer ? "Ready." : "No managed server is running."
    }

    var restartDisabledReason: String {
        canRestartManagedServer ? "Ready." : "Start a managed server before Restart. External server context cannot be restarted here."
    }

    var selectedBlockingStartIssue: String? {
        guard let selectedModel else { return "Select a model before Start." }
        return blockingStartIssue(for: selectedModel)
    }

    private func blockingStartIssue(for model: ModelConfig) -> String? {
        if executableSafetyText != "OK" { return executableSafetyText }
        let modelSafety = modelIdentitySafetyText(for: model)
        if modelSafety.localizedCaseInsensitiveContains("Missing") { return modelSafety }
        let portSafety = portSafetyText(host: model.host, port: model.serverPort)
        if portSafety != "Available" { return "Server port: \(portSafety)" }
        return nil
    }

    var canStartSelectedModel: Bool {
        selectedBlockingStartIssue == nil
    }

    var startActionReason: String {
        selectedBlockingStartIssue ?? "Ready."
    }

    var integratedActionStateSummary: String {
        [
            "Start: \(startActionReason)",
            "Stop: \(stopDisabledReason)",
            "Restart: \(restartDisabledReason)",
            "Speed Test: \(speedTestDisabledReason)"
        ].joined(separator: "  ")
    }

    var selectedModelSafetyRows: [(String, String)] {
        guard let selectedModel else {
            return [("Selected model", "Missing")]
        }
        return [
            ("Executable", executableSafetyText),
            ("Model", modelIdentitySafetyText(for: selectedModel)),
            ("Server port", portSafetyText(host: selectedModel.host, port: selectedModel.serverPort)),
            ("Duplicate", duplicateProfileWarning(for: selectedModel) ?? "OK"),
            ("Runtime edit", runtimeEditingSafetyText(for: selectedModel))
        ]
    }

    var selectedModelSafetySummary: String {
        let warningCount = selectedModelSafetyRows.filter { !$0.1.localizedCaseInsensitiveContains("OK") && !$0.1.localizedCaseInsensitiveContains("Available") && !$0.1.localizedCaseInsensitiveContains("Ready") }.count
        return warningCount == 0 ? "Safety: OK" : "Safety: \(warningCount) warning(s)"
    }

    var selectedServerPortSafetyText: String {
        guard let selectedModel else { return "No model selected" }
        return portSafetyText(host: selectedModel.host, port: selectedModel.serverPort)
    }


    var selectedModelIdentityDetailText: String {
        guard let selectedModel else { return "No model selected" }
        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: selectedModel) {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return "Local path exists: \(ModelAvailabilityPathFormatter.compact(path: localPath))"
            }
            return "Missing local path: \(ModelAvailabilityPathFormatter.compact(path: localPath))"
        }
        if selectedModel.modelID.contains("https://huggingface.co/") {
            return "Needs review: paste owner/model instead of a full URL when possible."
        }
        if selectedModel.modelID.split(separator: "/").count == 2 {
            return "HF ID format looks valid."
        }
        return "Needs review: expected local path or owner/model HF ID."
    }

    var copyableSafetySummary: String {
        (["Model Operations Safety", "Runtime: \(runtimeState.title)", "Selected: \(selectedModelIdentifier)"] + selectedModelSafetyRows.map { row in
            "\(row.0): \(row.1)"
        } + ["Recovery: \(failedStartRecoverySummary)"]).joined(separator: "\n")
    }

    var failedStartRecoverySummary: String {
        switch runtimeState {
        case let .error(message):
            return recoveryGuidance(for: message)
        case let .portBusy(host, port):
            return "Port busy at \(host):\(port). Stop the conflicting process or choose another port."
        case let .portCheckFailed(_, _, message):
            return recoveryGuidance(for: message)
        case let .readyCheckFailed(_, _, message):
            return recoveryGuidance(for: message)
        default:
            return "No failed start recovery needed."
        }
    }

    private var executableSafetyText: String {
        let executablePath = settings.mlxServerExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else { return "Missing executable path" }
        return FileManager.default.isExecutableFile(atPath: executablePath) ? "OK" : "Missing or not executable"
    }

    private func modelIdentitySafetyText(for model: ModelConfig) -> String {
        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) {
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory) && isDirectory.boolValue
                ? "OK local path"
                : "Missing local path"
        }
        return model.modelID.contains("/") ? "Needs review: HF ID" : "Needs review"
    }

    private func portSafetyText(host: String, port: Int) -> String {
        switch portChecker.check(host: host, port: port) {
        case .available:
            return "Available"
        case .busy:
            return "Busy"
        case let .invalidInput(message):
            return "Invalid: \(message)"
        case let .failed(_, _, message):
            return "Check failed: \(message)"
        }
    }

    func duplicateProfileWarning(for model: ModelConfig) -> String? {
        let duplicateName = models.contains { $0.id != model.id && $0.displayName == model.displayName }
        let duplicateModelID = models.contains { $0.id != model.id && $0.modelID == model.modelID }
        let duplicateEndpoint = models.contains { $0.id != model.id && $0.host == model.host && $0.serverPort == model.serverPort }
        if duplicateName { return "Duplicate display name" }
        if duplicateModelID { return "Duplicate model ID" }
        if duplicateEndpoint { return "Duplicate endpoint" }
        return nil
    }

    func runtimeEditingSafetyText(for model: ModelConfig) -> String {
        guard isManagedProcessRunning, model.id == runningModelID else { return "Ready" }
        return "Stop before runtime-critical edits"
    }

    private func recoveryGuidance(for message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("executable") { return "Executable problem. Check Settings and run Diagnostics." }
        if lower.contains("model path") || lower.contains("missing") { return "Model problem. Check the selected model path or Hugging Face ID." }
        if lower.contains("port") { return "Port problem. Check port safety or choose another port." }
        if lower.contains("permission") { return "Permission problem. Check executable and model folder permissions." }
        if lower.contains("timed out") || lower.contains("ready") { return "Readiness problem. Wait longer, run Ready Check, or inspect logs." }
        return "Inspect logs and copy troubleshooting context."
    }

    var latestSpeedTestSummary: String {
        latestBenchmarkResult?.summary ?? latestSpeedTestMessage
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
        return "Runs: \(benchmarkHistory.count), best \(best), average \(average), failed \(failedCount)"
    }

    var selectedLaunchCommandPreview: String {
        guard let selectedModel else {
            return "Select a profile to preview the launch command."
        }
        return LaunchCommandBuilder.command(
            executablePath: settings.mlxServerExecutablePath,
            model: selectedModel
        )
    }

    var selectedAdvancedLaunchOptionsSummary: String {
        guard let options = selectedModel?.advancedLaunchOptions, !options.isEmpty else {
            return "No advanced launch options configured."
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
        return "\(runtimeState.title) · \(mismatch) · \(restart) · \(latest)"
    }

    var benchmarkFailureGuidance: String? {
        guard let latestBenchmarkResult, latestBenchmarkResult.phase == .failed else {
            return nil
        }
        let message = latestBenchmarkResult.message.lowercased()
        if !connectionTargetSummary.isActiveTarget {
            return "Server is not running. Press Start before Speed Test."
        }
        if runtimeSelectionWarning != nil {
            return "Selected profile differs from the running profile. Stop → Start or Restart before measuring."
        }
        if message.contains("timed out") {
            return "The server may still be loading the model or the model may be too heavy. Wait, then retry."
        }
        if message.contains("http") {
            return "The endpoint responded but was not ready. Confirm the port and run Ready Check again."
        }
        return "Check runtime diagnostics and logs, then retry Speed Test."
    }

    var latestFailedHuggingFaceDownloadQueueEntry: HuggingFaceDownloadQueueEntry? {
        huggingFaceDownloadQueue.first { $0.phase == .failed }
    }

    var currentRecoveryIssue: RecoveryIssue {
        if let failedDownload = latestFailedHuggingFaceDownloadQueueEntry {
            return downloadRecoveryIssue(from: failedDownload)
        }
        return runtimeRecoveryIssue
    }

    private var runtimeRecoveryIssue: RecoveryIssue {
        switch runtimeState {
        case let .error(message):
            return recoveryIssue(from: message, relatedLogLine: latestImportantLogEntry?.line)
        case let .portBusy(host, port):
            return RecoveryIssue(
                category: .portBusy,
                severity: .failed,
                title: "Port busy",
                detail: "\(host):\(port) is already in use. Stop the conflicting process manually or choose another port.",
                relatedLogLine: latestImportantLogEntry?.line,
                actions: actions(for: .portBusy)
            )
        case let .portCheckFailed(_, _, message), let .readyCheckFailed(_, _, message):
            return recoveryIssue(from: message, relatedLogLine: latestImportantLogEntry?.line)
        default:
            return .none
        }
    }

    private func downloadRecoveryIssue(from entry: HuggingFaceDownloadQueueEntry) -> RecoveryIssue {
        let category = classifyFailure(entry.message)
        return RecoveryIssue(
            category: category,
            severity: .failed,
            title: category.title,
            detail: "Download failed for \(entry.repositoryID): \(entry.message)",
            relatedLogLine: latestImportantLogEntry?.line,
            actions: actions(for: category)
        )
    }

    private func recoveryIssue(from message: String, relatedLogLine: String?) -> RecoveryIssue {
        let category = classifyFailure(message)
        return RecoveryIssue(
            category: category,
            severity: category == .unknown ? .review : .failed,
            title: category.title,
            detail: recoveryGuidance(for: message),
            relatedLogLine: relatedLogLine,
            actions: actions(for: category)
        )
    }

    private func classifyFailure(_ message: String) -> RecoveryIssueCategory {
        let lower = message.lowercased()
        if lower.contains("not executable") { return .executableNotExecutable }
        if lower.contains("executable") || lower.contains("mlx_lm.server") { return .executableMissing }
        if lower.contains("model path") || lower.contains("missing local path") || lower.contains("model missing") { return .modelPathMissing }
        if lower.contains("port") || lower.contains("address already") { return .portBusy }
        if lower.contains("permission") || lower.contains("operation not permitted") { return .permissionDenied }
        if lower.contains("timed out") || lower.contains("ready") || lower.contains("readiness") { return .readinessTimeout }
        if lower.contains("exited") || lower.contains("terminated") { return .processExitedEarly }
        if lower.contains("hf") && lower.contains("not found") { return .huggingFaceCLIMissing }
        if lower.contains("gated") || lower.contains("unauthorized") || lower.contains("forbidden") { return .huggingFaceAccess }
        if lower.contains("network") || lower.contains("connection") || lower.contains("dns") { return .network }
        if lower.contains("destination") || lower.contains("disk") || lower.contains("space") || lower.contains("file exists") { return .destination }
        return .unknown
    }

    private func actions(for category: RecoveryIssueCategory) -> [RecoveryAction] {
        switch category {
        case .none:
            return []
        case .executableMissing, .executableNotExecutable:
            return [
                RecoveryAction(kind: .openSettings, title: "Open Settings", detail: "Set mlx_lm.server executable path.", isPrimary: true),
                RecoveryAction(kind: .runDiagnostics, title: "Run Diagnostics", detail: "Check setup readiness.", isPrimary: false)
            ]
        case .modelPathMissing:
            return [
                RecoveryAction(kind: .editProfile, title: "Edit Profile", detail: "Fix model path or model ID.", isPrimary: true),
                RecoveryAction(kind: .openDownloads, title: "Open Downloads", detail: "Download or restore a model.", isPrimary: false)
            ]
        case .portBusy:
            return [
                RecoveryAction(kind: .checkPort, title: "Check Port", detail: "Refresh port status.", isPrimary: true),
                RecoveryAction(kind: .editProfile, title: "Change Port", detail: "Edit the selected profile port.", isPrimary: false)
            ]
        case .permissionDenied:
            return [
                RecoveryAction(kind: .openSettings, title: "Open Settings", detail: "Review executable path.", isPrimary: true),
                RecoveryAction(kind: .openLogs, title: "Open Logs", detail: "Review permission error logs.", isPrimary: false)
            ]
        case .readinessTimeout, .processExitedEarly:
            return [
                RecoveryAction(kind: .runReadyCheck, title: "Run Ready Check", detail: "Check /v1/models again.", isPrimary: true),
                RecoveryAction(kind: .openLogs, title: "Open Logs", detail: "Inspect runtime logs.", isPrimary: false)
            ]
        case .huggingFaceCLIMissing:
            return [
                RecoveryAction(kind: .openDownloads, title: "Open Downloads", detail: "Check HF CLI status.", isPrimary: true),
                RecoveryAction(kind: .runDiagnostics, title: "Run Diagnostics", detail: "Review setup issues.", isPrimary: false)
            ]
        case .huggingFaceAccess, .network, .destination:
            return [
                RecoveryAction(kind: .openDownloads, title: "Open Downloads", detail: "Restore failed download form.", isPrimary: true),
                RecoveryAction(kind: .retryDownload, title: "Retry Download", detail: "Retry the latest failed download.", isPrimary: false)
            ]
        case .unknown:
            return [
                RecoveryAction(kind: .copyTroubleshooting, title: "Copy Troubleshooting", detail: "Copy context for manual review.", isPrimary: true),
                RecoveryAction(kind: .openLogs, title: "Open Logs", detail: "Inspect logs.", isPrimary: false)
            ]
        }
    }

    var benchmarkCopyText: String {
        guard !benchmarkHistory.isEmpty else {
            return "No benchmark results in this session."
        }
        return (["Benchmark Summary", benchmarkSummaryText] + benchmarkHistory.prefix(10).map { result in
            "- \(result.timestamp): \(result.modelID) @ \(result.baseURL): \(result.summary)"
        }).joined(separator: "\n")
    }

    var latestBenchmarkCopyText: String {
        guard let latestBenchmarkResult else {
            return "No benchmark result in this session."
        }
        return "Latest Benchmark\nModel: \(latestBenchmarkResult.modelID)\nEndpoint: \(latestBenchmarkResult.baseURL)\nSelected: \(latestBenchmarkResult.selectedProfileName)\nRunning: \(latestBenchmarkResult.runningProfileText)\nStatus: \(latestBenchmarkResult.phase.rawValue)\nLatency: \(latestBenchmarkResult.latencyText)\nHTTP: \(latestBenchmarkResult.httpStatusText)\nMessage: \(latestBenchmarkResult.message)"
    }

    var benchmarkTroubleshootingCopyText: String {
        [
            "Benchmark Troubleshooting",
            "Runtime: \(runtimeState.title)",
            "Target: \(connectionTargetSummary.targetType)",
            "Base URL: \(baseURL)",
            "Selected model: \(selectedModelIdentifier)",
            "Running model: \(runningModelID ?? "Not running")",
            "Restart required: \(restartRequired ? "Yes" : "No")",
            "Latest benchmark: \(latestBenchmarkResult?.summary ?? "Not run")",
            "Guidance: \(benchmarkFailureGuidance ?? "No failure guidance")"
        ].joined(separator: "\n")
    }

    var logCategoryFilterOptions: [String] {
        ["All"] + Array(Set(logEntries.map(\.category))).sorted()
    }

    var visibleLogEntries: [LogEntry] {
        logCategoryFilter == "All"
            ? logEntries
            : logEntries.filter { $0.category == logCategoryFilter }
    }

    var latestImportantLogEntry: LogEntry? {
        logEntries.reversed().first { entry in
            entry.message.localizedCaseInsensitiveContains("failed")
                || entry.message.localizedCaseInsensitiveContains("warning")
                || entry.category.localizedCaseInsensitiveContains("error")
        }
    }

    var runtimeSelectionWarning: String? {
        guard let runningModelID, let selectedModelID, runningModelID != selectedModelID else {
            return nil
        }
        return "Selected model differs from the running model. Stop or restart before expecting runtime changes."
    }

    var huggingFaceDownloadQueueSummary: String {
        guard !huggingFaceDownloadQueue.isEmpty else {
            return "No downloads in this session."
        }
        let completed = huggingFaceDownloadQueue.filter { $0.phase == .completed }.count
        let failed = huggingFaceDownloadQueue.filter { $0.phase == .failed }.count
        let cancelled = huggingFaceDownloadQueue.filter { $0.phase == .cancelled }.count
        return "Session downloads: \(huggingFaceDownloadQueue.count), completed \(completed), failed \(failed), cancelled \(cancelled)"
    }

    var canRetryHuggingFaceDownload: Bool {
        !isHuggingFaceDownloadRunning && (huggingFaceDownloadStatus.phase == .failed || huggingFaceDownloadStatus.phase == .cancelled)
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
            return "MLX管理RSS: 外部サーバー対象外"
        }

        guard let memoryUsageGB else {
            return "MLX管理RSS: 未稼働"
        }

        return "MLX管理RSS: \(Self.formatMemoryGigabytes(memoryUsageGB))"
    }

    var integratedMemoryUsageFraction: Double {
        guard let systemMemorySnapshot = activeSystemMemorySnapshot,
              let usedGigabytes = systemMemorySnapshot.usedGigabytes,
              systemMemorySnapshot.totalGigabytes > 0 else {
            return 0
        }

        return min(max(usedGigabytes / systemMemorySnapshot.totalGigabytes, 0), 1)
    }

    var integratedMemoryUsagePercentText: String {
        guard activeSystemMemorySnapshot != nil else { return "0%" }
        return "\(Int(integratedMemoryUsageFraction * 100))%"
    }

    var memoryTotalText: String {
        guard let systemMemorySnapshot = activeSystemMemorySnapshot else {
            return "合計: 未取得"
        }

        return "合計: \(Self.formatMemoryGigabytes(systemMemorySnapshot.totalGigabytes))"
    }

    var memoryAvailableText: String {
        guard let availableGigabytes = activeSystemMemorySnapshot?.availableGigabytes else {
            return "未取得"
        }

        return Self.formatMemoryGigabytes(availableGigabytes)
    }

    var memoryMLXProcessText: String {
        guard !runtimeState.isExternalServerContext else { return "対象外" }
        guard let memoryBreakdown else { return Self.formatMemoryGigabytes(0) }

        return Self.formatMemoryGigabytes(memoryBreakdown.managedProcessGigabytes)
    }

    var memoryOtherProcessesText: String {
        guard let usedGigabytes = activeSystemMemorySnapshot?.usedGigabytes else {
            return "未取得"
        }

        let managedProcessGigabytes = memoryBreakdown?.managedProcessGigabytes ?? 0
        return Self.formatMemoryGigabytes(max(usedGigabytes - managedProcessGigabytes, 0))
    }

    var memoryBreakdownUpdateText: String {
        memoryBreakdown == nil ? "管理サーバー起動後に更新開始" : "1秒ごとに更新 / 直近60秒"
    }

    var memoryBreakdownAccuracyText: String {
        "mlx-lmは管理プロセスRSS、その他/空き容量はvm_statベース"
    }

    var memoryMLXProcessFraction: Double {
        memoryFraction(memoryBreakdown?.managedProcessGigabytes)
    }

    var memoryOtherProcessesFraction: Double {
        guard let usedGigabytes = activeSystemMemorySnapshot?.usedGigabytes else { return 0 }
        let managedProcessGigabytes = memoryBreakdown?.managedProcessGigabytes ?? 0
        return memoryFraction(max(usedGigabytes - managedProcessGigabytes, 0))
    }

    var memoryAvailableFraction: Double {
        memoryFraction(activeSystemMemorySnapshot?.availableGigabytes)
    }

    var integratedCPUUsageText: String {
        guard let cpuUsagePercent else { return "未取得" }
        return String(format: "%.0f%%", cpuUsagePercent)
    }

    var integratedGPUUsageText: String {
        guard let gpuUsagePercent else { return "非対応" }
        return String(format: "%.0f%%", gpuUsagePercent)
    }

    var integratedUptimeText: String {
        guard let managedServerStartedAt,
              runningModelID != nil else {
            return "-"
        }

        let elapsed = max(Int(Date().timeIntervalSince(managedServerStartedAt)), 0)
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        return String(format: "%02d時間%02d分%02d秒", hours, minutes, seconds)
    }

    func integratedStatusText(for model: ModelConfig) -> String {
        interactiveStatusText(for: model, isHovered: false)
    }

    func interactiveStatusText(for model: ModelConfig, isHovered: Bool) -> String {
        if model.id == runningModelID {
            switch runtimeState {
            case .starting, .loading, .checkingReady:
                return "ロード中"
            case .stopping:
                return "アンロード中"
            default:
                return isHovered ? "アンロード" : "ロード済"
            }
        }

        return isHovered ? "ロード" : "準備完了"
    }

    func isModelLoaded(_ model: ModelConfig) -> Bool {
        model.id == runningModelID && !isModelTransitioning(model)
    }

    func isModelTransitioning(_ model: ModelConfig) -> Bool {
        guard model.id == runningModelID else { return false }
        switch runtimeState {
        case .starting, .loading, .checkingReady, .stopping:
            return true
        default:
            return false
        }
    }

    func canUseStatusAction(for model: ModelConfig) -> Bool {
        if model.id == runningModelID {
            return canStopManagedServer
        }

        return canStartModel(model)
    }

    func statusActionRequested(for model: ModelConfig) {
        if model.id == runningModelID {
            stopRequested()
        } else {
            startRequested(for: model)
        }
    }

    func modelSizeText(for model: ModelConfig) -> String {
        guard let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model),
              let gigabytes = memoryMonitor.estimatedModelStorageGigabytes(modelDirectoryPath: modelDirectoryPath) else {
            return "-"
        }

        return Self.formatMemoryGigabytes(gigabytes)
    }

    func integratedStatusDetail(for model: ModelConfig) -> String {
        integratedStatusText(for: model)
    }


    func integratedMemoryText(for model: ModelConfig) -> String {
        guard model.id == runningModelID,
              let memoryUsageGB else {
            return "-"
        }

        return Self.formatMemoryGigabytes(memoryUsageGB)
    }

    func integratedLatestUseText(for model: ModelConfig) -> String {
        guard model.id == runningModelID else { return "-" }
        if let latestBenchmarkResult {
            return latestBenchmarkResult.latencyText
        }
        return runtimeEvents.first?.category ?? "active"
    }

    func integratedStopModeText(for model: ModelConfig) -> String {
        isAutoUnloadEnabled(for: model) ? "ON / \(autoUnloadMinutes(for: model))分" : "OFF"
    }

    private func sortedModels(_ input: [ModelConfig]) -> [ModelConfig] {
        guard let modelSortKey else { return input }

        let sorted = input.sorted { lhs, rhs in
            switch modelSortKey {
            case "name":
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            case "size":
                return (modelSizeGigabytes(for: lhs) ?? -1) < (modelSizeGigabytes(for: rhs) ?? -1)
            case "status":
                return integratedStatusText(for: lhs) < integratedStatusText(for: rhs)
            case "port":
                return lhs.serverPort < rhs.serverPort
            case "memory":
                return memoryValueForSort(lhs) < memoryValueForSort(rhs)
            case "autoUnload":
                return autoUnloadSortValue(lhs) < autoUnloadSortValue(rhs)
            case "reasoning":
                return reasoningText(for: lhs) < reasoningText(for: rhs)
            default:
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }

        return isModelSortAscending ? sorted : sorted.reversed()
    }

    private func modelSizeGigabytes(for model: ModelConfig) -> Double? {
        guard let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
            return nil
        }

        return memoryMonitor.estimatedModelStorageGigabytes(modelDirectoryPath: modelDirectoryPath)
    }

    private func memoryValueForSort(_ model: ModelConfig) -> Double {
        model.id == runningModelID ? (memoryUsageGB ?? -1) : -1
    }

    private func autoUnloadSortValue(_ model: ModelConfig) -> Int {
        isAutoUnloadEnabled(for: model) ? autoUnloadMinutes(for: model) : Int.max
    }

    private var activeSystemMemorySnapshot: SystemMemorySnapshot? {
        memoryBreakdown?.system ?? systemMemorySnapshot
    }

    private func memoryFraction(_ value: Double?) -> Double {
        guard let value,
              let totalGigabytes = activeSystemMemorySnapshot?.totalGigabytes,
              totalGigabytes > 0 else {
            return 0
        }

        return min(max(value / totalGigabytes, 0), 1)
    }

    private static func formatMemoryGigabytes(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.1f GB", value)
        }

        return String(format: "%.2f GB", value)
    }

    private static var macOSVersionNumberText: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static func processingCapabilityText(from hardwareInfo: [String: String]) -> String {
        let rawCoreText = hardwareInfo["Total Number of Cores"] ?? String(ProcessInfo.processInfo.activeProcessorCount)
        let totalCoreText = rawCoreText.split(separator: " ").first.map(String.init) ?? rawCoreText
        return "\(totalCoreText) CPU"
    }

    nonisolated private static func loadSystemProfilerHardwareInfo() -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPHardwareDataType", "SPDisplaysDataType"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return [:]
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return [:]
        }

        return Self.parseSystemProfilerHardwareInfo(output)
    }

    nonisolated private static func parseSystemProfilerHardwareInfo(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        var isHardwareSection = false
        var isDisplaysSection = false
        var didCaptureCPUCores = false
        var didCaptureGPUCores = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "Hardware:" {
                isHardwareSection = true
                isDisplaysSection = false
                continue
            }
            if trimmed == "Graphics/Displays:" {
                isHardwareSection = false
                isDisplaysSection = true
                continue
            }
            guard let separatorIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }

            if isHardwareSection {
                if ["Model Name", "Model Identifier", "Chip", "Memory"].contains(key) {
                    result[key] = value
                } else if key == "Total Number of Cores", !didCaptureCPUCores {
                    result[key] = value
                    didCaptureCPUCores = true
                }
            } else if isDisplaysSection, key == "Total Number of Cores", !didCaptureGPUCores {
                result["GPU Cores"] = value
                didCaptureGPUCores = true
            }
        }
        return result
    }

    nonisolated private static func sysctlString(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0,
              size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func storageUsageText() -> String {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let size = attributes[.systemSize] as? NSNumber,
                  let free = attributes[.systemFreeSize] as? NSNumber else {
                return "不明"
            }

            let usedBytes = max(size.doubleValue - free.doubleValue, 0)
            return "\(formatStorageBytes(usedBytes)) / \(formatStorageBytes(size.doubleValue))"
        } catch {
            return "不明"
        }
    }

    nonisolated private static func formatStorageBytes(_ bytes: Double) -> String {
        let gigabytes = bytes / 1_073_741_824
        if gigabytes >= 1024 {
            return String(format: "%.1f TB", gigabytes / 1024)
        }

        return String(format: "%.0f GB", gigabytes)
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

    private func moveModel(_ model: ModelConfig, offset: Int) {
        guard let currentIndex = models.firstIndex(where: { $0.id == model.id }) else {
            return
        }

        let targetIndex = currentIndex + offset
        guard models.indices.contains(targetIndex) else {
            return
        }

        models.swapAt(currentIndex, targetIndex)
        do {
            try settingsStore.save(models: models)
            appendLog("[model] moved \(model.displayName) to row \(targetIndex + 1).")
        } catch {
            appendLog("[model] warning: failed to save model order: \(error.localizedDescription)")
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

    func runSpeedTestRequested() {
        guard canRunSpeedTest else {
            latestSpeedTestMessage = "Start the server before running Speed Test."
            appendLog("[benchmark] speed test skipped: no active connection target.")
            return
        }

        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        let profileID = selectedModel?.id ?? selectedModelIdentifier
        let selectedProfileName = selectedModel?.displayName ?? selectedModelIdentifier
        let runningProfileID = runningModelID
        let modelID = selectedModelIdentifier
        let targetBaseURL = baseURL
        isSpeedTestRunning = true
        latestSpeedTestMessage = "Running /v1/models readiness latency test..."
        latestSpeedTestDurationMS = nil
        appendRuntimeEvent(category: "Benchmark", message: "Speed Test started for \(host):\(port)")
        appendLog("[benchmark] speed test started: http://\(host):\(port)/v1/models")

        Task {
            let startedAt = Date()
            let result = await readyChecker.check(host: host, port: port)
            let elapsedMS = Date().timeIntervalSince(startedAt) * 1000
            latestSpeedTestDurationMS = elapsedMS
            let benchmarkResult: BenchmarkResult
            switch result {
            case let .ready(url, statusCode):
                latestSpeedTestMessage = "Success: \(url.absoluteString) returned HTTP \(statusCode)."
                benchmarkResult = BenchmarkResult(
                    profileID: profileID,
                    modelID: modelID,
                    baseURL: targetBaseURL,
                    phase: .success,
                    readinessLatencyMS: elapsedMS,
                    statusCode: statusCode,
                    selectedProfileName: selectedProfileName,
                    runningProfileID: runningProfileID,
                    message: "HTTP \(statusCode) from /v1/models"
                )
                appendLog("[benchmark] speed test succeeded in \(Int(elapsedMS)) ms.")
            case let .notReady(_, statusCode):
                latestSpeedTestMessage = "Failed: /v1/models returned HTTP \(statusCode)."
                benchmarkResult = BenchmarkResult(
                    profileID: profileID,
                    modelID: modelID,
                    baseURL: targetBaseURL,
                    phase: .failed,
                    readinessLatencyMS: elapsedMS,
                    statusCode: statusCode,
                    selectedProfileName: selectedProfileName,
                    runningProfileID: runningProfileID,
                    message: "HTTP \(statusCode) from /v1/models"
                )
                appendLog("[benchmark] speed test failed in \(Int(elapsedMS)) ms: HTTP \(statusCode).")
            case let .invalidInput(message):
                latestSpeedTestMessage = "Failed: \(message)"
                benchmarkResult = BenchmarkResult(profileID: profileID, modelID: modelID, baseURL: targetBaseURL, phase: .failed, readinessLatencyMS: nil, selectedProfileName: selectedProfileName, runningProfileID: runningProfileID, message: message)
                appendLog("[benchmark] speed test failed: \(message)")
            case let .failed(_, message):
                latestSpeedTestMessage = "Failed: \(message)"
                benchmarkResult = BenchmarkResult(profileID: profileID, modelID: modelID, baseURL: targetBaseURL, phase: .failed, readinessLatencyMS: elapsedMS, selectedProfileName: selectedProfileName, runningProfileID: runningProfileID, message: message)
                appendLog("[benchmark] speed test failed in \(Int(elapsedMS)) ms: \(message)")
            case .timedOut:
                latestSpeedTestMessage = "Failed: request timed out."
                benchmarkResult = BenchmarkResult(profileID: profileID, modelID: modelID, baseURL: targetBaseURL, phase: .failed, readinessLatencyMS: elapsedMS, selectedProfileName: selectedProfileName, runningProfileID: runningProfileID, message: "Request timed out")
                appendLog("[benchmark] speed test timed out after \(Int(elapsedMS)) ms.")
            }
            latestBenchmarkResult = benchmarkResult
            benchmarkHistory.insert(benchmarkResult, at: 0)
            appendRuntimeEvent(category: "Benchmark", message: benchmarkResult.summary)
            isSpeedTestRunning = false
        }
    }

    func checkReadyRequested() {
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        if !runtimeState.isExternalServerContext {
            runtimeState = .checkingReady(host: host, port: port)
        }
        appendRuntimeEvent(category: "Ready", message: "Ready Check started for \(host):\(port)")
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

    func chooseMLXServerExecutableRequested() {
        let panel = NSOpenPanel()
        panel.title = "Choose mlx_lm.server executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[settings] executable picker cancelled.")
            return
        }
        settings.mlxServerExecutablePath = url.path
        saveSettingsRequested()
        appendLog("[settings] executable path set to \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
    }

    func chooseLocalModelFolderRequested() {
        let panel = NSOpenPanel()
        panel.title = "Choose local model folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[profile] local model folder picker cancelled.")
            return
        }
        localModelPath = url.path
        if localModelDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            localModelDisplayName = url.lastPathComponent
        }
        appendLog("[profile] local model folder selected: \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
    }

    func previewHuggingFaceFilesRequested() {
        let preview = huggingFaceDownloadPreview
        guard let reference = preview.reference else {
            huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(isLoading: false, message: preview.message, files: [])
            return
        }

        huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(isLoading: true, message: "Fetching file list...", files: [])
        selectedHuggingFacePreviewFileIDs = []
        let revision = normalizedHuggingFaceRevision

        Task { [weak self] in
            await self?.fetchHuggingFaceFilePreview(repositoryID: reference.repositoryID, revision: revision)
        }
    }

    func toggleHuggingFacePreviewFile(_ file: HuggingFaceDownloadPreviewFile) {
        if selectedHuggingFacePreviewFileIDs.contains(file.id) {
            selectedHuggingFacePreviewFileIDs.remove(file.id)
        } else {
            selectedHuggingFacePreviewFileIDs.insert(file.id)
        }
    }

    func selectAllHuggingFacePreviewFiles() {
        selectedHuggingFacePreviewFileIDs = Set(filteredHuggingFacePreviewFiles.map(\.id))
    }

    func applyHuggingFaceMLXPreset() {
        huggingFaceDownloadDraft.includePatterns = "*.safetensors, *.json, tokenizer.*, *.model, *.txt"
        huggingFaceDownloadDraft.excludePatterns = "*.h5, *.onnx, *.msgpack, *.bin"
        appendLog("[hf] applied MLX model file filter preset.")
    }

    func applyHuggingFaceSafeTensorPreset() {
        huggingFaceDownloadDraft.includePatterns = "*.safetensors, *.json, tokenizer.*"
        huggingFaceDownloadDraft.excludePatterns = "*.bin, *.h5, *.onnx, *.msgpack"
        appendLog("[hf] applied safetensors-focused file filter preset.")
    }

    func clearHuggingFaceFileFilters() {
        huggingFaceDownloadDraft.includePatterns = ""
        huggingFaceDownloadDraft.excludePatterns = ""
        appendLog("[hf] cleared file filters.")
    }

    func clearHuggingFacePreviewSelection() {
        selectedHuggingFacePreviewFileIDs = []
    }

    private func fetchHuggingFaceFilePreview(repositoryID: String, revision: String) async {
        do {
            let files = try await huggingFaceRepositoryFileService.fetchFiles(
                repositoryID: repositoryID,
                revision: revision,
                token: huggingFaceCredentialStore.readValue()
            )
            huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(
                isLoading: false,
                message: files.isEmpty ? "No downloadable files found." : "Preview ready. Select files or adjust filters before downloading.",
                files: files
            )
            selectedHuggingFacePreviewFileIDs = Set(files.map(\.id))
            appendLog("[hf] preview fetched \(files.count) files for \(repositoryID).")
        } catch {
            huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(isLoading: false, message: error.localizedDescription, files: [])
            appendLog("[hf] preview failed: \(error.localizedDescription)")
        }
    }

    func chooseHuggingFaceDownloadDirectoryRequested() {
        let panel = NSOpenPanel()
        panel.title = "Choose Hugging Face download save directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[hf] download directory picker cancelled.")
            return
        }
        huggingFaceDownloadDraft.saveDirectory = url.path
        appendLog("[hf] download save directory selected: \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
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
                message: "Preparing",
                fileCount: huggingFaceDownloadDraft.useSelectedPreviewFiles ? selectedHuggingFacePreviewFiles.count : nil,
                downloadedBytes: nil,
                totalBytes: nil,
                speedBytesPerSecond: nil
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

    func restoreHuggingFaceDownloadForm(from entry: HuggingFaceDownloadQueueEntry) {
        huggingFaceDownloadDraft.source = entry.repositoryID
        let destinationURL = URL(fileURLWithPath: entry.destinationPath, isDirectory: true)
        huggingFaceDownloadDraft.saveDirectory = destinationURL.deletingLastPathComponent().path
        huggingFaceDownloadDraft.displayName = destinationURL.lastPathComponent
        huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
            phase: .waiting,
            message: "Restored download form from queue entry. Review it, then press Download or Retry.",
            repositoryID: entry.repositoryID,
            destinationPath: entry.destinationPath,
            progress: nil,
            outputLines: []
        )
        appendLog("[hf] restored download form from queue entry: \(entry.repositoryID)")
    }

    func copyHuggingFaceDownloadURL(from entry: HuggingFaceDownloadQueueEntry) {
        copyToPasteboard("https://huggingface.co/\(entry.repositoryID)")
        appendLog("[hf] copied queue entry URL for \(entry.repositoryID).")
    }

    func retryHuggingFaceDownloadRequested() {
        guard canRetryHuggingFaceDownload else {
            appendLog("[hf] retry skipped: no failed or cancelled download is ready to retry.")
            return
        }
        appendLog("[hf] retry requested for current download form.")
        startHuggingFaceDownloadRequested()
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

    func saveHuggingFaceAccessRequested() {
        let value = huggingFaceAccessInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            huggingFaceAccessMessage = "Enter a value before saving."
            return
        }
        huggingFaceCredentialStore.saveValue(value)
        huggingFaceAccessInput = ""
        refreshHuggingFaceAccessStatus()
    }

    func deleteHuggingFaceAccessRequested() {
        huggingFaceCredentialStore.deleteValue()
        refreshHuggingFaceAccessStatus()
    }

    func refreshAria2Status() {
        aria2Availability = Aria2AvailabilityChecker.check()
    }

    private func refreshHuggingFaceAccessStatus() {
        isHuggingFaceAccessSaved = huggingFaceCredentialStore.readValue() != nil
        huggingFaceAccessMessage = isHuggingFaceAccessSaved
            ? "Saved locally. The value is used for gated/private Hugging Face requests and is not shown again."
            : "No saved Hugging Face access value. Public repos can still be previewed."
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

    func editProfileRequested(for model: ModelConfig) {
        selectedModelID = model.id
        editProfileRequested()
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

    func deleteProfileRequested(for model: ModelConfig) {
        selectedModelID = model.id
        deleteProfileRequested()
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

    func copyBenchmarkSummary() {
        copyToPasteboard(benchmarkCopyText)
        appendLog("[benchmark] copied benchmark history summary.")
    }

    func copyLatestBenchmark() {
        copyToPasteboard(latestBenchmarkCopyText)
        appendLog("[benchmark] copied latest benchmark.")
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
            "MLX Server Manager Troubleshooting Summary",
            "Runtime: \(runtimeState.title)",
            "Target: \(connectionTargetSummary.baseURL)",
            "Selected model: \(selectedModelIdentifier)",
            "Recovery: \(currentRecoveryIssue.title) / \(currentRecoveryIssue.detail)",
            "Safety:",
            copyableSafetySummary,
            "Recent logs:",
            recentLogs.isEmpty ? "No logs" : recentLogs
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
        case .retryDownload:
            retryHuggingFaceDownloadRequested()
        case .restoreDownloadForm:
            if let entry = latestFailedHuggingFaceDownloadQueueEntry {
                restoreHuggingFaceDownloadForm(from: entry)
            }
        case .copyURL:
            if let entry = latestFailedHuggingFaceDownloadQueueEntry {
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
                    destinationPath: destinationPath,
                    revision: normalizedHuggingFaceRevision,
                    includePatterns: huggingFaceIncludePatternsForDownload(),
                    excludePatterns: Self.patternList(from: draft.excludePatterns),
                    authorizationValue: huggingFaceCredentialStore.readValue()
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
                let guidance = huggingFaceDownloadFailureGuidance(from: error)
                huggingFaceDownloadStatus.phase = .failed
                huggingFaceDownloadStatus.message = guidance
                updateHuggingFaceQueueEntry(queueEntryID, phase: .failed, message: guidance)
                appendLog("[hf] download failed: \(guidance)")
            }
            huggingFaceDownloadTask = nil
        }
    }

    private var normalizedHuggingFaceRevision: String {
        let value = huggingFaceDownloadDraft.revision.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "main" : value
    }

    private func huggingFaceIncludePatternsForDownload() -> [String] {
        if huggingFaceDownloadDraft.useSelectedPreviewFiles, !selectedHuggingFacePreviewFiles.isEmpty {
            return selectedHuggingFacePreviewFiles.map(\.path)
        }
        return Self.patternList(from: huggingFaceDownloadDraft.includePatterns)
    }

    nonisolated private static func patternList(from text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    nonisolated private static func shouldIncludePreviewFile(_ path: String, includePatterns: [String], excludePatterns: [String]) -> Bool {
        let included = includePatterns.isEmpty || includePatterns.contains { matchesGlob(path: path, pattern: $0) }
        let excluded = excludePatterns.contains { matchesGlob(path: path, pattern: $0) }
        return included && !excluded
    }

    nonisolated private static func matchesGlob(path: String, pattern: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*\\*", with: ".*")
            .replacingOccurrences(of: "\\*", with: "[^/]*")
            .replacingOccurrences(of: "\\?", with: "[^/]")
        let fullPattern = "^\(escaped)$"
        let basenamePattern = "^\(escaped)$"
        let basename = URL(fileURLWithPath: path).lastPathComponent
        return path.range(of: fullPattern, options: .regularExpression) != nil
            || basename.range(of: basenamePattern, options: .regularExpression) != nil
    }

    private func huggingFaceDownloadFailureGuidance(from error: Error) -> String {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        if lowercased.contains("command is not available") || lowercased.contains("no such file") {
            return "Hugging Face CLI was not found. Install `hf`, then press Retry CLI."
        }
        if lowercased.contains("401") || lowercased.contains("403") || lowercased.contains("gated") || lowercased.contains("unauthorized") {
            return "This may be gated or require authentication. Open the model page in a browser and confirm access."
        }
        if lowercased.contains("404") || lowercased.contains("not found") || lowercased.contains("invalid") {
            return "Repository was not found. Confirm the model ID or choose another search result."
        }
        if lowercased.contains("permission") || lowercased.contains("denied") {
            return "Permission denied. Choose another save folder or check folder permissions."
        }
        if lowercased.contains("network") || lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("could not resolve") {
            return "Network failure. Check the connection and retry the download."
        }
        if lowercased.contains("disk") || lowercased.contains("space") || lowercased.contains("no space") {
            return "Disk or destination problem. Check free space and the save folder."
        }
        return message
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
            enableThinking: selectedModel.enableThinking,
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
            startMemoryMonitoring(processIdentifier: launchResult.processIdentifier, model: selectedModel)
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
        managedServerStartedAt = Date()
        appendLog("[\(logPrefix)] running modelID: \(modelID)")
        logRestartRequiredIfNeeded()
    }

    private func clearRunningModel(logPrefix: String) {
        guard runningModelID != nil else {
            return
        }

        runningModelID = nil
        managedServerStartedAt = nil
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

    private func startMemoryMonitoring(processIdentifier: Int32, model: ModelConfig) {
        stopMemoryMonitoring(resetUsage: true)

        appendLog("[memory] monitoring managed pid \(processIdentifier) every 1 second.")
        let monitor = memoryMonitor
        let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model)
        let modelEstimateGigabytes = monitor.estimatedModelStorageGigabytes(modelDirectoryPath: modelDirectoryPath)
        let modelEstimateSource = modelDirectoryPath.map { ModelAvailabilityPathFormatter.compact(path: $0) }

        if let modelEstimateGigabytes, let modelEstimateSource {
            appendLog("[memory] model estimate: \(Self.formatMemoryGigabytes(modelEstimateGigabytes)) from \(modelEstimateSource).")
        } else {
            appendLog("[memory] model estimate unavailable. A local model folder is required for the model segment.")
        }

        memoryMonitorTask = Task { [weak self, monitor, modelEstimateGigabytes, modelEstimateSource] in
            while !Task.isCancelled {
                let result = await monitor.currentBreakdown(
                    processIdentifier: processIdentifier,
                    modelEstimateGigabytes: modelEstimateGigabytes,
                    modelEstimateSource: modelEstimateSource
                )
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
                    try await Task.sleep(nanoseconds: 1_000_000_000)
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
            memoryBreakdown = nil
            memoryHistory = []
        }
    }

    private func handleMemoryMonitorResult(
        _ result: MemoryBreakdownMonitorResult,
        processIdentifier: Int32
    ) -> Bool {
        guard processManager.managedProcessIdentifier == processIdentifier else {
            memoryUsageGB = nil
            memoryBreakdown = nil
            appendLog("[memory] monitoring stopped because managed pid changed.")
            return false
        }

        switch result {
        case let .usage(snapshot):
            memoryUsageGB = snapshot.managedProcessGigabytes
            memoryBreakdown = snapshot
            appendMemoryHistorySample(from: snapshot)
            return true
        case let .notRunning(processIdentifier):
            memoryUsageGB = nil
            memoryBreakdown = nil
            appendLog("[memory] warning: managed pid \(processIdentifier) is no longer reporting RSS.")
            return false
        case let .invalidInput(message):
            memoryUsageGB = nil
            memoryBreakdown = nil
            appendLog("[memory] warning: \(message)")
            return false
        case let .failed(processIdentifier, message):
            appendLog("[memory] warning: failed to read RSS for pid \(processIdentifier): \(message)")
            return true
        }
    }

    private func appendMemoryHistorySample(from snapshot: MemoryBreakdownSnapshot) {
        guard snapshot.system.totalGigabytes > 0,
              let usedGigabytes = snapshot.system.usedGigabytes else {
            return
        }

        let sample = MemoryHistorySample(
            usedFraction: min(max(usedGigabytes / snapshot.system.totalGigabytes, 0), 1),
            managedProcessFraction: min(max(snapshot.managedProcessGigabytes / snapshot.system.totalGigabytes, 0), 1),
            timestamp: snapshot.updatedAt
        )

        memoryHistory.append(sample)
        if memoryHistory.count > 60 {
            memoryHistory.removeFirst(memoryHistory.count - 60)
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

    private func startSystemUsageMonitoring() {
        systemUsageMonitorTask?.cancel()
        systemUsageMonitorTask = Task.detached { [weak self] in
            var cpuUsageSampler = CPUUsageSampler()
            while !Task.isCancelled {
                let cpuPercent = cpuUsageSampler.samplePercent()
                let systemMemorySnapshot = MemoryMonitor().currentSystemSnapshot()
                guard let self else {
                    return
                }
                await self.handleSystemUsageMonitorResult(cpuPercent: cpuPercent, gpuPercent: nil, systemMemorySnapshot: systemMemorySnapshot)

                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func handleSystemUsageMonitorResult(cpuPercent: Double?, gpuPercent: Double?, systemMemorySnapshot: SystemMemorySnapshot) {
        cpuUsagePercent = cpuPercent
        gpuUsagePercent = gpuPercent
        self.systemMemorySnapshot = systemMemorySnapshot
        appendSystemMemoryHistory(systemMemorySnapshot)
        appendSystemUsageHistory(cpuPercent: cpuPercent, gpuPercent: gpuPercent)
    }

    private func appendSystemMemoryHistory(_ snapshot: SystemMemorySnapshot) {
        guard let usedGigabytes = snapshot.usedGigabytes,
              snapshot.totalGigabytes > 0 else {
            return
        }

        memoryHistory.append(
            MemoryHistorySample(
                usedFraction: min(max(usedGigabytes / snapshot.totalGigabytes, 0), 1),
                managedProcessFraction: memoryBreakdown.map { memoryFraction($0.managedProcessGigabytes) } ?? 0,
                timestamp: Date()
            )
        )
        if memoryHistory.count > 60 {
            memoryHistory.removeFirst(memoryHistory.count - 60)
        }
    }

    private func startAutoUnloadMonitoring() {
        autoUnloadTask?.cancel()
        autoUnloadTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.evaluateAutoUnload()
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func evaluateAutoUnload() async {
        guard let runningModelID,
              let runningModel = models.first(where: { $0.id == runningModelID }),
              isAutoUnloadEnabled(for: runningModel),
              let managedServerStartedAt,
              !isModelTransitioning(runningModel) else {
            return
        }

        let elapsedSeconds = Date().timeIntervalSince(managedServerStartedAt)
        let limitSeconds = TimeInterval(autoUnloadMinutes(for: runningModel) * 60)
        guard elapsedSeconds >= limitSeconds else {
            return
        }

        appendLog("[auto-unload] elapsed \(Int(elapsedSeconds))s reached \(autoUnloadMinutes(for: runningModel)) minute limit. Unloading \(runningModel.displayName).")
        stopRequested()
    }

    private func appendSystemUsageHistory(cpuPercent: Double?, gpuPercent: Double?) {
        let sample = SystemUsageHistorySample(
            cpuFraction: min(max((cpuPercent ?? 0) / 100, 0), 1),
            gpuFraction: gpuPercent.map { min(max($0 / 100, 0), 1) },
            timestamp: Date()
        )

        systemUsageHistory.append(sample)
        if systemUsageHistory.count > 60 {
            systemUsageHistory.removeFirst(systemUsageHistory.count - 60)
        }
    }

    private func appendRuntimeEvent(category: String, message: String) {
        runtimeEvents.insert(RuntimeEvent(category: category, message: message), at: 0)
        if runtimeEvents.count > 30 {
            runtimeEvents.removeLast(runtimeEvents.count - 30)
        }
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
