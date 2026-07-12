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

struct MiniChatTranscriptMessage: Identifiable, Equatable {
    enum Sender: Equatable {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let sender: Sender
    let content: String
}

private struct MiniChatMessagePayload: Codable {
    let role: String
    let content: String
}

private struct MiniChatRequestPayload: Encodable {
    let model: String
    let messages: [MiniChatMessagePayload]
    let stream: Bool
    let maxTokens: Int
    let temperature: Double
    let stop: [String]

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case stop
    }
}

private struct QueuedHuggingFaceDownload {
    let id: UUID
    let reference: HuggingFaceModelReference
    let destinationPath: String
    let displayName: String
    let draft: HuggingFaceDownloadDraft
    let expectedFiles: [HuggingFaceDownloadPreviewFile]
    let expectedBytes: Int64?
}

private struct MiniChatResponsePayload: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message?
    }
    struct ErrorPayload: Decodable {
        let message: String?
    }
    let choices: [Choice]?
    let error: ErrorPayload?
}

private struct PortCheckCacheEntry {
    let result: PortCheckResult
    let checkedAt: Date
}

private struct SystemInfoRowsCacheEntry {
    let rows: [(String, String)]
    let measuredAt: Date
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
    @Published private(set) var logText: String
    @Published private(set) var logEntries: [LogEntry]
    @Published var logCategoryFilter = "All" {
        didSet {
            refreshLogDerivedState()
        }
    }
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
    @Published private(set) var lastAddedDownloadedModelID: ModelConfig.ID?
    @Published private(set) var downloadCompletionMarkerDate: Date?
    @Published private(set) var huggingFaceFilePreview: HuggingFaceDownloadFilePreviewState = .waiting
    @Published private(set) var huggingFaceFilePreviewIdentity: HuggingFaceFilePreviewIdentity?
    @Published var selectedHuggingFacePreviewFileIDs: Set<String> = []
    @Published private(set) var isHuggingFaceCLIAvailable = false
    @Published private(set) var huggingFaceCLIPath = AppViewModel.notCheckedText(language: .system)
    @Published private(set) var huggingFaceCLIMessage = AppViewModel.defaultHuggingFaceCLIMessage(language: .system)
    @Published private(set) var aria2Availability = Aria2AvailabilityChecker.check()
    @Published var enableDownloadAutoRestart = false
    @Published var lowSpeedRestartThresholdText = "50K"
    @Published var localModelPath = ""
    @Published var localModelDisplayName = ""
    @Published var localModelPortText = String(AppSettings.defaults.defaultPort)
    @Published var localModelEnableThinking = false
    @Published private(set) var localModelMessage = AppViewModel.defaultLocalModelMessage(language: .system)
    @Published var huggingFaceSearchQuery = ""
    @Published var showOnlyMLXLikelySearchResults = false
    @Published private(set) var huggingFaceSearchMessage = AppViewModel.defaultHuggingFaceSearchMessage(language: .system)
    @Published private(set) var huggingFaceSearchResults: [HuggingFaceSearchResult] = []
    private let systemProfilerHardwareInfo = AppViewModel.loadSystemProfilerHardwareInfo()
    @Published private(set) var selectedHuggingFaceSearchResult: HuggingFaceSearchResult?
    @Published private(set) var isHuggingFaceSearching = false
    @Published private(set) var isSpeedTestRunning = false
    @Published private(set) var latestSpeedTestMessage = AppViewModel.defaultSpeedTestMessage(language: .system)
    @Published private(set) var latestSpeedTestDurationMS: Double?
    @Published private(set) var latestBenchmarkResult: BenchmarkResult?
    @Published private(set) var benchmarkHistory: [BenchmarkResult] = []
    @Published private(set) var benchmarkResultsByProfileID: [ModelConfig.ID: BenchmarkResult] = [:]
    @Published private(set) var isAgenticBenchmarkRunning = false
    @Published private(set) var latestAgenticBenchmarkResult: AgenticBenchmarkResult?
    @Published private(set) var agenticBenchmarkHistory: [AgenticBenchmarkResult] = []
    @Published private(set) var agenticBenchmarkResultsByProfileID: [ModelConfig.ID: AgenticBenchmarkResult] = [:]
    @Published var miniChatPrompt = ""
    @Published private(set) var miniChatMessages: [MiniChatTranscriptMessage] = []
    @Published private(set) var miniChatResponse = ""
    @Published private(set) var miniChatStatus = "Ready."
    @Published private(set) var miniChatHTTPStatusText = "-"
    @Published private(set) var miniChatDurationText = "-"
    @Published private(set) var isMiniChatRunning = false
    @Published private(set) var hermesAgentConfigMessage = AppViewModel.defaultHermesAgentConfigMessage(language: .system)
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
    private let huggingFaceDownloadManagerFactory: () -> HuggingFaceModelDownloading
    private let huggingFaceCredentialStore: HuggingFaceCredentialStoring
    private let huggingFaceSearchService: HuggingFaceModelSearching
    private let huggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing
    private let hermesAgentConfigService: HermesAgentConfigService
    private let benchmarkService: BenchmarkService
    private let agenticBenchmarkService: AgenticBenchmarkService
    private var logBuffer: LogBuffer
    private var memoryMonitorTask: Task<Void, Never>?
    private var systemUsageMonitorTask: Task<Void, Never>?
    private var autoUnloadTask: Task<Void, Never>?
    private var huggingFaceSearchTask: Task<Void, Never>?
    private var huggingFaceSearchGeneration = 0
    private var huggingFaceFilePreviewTask: Task<Void, Never>?
    private var huggingFaceFilePreviewGeneration = 0
    private var queuedHuggingFaceDownloads: [UUID: QueuedHuggingFaceDownload] = [:]
    private var activeHuggingFaceDownloadTasks: [UUID: Task<Void, Never>] = [:]
    private var activeHuggingFaceDownloadManagers: [UUID: HuggingFaceModelDownloading] = [:]
    private var activeHuggingFaceProgressTasks: [UUID: Task<Void, Never>] = [:]
    private var huggingFaceDownloadOutputLinesByID: [UUID: [String]] = [:]
    private var primaryHuggingFaceDownloadID: UUID?
    private var cancelledHuggingFaceDownloadIDs: Set<UUID> = []
    private var miniChatTask: Task<Void, Never>?
    private var pendingDeleteModelID: ModelConfig.ID?
    private var modelSizeGigabytesCache: [String: Double] = [:]
    private var portCheckCache: [String: PortCheckCacheEntry] = [:]
    private var systemInfoRowsCache: [AppLanguage: SystemInfoRowsCacheEntry] = [:]
    private var logCategoryFilterOptionsCache: [String]
    private var visibleLogEntriesCache: [LogEntry]
    private var latestImportantLogEntryCache: LogEntry?

    private static let initialLogLines = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Start, Stop, and Restart are available.",
        "[info] Memory monitoring starts after managed process launch."
    ]
    private static let portCheckCacheLifetime: TimeInterval = 1.0
    private static let systemInfoRowsCacheLifetime: TimeInterval = 5.0

    private static func localizedText(language: AppLanguage, english: String, japanese: String) -> String {
        AppLocalization(language: language).text(english: english, japanese: japanese)
    }

    private static func defaultHuggingFaceCLIMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Check Hugging Face CLI before downloading.",
            japanese: "ダウンロード前にHugging Face CLIを確認してください。"
        )
    }

    private static func defaultLocalModelMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Paste an existing local model folder path, then add it to the model list.",
            japanese: "既存のローカルモデルフォルダパスを貼り付けてから、モデル一覧へ追加してください。"
        )
    }

    private static func defaultHuggingFaceSearchMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Search Hugging Face explicitly, then choose a result for the download form.",
            japanese: "Hugging Faceを明示的に検索し、結果を選んでダウンロードフォームへ反映してください。"
        )
    }

    private static func defaultSpeedTestMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Benchmark has not run yet.",
            japanese: "ベンチマークはまだ実行されていません。"
        )
    }

    private static func defaultHermesAgentConfigMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Apply the selected model connection values to the configured Hermes Agent YAML file.",
            japanese: "選択モデルの接続値を設定済みのHermes Agent YAMLファイルへ反映します。"
        )
    }

    private static func notCheckedText(language: AppLanguage) -> String {
        localizedText(language: language, english: "Not checked", japanese: "未確認")
    }

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
        huggingFaceDownloadManagerFactory: (() -> HuggingFaceModelDownloading)? = nil,
        huggingFaceCredentialStore: HuggingFaceCredentialStoring? = nil,
        huggingFaceSearchService: HuggingFaceModelSearching? = nil,
        huggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing? = nil,
        hermesAgentConfigService: HermesAgentConfigService? = nil,
        benchmarkService: BenchmarkService? = nil,
        agenticBenchmarkService: AgenticBenchmarkService? = nil
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
        self.huggingFaceDownloadManagerFactory = huggingFaceDownloadManagerFactory ?? { HuggingFaceDownloadManager() }
        self.huggingFaceCredentialStore = huggingFaceCredentialStore ?? HuggingFaceCredentialStore()
        self.huggingFaceSearchService = huggingFaceSearchService ?? HuggingFaceSearchService()
        self.huggingFaceRepositoryFileService = huggingFaceRepositoryFileService ?? HuggingFaceRepositoryFileService()
        self.hermesAgentConfigService = hermesAgentConfigService ?? HermesAgentConfigService()
        self.benchmarkService = benchmarkService ?? BenchmarkService()
        self.agenticBenchmarkService = agenticBenchmarkService ?? AgenticBenchmarkService()
        let initialLogBuffer = LogBuffer(initialLines: Self.initialLogLines)
        let initialLogEntries = initialLogBuffer.entries
        self.logBuffer = initialLogBuffer
        self.logText = initialLogBuffer.text
        self.logEntries = initialLogEntries
        self.logCategoryFilterOptionsCache = Self.makeLogCategoryFilterOptions(from: initialLogEntries)
        self.visibleLogEntriesCache = initialLogEntries
        self.latestImportantLogEntryCache = Self.findLatestImportantLogEntry(in: initialLogEntries)
        loadSettings()
        refreshDefaultUserFacingMessagesForCurrentLanguage()
        huggingFaceDownloadDraft = .defaults(
            defaultHost: settings.defaultHost,
            defaultPort: settings.defaultPort
        )
        applyDownloadSettingsToDraft()
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

    var activeHuggingFaceDownloadEntry: HuggingFaceDownloadQueueEntry? {
        huggingFaceDownloadQueue.first { entry in
            entry.phase == .preparing || entry.phase == .downloading || entry.phase == .finalizing
        }
    }

    var latestHuggingFaceDownloadEntry: HuggingFaceDownloadQueueEntry? {
        activeHuggingFaceDownloadEntry ?? huggingFaceDownloadQueue.first
    }

    var hasCompletedHuggingFaceDownloadMarker: Bool {
        guard let entry = huggingFaceDownloadQueue.first else {
            return false
        }
        return entry.phase == .completed
    }

    var isHuggingFaceDownloadActive: Bool {
        activeHuggingFaceDownloadEntry != nil
    }

    var downloadSidebarProgressFraction: Double? {
        activeHuggingFaceDownloadEntry?.progressFraction
    }

    var downloadProgressSummaryText: String {
        guard let entry = latestHuggingFaceDownloadEntry else {
            return Self.localizedText(language: settings.uiLanguage, english: "No download", japanese: "ダウンロードなし")
        }
        let percentText = entry.progressFraction.map { "\(Int($0 * 100))%" } ?? "-"
        let filesText = entry.fileCount.map { "\(entry.downloadedFileCount ?? 0)/\($0)" } ?? "-"
        return Self.localizedText(
            language: settings.uiLanguage,
            english: "\(percentText) • file \(filesText)",
            japanese: "\(percentText)・ファイル \(filesText)"
        )
    }

    func isLastAddedDownloadedModel(_ model: ModelConfig) -> Bool {
        lastAddedDownloadedModelID == model.id
    }

    var systemInfoRows: [(String, String)] {
        cachedSystemInfoRows(language: settings.uiLanguage)
    }

    private func cachedSystemInfoRows(language: AppLanguage) -> [(String, String)] {
        let cacheKey = language.resolved
        let now = Date()
        if let cached = systemInfoRowsCache[cacheKey],
           now.timeIntervalSince(cached.measuredAt) <= Self.systemInfoRowsCacheLifetime {
            return cached.rows
        }

        let rows = makeSystemInfoRows(language: language)
        systemInfoRowsCache[cacheKey] = SystemInfoRowsCacheEntry(rows: rows, measuredAt: now)
        return rows
    }

    private func makeSystemInfoRows(language: AppLanguage) -> [(String, String)] {
        [
            (
                Self.localizedText(language: language, english: "Model", japanese: "機種"),
                systemProfilerHardwareInfo["Model Name"] ?? Self.sysctlString("hw.model") ?? Self.localizedText(language: language, english: "Unknown", japanese: "不明")
            ),
            ("macOS", Self.macOSVersionNumberText),
            (
                Self.localizedText(language: language, english: "Chip", japanese: "チップ"),
                systemProfilerHardwareInfo["Chip"] ?? Self.sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
            ),
            (
                Self.localizedText(language: language, english: "Processing", japanese: "処理能力"),
                Self.processingCapabilityText(from: systemProfilerHardwareInfo)
            ),
            (
                Self.localizedText(language: language, english: "Memory", japanese: "メモリ"),
                systemProfilerHardwareInfo["Memory"] ?? Self.formatMemoryGigabytes(Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
            ),
            (
                Self.localizedText(language: language, english: "Storage", japanese: "ストレージ"),
                Self.storageUsageText(language: language)
            )
        ]
    }

    var visibleModels: [ModelConfig] {
        models
    }

    private func refreshDefaultUserFacingMessagesForCurrentLanguage() {
        let language = settings.uiLanguage
        huggingFaceCLIPath = Self.notCheckedText(language: language)
        huggingFaceCLIMessage = Self.defaultHuggingFaceCLIMessage(language: language)
        localModelMessage = Self.defaultLocalModelMessage(language: language)
        huggingFaceSearchMessage = Self.defaultHuggingFaceSearchMessage(language: language)
        latestSpeedTestMessage = Self.defaultSpeedTestMessage(language: language)
        hermesAgentConfigMessage = Self.defaultHermesAgentConfigMessage(language: language)
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
            invalidatePortCheckCache()
            appendLog("[model] reordered \(movedModel.displayName).")
        } catch {
            appendLog("[model] warning: failed to save model order: \(error.localizedDescription)")
        }
    }

    func moveModelToEnd(withID draggedModelID: ModelConfig.ID) {
        guard let sourceIndex = models.firstIndex(where: { $0.id == draggedModelID }),
              sourceIndex != models.index(before: models.endIndex) else {
            return
        }

        let movedModel = models.remove(at: sourceIndex)
        models.append(movedModel)
        do {
            try settingsStore.save(models: models)
            invalidatePortCheckCache()
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
        settings.autoUnloadEnabledByModelID[model.id] = isEnabled
        persistAutoUnloadSettings()
    }

    func autoUnloadMinutes(for model: ModelConfig) -> Int {
        autoUnloadMinutesByModelID[model.id] ?? 30
    }

    func setAutoUnloadMinutes(_ minutes: Int, for model: ModelConfig) {
        let clampedMinutes = min(max(minutes, 1), 999)
        autoUnloadMinutesByModelID[model.id] = clampedMinutes
        settings.autoUnloadMinutesByModelID[model.id] = clampedMinutes
        persistAutoUnloadSettings()
    }

    private func persistAutoUnloadSettings() {
        do {
            try settingsStore.save(settings: settings, models: models)
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

    var huggingFaceDownloadPreview: HuggingFaceDownloadPreview {
        HuggingFaceDownloadPreview.make(draft: huggingFaceDownloadDraft)
    }

    var isHuggingFaceDownloadRunning: Bool {
        !activeHuggingFaceDownloadTasks.isEmpty
    }

    var canStartHuggingFaceDownload: Bool {
        huggingFaceDownloadPreview.canDownload
            && isHuggingFaceCLIAvailable
            && selectedHuggingFaceSearchResult?.isSupportedForDownload == true
            && selectedHuggingFaceSearchResult?.id == huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredHuggingFacePreviewFiles: [HuggingFaceDownloadPreviewFile] {
        guard huggingFaceFilePreviewMatchesCurrentDraft else {
            return []
        }
        return huggingFaceFilePreview.files.filter { file in
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
        if files.isEmpty { return Self.localizedText(language: settings.uiLanguage, english: "No preview files selected.", japanese: "プレビューファイルが選択されていません。") }
        let total = files.compactMap(\.size).reduce(Int64(0), +)
        let hasUnknown = files.contains { $0.size == nil }
        let sizeText = hasUnknown ? "unknown size" : ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return "\(files.count) files • \(sizeText)"
    }

    var visibleHuggingFaceSearchResults: [HuggingFaceSearchResult] {
        showOnlyMLXLikelySearchResults
            ? huggingFaceSearchResults.filter(\.isSupportedForDownload)
            : huggingFaceSearchResults
    }

    var canRunSpeedTest: Bool {
        connectionTargetSummary.isActiveTarget && !isSpeedTestRunning && !isAgenticBenchmarkRunning
    }

    var speedTestDisabledReason: String {
        if isSpeedTestRunning { return Self.localizedText(language: settings.uiLanguage, english: "Benchmark is already running.", japanese: "ベンチマークはすでに実行中です。") }
        if isAgenticBenchmarkRunning { return Self.localizedText(language: settings.uiLanguage, english: "Agent Readiness is already running.", japanese: "Agent Readinessはすでに実行中です。") }
        if !connectionTargetSummary.isActiveTarget { return Self.localizedText(language: settings.uiLanguage, english: "Start or adopt a server before running Benchmark.", japanese: "ベンチマーク前にサーバーを起動するか採用してください。") }
        return Self.localizedText(language: settings.uiLanguage, english: "Ready.", japanese: "準備完了。")
    }

    var canRunAgenticBenchmark: Bool {
        connectionTargetSummary.isActiveTarget && !isSpeedTestRunning && !isAgenticBenchmarkRunning
    }

    var agenticBenchmarkDisabledReason: String {
        if isAgenticBenchmarkRunning { return Self.localizedText(language: settings.uiLanguage, english: "Agent Readiness is already running.", japanese: "Agent Readinessはすでに実行中です。") }
        if isSpeedTestRunning { return Self.localizedText(language: settings.uiLanguage, english: "Benchmark v1 is already running.", japanese: "Benchmark v1はすでに実行中です。") }
        if !connectionTargetSummary.isActiveTarget { return Self.localizedText(language: settings.uiLanguage, english: "Start or adopt a server before running Agent Readiness.", japanese: "Agent Readiness前にサーバーを起動するか採用してください。") }
        return Self.localizedText(language: settings.uiLanguage, english: "Runs virtual tool tasks without external dependencies.", japanese: "外部依存なしで仮想ツールタスクを実行します。")
    }

    var stopDisabledReason: String {
        canStopManagedServer ? "Ready." : "No managed server is running."
    }

    var restartDisabledReason: String {
        canRestartManagedServer ? "Ready." : "Start a managed server before Restart. External server context cannot be restarted here."
    }

    var selectedBlockingStartIssue: String? {
        guard let selectedModel else { return Self.localizedText(language: settings.uiLanguage, english: "Select a model before Start.", japanese: "起動前にモデルを選択してください。") }
        return blockingStartIssue(for: selectedModel)
    }

    private func blockingStartIssue(for model: ModelConfig) -> String? {
        let executablePath = settings.mlxServerExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty,
              FileManager.default.isExecutableFile(atPath: executablePath) else {
            return executableSafetyText
        }

        let modelSafety = modelIdentitySafetyText(for: model)
        if modelSafety.localizedCaseInsensitiveContains("Missing") {
            return modelSafety
        }

        switch cachedPortCheck(host: model.host, port: model.serverPort) {
        case .available:
            return nil
        default:
            return "Server port: \(portSafetyText(host: model.host, port: model.serverPort))"
        }
    }

    var canStartSelectedModel: Bool {
        selectedBlockingStartIssue == nil
    }

    var startActionReason: String {
        selectedBlockingStartIssue ?? "Ready."
    }

    var integratedActionStateSummary: String {
        if let selectedModel, selectedModel.id == runningModelID {
            return Self.localizedText(language: settings.uiLanguage, english: "Loaded. Stop or restart is available.", japanese: "ロード済みです。停止または再起動できます。")
        }

        return [
            "Start: \(startActionReason)",
            "Stop: \(stopDisabledReason)",
            "Restart: \(restartDisabledReason)",
            "Benchmark: \(speedTestDisabledReason)"
        ].joined(separator: "  ")
    }

    var selectedModelSafetyRows: [(String, String)] {
        guard let selectedModel else {
            return [("Selected model", "Missing")]
        }
        if settings.uiLanguage.resolved == .english {
            return [
                ("Executable file", executableSafetyText),
                ("Model validation", modelIdentitySafetyText(for: selectedModel)),
                ("Port / IP address", portSafetyText(for: selectedModel)),
                ("Duplicate check", duplicateProfileWarning(for: selectedModel) ?? "No duplicate issue"),
                ("Runtime edit safety", runtimeEditingSafetyText(for: selectedModel))
            ]
        }
        return [
            ("Executable", executableSafetyText),
            ("Model", modelIdentitySafetyText(for: selectedModel)),
            ("Server port", portSafetyText(for: selectedModel)),
            ("Duplicate", duplicateProfileWarning(for: selectedModel) ?? "OK"),
            ("Runtime edit", runtimeEditingSafetyText(for: selectedModel))
        ]
    }

    var selectedModelSafetySummary: String {
        let warningCount = selectedModelSafetyRows.filter { isSafetyWarning(label: $0.0, value: $0.1) }.count
        if settings.uiLanguage.resolved == .english {
            return warningCount == 0 ? "Safety: no issues" : "Safety: \(warningCount) warning(s)"
        }
        return warningCount == 0 ? "Safety: OK" : "Safety: \(warningCount) warning(s)"
    }

    var selectedServerPortSafetyText: String {
        guard let selectedModel else { return Self.localizedText(language: settings.uiLanguage, english: "No model selected", japanese: "モデル未選択") }
        return portSafetyText(for: selectedModel)
    }

    func integratedPortStatusText(for model: ModelConfig) -> String {
        portSafetyText(for: model)
    }


    var selectedModelIdentityDetailText: String {
        guard let selectedModel else { return Self.localizedText(language: settings.uiLanguage, english: "No model selected", japanese: "モデル未選択") }
        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: selectedModel) {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory), isDirectory.boolValue {
                return Self.localizedText(language: settings.uiLanguage, english: "Local path exists: \(ModelAvailabilityPathFormatter.compact(path: localPath))", japanese: "ローカルパスがあります: \(ModelAvailabilityPathFormatter.compact(path: localPath))")
            }
            return Self.localizedText(language: settings.uiLanguage, english: "Missing local path: \(ModelAvailabilityPathFormatter.compact(path: localPath))", japanese: "ローカルパスがありません: \(ModelAvailabilityPathFormatter.compact(path: localPath))")
        }
        if selectedModel.modelID.contains("https://huggingface.co/") {
            return Self.localizedText(language: settings.uiLanguage, english: "Needs review: paste owner/model instead of a full URL when possible.", japanese: "要確認: 可能な場合は完全なURLではなく owner/model を貼り付けてください。")
        }
        if selectedModel.modelID.split(separator: "/").count == 2 {
            return Self.localizedText(language: settings.uiLanguage, english: "HF ID format looks valid.", japanese: "HF ID形式は有効に見えます。")
        }
        return Self.localizedText(language: settings.uiLanguage, english: "Needs review: expected local path or owner/model HF ID.", japanese: "要確認: ローカルパスまたは owner/model 形式のHF IDが必要です。")
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
            return Self.localizedText(language: settings.uiLanguage, english: "Port busy at \(host):\(port). Stop the conflicting process or choose another port.", japanese: "\(host):\(port) は使用中です。競合プロセスを停止するか、別のポートを選択してください。")
        case let .portCheckFailed(_, _, message):
            return recoveryGuidance(for: message)
        case let .readyCheckFailed(_, _, message):
            return recoveryGuidance(for: message)
        default:
            return Self.localizedText(language: settings.uiLanguage, english: "No recovery action needed.", japanese: "起動失敗の復旧は不要です。")
        }
    }

    private var executableSafetyText: String {
        let executablePath = settings.mlxServerExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else { return Self.localizedText(language: settings.uiLanguage, english: "Missing executable path", japanese: "実行ファイルパスが未設定") }
        if FileManager.default.isExecutableFile(atPath: executablePath) {
            return settings.uiLanguage.resolved == .english ? "Executable OK" : "OK"
        }
        return "Missing or not executable"
    }

    private func modelIdentitySafetyText(for model: ModelConfig) -> String {
        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) {
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory) && isDirectory.boolValue
                ? Self.localizedText(language: settings.uiLanguage, english: "Local path OK", japanese: "OK local path")
                : Self.localizedText(language: settings.uiLanguage, english: "Missing local path", japanese: "Missing local path")
        }
        return model.modelID.contains("/") ? "Needs review: HF ID" : "Needs review"
    }

    private func isSafetyWarning(label: String, value: String) -> Bool {
        let normalized = value.lowercased()
        if normalized.contains("missing")
            || normalized.contains("invalid")
            || normalized.contains("failed")
            || normalized.contains("not executable")
            || normalized.contains("要確認")
            || normalized.contains("未検出")
            || normalized.contains("未設定")
            || normalized.contains("無効")
            || normalized.contains("失敗") {
            return true
        }
        if normalized.contains("stop before") || normalized.contains("停止") {
            return true
        }
        if normalized == "busy" || normalized == "使用中" {
            return true
        }
        return false
    }

    private func portSafetyText(for model: ModelConfig) -> String {
        if model.id == runningModelID {
            return Self.localizedText(language: settings.uiLanguage, english: "OK: in use by loaded model", japanese: "OK: ロード済みモデルが使用中")
        }
        return portSafetyText(host: model.host, port: model.serverPort)
    }

    private func portSafetyText(host: String, port: Int) -> String {
        switch cachedPortCheck(host: host, port: port) {
        case .available:
            return Self.localizedText(language: settings.uiLanguage, english: "Port available", japanese: "利用可能")
        case let .busy(_, _, pid):
            if let pid {
                return Self.localizedText(language: settings.uiLanguage, english: "Busy (PID: \(pid))", japanese: "使用中（PID: \(pid)）")
            }
            return Self.localizedText(language: settings.uiLanguage, english: "Busy", japanese: "使用中")
        case let .invalidInput(message):
            return Self.localizedText(language: settings.uiLanguage, english: "Invalid: \(message)", japanese: "無効: \(message)")
        case let .failed(_, _, message):
            return Self.localizedText(language: settings.uiLanguage, english: "Check failed: \(message)", japanese: "確認失敗: \(message)")
        }
    }

    func duplicateProfileWarning(for model: ModelConfig) -> String? {
        let duplicateName = models.contains { $0.id != model.id && $0.displayName == model.displayName }
        let duplicateModelID = models.contains { $0.id != model.id && $0.modelID == model.modelID }
        let duplicateEndpoint = models.contains { $0.id != model.id && $0.host == model.host && $0.serverPort == model.serverPort }
        if duplicateName { return Self.localizedText(language: settings.uiLanguage, english: "Duplicate display name", japanese: "表示名が重複") }
        if duplicateModelID { return Self.localizedText(language: settings.uiLanguage, english: "Duplicate model ID", japanese: "Model IDが重複") }
        if duplicateEndpoint { return Self.localizedText(language: settings.uiLanguage, english: "Shared endpoint", japanese: "共有エンドポイント") }
        return nil
    }

    func runtimeEditingSafetyText(for model: ModelConfig) -> String {
        guard isManagedProcessRunning, model.id == runningModelID else { return Self.localizedText(language: settings.uiLanguage, english: "Edit safe", japanese: "Ready") }
        return Self.localizedText(language: settings.uiLanguage, english: "Stop before runtime-critical edits", japanese: "ランタイム重要項目の編集前に停止してください")
    }

    private func recoveryGuidance(for message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("executable") { return Self.localizedText(language: settings.uiLanguage, english: "Executable problem. Check Settings and run Diagnostics.", japanese: "実行ファイルの問題です。設定を確認し、診断を実行してください。") }
        if lower.contains("model path") || lower.contains("missing") { return Self.localizedText(language: settings.uiLanguage, english: "Model problem. Check the selected model path or Hugging Face ID.", japanese: "モデルの問題です。選択モデルのパスまたはHugging Face IDを確認してください。") }
        if lower.contains("port") { return Self.localizedText(language: settings.uiLanguage, english: "Port problem. Check port safety or choose another port.", japanese: "ポートの問題です。ポート安全性を確認するか、別のポートを選択してください。") }
        if lower.contains("permission") { return Self.localizedText(language: settings.uiLanguage, english: "Permission problem. Check executable and model folder permissions.", japanese: "権限の問題です。実行ファイルとモデルフォルダの権限を確認してください。") }
        if lower.contains("timed out") || lower.contains("ready") { return Self.localizedText(language: settings.uiLanguage, english: "Readiness problem. Wait longer, run Ready Check, or inspect logs.", japanese: "Ready確認の問題です。少し待つか、Ready確認を実行し、ログを確認してください。") }
        return Self.localizedText(language: settings.uiLanguage, english: "Inspect logs and copy troubleshooting context.", japanese: "ログを確認し、トラブルシューティング情報をコピーしてください。")
    }

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
            executablePath: settings.mlxServerExecutablePath,
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
        return "\(runtimeState.title) · \(mismatch) · \(restart) · \(latest)"
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
            return Self.localizedText(language: settings.uiLanguage, english: "No benchmark results in this session.", japanese: "このセッションにはベンチマーク結果がありません。")
        }
        let title = Self.localizedText(language: settings.uiLanguage, english: "Benchmark Summary", japanese: "ベンチマーク概要")
        return ([title, benchmarkSummaryText] + benchmarkHistory.prefix(10).map { result in
            "- \(result.timestamp): \(result.modelID) @ \(result.baseURL): \(result.localizedUseCaseScoreSummary(language: settings.uiLanguage)) — \(result.localizedSummary(language: settings.uiLanguage))"
        }).joined(separator: "\n")
    }

    var latestBenchmarkCopyText: String {
        guard let latestBenchmarkResult else {
            return Self.localizedText(language: settings.uiLanguage, english: "No benchmark result in this session.", japanese: "このセッションにはベンチマーク結果がありません。")
        }
        let title = Self.localizedText(language: settings.uiLanguage, english: "Latest Benchmark", japanese: "最新ベンチマーク")
        return "\(title)\n\(latestBenchmarkResult.localizedDetailedText(language: settings.uiLanguage))"
    }

    var latestAgenticBenchmarkCopyText: String {
        guard let latestAgenticBenchmarkResult else {
            return Self.localizedText(language: settings.uiLanguage, english: "No Agent Readiness result in this session.", japanese: "このセッションにはAgent Readiness結果がありません。")
        }
        let title = Self.localizedText(language: settings.uiLanguage, english: "Latest Agent Readiness", japanese: "最新Agent Readiness")
        return "\(title)\n\(latestAgenticBenchmarkResult.localizedDetailedText(language: settings.uiLanguage))"
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
        logCategoryFilterOptionsCache
    }

    func logCategoryFilterLabel(_ category: String) -> String {
        category == "All"
            ? Self.localizedText(language: settings.uiLanguage, english: "All", japanese: "すべて")
            : category
    }

    var visibleLogEntries: [LogEntry] {
        visibleLogEntriesCache
    }

    var latestImportantLogEntry: LogEntry? {
        latestImportantLogEntryCache
    }

    var runtimeSelectionWarning: String? {
        guard let runningModelID, let selectedModelID, runningModelID != selectedModelID else {
            return nil
        }
        return Self.localizedText(language: settings.uiLanguage, english: "Selected model differs from the running model. Stop or restart before expecting runtime changes.", japanese: "選択モデルが実行中モデルと異なります。ランタイム変更を反映するには停止または再起動してください。")
    }

    var huggingFaceDownloadQueueSummary: String {
        guard !huggingFaceDownloadQueue.isEmpty else {
            return Self.localizedText(language: settings.uiLanguage, english: "No downloads in this session.", japanese: "このセッションにはダウンロードがありません。")
        }
        let active = huggingFaceDownloadQueue.filter { $0.phase == .preparing || $0.phase == .downloading || $0.phase == .finalizing }.count
        let waiting = huggingFaceDownloadQueue.filter { $0.phase == .waiting }.count
        let completed = huggingFaceDownloadQueue.filter { $0.phase == .completed }.count
        let failed = huggingFaceDownloadQueue.filter { $0.phase == .failed }.count
        let cancelled = huggingFaceDownloadQueue.filter { $0.phase == .cancelled }.count
        return Self.localizedText(language: settings.uiLanguage, english: "Session downloads: \(huggingFaceDownloadQueue.count), active \(active), waiting \(waiting), completed \(completed), failed \(failed), cancelled \(cancelled)", japanese: "セッションダウンロード: \(huggingFaceDownloadQueue.count)件、実行中 \(active)、待機中 \(waiting)、完了 \(completed)、失敗 \(failed)、キャンセル \(cancelled)")
    }

    var canRetryHuggingFaceDownload: Bool {
        huggingFaceDownloadStatus.phase == .failed || huggingFaceDownloadStatus.phase == .cancelled
    }

    var huggingFaceDownloadProgressText: String {
        if let progress = huggingFaceDownloadStatus.progress {
            return "\(Int(progress * 100))%"
        }

        switch huggingFaceDownloadStatus.phase {
        case .completed:
            return "100%"
        default:
            return huggingFaceDownloadStatus.phase.localizedTitle(language: settings.uiLanguage)
        }
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
            return Self.localizedText(language: settings.uiLanguage, english: "Running Model: Not running", japanese: "実行中モデル: 未実行")
        }

        return Self.localizedText(language: settings.uiLanguage, english: "Running Model: \(runningModelID)", japanese: "実行中モデル: \(runningModelID)")
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

        return Self.localizedText(language: settings.uiLanguage, english: "\(models.count) profile(s). \(advancedText). Export does not start or stop servers.", japanese: "\(models.count)件のプロファイル。\(advancedText)。エクスポートはサーバーを起動・停止しません。")
    }

    var memoryUsageText: String {
        if runtimeState.isExternalServerContext {
            return Self.localizedText(language: settings.uiLanguage, english: "MLX managed RSS: external server not applicable", japanese: "MLX管理RSS: 外部サーバー対象外")
        }

        guard let memoryUsageGB else {
            return Self.localizedText(language: settings.uiLanguage, english: "MLX managed RSS: not running", japanese: "MLX管理RSS: 未稼働")
        }

        return Self.localizedText(language: settings.uiLanguage, english: "MLX managed RSS: \(Self.formatMemoryGigabytes(memoryUsageGB))", japanese: "MLX管理RSS: \(Self.formatMemoryGigabytes(memoryUsageGB))")
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
        if settings.uiLanguage.resolved == .english {
            guard let systemMemorySnapshot = activeSystemMemorySnapshot else {
                return "Total: Not available"
            }
            return "Total: \(Self.formatMemoryGigabytes(systemMemorySnapshot.totalGigabytes))"
        }
        guard let systemMemorySnapshot = activeSystemMemorySnapshot else {
            return "合計: 未取得"
        }

        return "合計: \(Self.formatMemoryGigabytes(systemMemorySnapshot.totalGigabytes))"
    }

    var memoryAvailableText: String {
        if settings.uiLanguage.resolved == .english, activeSystemMemorySnapshot?.availableGigabytes == nil {
            return "Not available"
        }
        guard let availableGigabytes = activeSystemMemorySnapshot?.availableGigabytes else {
            return "未取得"
        }

        return Self.formatMemoryGigabytes(availableGigabytes)
    }

    var memoryMLXProcessText: String {
        guard !runtimeState.isExternalServerContext else { return Self.localizedText(language: settings.uiLanguage, english: "N/A", japanese: "対象外") }
        guard let memoryBreakdown else { return Self.formatMemoryGigabytes(0) }

        return Self.formatMemoryGigabytes(memoryBreakdown.managedProcessGigabytes)
    }

    var memoryOtherProcessesText: String {
        guard let usedGigabytes = activeSystemMemorySnapshot?.usedGigabytes else {
            return Self.localizedText(language: settings.uiLanguage, english: "Not available", japanese: "未取得")
        }

        let managedProcessGigabytes = memoryBreakdown?.managedProcessGigabytes ?? 0
        return Self.formatMemoryGigabytes(max(usedGigabytes - managedProcessGigabytes, 0))
    }

    var memoryBreakdownUpdateText: String {
        if settings.uiLanguage.resolved == .english {
            return memoryBreakdown == nil ? "Updates begin after managed server start" : "Updates every second / last 60 seconds"
        }
        return memoryBreakdown == nil ? "管理サーバー起動後に更新開始" : "1秒ごとに更新 / 直近60秒"
    }

    var memoryBreakdownAccuracyText: String {
        if settings.uiLanguage.resolved == .english {
            return "mlx-lm is managed process RSS; other/available memory is vm_stat-based"
        }
        return "mlx-lmは管理プロセスRSS、その他/空き容量はvm_statベース"
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
        if settings.uiLanguage.resolved == .english, cpuUsagePercent == nil { return "Not available" }
        guard let cpuUsagePercent else { return "未取得" }
        return String(format: "%.0f%%", cpuUsagePercent)
    }

    var integratedGPUUsageText: String {
        if settings.uiLanguage.resolved == .english, gpuUsagePercent == nil { return "Unsupported" }
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
        if settings.uiLanguage.resolved == .english {
            return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
        }
        return String(format: "%02d時間%02d分%02d秒", hours, minutes, seconds)
    }

    func integratedStatusText(for model: ModelConfig) -> String {
        interactiveStatusText(for: model, isHovered: false)
    }

    func interactiveStatusText(for model: ModelConfig, isHovered: Bool, isPortBusy knownPortBusy: Bool? = nil) -> String {
        if settings.uiLanguage.resolved == .english {
            if model.id == runningModelID {
                switch runtimeState {
                case .starting, .loading, .checkingReady:
                    return "Loading"
                case .stopping:
                    return "Unloading"
                default:
                    return isHovered ? "Unload" : "Loaded"
                }
            }
            if knownPortBusy ?? isModelPortBusy(for: model) {
                return "Port Busy"
            }
            return isHovered ? "Load" : "Ready"
        }
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

        if knownPortBusy ?? isModelPortBusy(for: model) {
            return "ポート使用中"
        }
        return isHovered ? "ロード" : "準備完了"
    }

    func isModelPortBusy(for model: ModelConfig) -> Bool {
        guard model.id != runningModelID else { return false }
        if case .busy = cachedPortCheck(host: model.host, port: model.serverPort) {
            return true
        }
        return false
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
        guard let gigabytes = modelSizeGigabytes(for: model) else {
            return "-"
        }

        return Self.formatMemoryGigabytes(gigabytes)
    }

    func integratedMemoryText(for model: ModelConfig) -> String {
        guard model.id == runningModelID,
              let memoryUsageGB else {
            return "-"
        }

        return Self.formatMemoryGigabytes(memoryUsageGB)
    }

    func modelSizeSortValue(for model: ModelConfig) -> Double {
        modelSizeGigabytes(for: model) ?? -1
    }

    func integratedStatusSortValue(for model: ModelConfig) -> Int {
        let isTransitioning = isModelTransitioning(model)
        if isTransitioning {
            return 0
        }
        if model.id == runningModelID {
            return 1
        }
        if isModelPortBusy(for: model) {
            return 2
        }
        return 3
    }

    func endpointSortValue(for model: ModelConfig) -> String {
        "\(model.host):\(String(format: "%05d", model.serverPort))"
    }

    func integratedMemorySortValue(for model: ModelConfig) -> Double {
        memoryValueForSort(model)
    }

    func autoUnloadTableSortValue(for model: ModelConfig) -> Int {
        autoUnloadSortValue(model)
    }

    func reasoningSortValue(for model: ModelConfig) -> Int {
        model.enableThinking ? 1 : 0
    }

    func integratedStopModeText(for model: ModelConfig) -> String {
        guard isAutoUnloadEnabled(for: model) else { return "OFF" }
        return Self.localizedText(language: settings.uiLanguage, english: "ON / \(autoUnloadMinutes(for: model)) min", japanese: "ON / \(autoUnloadMinutes(for: model))分")
    }

    private func modelSizeGigabytes(for model: ModelConfig) -> Double? {
        guard let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
            return nil
        }

        return modelSizeGigabytes(modelDirectoryPath: modelDirectoryPath)
    }

    private func modelSizeGigabytes(modelDirectoryPath: String?) -> Double? {
        guard let modelDirectoryPath,
              !modelDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let cacheKey = Self.modelSizeCacheKey(forDirectoryPath: modelDirectoryPath)
        if let cached = modelSizeGigabytesCache[cacheKey] {
            return cached
        }

        let gigabytes = memoryMonitor.estimatedModelStorageGigabytes(modelDirectoryPath: modelDirectoryPath)
        if let gigabytes {
            modelSizeGigabytesCache[cacheKey] = gigabytes
        }
        return gigabytes
    }

    private func invalidateModelSizeCache(for model: ModelConfig) {
        invalidateModelSizeCache(forDirectoryPath: ModelAvailabilityPathFormatter.localPathCandidate(for: model))
    }

    private func invalidateModelSizeCache(forDirectoryPath modelDirectoryPath: String?) {
        guard let modelDirectoryPath,
              !modelDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        modelSizeGigabytesCache.removeValue(forKey: Self.modelSizeCacheKey(forDirectoryPath: modelDirectoryPath))
    }

    private func invalidateModelSizeCache() {
        modelSizeGigabytesCache.removeAll()
    }

    private static func modelSizeCacheKey(forDirectoryPath modelDirectoryPath: String) -> String {
        URL(fileURLWithPath: modelDirectoryPath).standardizedFileURL.path
    }

    private func cachedPortCheck(host: String, port: Int) -> PortCheckResult {
        let cacheKey = Self.portCheckCacheKey(host: host, port: port)
        if let cached = portCheckCache[cacheKey],
           Date().timeIntervalSince(cached.checkedAt) <= Self.portCheckCacheLifetime {
            return cached.result
        }

        return freshPortCheck(host: host, port: port)
    }

    private func freshPortCheck(host: String, port: Int) -> PortCheckResult {
        let result = portChecker.check(host: host, port: port)
        portCheckCache[Self.portCheckCacheKey(host: host, port: port)] = PortCheckCacheEntry(
            result: result,
            checkedAt: Date()
        )
        return result
    }

    private func invalidatePortCheckCache() {
        portCheckCache.removeAll()
    }

    private static func portCheckCacheKey(host: String, port: Int) -> String {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedHost == "localhost" ? "127.0.0.1" : normalizedHost):\(port)"
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
        let rawGPUCoreText = hardwareInfo["GPU Cores"]
        let gpuCoreText = rawGPUCoreText?.split(separator: " ").first.map(String.init) ?? rawGPUCoreText
        if let gpuCoreText, !gpuCoreText.isEmpty {
            return "\(totalCoreText) CPU / \(gpuCoreText) GPU"
        }
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

    private static func storageUsageText(language: AppLanguage) -> String {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let size = attributes[.systemSize] as? NSNumber,
                  let free = attributes[.systemFreeSize] as? NSNumber else {
                return localizedText(language: language, english: "Unknown", japanese: "不明")
            }

            let usedBytes = max(size.doubleValue - free.doubleValue, 0)
            return "\(formatStorageBytes(usedBytes)) / \(formatStorageBytes(size.doubleValue))"
        } catch {
            return localizedText(language: language, english: "Unknown", japanese: "不明")
        }
    }

    nonisolated private static func formatStorageBytes(_ bytes: Double) -> String {
        let gigabytes = bytes / 1_000_000_000
        if gigabytes >= 1000 {
            return String(format: "%.1f TB", gigabytes / 1000)
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

    var hermesAgentConfigPathText: String {
        let path = settings.hermesConfigPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? "~/.hermes/config.yaml" : path
    }

    var canApplyHermesAgentConfig: Bool {
        selectedModel != nil && !hermesAgentConfigPathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hermesAgentTargetModelText: String {
        selectedModelIdentifier
    }

    var hermesAgentTargetBaseURLText: String {
        baseURL
    }

    var settingsDirectoryPath: String {
        do {
            return try settingsStore.settingsDirectoryURL.path
        } catch {
            return Self.localizedText(language: settings.uiLanguage, english: "Application Support directory unavailable", japanese: "Application Supportディレクトリを利用できません")
        }
    }

    var diagnosticsSummaryText: String {
        guard diagnosticsDidRun else {
            return Self.localizedText(language: settings.uiLanguage, english: "Not run", japanese: "未実行")
        }

        let passCount = diagnosticsResults.filter { $0.status == .pass }.count
        let failureCount = diagnosticsResults.filter { $0.status == .fail }.count
        let warningCount = diagnosticsResults.filter { $0.status == .warning }.count
        return Self.localizedText(language: settings.uiLanguage, english: "\(passCount) pass(es), \(warningCount) warning(s), \(failureCount) failure(s)", japanese: "成功 \(passCount)件、警告 \(warningCount)件、失敗 \(failureCount)件")
    }

    var menuBarTitle: String {
        if restartRequired {
            return Self.localizedText(language: settings.uiLanguage, english: "MLX: \(runtimeState.menuBarStatus) - restart required", japanese: "MLX: \(runtimeState.menuBarStatus) - 再起動が必要")
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

        switch freshPortCheck(host: host, port: port) {
        case let .available(host, port):
            runtimeState = .portAvailable(host: host, port: port)
            appendLog("[port] port available: \(host):\(port)")
        case let .busy(host, port, pid):
            runtimeState = .portBusy(host: host, port: port)
            if let pid {
                appendLog("[port] port busy: \(host):\(port) PID=\(pid)")
            } else {
                appendLog("[port] port busy: \(host):\(port)")
            }
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
            latestSpeedTestMessage = Self.localizedText(language: settings.uiLanguage, english: "Start the server before running Benchmark.", japanese: "ベンチマーク前にサーバーを起動してください。")
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
        let managedProcessID = processManager.managedProcessIdentifier
        let chipName = systemProfilerHardwareInfo["Chip"] ?? "Apple Silicon"
        let memoryText = systemProfilerHardwareInfo["Memory"] ?? Self.formatMemoryGigabytes(Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824)
        let service = benchmarkService
        isSpeedTestRunning = true
        latestSpeedTestMessage = Self.localizedText(language: settings.uiLanguage, english: "Running Benchmark v1...", japanese: "Benchmark v1 を実行中...")
        latestSpeedTestDurationMS = nil
        appendRuntimeEvent(category: "Benchmark", message: "Benchmark v1 started for \(host):\(port)")
        appendLog("[benchmark] Benchmark v1 started: \(targetBaseURL)")

        Task {
            let startedAt = Date()
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
                mlxServerExecutablePath: settings.mlxServerExecutablePath
            )
            let benchmarkResult = await service.run(configuration: configuration)
            let elapsedMS = Date().timeIntervalSince(startedAt) * 1000
            latestSpeedTestDurationMS = elapsedMS
            latestSpeedTestMessage = benchmarkResult.summary
            latestBenchmarkResult = benchmarkResult
            benchmarkHistory.insert(benchmarkResult, at: 0)
            benchmarkResultsByProfileID[benchmarkResult.profileID] = benchmarkResult
            savePersistedBenchmarkResults()
            appendRuntimeEvent(category: "Benchmark", message: benchmarkResult.summary)
            appendLog("[benchmark] Benchmark v1 \(benchmarkResult.phase.rawValue.lowercased()) in \(Int(elapsedMS)) ms: \(benchmarkResult.message)")
            isSpeedTestRunning = false
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

        isAgenticBenchmarkRunning = true
        appendRuntimeEvent(category: "Benchmark", message: "Agent Readiness started for \(host):\(port)")
        appendLog("[agent-readiness] started: \(targetBaseURL)")

        Task {
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
            let elapsedMS = Date().timeIntervalSince(startedAt) * 1000
            latestAgenticBenchmarkResult = result
            agenticBenchmarkHistory.insert(result, at: 0)
            agenticBenchmarkResultsByProfileID[result.profileID] = result
            savePersistedBenchmarkResults()
            appendRuntimeEvent(category: "Benchmark", message: result.summary)
            appendLog("[agent-readiness] \(result.phase.rawValue.lowercased()) in \(Int(elapsedMS)) ms: \(result.message)")
            isAgenticBenchmarkRunning = false
        }
    }

    var canSendMiniChat: Bool {
        !isMiniChatRunning && !miniChatPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedModel != nil
    }

    func sendMiniChatRequested() {
        let prompt = miniChatPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Enter a test message.", japanese: "テストメッセージを入力してください。")
            return
        }
        guard selectedModel != nil else {
            miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Select a model before sending.", japanese: "送信前にモデルを選択してください。")
            return
        }
        guard let url = Self.chatCompletionsURL(from: baseURL) else {
            miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Invalid base URL.", japanese: "Base URLが無効です。")
            return
        }

        let modelID = selectedModelIdentifier
        let targetBaseURL = baseURL
        miniChatPrompt = ""
        miniChatMessages.append(MiniChatTranscriptMessage(sender: .user, content: prompt))
        isMiniChatRunning = true
        miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Sending test request...", japanese: "テストリクエストを送信中...")
        miniChatHTTPStatusText = "-"
        miniChatDurationText = "-"
        miniChatResponse = ""
        appendLog("[test-chat] request started: \(targetBaseURL)/chat/completions model=\(modelID)")

        miniChatTask?.cancel()
        miniChatTask = Task {
            let startedAt = Date()
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 60
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let payload = MiniChatRequestPayload(
                    model: modelID,
                    messages: [MiniChatMessagePayload(role: "user", content: prompt)],
                    stream: false,
                    maxTokens: 1024,
                    temperature: 0.7,
                    stop: ["USER:", "ASSISTANT:"]
                )
                request.httpBody = try JSONEncoder().encode(payload)

                let (data, response) = try await URLSession.shared.data(for: request)
                let elapsedMS = Date().timeIntervalSince(startedAt) * 1000
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                miniChatHTTPStatusText = statusCode.map { "HTTP \($0)" } ?? "-"
                miniChatDurationText = "\(Int(elapsedMS)) ms"

                let decoded = try? JSONDecoder().decode(MiniChatResponsePayload.self, from: data)
                if let message = decoded?.error?.message, !message.isEmpty {
                    miniChatResponse = message
                    miniChatMessages.append(MiniChatTranscriptMessage(sender: .system, content: message))
                    miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Request failed.", japanese: "リクエストに失敗しました。")
                    appendLog("[test-chat] failed: \(miniChatHTTPStatusText) \(message)")
                } else {
                    let responseText = decoded?.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines)
                    miniChatResponse = responseText?.isEmpty == false ? responseText! : Self.fallbackMiniChatResponseText(from: data)
                    miniChatMessages.append(MiniChatTranscriptMessage(sender: .assistant, content: miniChatResponse))
                    if let statusCode, (200..<300).contains(statusCode) {
                        miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Response received.", japanese: "応答を受信しました。")
                    } else {
                        miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Response returned non-success status.", japanese: "成功以外のHTTPステータスが返りました。")
                    }
                    appendLog("[test-chat] response received: \(miniChatHTTPStatusText) in \(Int(elapsedMS)) ms.")
                }
            } catch is CancellationError {
                miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Cancelled.", japanese: "キャンセルしました。")
                miniChatMessages.append(MiniChatTranscriptMessage(sender: .system, content: miniChatStatus))
                appendLog("[test-chat] cancelled.")
            } catch {
                miniChatHTTPStatusText = "-"
                miniChatDurationText = "-"
                miniChatResponse = error.localizedDescription
                miniChatMessages.append(MiniChatTranscriptMessage(sender: .system, content: miniChatResponse))
                miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Request failed.", japanese: "リクエストに失敗しました。")
                appendLog("[test-chat] failed: \(error.localizedDescription)")
            }
            isMiniChatRunning = false
        }
    }

    func cancelMiniChatRequested() {
        miniChatTask?.cancel()
        miniChatTask = nil
        isMiniChatRunning = false
        miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Cancelled.", japanese: "キャンセルしました。")
        appendLog("[test-chat] cancelled by user.")
    }

    func clearMiniChatRequested() {
        miniChatPrompt = ""
        miniChatMessages = []
        miniChatResponse = ""
        miniChatStatus = "Ready."
        miniChatHTTPStatusText = "-"
        miniChatDurationText = "-"
    }

    func copyMiniChatResponseRequested() {
        guard !miniChatResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = copyToPasteboard(miniChatResponse)
    }

    func copyMiniChatMessageRequested(_ message: MiniChatTranscriptMessage) {
        guard message.sender == .assistant,
              !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        if copyToPasteboard(message.content) {
            miniChatStatus = Self.localizedText(language: settings.uiLanguage, english: "Copied response.", japanese: "返答をコピーしました。")
        }
    }

    nonisolated private static func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmed)/chat/completions")
    }

    nonisolated private static func fallbackMiniChatResponseText(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let text = String(data: prettyData, encoding: .utf8) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? ""
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
            let result = await readyChecker.check(
                host: host,
                port: port,
                expectedModelID: selectedModelIdentifier
            )
            handleReadyCheckResult(result, fallbackHost: host, fallbackPort: port)
        }
    }

    private func applyDownloadSettingsToDraft() {
        huggingFaceDownloadDraft.saveDirectory = settings.downloadSaveDirectory
        huggingFaceDownloadDraft.autoAddToModelList = true
        huggingFaceDownloadDraft.autoSelectAfterAdd = true
        huggingFaceDownloadDraft.useSelectedPreviewFiles = false
    }

    func saveSettingsRequested() {
        refreshDefaultUserFacingMessagesForCurrentLanguage()
        applyDownloadSettingsToDraft()
        do {
            try settingsStore.save(settings: settings, models: models)
            invalidatePortCheckCache()
            appendLog("[settings] Saved settings.json and models.json to \(settingsDirectoryPath).")
        } catch {
            appendLog("[settings] Failed to save settings: \(error.localizedDescription)")
        }
    }

    func chooseMLXServerExecutableRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose mlx_lm.server executable", japanese: "mlx_lm.server実行ファイルを選択")
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

    func chooseHermesAgentConfigRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose Hermes Agent config file", japanese: "Hermes Agent設定ファイルを選択")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .data]
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[hermes] config picker cancelled.")
            return
        }
        settings.hermesConfigPath = url.path
        saveSettingsRequested()
        hermesAgentConfigMessage = Self.localizedText(
            language: settings.uiLanguage,
            english: "Hermes Agent config file selected.",
            japanese: "Hermes Agent設定ファイルを選択しました。"
        )
        appendLog("[hermes] config path set to \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
    }

    func openHermesAgentConfigRequested() {
        let url = hermesAgentConfigService.expandedConfigURL(from: hermesAgentConfigPathText)
        guard FileManager.default.fileExists(atPath: url.path) else {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Hermes Agent config file was not found.",
                japanese: "Hermes Agent設定ファイルが見つかりません。"
            )
            appendLog("[hermes] open failed: config file not found at \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
            return
        }
        NSWorkspace.shared.open(url)
        appendLog("[hermes] opened config file: \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
    }

    func restoreHermesAgentConfigBackupRequested() {
        do {
            let restoredBackupURL = try hermesAgentConfigService.restoreLatestBackup(configPath: hermesAgentConfigPathText)
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Restored latest Hermes Agent backup: \(ModelAvailabilityPathFormatter.compact(path: restoredBackupURL.path))",
                japanese: "最新のHermes Agentバックアップを復元しました: \(ModelAvailabilityPathFormatter.compact(path: restoredBackupURL.path))"
            )
            appendLog("[hermes] restored latest backup: \(ModelAvailabilityPathFormatter.compact(path: restoredBackupURL.path)).")
        } catch {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not restore Hermes Agent backup: \(error.localizedDescription)",
                japanese: "Hermes Agentバックアップを復元できませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] restore failed: \(error.localizedDescription)")
        }
    }

    func chooseLocalModelFolderRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose local model folder", japanese: "ローカルモデルフォルダを選択")
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
            invalidateHuggingFaceFilePreview()
            huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(isLoading: false, message: preview.message, files: [])
            return
        }

        requestHuggingFaceFilePreview(
            identity: HuggingFaceFilePreviewIdentity(
                repositoryID: reference.repositoryID,
                revision: normalizedHuggingFaceRevision
            )
        )
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

    private func requestHuggingFaceFilePreview(
        identity: HuggingFaceFilePreviewIdentity,
        completion: (() -> Void)? = nil
    ) {
        huggingFaceFilePreviewTask?.cancel()
        huggingFaceFilePreviewGeneration += 1
        let generation = huggingFaceFilePreviewGeneration
        huggingFaceFilePreviewIdentity = identity
        huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(
            isLoading: true,
            message: Self.localizedText(language: settings.uiLanguage, english: "Fetching file list...", japanese: "ファイル一覧を取得中..."),
            files: []
        )
        selectedHuggingFacePreviewFileIDs = []

        huggingFaceFilePreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let files = try await huggingFaceRepositoryFileService.fetchFiles(
                    repositoryID: identity.repositoryID,
                    revision: identity.revision,
                    token: huggingFaceCredentialStore.readValue()
                )
                guard !Task.isCancelled,
                      generation == huggingFaceFilePreviewGeneration,
                      huggingFaceFilePreviewIdentity == identity,
                      currentHuggingFaceDraftIdentity == identity else {
                    return
                }

                huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(
                    isLoading: false,
                    message: files.isEmpty
                        ? Self.localizedText(language: settings.uiLanguage, english: "No downloadable files found.", japanese: "ダウンロード対象ファイルが見つかりません。")
                        : Self.localizedText(language: settings.uiLanguage, english: "File list is ready.", japanese: "ファイル一覧を取得しました。"),
                    files: files
                )
                selectedHuggingFacePreviewFileIDs = Set(files.map(\.id))
                appendLog("[hf] preview fetched \(files.count) files for \(identity.repositoryID) at \(identity.revision).")
                completion?()
            } catch is CancellationError {
                return
            } catch {
                guard generation == huggingFaceFilePreviewGeneration,
                      huggingFaceFilePreviewIdentity == identity else {
                    return
                }
                huggingFaceFilePreview = HuggingFaceDownloadFilePreviewState(isLoading: false, message: error.localizedDescription, files: [])
                selectedHuggingFacePreviewFileIDs = []
                appendLog("[hf] preview failed for \(identity.repositoryID) at \(identity.revision): \(error.localizedDescription)")
            }

            if generation == huggingFaceFilePreviewGeneration {
                huggingFaceFilePreviewTask = nil
            }
        }
    }

    private func invalidateHuggingFaceFilePreview() {
        huggingFaceFilePreviewTask?.cancel()
        huggingFaceFilePreviewTask = nil
        huggingFaceFilePreviewGeneration += 1
        huggingFaceFilePreviewIdentity = nil
        huggingFaceFilePreview = .waiting
        selectedHuggingFacePreviewFileIDs = []
    }

    func chooseHuggingFaceDownloadDirectoryRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose Hugging Face download save directory", japanese: "Hugging Faceダウンロード保存先を選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[hf] download directory picker cancelled.")
            return
        }
        settings.downloadSaveDirectory = url.path
        huggingFaceDownloadDraft.saveDirectory = url.path
        saveSettingsRequested()
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

        applyDownloadSettingsToDraft()
        let preview = huggingFaceDownloadPreview
        guard let reference = preview.reference,
              let destinationPath = preview.destinationPath else {
            huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
                phase: .failed,
                message: downloadReadinessMessage(previewMessage: preview.message),
                repositoryID: nil,
                destinationPath: nil,
                progress: nil,
                outputLines: []
            )
            appendLog("[hf] download not started: \(preview.message)")
            return
        }

        guard canStartHuggingFaceDownload else {
            huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
                phase: .failed,
                message: downloadReadinessMessage(previewMessage: preview.message),
                repositoryID: reference.repositoryID,
                destinationPath: destinationPath,
                progress: nil,
                outputLines: []
            )
            appendLog("[hf] download blocked: missing required tag for \(reference.repositoryID).")
            return
        }

        guard prepareHuggingFaceFileListForDownload(reference: reference, destinationPath: destinationPath) else {
            return
        }

        let displayName = preview.displayName
        let draft = huggingFaceDownloadDraft
        let expectedDownloadFiles = huggingFaceExpectedDownloadFiles()
        let expectedDownloadBytes = totalBytes(for: expectedDownloadFiles)
        let queueEntryID = UUID()
        let entryPhase: HuggingFaceDownloadPhase = activeHuggingFaceDownloadTasks.count < settings.maxConcurrentModelDownloads ? .preparing : .waiting
        huggingFaceDownloadQueue.insert(
            HuggingFaceDownloadQueueEntry(
                id: queueEntryID,
                repositoryID: reference.repositoryID,
                destinationPath: destinationPath,
                phase: entryPhase,
                message: entryPhase == .waiting ? "Waiting for an available download slot." : "Preparing",
                fileCount: expectedDownloadFiles.isEmpty ? nil : expectedDownloadFiles.count,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: expectedDownloadBytes,
                speedBytesPerSecond: nil
            ),
            at: 0
        )
        queuedHuggingFaceDownloads[queueEntryID] = QueuedHuggingFaceDownload(
            id: queueEntryID,
            reference: reference,
            destinationPath: destinationPath,
            displayName: displayName,
            draft: draft,
            expectedFiles: expectedDownloadFiles,
            expectedBytes: expectedDownloadBytes
        )
        if primaryHuggingFaceDownloadID == nil {
            primaryHuggingFaceDownloadID = queueEntryID
        }
        downloadCompletionMarkerDate = nil
        refreshAggregateHuggingFaceDownloadStatus()
        appendLog("[hf] queued Hugging Face download for \(reference.repositoryID).")
        appendLog("[hf] destination: \(ModelAvailabilityPathFormatter.compact(path: destinationPath))")
        drainHuggingFaceDownloadQueue()
    }

    private func prepareHuggingFaceFileListForDownload(
        reference: HuggingFaceModelReference,
        destinationPath: String
    ) -> Bool {
        let identity = HuggingFaceFilePreviewIdentity(
            repositoryID: reference.repositoryID,
            revision: normalizedHuggingFaceRevision
        )

        if huggingFaceFilePreviewIdentity == identity,
           !filteredHuggingFacePreviewFiles.isEmpty {
            return true
        }

        huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
            phase: .preparing,
            message: Self.localizedText(
                language: settings.uiLanguage,
                english: "Preparing file list before download...",
                japanese: "ダウンロード前にファイル一覧を取得しています..."
            ),
            repositoryID: reference.repositoryID,
            destinationPath: destinationPath,
            progress: nil,
            outputLines: []
        )

        if huggingFaceFilePreview.isLoading,
           huggingFaceFilePreviewIdentity == identity {
            return false
        }

        appendLog("[hf] preparing file list before download for \(reference.repositoryID) at \(identity.revision).")
        requestHuggingFaceFilePreview(identity: identity) { [weak self] in
            guard let self,
                  self.huggingFaceFilePreviewIdentity == identity,
                  self.currentHuggingFaceDraftIdentity == identity else {
                return
            }

            guard !self.filteredHuggingFacePreviewFiles.isEmpty else {
                self.huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
                    phase: .failed,
                    message: Self.localizedText(
                        language: self.settings.uiLanguage,
                        english: "No downloadable files were found. Choose another model or check the repository.",
                        japanese: "ダウンロード対象ファイルが見つかりません。別のモデルを選ぶか、リポジトリを確認してください。"
                    ),
                    repositoryID: reference.repositoryID,
                    destinationPath: destinationPath,
                    progress: nil,
                    outputLines: []
                )
                return
            }

            self.startHuggingFaceDownloadRequested()
        }

        return false
    }

    private func downloadReadinessMessage(previewMessage: String) -> String {
        let trimmedSource = huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return previewMessage
        }
        guard let selectedHuggingFaceSearchResult,
              selectedHuggingFaceSearchResult.id == trimmedSource else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Search the model first to verify the required MLX tag.",
                japanese: "必要なMLXタグを確認するため、先にモデルを検索してください。"
            )
        }
        guard selectedHuggingFaceSearchResult.isSupportedForDownload else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "This model does not have the required MLX tag and cannot be downloaded.",
                japanese: "このモデルには必要なMLXタグがないため、ダウンロードできません。"
            )
        }
        return previewMessage
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
        guard isHuggingFaceDownloadRunning || huggingFaceDownloadQueue.contains(where: { $0.phase == .waiting }) else {
            appendLog("[hf] no active download to cancel.")
            return
        }

        let cancellableIDs = Set(huggingFaceDownloadQueue.filter { entry in
            entry.phase == .waiting || entry.phase == .preparing || entry.phase == .downloading || entry.phase == .finalizing
        }.map(\.id))
        cancelledHuggingFaceDownloadIDs.formUnion(cancellableIDs)
        for id in cancellableIDs where activeHuggingFaceDownloadTasks[id] == nil {
            updateHuggingFaceQueueEntry(
                id,
                phase: .cancelled,
                message: "Download cancelled. The model was not added."
            )
            queuedHuggingFaceDownloads[id] = nil
        }
        activeHuggingFaceDownloadManagers.values.forEach { $0.cancel() }
        activeHuggingFaceDownloadTasks.values.forEach { $0.cancel() }
        appendLog("[hf] cancel requested for \(cancellableIDs.count) download(s).")
    }

    func resetHuggingFaceDownloadStatus() {
        guard !isHuggingFaceDownloadRunning else {
            return
        }

        huggingFaceDownloadStatus = .waiting
    }

    func refreshHuggingFaceCLIRequested() {
        refreshHuggingFaceCLIStatus(logResult: true)
    }

    func refreshAria2Status() {
        aria2Availability = Aria2AvailabilityChecker.check()
    }

    private func refreshHuggingFaceCLIStatus(logResult: Bool) {
        if let resolution = HuggingFaceDownloadManager.resolveCLI() {
            isHuggingFaceCLIAvailable = true
            huggingFaceCLIPath = resolution.displayPath
            huggingFaceCLIMessage = Self.localizedText(language: settings.uiLanguage, english: "Available", japanese: "利用可能")
            if logResult {
                appendLog("[hf] CLI detected at \(resolution.displayPath).")
            }
        } else {
            let candidates = HuggingFaceDownloadManager.candidateExecutablePaths()
            let checked = candidates
                .map { ModelAvailabilityPathFormatter.compact(path: $0) }
                .joined(separator: ", ")
            isHuggingFaceCLIAvailable = false
            huggingFaceCLIPath = Self.localizedText(language: settings.uiLanguage, english: "Not found", japanese: "見つかりません")
            huggingFaceCLIMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Install Hugging Face CLI, then press Retry CLI or restart the app.",
                japanese: "Hugging Face CLIをインストールしてから、CLI再確認を押すかアプリを再起動してください。"
            )
            if logResult {
                appendLog("[hf] CLI not found. Checked: \(checked)")
            }
        }
    }

    func performHuggingFaceSearchRequested() {
        let query = huggingFaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        huggingFaceSearchTask?.cancel()
        huggingFaceSearchGeneration += 1
        let generation = huggingFaceSearchGeneration

        guard !query.isEmpty else {
            huggingFaceSearchResults = []
            selectedHuggingFaceSearchResult = nil
            invalidateHuggingFaceFilePreview()
            isHuggingFaceSearching = false
            huggingFaceSearchMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Enter a search term before searching.",
                japanese: "検索前に検索語を入力してください。"
            )
            appendLog("[hf] search skipped: empty query.")
            return
        }

        isHuggingFaceSearching = true
        huggingFaceSearchMessage = Self.localizedText(language: settings.uiLanguage, english: "Searching Hugging Face for: \(query)", japanese: "Hugging Faceを検索中: \(query)")
        appendLog("[hf] search started: \(query)")

        huggingFaceSearchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await huggingFaceSearchService.search(query: query, limit: 10)
                guard !Task.isCancelled,
                      generation == huggingFaceSearchGeneration,
                      huggingFaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    return
                }

                huggingFaceSearchResults = results
                if let exactResult = results.first(where: { $0.id.caseInsensitiveCompare(query) == .orderedSame }) ?? results.first {
                    selectHuggingFaceSearchResult(exactResult)
                    huggingFaceSearchMessage = Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Selected search result. Review the details, then press Download.",
                        japanese: "検索結果を選択しました。内容を確認してからダウンロードしてください。"
                    )
                } else {
                    selectedHuggingFaceSearchResult = nil
                    invalidateHuggingFaceFilePreview()
                    huggingFaceSearchMessage = Self.localizedText(
                        language: settings.uiLanguage,
                        english: "No matching models found. Try another query or paste an exact ID / URL.",
                        japanese: "一致するモデルが見つかりません。別の語句で検索するか、正確なModel ID / URLを貼り付けてください。"
                    )
                }
                appendLog("[hf] search completed with \(results.count) results.")
            } catch is CancellationError {
                return
            } catch {
                guard generation == huggingFaceSearchGeneration else {
                    return
                }
                huggingFaceSearchResults = []
                selectedHuggingFaceSearchResult = nil
                invalidateHuggingFaceFilePreview()
                huggingFaceSearchMessage = error.localizedDescription
                appendLog("[hf] search failed: \(error.localizedDescription)")
            }

            if generation == huggingFaceSearchGeneration {
                isHuggingFaceSearching = false
                huggingFaceSearchTask = nil
            }
        }
    }

    func selectHuggingFaceSearchResult(_ result: HuggingFaceSearchResult) {
        let previousIdentity = currentHuggingFaceDraftIdentity
        selectedHuggingFaceSearchResult = result
        huggingFaceDownloadDraft.source = result.id
        huggingFaceDownloadDraft.displayName = result.name
        if previousIdentity != currentHuggingFaceDraftIdentity {
            invalidateHuggingFaceFilePreview()
        }
        huggingFaceSearchMessage = result.selectionMessage(language: settings.uiLanguage)
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
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Enter a local folder path such as ~/Models/mlx/model-name.", japanese: "~/Models/mlx/model-name のようなローカルフォルダパスを入力してください。")
            appendLog("[profile] local model add failed: invalid local path.")
            return
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Local model folder was not found.", japanese: "ローカルモデルフォルダが見つかりません。")
            appendLog("[profile] local model add failed: folder not found at \(ModelAvailabilityPathFormatter.compact(path: expandedPath)).")
            return
        }

        if models.contains(where: { $0.modelID == expandedPath }) {
            selectedModelID = expandedPath
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Existing local model profile selected.", japanese: "既存のローカルモデルプロファイルを選択しました。")
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
            invalidateModelSizeCache(for: model)
            invalidatePortCheckCache()
            models = nextModels
            selectedModelID = model.id
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(
                for: model,
                result: .present(path: expandedPath)
            )
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Local model added and selected.", japanese: "ローカルモデルを追加して選択しました。")
            appendLog("[profile] local model added: \(displayName).")
        } catch {
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Could not save local model profile: \(error.localizedDescription)", japanese: "ローカルモデルプロファイルを保存できませんでした: \(error.localizedDescription)")
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
            profileEditorMessage = Self.localizedText(language: settings.uiLanguage, english: "No model is selected.", japanese: "モデルが選択されていません。")
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
            let message = Self.localizedText(language: settings.uiLanguage, english: "No model profiles are available to export.", japanese: "エクスポートできるモデルプロファイルがありません。")
            modelProfileExportMessage = message
            appendLog("[profile] export failed: \(message)")
            return
        }

        let panel = NSSavePanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Export Model Profiles", japanese: "モデルプロファイルをエクスポート")
        panel.nameFieldStringValue = "MLXServerManager-Profiles.json"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            modelProfileExportMessage = Self.localizedText(language: settings.uiLanguage, english: "Export cancelled.", japanese: "エクスポートをキャンセルしました。")
            appendLog("[profile] export cancelled.")
            return
        }

        do {
            let data = try modelProfileExportService.exportData(from: models)
            try data.write(to: url, options: [.atomic])

            let message = Self.localizedText(language: settings.uiLanguage, english: "Exported \(models.count) profile(s) to \(url.lastPathComponent).", japanese: "\(models.count)件のプロファイルを\(url.lastPathComponent)へエクスポートしました。")
            modelProfileExportMessage = message
            appendLog("[profile] \(message)")
            appendLog("[profile] export includes profile metadata only. It does not include API keys, tokens, model weights, caches, logs, executable paths, or runtime state.")
        } catch {
            let message = error.localizedDescription
            modelProfileExportMessage = Self.localizedText(language: settings.uiLanguage, english: "Export failed: \(message)", japanese: "エクスポートに失敗しました: \(message)")
            appendLog("[profile] export failed: \(message)")
        }
    }

    func importProfilesPreviewRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Import Model Profiles Preview", japanese: "モデルプロファイルのインポートプレビュー")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Import preview cancelled.", japanese: "インポートプレビューをキャンセルしました。")
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
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Previewed \(result.totalProfiles) profile row(s) from \(result.sourceFileName).", japanese: "\(result.sourceFileName)から\(result.totalProfiles)件のプロファイル行をプレビューしました。")
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
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Import preview failed: \(error.localizedDescription)", japanese: "インポートプレビューに失敗しました: \(error.localizedDescription)")
            appendLog("[profile] import preview failed: \(error.localizedDescription)")
        }
    }

    func dismissImportPreview() {
        isImportPreviewPresented = false
    }

    func importSelectedProfilesRequested(requests: [ImportSelectedProfileRequest]) {
        guard let importPreviewResult else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "No import preview is available.", japanese: "利用できるインポートプレビューがありません。")
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
            let message = importResult.messages.last ?? Self.localizedText(language: settings.uiLanguage, english: "No profiles were imported or replaced.", japanese: "インポートまたは置換されたプロファイルはありません。")
            modelProfileImportMessage = message
            return
        }

        let previousSelectedModelID = selectedModelID
        let nextModels = importResult.modelsAfterImport

        do {
            try settingsStore.save(models: nextModels)
            invalidateModelSizeCache()
            invalidatePortCheckCache()
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

            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Imported \(importResult.importedCount) profile(s). Renamed \(importResult.renamedCount) profile(s). Replaced \(importResult.replacedCount) profile(s). Skipped \(importResult.skippedCount) profile(s).", japanese: "\(importResult.importedCount)件をインポート、\(importResult.renamedCount)件をリネーム、\(importResult.replacedCount)件を置換、\(importResult.skippedCount)件をスキップしました。")
            appendLog("[profile] profile metadata changes saved to models.json.")
            if selectionUpdate.preservedThroughReplacement {
                appendLog("[profile] selected profile was preserved through the explicit Replace action. No server lifecycle action was taken.")
            } else {
                appendLog("[profile] selected profile was not changed. No server lifecycle action was taken.")
            }
            isImportPreviewPresented = false
        } catch {
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Import failed: \(error.localizedDescription)", japanese: "インポートに失敗しました: \(error.localizedDescription)")
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
                invalidateModelSizeCache(for: newModel)
                invalidatePortCheckCache()
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
            let message = Self.localizedText(language: settings.uiLanguage, english: "No model is selected.", japanese: "モデルが選択されていません。")
            profileDeletionMessage = message
            appendLog("[profile] delete failed: No model is selected.")
            return
        }

        guard models.count > 1 else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "At least one model profile is required.", japanese: "少なくとも1件のモデルプロファイルが必要です。")
            profileDeletionMessage = message
            appendLog("[profile] delete failed: At least one model profile is required.")
            return
        }

        guard !isManagedProcessRunning else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "Stop the managed server before deleting profiles.", japanese: "プロファイルを削除する前に管理サーバーを停止してください。")
            profileDeletionMessage = message
            appendLog("[profile] delete failed: Stop the managed server before deleting profiles.")
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

    func confirmDeleteProfile(deleteHuggingFaceCache: Bool = false) {
        guard let pendingDeleteModelID else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "No model profile is pending deletion.", japanese: "削除待ちのモデルプロファイルはありません。")
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: No model profile is pending deletion.")
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
        let cacheDeletionMessage = deleteHuggingFaceCache
            ? deleteHuggingFaceCacheIfAvailable(for: deletedModel)
            : nil
        var nextModels = models
        nextModels.remove(at: index)

        guard let fallbackModel = nextModels.first else {
            let message = "At least one model profile is required."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        var nextSettings = settings
        nextSettings.autoUnloadEnabledByModelID.removeValue(forKey: deletedModel.id)
        nextSettings.autoUnloadMinutesByModelID.removeValue(forKey: deletedModel.id)

        do {
            try settingsStore.save(settings: nextSettings, models: nextModels)
            invalidateModelSizeCache(for: deletedModel)
            invalidatePortCheckCache()
            settings = nextSettings
            autoUnloadEnabledByModelID = nextSettings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = nextSettings.autoUnloadMinutesByModelID
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
            profileDeletionMessage = cacheDeletionMessage
            self.pendingDeleteModelID = nil
            isDeleteProfileConfirmationPresented = false
        } catch {
            profileDeletionMessage = error.localizedDescription
            self.pendingDeleteModelID = nil
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(error.localizedDescription)")
        }
    }

    private func deleteHuggingFaceCacheIfAvailable(for model: ModelConfig) -> String {
        guard let cacheURL = huggingFaceCacheURL(for: model) else {
            appendLog("[profile] Hugging Face cache delete skipped: repository ID could not be resolved for \(model.modelID).")
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile deleted. Hugging Face cache was not deleted because the repository ID could not be resolved.",
                japanese: "プロファイルを削除しました。リポジトリIDを特定できなかったため、Hugging Faceキャッシュは削除していません。"
            )
        }

        guard cacheURL.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) else {
            appendLog("[profile] Hugging Face cache delete skipped: resolved path is outside the home directory.")
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile deleted. Hugging Face cache was not deleted because the resolved cache path was outside the home directory.",
                japanese: "プロファイルを削除しました。解決されたキャッシュパスがホームディレクトリ外だったため、Hugging Faceキャッシュは削除していません。"
            )
        }

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            appendLog("[profile] Hugging Face cache was not present at \(ModelAvailabilityPathFormatter.compact(path: cacheURL.path)).")
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile deleted. Matching Hugging Face cache was not found.",
                japanese: "プロファイルを削除しました。一致するHugging Faceキャッシュは見つかりませんでした。"
            )
        }

        do {
            try FileManager.default.removeItem(at: cacheURL)
            appendLog("[profile] deleted Hugging Face cache at \(ModelAvailabilityPathFormatter.compact(path: cacheURL.path)).")
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile and matching Hugging Face cache were deleted.",
                japanese: "プロファイルと一致するHugging Faceキャッシュを削除しました。"
            )
        } catch {
            appendLog("[profile] Hugging Face cache delete failed: \(error.localizedDescription)")
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile deleted, but Hugging Face cache deletion failed: \(error.localizedDescription)",
                japanese: "プロファイルは削除しましたが、Hugging Faceキャッシュの削除に失敗しました: \(error.localizedDescription)"
            )
        }
    }

    private func huggingFaceCacheURL(for model: ModelConfig) -> URL? {
        guard let repositoryID = huggingFaceRepositoryID(for: model) else {
            return nil
        }

        let parts = repositoryID.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return nil
        }

        let cacheFolderName = "models--\(parts[0])--\(parts[1])"
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
            .appendingPathComponent(cacheFolderName, isDirectory: true)
    }

    private func huggingFaceRepositoryID(for model: ModelConfig) -> String? {
        if let repositoryID = Self.validHuggingFaceRepositoryID(model.modelID) {
            return repositoryID
        }

        return Self.huggingFaceRepositoryID(in: model.notes)
    }

    nonisolated private static func validHuggingFaceRepositoryID(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~"),
              !trimmed.localizedCaseInsensitiveContains("file:"),
              trimmed.split(separator: "/").count == 2,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        return trimmed
    }

    nonisolated private static func huggingFaceRepositoryID(in text: String) -> String? {
        let pattern = #"(?:huggingface\.co/|Downloaded from\s+)([A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let repositoryRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return validHuggingFaceRepositoryID(String(text[repositoryRange]))
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
            var nextModels = models
            nextModels[index] = updatedModel
            var nextSettings = settings
            if existingModel.id != updatedModel.id {
                if let enabled = nextSettings.autoUnloadEnabledByModelID.removeValue(forKey: existingModel.id) {
                    nextSettings.autoUnloadEnabledByModelID[updatedModel.id] = enabled
                }
                if let minutes = nextSettings.autoUnloadMinutesByModelID.removeValue(forKey: existingModel.id) {
                    nextSettings.autoUnloadMinutesByModelID[updatedModel.id] = minutes
                }
            }

            do {
                try settingsStore.save(settings: nextSettings, models: nextModels)
                invalidateModelSizeCache(for: existingModel)
                invalidateModelSizeCache(for: updatedModel)
                invalidatePortCheckCache()
                settings = nextSettings
                autoUnloadEnabledByModelID = nextSettings.autoUnloadEnabledByModelID
                autoUnloadMinutesByModelID = nextSettings.autoUnloadMinutesByModelID
                models = nextModels
                selectedModelID = updatedModel.id
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

    func applyHermesAgentConfigRequested() {
        guard canApplyHermesAgentConfig else {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Select a model and configure the Hermes Agent config file path first.",
                japanese: "先にモデルを選択し、Hermes Agent設定ファイルのパスを設定してください。"
            )
            appendLog("[hermes] apply skipped: missing selected model or config path.")
            return
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
        } catch {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not apply Hermes Agent config: \(error.localizedDescription)",
                japanese: "Hermes Agent設定を反映できませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] apply failed: \(error.localizedDescription)")
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
        copyToPasteboard("\(title)\n\(result.localizedDetailedText(language: settings.uiLanguage))")
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
        let preview = LaunchCommandBuilder.command(
            executablePath: settings.mlxServerExecutablePath,
            model: model
        )
        copyLaunchCommandPreview(preview)
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

    private func drainHuggingFaceDownloadQueue() {
        let maxActiveDownloads = min(max(settings.maxConcurrentModelDownloads, 1), 5)
        while activeHuggingFaceDownloadTasks.count < maxActiveDownloads {
            guard let nextEntry = huggingFaceDownloadQueue.reversed().first(where: { entry in
                queuedHuggingFaceDownloads[entry.id] != nil
                    && activeHuggingFaceDownloadTasks[entry.id] == nil
                    && (entry.phase == .waiting || entry.phase == .preparing)
            }), let job = queuedHuggingFaceDownloads[nextEntry.id] else {
                return
            }
            startQueuedHuggingFaceDownload(job)
        }
    }

    private func startQueuedHuggingFaceDownload(_ job: QueuedHuggingFaceDownload) {
        updateHuggingFaceQueueEntry(
            job.id,
            phase: .preparing,
            message: "Preparing destination: \(ModelAvailabilityPathFormatter.compact(path: job.destinationPath))"
        )
        appendLog("[hf] starting Hugging Face download for \(job.reference.repositoryID).")
        let manager = huggingFaceDownloadManagerFactory()
        activeHuggingFaceDownloadManagers[job.id] = manager
        startHuggingFaceProgressPolling(
            destinationPath: job.destinationPath,
            expectedFiles: job.expectedFiles,
            totalBytes: job.expectedBytes,
            queueEntryID: job.id
        )

        activeHuggingFaceDownloadTasks[job.id] = Task { [weak self] in
            await self?.runHuggingFaceDownload(job: job, manager: manager)
        }
    }

    private func runHuggingFaceDownload(job: QueuedHuggingFaceDownload, manager: HuggingFaceModelDownloading) async {
        do {
            updateHuggingFaceQueueEntry(
                job.id,
                phase: .downloading,
                message: "Downloading \(job.reference.repositoryID)..."
            )

            let result = try await manager.download(
                request: HuggingFaceDownloadRequest(
                    repositoryID: job.reference.repositoryID,
                    destinationPath: job.destinationPath,
                    revision: job.draft.revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "main" : job.draft.revision.trimmingCharacters(in: .whitespacesAndNewlines),
                    includePatterns: job.draft.useSelectedPreviewFiles ? job.expectedFiles.map(\.path) : Self.patternList(from: job.draft.includePatterns),
                    excludePatterns: Self.patternList(from: job.draft.excludePatterns),
                    authorizationValue: huggingFaceCredentialStore.readValue()
                ),
                outputHandler: { [weak self] line in
                    Task { @MainActor in
                        self?.appendHuggingFaceOutputLine(line, queueEntryID: job.id)
                    }
                }
            )

            guard !cancelledHuggingFaceDownloadIDs.contains(job.id) else {
                finishHuggingFaceDownload(job.id)
                updateHuggingFaceQueueEntry(job.id, phase: .cancelled, message: "Cancelled")
                appendLog("[hf] download cancelled for \(job.reference.repositoryID).")
                drainHuggingFaceDownloadQueue()
                return
            }

            updateHuggingFaceQueueEntry(
                job.id,
                phase: .finalizing,
                message: "Finalizing downloaded model profile...",
                progress: 1
            )
            stopHuggingFaceProgressPolling(queueEntryID: job.id)

            if job.draft.autoAddToModelList,
               let profileAddError = addDownloadedHuggingFaceModelProfile(
                   reference: job.reference,
                   destinationPath: result.destinationPath,
                   displayName: job.displayName,
                   draft: job.draft
               ) {
                updateHuggingFaceQueueEntry(job.id, phase: .failed, message: profileAddError)
                finishHuggingFaceDownload(job.id)
                drainHuggingFaceDownloadQueue()
                return
            }

            downloadCompletionMarkerDate = Date()
            updateHuggingFaceQueueEntry(
                job.id,
                phase: .completed,
                message: job.draft.autoAddToModelList
                    ? "Download completed. Added to model list and selected. Ready to start."
                    : "Download completed. Auto-add was disabled.",
                progress: 1
            )
            appendLog("[hf] download completed for \(job.reference.repositoryID).")
            appendLog("[hf] saved to \(ModelAvailabilityPathFormatter.compact(path: result.destinationPath)).")
            finishHuggingFaceDownload(job.id)
            drainHuggingFaceDownloadQueue()
        } catch {
            if cancelledHuggingFaceDownloadIDs.contains(job.id) {
                updateHuggingFaceQueueEntry(
                    job.id,
                    phase: .cancelled,
                    message: "Download cancelled. The model was not added."
                )
                appendLog("[hf] download cancelled for \(job.reference.repositoryID).")
            } else {
                let guidance = huggingFaceDownloadFailureGuidance(from: error)
                updateHuggingFaceQueueEntry(job.id, phase: .failed, message: guidance)
                appendLog("[hf] download failed for \(job.reference.repositoryID): \(guidance)")
            }
            finishHuggingFaceDownload(job.id)
            drainHuggingFaceDownloadQueue()
        }
    }

    private func finishHuggingFaceDownload(_ id: UUID) {
        stopHuggingFaceProgressPolling(queueEntryID: id)
        activeHuggingFaceDownloadTasks[id] = nil
        activeHuggingFaceDownloadManagers[id] = nil
        queuedHuggingFaceDownloads[id] = nil
        huggingFaceDownloadOutputLinesByID[id] = nil
        cancelledHuggingFaceDownloadIDs.remove(id)
        if primaryHuggingFaceDownloadID == id {
            primaryHuggingFaceDownloadID = nil
        }
        refreshAggregateHuggingFaceDownloadStatus()
        if activeHuggingFaceDownloadTasks.isEmpty,
           !huggingFaceDownloadQueue.contains(where: { $0.phase == .waiting || $0.phase == .preparing }) {
            stopHuggingFaceProgressPolling()
        }
    }

    private var normalizedHuggingFaceRevision: String {
        let value = huggingFaceDownloadDraft.revision.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "main" : value
    }

    private var currentHuggingFaceDraftIdentity: HuggingFaceFilePreviewIdentity? {
        guard let reference = huggingFaceDownloadPreview.reference else {
            return nil
        }
        return HuggingFaceFilePreviewIdentity(
            repositoryID: reference.repositoryID,
            revision: normalizedHuggingFaceRevision
        )
    }

    private var huggingFaceFilePreviewMatchesCurrentDraft: Bool {
        guard let huggingFaceFilePreviewIdentity,
              let currentHuggingFaceDraftIdentity else {
            return false
        }
        return huggingFaceFilePreviewIdentity == currentHuggingFaceDraftIdentity
    }

    private func huggingFaceIncludePatternsForDownload() -> [String] {
        if huggingFaceDownloadDraft.useSelectedPreviewFiles, !selectedHuggingFacePreviewFiles.isEmpty {
            return selectedHuggingFacePreviewFiles.map(\.path)
        }
        return Self.patternList(from: huggingFaceDownloadDraft.includePatterns)
    }

    private func huggingFaceExpectedDownloadFiles() -> [HuggingFaceDownloadPreviewFile] {
        let files = huggingFaceDownloadDraft.useSelectedPreviewFiles ? selectedHuggingFacePreviewFiles : filteredHuggingFacePreviewFiles
        return files
    }

    private func totalBytes(for files: [HuggingFaceDownloadPreviewFile]) -> Int64? {
        guard !files.isEmpty else {
            return nil
        }

        var total: Int64 = 0
        for file in files {
            guard let size = file.size else {
                return nil
            }
            total += size
        }
        return total > 0 ? total : nil
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
            return Self.localizedText(language: settings.uiLanguage, english: "Hugging Face CLI was not found. Install `hf`, then press Retry CLI.", japanese: "Hugging Face CLIが見つかりません。`hf`をインストールしてからCLI再確認を押してください。")
        }
        if lowercased.contains("401") || lowercased.contains("403") || lowercased.contains("gated") || lowercased.contains("unauthorized") {
            return Self.localizedText(language: settings.uiLanguage, english: "This may be gated or require authentication. Open the model page in a browser and confirm access.", japanese: "ゲート付き、または認証が必要な可能性があります。ブラウザでモデルページを開き、アクセス権を確認してください。")
        }
        if lowercased.contains("404") || lowercased.contains("not found") || lowercased.contains("invalid") {
            return Self.localizedText(language: settings.uiLanguage, english: "Repository was not found. Confirm the model ID or choose another search result.", japanese: "リポジトリが見つかりません。Model IDを確認するか、別の検索結果を選択してください。")
        }
        if lowercased.contains("permission") || lowercased.contains("denied") {
            return Self.localizedText(language: settings.uiLanguage, english: "Permission denied. Choose another save folder or check folder permissions.", japanese: "権限がありません。別の保存フォルダを選択するか、フォルダ権限を確認してください。")
        }
        if lowercased.contains("network") || lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("could not resolve") {
            return Self.localizedText(language: settings.uiLanguage, english: "Network failure. Check the connection and retry the download.", japanese: "ネットワーク障害です。接続を確認し、ダウンロードを再試行してください。")
        }
        if lowercased.contains("disk") || lowercased.contains("space") || lowercased.contains("no space") {
            return Self.localizedText(language: settings.uiLanguage, english: "Disk or destination problem. Check free space and the save folder.", japanese: "ディスクまたは保存先の問題です。空き容量と保存フォルダを確認してください。")
        }
        return message
    }

    private func updateHuggingFaceQueueEntry(_ id: UUID, phase: HuggingFaceDownloadPhase, message: String, progress: Double? = nil) {
        guard let index = huggingFaceDownloadQueue.firstIndex(where: { $0.id == id }) else {
            return
        }
        huggingFaceDownloadQueue[index].phase = phase
        huggingFaceDownloadQueue[index].message = message
        if let progress, let totalBytes = huggingFaceDownloadQueue[index].totalBytes, totalBytes > 0 {
            huggingFaceDownloadQueue[index].downloadedBytes = Int64(progress * Double(totalBytes))
        }
        refreshAggregateHuggingFaceDownloadStatus()
    }

    private func refreshAggregateHuggingFaceDownloadStatus() {
        let primaryEntry = primaryHuggingFaceDownloadID.flatMap { id in
            huggingFaceDownloadQueue.first(where: { $0.id == id && !$0.phase.isTerminal })
        }
        let fallbackEntry = huggingFaceDownloadQueue.first(where: { !$0.phase.isTerminal })
            ?? huggingFaceDownloadQueue.first

        guard let entry = primaryEntry ?? fallbackEntry else {
            primaryHuggingFaceDownloadID = nil
            return
        }

        primaryHuggingFaceDownloadID = entry.id
        huggingFaceDownloadStatus = HuggingFaceDownloadStatus(
            phase: entry.phase,
            message: entry.message,
            repositoryID: entry.repositoryID,
            destinationPath: entry.destinationPath,
            progress: entry.progressFraction,
            outputLines: huggingFaceDownloadOutputLinesByID[entry.id] ?? []
        )
    }

    private func updateMeasuredHuggingFaceProgress(
        queueEntryID: UUID,
        downloadedBytes: Int64,
        downloadedFileCount: Int,
        totalBytes: Int64?,
        speedBytesPerSecond: Int64?
    ) {
        guard let index = huggingFaceDownloadQueue.firstIndex(where: { $0.id == queueEntryID }) else {
            return
        }

        let safeDownloadedBytes = max(downloadedBytes, 0)
        huggingFaceDownloadQueue[index].phase = .downloading
        huggingFaceDownloadQueue[index].downloadedFileCount = min(
            max(downloadedFileCount, 0),
            huggingFaceDownloadQueue[index].fileCount ?? max(downloadedFileCount, 0)
        )
        huggingFaceDownloadQueue[index].speedBytesPerSecond = speedBytesPerSecond

        if let totalBytes, totalBytes > 0 {
            let clampedDownloadedBytes = min(safeDownloadedBytes, totalBytes)
            let progress = min(max(Double(clampedDownloadedBytes) / Double(totalBytes), 0), 1)
            huggingFaceDownloadQueue[index].message = "Downloading... \(Int(progress * 100))%"
            huggingFaceDownloadQueue[index].downloadedBytes = clampedDownloadedBytes
            huggingFaceDownloadQueue[index].totalBytes = totalBytes
        } else {
            let downloadedText = ByteCountFormatter.string(fromByteCount: safeDownloadedBytes, countStyle: .file)
            huggingFaceDownloadQueue[index].message = "Downloading... \(downloadedText)"
            huggingFaceDownloadQueue[index].downloadedBytes = safeDownloadedBytes
        }

        refreshAggregateHuggingFaceDownloadStatus()
    }

    private func startHuggingFaceProgressPolling(
        destinationPath: String,
        expectedFiles: [HuggingFaceDownloadPreviewFile],
        totalBytes: Int64?,
        queueEntryID: UUID
    ) {
        stopHuggingFaceProgressPolling(queueEntryID: queueEntryID)

        let task = Task { [weak self] in
            var lastBytes: Int64 = 0
            var lastDate = Date()

            while !Task.isCancelled {
                let snapshot = await Task.detached(priority: .utility) {
                    HuggingFaceDownloadProgressMeasurer.snapshot(
                        destinationPath: destinationPath,
                        expectedFiles: expectedFiles
                    )
                }.value
                let downloadedBytes = snapshot.downloadedBytes
                let now = Date()
                let elapsed = max(now.timeIntervalSince(lastDate), 0.001)
                let byteDelta = max(downloadedBytes - lastBytes, 0)
                let speed = Int64(Double(byteDelta) / elapsed)
                lastBytes = downloadedBytes
                lastDate = now

                self?.updateMeasuredHuggingFaceProgress(
                    queueEntryID: queueEntryID,
                    downloadedBytes: downloadedBytes,
                    downloadedFileCount: snapshot.completedFileCount,
                    totalBytes: totalBytes,
                    speedBytesPerSecond: speed
                )

                do {
                    try await Task.sleep(nanoseconds: 700_000_000)
                } catch {
                    return
                }
            }
        }
        activeHuggingFaceProgressTasks[queueEntryID] = task
    }

    private func stopHuggingFaceProgressPolling(queueEntryID: UUID) {
        activeHuggingFaceProgressTasks[queueEntryID]?.cancel()
        activeHuggingFaceProgressTasks[queueEntryID] = nil
    }

    private func stopHuggingFaceProgressPolling() {
        activeHuggingFaceProgressTasks.values.forEach { $0.cancel() }
        activeHuggingFaceProgressTasks.removeAll()
    }

    private func appendHuggingFaceOutputLine(_ line: String, queueEntryID: UUID? = nil) {
        let sanitizedLine = HuggingFaceDownloadPlanner.sanitizedOutputLine(line)
        guard !sanitizedLine.isEmpty else {
            return
        }

        if let queueEntryID {
            var outputLines = huggingFaceDownloadOutputLinesByID[queueEntryID] ?? []
            outputLines.append(sanitizedLine)
            if outputLines.count > 24 {
                outputLines.removeFirst(outputLines.count - 24)
            }
            huggingFaceDownloadOutputLinesByID[queueEntryID] = outputLines

            if HuggingFaceDownloadPlanner.progressFraction(from: sanitizedLine) != nil {
                updateHuggingFaceQueueEntry(queueEntryID, phase: .downloading, message: "Downloading")
            } else {
                refreshAggregateHuggingFaceDownloadStatus()
            }
        }

        appendLog(sanitizedLine)
    }

    private func addDownloadedHuggingFaceModelProfile(
        reference: HuggingFaceModelReference,
        destinationPath: String,
        displayName: String,
        draft: HuggingFaceDownloadDraft
    ) -> String? {
        if models.contains(where: { $0.modelID == destinationPath }) {
            invalidateModelSizeCache(forDirectoryPath: destinationPath)
            selectedModelID = destinationPath
            lastAddedDownloadedModelID = destinationPath
            appendLog("[hf] existing profile selected for \(ModelAvailabilityPathFormatter.compact(path: destinationPath)).")
            return nil
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
            invalidateModelSizeCache(for: model)
            invalidatePortCheckCache()
            models = nextModels
            lastAddedDownloadedModelID = model.id
            if draft.autoSelectAfterAdd {
                selectedModelID = model.id
            }
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(
                for: model,
                result: .present(path: destinationPath)
            )
            appendLog("[hf] added downloaded model to list: \(displayName).")
            return nil
        } catch {
            let message = "Downloaded, but profile add failed: \(error.localizedDescription)"
            appendLog("[hf] profile add failed after download: \(error.localizedDescription)")
            return message
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

        switch freshPortCheck(host: host, port: port) {
        case .available:
            appendLog("[\(logPrefix)] port available: \(host):\(port)")
        case let .busy(_, _, pid):
            if let pid {
                appendLog("[\(logPrefix)] port occupied: \(host):\(port) PID=\(pid)")
            } else {
                appendLog("[\(logPrefix)] port occupied: \(host):\(port)")
            }
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
                processIdentifier: launchResult.processIdentifier,
                expectedModelID: selectedModel.modelID
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
            autoUnloadEnabledByModelID = settings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = settings.autoUnloadMinutesByModelID
            invalidateModelSizeCache()
            invalidatePortCheckCache()
            models = snapshot.models

            if snapshot.usedDefaults {
                appendLog("[settings] settings.json or models.json not found. Using defaults until saved.")
            } else {
                appendLog("[settings] Loaded settings.json and models.json from \(settingsDirectoryPath).")
            }
            loadPersistedBenchmarkResults()
        } catch {
            settings = .defaults
            autoUnloadEnabledByModelID = settings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = settings.autoUnloadMinutesByModelID
            invalidateModelSizeCache()
            invalidatePortCheckCache()
            models = ModelConfig.defaults
            appendLog("[settings] Failed to load settings. Using defaults: \(error.localizedDescription)")
            loadPersistedBenchmarkResults()
        }
    }

    private func loadPersistedBenchmarkResults() {
        do {
            let snapshot = try settingsStore.loadBenchmarkResults()
            benchmarkResultsByProfileID = snapshot.value.benchmarkResultsByProfileID
            agenticBenchmarkResultsByProfileID = snapshot.value.agenticBenchmarkResultsByProfileID
            if snapshot.usedDefault {
                appendLog("[benchmark] benchmark-results.json not found. Model benchmark results will be saved after the next run.")
            } else {
                appendLog("[benchmark] Loaded benchmark-results.json from \(settingsDirectoryPath).")
            }
        } catch {
            benchmarkResultsByProfileID = [:]
            agenticBenchmarkResultsByProfileID = [:]
            appendLog("[benchmark] Failed to load benchmark-results.json: \(error.localizedDescription)")
        }
    }

    private func savePersistedBenchmarkResults() {
        let snapshot = BenchmarkResultsSnapshot(
            benchmarkResultsByProfileID: benchmarkResultsByProfileID,
            agenticBenchmarkResultsByProfileID: agenticBenchmarkResultsByProfileID
        )
        do {
            try settingsStore.save(benchmarkResults: snapshot)
        } catch {
            appendLog("[benchmark] Failed to save benchmark-results.json: \(error.localizedDescription)")
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
        processIdentifier: Int32,
        expectedModelID: String
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

            let result = await readyChecker.check(
                host: host,
                port: port,
                expectedModelID: expectedModelID
            )

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
            switch freshPortCheck(host: host, port: port) {
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

        switch freshPortCheck(host: host, port: port) {
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

        invalidatePortCheckCache()

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
        invalidatePortCheckCache()
        appendLog("[\(logPrefix)] running modelID: \(modelID)")
        logRestartRequiredIfNeeded()
    }

    private func clearRunningModel(logPrefix: String) {
        guard runningModelID != nil else {
            return
        }

        runningModelID = nil
        managedServerStartedAt = nil
        invalidatePortCheckCache()
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
        let modelEstimateGigabytes = modelSizeGigabytes(modelDirectoryPath: modelDirectoryPath)
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

        if let rawExtraArgs = normalizedOptions.rawExtraArgs {
            do {
                _ = try ShellArgumentParser.parse(rawExtraArgs)
            } catch {
                return .invalid(error.localizedDescription)
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
        let monitor = memoryMonitor
        systemUsageMonitorTask = Task.detached { [weak self, monitor] in
            var cpuUsageSampler = CPUUsageSampler()
            while !Task.isCancelled {
                let cpuPercent = cpuUsageSampler.samplePercent()
                let systemMemorySnapshot = monitor.currentSystemSnapshot()
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
        let currentText = logBuffer.text
        let currentEntries = logBuffer.entries
        refreshLogDerivedState(for: currentEntries)
        logText = currentText
        logEntries = currentEntries
    }

    private func refreshLogDerivedState() {
        refreshLogDerivedState(for: logEntries)
    }

    private func refreshLogDerivedState(for entries: [LogEntry]) {
        logCategoryFilterOptionsCache = Self.makeLogCategoryFilterOptions(from: entries)
        visibleLogEntriesCache = Self.visibleLogEntries(from: entries, filter: logCategoryFilter)
        latestImportantLogEntryCache = Self.findLatestImportantLogEntry(in: entries)
    }

    private static func makeLogCategoryFilterOptions(from entries: [LogEntry]) -> [String] {
        ["All"] + Array(Set(entries.map(\.category))).sorted()
    }

    private static func visibleLogEntries(from entries: [LogEntry], filter: String) -> [LogEntry] {
        filter == "All" ? entries : entries.filter { $0.category == filter }
    }

    private static func findLatestImportantLogEntry(in entries: [LogEntry]) -> LogEntry? {
        entries.reversed().first { entry in
            entry.message.localizedCaseInsensitiveContains("failed")
                || entry.message.localizedCaseInsensitiveContains("warning")
                || entry.category.localizedCaseInsensitiveContains("error")
        }
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
