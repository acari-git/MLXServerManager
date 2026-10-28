import AppKit
import Darwin
import Combine
import Foundation
import UniformTypeIdentifiers

enum HermesAgentTranscriptExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case plainText

    var id: String { rawValue }
    var fileExtension: String { self == .markdown ? "md" : "txt" }
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

struct ProfileDeletionUndoState: Identifiable, Equatable {
    let id: UUID
    let modelID: ModelConfig.ID
    let displayName: String
    let expiresAt: Date
}

struct ProfileDeletionUndoPayload {
    let state: ProfileDeletionUndoState
    let model: ModelConfig
    let originalIndex: Int
    let previousSelectedModelID: ModelConfig.ID?
    let autoUnloadEnabled: Bool?
    let autoUnloadMinutes: Int?
}

private struct PortCheckCacheEntry {
    let result: PortCheckResult
    let checkedAt: Date
}

private struct SystemInfoRowsCacheEntry {
    let rows: [(String, String)]
    let measuredAt: Date
}

struct BenchmarkComparisonProjectionCacheKey: Equatable {
    let models: [ModelConfig]
    let sessionsByProfileID: [ModelConfig.ID: BenchmarkSessionResult]
    let currentChipName: String?
    let mlxServerExecutablePath: String
    let rapidMLXExecutablePath: String
}

struct BenchmarkComparisonProjectionCacheEntry {
    let key: BenchmarkComparisonProjectionCacheKey
    let projection: BenchmarkComparisonProjection
}

struct DownloadStorageAssessmentCacheKey: Equatable {
    let destinationPath: String
    let files: [HuggingFaceDownloadPreviewFile]
}

struct DownloadStorageAssessmentCacheEntry {
    let key: DownloadStorageAssessmentCacheKey
    let assessment: DownloadStorageAssessment
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
    @Published var runtimeViewState: RuntimeViewState = .empty
    var runningModelID: ModelConfig.ID? { runtimeViewState.runningModelID }
    var runningModelIDs: Set<ModelConfig.ID> { runtimeViewState.runningModelIDs }
    var managedServerStartedAt: Date? { runtimeViewState.managedServerStartedAt }
    var managedServerStartedAtByModelID: [ModelConfig.ID: Date] { runtimeViewState.managedServerStartedAtByModelID }
    var runtimeState: ModelRuntimeState {
        get { runtimeViewState.selectedRuntimeState }
        set {
            var nextState = runtimeViewState
            nextState.setSelectedRuntimeState(newValue, selectedModelID: selectedModelID)
            guard nextState != runtimeViewState else {
                return
            }
            runtimeViewState = nextState
        }
    }
    var runtimeStatesByModelID: [ModelConfig.ID: ModelRuntimeState] { runtimeViewState.runtimeStatesByModelID }
    @Published var monitoringViewState: MonitoringViewState = .empty
    var memoryUsageGB: Double? { monitoringViewState.memoryUsageGB }
    var memoryUsageByModelID: [ModelConfig.ID: Double] { monitoringViewState.memoryUsageByModelID }
    var memoryBreakdown: MemoryBreakdownSnapshot? { monitoringViewState.memoryBreakdown }
    var memoryBreakdownByModelID: [ModelConfig.ID: MemoryBreakdownSnapshot] { monitoringViewState.memoryBreakdownByModelID }
    var systemMemorySnapshot: SystemMemorySnapshot? { monitoringViewState.systemMemorySnapshot }
    var runtimeMemoryProtectionState: RuntimeMemoryProtectionState { monitoringViewState.runtimeMemoryProtectionState }
    var memoryHistory: [MemoryHistorySample] { monitoringViewState.memoryHistory }
    var cpuUsagePercent: Double? { monitoringViewState.cpuUsagePercent }
    var gpuUsagePercent: Double? { monitoringViewState.gpuUsagePercent }
    var systemUsageHistory: [SystemUsageHistorySample] { monitoringViewState.systemUsageHistory }
    @Published var autoUnloadEnabledByModelID: [ModelConfig.ID: Bool] = [:]
    @Published var autoUnloadMinutesByModelID: [ModelConfig.ID: Int] = [:]
    @Published var logViewState: LogViewState
    var logText: String { logViewState.text }
    var logEntries: [LogEntry] { logViewState.entries }
    @Published var logCategoryFilter = "All" {
        didSet {
            logViewState = logStateCoordinator.setFilter(logCategoryFilter)
        }
    }
    @Published var diagnosticsViewState: DiagnosticsViewState = .notRun
    @Published var diagnosticsHistory: [DiagnosticsSnapshot] = DiagnosticsHistoryStore.load()
    var diagnosticsResults: [DiagnosticsResult] { diagnosticsViewState.results }
    var diagnosticsDidRun: Bool { diagnosticsViewState.didRun }
    var isDiagnosticsRunning: Bool { diagnosticsViewState.isRunning }
    @Published var selectedModelAvailabilitySummary: ModelAvailabilitySummary = .noSelection
    @Published var profileEditorViewState: ProfileFormViewState = .hidden
    var profileEditorDraft: ModelProfileDraft {
        get { profileEditorViewState.draft }
        set {
            updateProfileEditorViewState { state in
                state.setDraft(newValue)
            }
        }
    }
    var isProfileEditorPresented: Bool { profileEditorViewState.isPresented }
    var profileEditorMessage: String? { profileEditorViewState.message }
    var profileEditorPortSuggestionMessage: String? { profileEditorViewState.portSuggestionMessage }
    @Published var addProfileViewState: ProfileFormViewState = .hidden
    var addProfileDraft: ModelProfileDraft {
        get { addProfileViewState.draft }
        set {
            updateAddProfileViewState { state in
                state.setDraft(newValue)
            }
        }
    }
    var isAddProfilePresented: Bool { addProfileViewState.isPresented }
    var addProfileMessage: String? { addProfileViewState.message }
    var addProfilePortSuggestionMessage: String? { addProfileViewState.portSuggestionMessage }
    @Published var isDeleteProfileConfirmationPresented = false
    @Published var isNetworkExposureStartConfirmationPresented = false
    @Published var isMemoryRiskStartConfirmationPresented = false
    @Published var pendingNetworkExposureAssessment: NetworkExposureAssessment?
    @Published var pendingMemoryRiskAssessment: MultiModelMemoryAssessment?
    @Published var profileDeletionMessage: String?
    @Published var profileDeletionUndoState: ProfileDeletionUndoState?
    @Published var modelProfileExportMessage: String?
    @Published var modelProfileImportMessage: String?
    @Published var isImportPreviewPresented = false
    @Published var importPreviewResult: ImportPreviewResult?
    @Published var huggingFaceDownloadDraft: HuggingFaceDownloadDraft = .defaults(
        defaultHost: AppSettings.defaults.defaultHost,
        defaultPort: AppSettings.defaults.defaultPort
    )
    @Published var huggingFaceDownloadViewState: HuggingFaceDownloadViewState = .waiting
    var huggingFaceDownloadStatus: HuggingFaceDownloadStatus { huggingFaceDownloadViewState.status }
    var huggingFaceDownloadQueue: [HuggingFaceDownloadQueueEntry] { huggingFaceDownloadViewState.entries }
    @Published var lastAddedDownloadedModelID: ModelConfig.ID?
    @Published var downloadCompletionMarkerDate: Date?
    @Published var huggingFaceFilePreviewViewState: HuggingFaceFilePreviewViewState = .waiting
    var huggingFaceFilePreview: HuggingFaceDownloadFilePreviewState { huggingFaceFilePreviewViewState.preview }
    var huggingFaceFilePreviewIdentity: HuggingFaceFilePreviewIdentity? { huggingFaceFilePreviewViewState.identity }
    var selectedHuggingFacePreviewFileIDs: Set<String> { huggingFaceFilePreviewViewState.selectedFileIDs }
    @Published var isHuggingFaceCLIAvailable = false
    @Published var huggingFaceCLIPath = AppViewModel.notCheckedText(language: .system)
    @Published var huggingFaceCLIMessage = AppViewModel.defaultHuggingFaceCLIMessage(language: .system)
    @Published var aria2Availability = Aria2AvailabilityChecker.check()
    @Published var enableDownloadAutoRestart = false
    @Published var lowSpeedRestartThresholdText = "50K"
    @Published var localModelPath = ""
    @Published var localModelDisplayName = ""
    @Published var localModelPortText = String(AppSettings.defaults.defaultPort)
    @Published var localModelEnableThinking = false
    @Published var localModelMessage = AppViewModel.defaultLocalModelMessage(language: .system)
    @Published var huggingFaceSearchViewState = HuggingFaceSearchViewState.initial(
        message: AppViewModel.defaultHuggingFaceSearchMessage(language: .system)
    )
    var huggingFaceSearchQuery: String {
        get { huggingFaceSearchViewState.query }
        set {
            updateHuggingFaceSearchViewState { state in
                state.setQuery(newValue)
            }
        }
    }
    @Published var showOnlyMLXLikelySearchResults = false
    @Published var huggingFaceDiscoverySort: HuggingFaceDiscoverySort = .recommended
    @Published var huggingFaceMinimumDownloads = 0
    var huggingFaceSearchMessage: String { huggingFaceSearchViewState.message }
    var huggingFaceSearchResults: [HuggingFaceSearchResult] { huggingFaceSearchViewState.results }
    @Published private(set) var systemProfilerHardwareInfo: [String: String] = [:]
    var selectedHuggingFaceSearchResult: HuggingFaceSearchResult? { huggingFaceSearchViewState.selectedResult }
    var isHuggingFaceSearching: Bool { huggingFaceSearchViewState.isSearching }
    @Published var benchmarkViewState: BenchmarkViewState
    @Published var miniChatViewState: MiniChatViewState = .ready
    var miniChatPrompt: String {
        get { miniChatViewState.prompt }
        set {
            updateMiniChatViewState { state in
                state.setPrompt(newValue)
            }
        }
    }
    var miniChatMessages: [MiniChatTranscriptMessage] { miniChatViewState.messages }
    var miniChatResponse: String { miniChatViewState.response }
    var miniChatStatus: String { miniChatViewState.status }
    var miniChatHTTPStatusText: String { miniChatViewState.httpStatusText }
    var miniChatDurationText: String { miniChatViewState.durationText }
    var isMiniChatRunning: Bool { miniChatViewState.isRunning }
    @Published var hermesAgentConfigMessage = AppViewModel.defaultHermesAgentConfigMessage(language: .system)
    @Published var hermesAgentConfigInspection: HermesAgentConfigInspection?
    @Published var hermesAgentConfigBackups: [HermesAgentConfigBackup] = []
    @Published var selectedHermesAgentBackupID: String?
    @Published var hermesAgentSessions: [HermesAgentSessionSummary] = []
    @Published var selectedHermesAgentSessionID: String?
    @Published var hermesAgentSessionMessages: [HermesAgentSessionMessage] = []
    @Published var hermesAgentTranscriptRoleFilter = "all"
    @Published var hermesAgentTranscriptSearchText = ""
    @Published var hermesAgentTranscriptIncludesInactive = false
    @Published var hermesAgentTranscriptIncludesCompacted = false
    @Published var hermesAgentTranscriptNewestFirst = false
    @Published var hermesAgentTranscriptDisplayLimit = 20
    @Published var hermesAgentTranscriptExportFormat: HermesAgentTranscriptExportFormat = .markdown
    @Published var hermesAgentTranscriptExportMessage = ""
    @Published var selectedHermesAgentMessageID: Int?
    @Published var hermesAgentSessionMessage = AppViewModel.defaultHermesAgentSessionMessage(language: .system)
    @Published var runtimeReadinessViewState = RuntimeReadinessViewState.initial()
    @Published var runtimeSetupAssistantViewState = RuntimeSetupAssistantViewState.initial
    @Published var runtimeCompatibilityViewState = RuntimeCompatibilityViewState.initial
    @Published var registeredModelHealthViewState = RegisteredModelHealthViewState.initial
    @Published var operationalReadinessViewState: OperationalReadinessViewState = .hidden
    @Published var operationsCenterViewState: OperationsCenterViewState = .hidden
    @Published var launchFailureDiagnosesByModelID: [ModelConfig.ID: LaunchFailureDiagnosis] = [:]
    @Published var applicationTerminationPhase: ApplicationTerminationPhase = .idle
    @Published var sessionRecoveryViewState: SessionRecoveryViewState = .hidden
    @Published var runtimeEvents: [RuntimeEvent] = []
    @Published var operationalHistoryCategoryFilter = OperationalHistoryProjection.allCategories
    @Published var operationalHistorySeverityFilter: OperationalHistorySeverityFilter = .all

    let settingsStore: SettingsStore
    private let portChecker: PortChecker
    let serverLifecycleCoordinator: ServerLifecycleCoordinator
    private let memoryMonitor: MemoryMonitor
    let modelStorageEstimateOperation: @Sendable (String?) -> Double?
    let modelSizeEstimationCoordinator: ModelSizeEstimationCoordinator
    let modelMemoryMonitoringCoordinator: ModelMemoryMonitoringCoordinator
    let systemUsageMonitoringCoordinator: SystemUsageMonitoringCoordinator
    private let systemHardwareInfoProvider: any SystemHardwareInfoProviding
    let autoUnloadMonitoringCoordinator: AutoUnloadMonitoringCoordinator
    let systemMemorySnapshotProvider: () -> SystemMemorySnapshot
    let availablePortFinder: AvailablePortFinder
    let setupDiagnostics: SetupDiagnostics
    let diagnosticsRunCoordinator: DiagnosticsRunCoordinator
    let miniChatRunCoordinator: MiniChatRunCoordinator
    let profileDeletionUndoRunCoordinator: ProfileDeletionUndoRunCoordinator
    let profileDeletionCacheRunCoordinator: ProfileDeletionCacheRunCoordinator
    let readyCheckRunCoordinator: ReadyCheckRunCoordinator
    let systemHardwareInfoRunCoordinator: SystemHardwareInfoRunCoordinator
    let modelStartPreparationCoordinator: ModelStartPreparationCoordinator
    let managedStartRunCoordinator: ManagedStartRunCoordinator
    let lifecycleRunCoordinator: LifecycleRunCoordinator
    let benchmarkRunCoordinator: BenchmarkRunCoordinator
    let agenticBenchmarkRunCoordinator: AgenticBenchmarkRunCoordinator
    let huggingFaceOutputStateCoordinator: HuggingFaceOutputStateCoordinator
    let managedModelOutputCoordinator: ManagedModelOutputCoordinator
    let modelProfileExportService: ModelProfileExportService
    let modelProfileImportPreviewService: ModelProfileImportPreviewService
    let modelAvailabilityChecker: LocalModelAvailabilityChecking
    let huggingFaceDownloadManagerFactory: () -> HuggingFaceModelDownloading
    let huggingFaceCredentialStore: HuggingFaceCredentialStoring
    let huggingFaceCacheDeletionService: any HuggingFaceCacheDeleting
    let huggingFaceSearchService: HuggingFaceModelSearching
    let huggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing
    let downloadStorageCapacityProvider: any DownloadStorageCapacityProviding
    let huggingFaceRequestCoordinator: HuggingFaceRequestCoordinator
    let huggingFaceDownloadExecutionCoordinator: HuggingFaceDownloadExecutionCoordinator
    let hermesAgentConfigService: HermesAgentConfigService
    let benchmarkSessionRunner: BenchmarkSessionRunner
    let agenticBenchmarkService: AgenticBenchmarkService
    let testChatService: TestChatService
    private let mlxLMServerCapabilityProvider: any MLXLMServerCapabilityProviding
    let runtimeReadinessService: any RuntimeReadinessAssessing
    let runtimeReadinessRunCoordinator: LatestRequestCoordinator
    let runtimeSetupAssistantService: any RuntimeSetupAssisting
    let runtimeSetupAssistantRunCoordinator: LatestRequestCoordinator
    let runtimeCompatibilityService: any RuntimeCompatibilityAssessing
    let runtimeCompatibilityRunCoordinator: LatestRequestCoordinator
    let runtimeOptionCapabilityProvider: any RuntimeOptionCapabilityProviding
    let registeredModelHealthService: any RegisteredModelHealthAssessing
    let registeredModelHealthRunCoordinator: LatestRequestCoordinator
    let operationalReadinessRunCoordinator: LatestRequestCoordinator
    let operationsCenterRunCoordinator: LatestRequestCoordinator
    let launchStabilityRunCoordinator: LatestRequestCoordinator
    let launchPlanRunCoordinator: LatestRequestCoordinator
    let platformCompatibilityService: PlatformCompatibilityService
    let evidenceFreshnessService: EvidenceFreshnessService
    let runtimeEnvironmentDoctorService: any RuntimeEnvironmentDoctorAssessing
    let modelMetadataInspectionService: any ModelMetadataInspecting
    let capacityPlanningService: CapacityPlanningService
    let supportBundleService: SupportBundleService
    let operationsReadyChecker: ReadyChecker
    let launchFailureDiagnosticCoordinator: LaunchFailureDiagnosticCoordinator
    let applicationTerminationCoordinator: ApplicationTerminationCoordinator
    let sessionRecoveryStore: SessionRecoveryStore
    let sessionRecoveryCoordinator: SessionRecoveryCoordinator
    let modelProfileValidator = ModelProfileValidator()
    let localModelIntegrityChecker: any LocalModelIntegrityChecking
    private let modelStartPreflightEvaluator: ModelStartPreflightEvaluator
    var logStateCoordinator: LogStateCoordinator
    var queuedHuggingFaceDownloads: [UUID: HuggingFaceDownloadJob] = [:]
    var huggingFaceDownloadRetryStore = HuggingFaceDownloadRetryStore()
    static let maximumTerminalHuggingFaceDownloadHistory = 50
    static let maximumRuntimeEventHistory = 100
    static let maximumVisibleHuggingFaceOutputLines = 24
    static let huggingFaceOutputFlushDelayNanoseconds: UInt64 = 120_000_000
    var pendingDeleteModelID: ModelConfig.ID?
    var pendingNetworkExposureModelID: ModelConfig.ID?
    var pendingMemoryRiskModelID: ModelConfig.ID?
    var profileDeletionUndoPayload: ProfileDeletionUndoPayload?
    var downloadStorageAssessmentCache: DownloadStorageAssessmentCacheEntry?
    @Published private var modelSizeGigabytesCache: [String: Double] = [:]
    private var unavailableModelSizeCacheKeys: Set<String> = []
    private var portCheckCache: [String: PortCheckCacheEntry] = [:]
    var profileEditorPortSuggestionEndpointKey: String?
    var addProfilePortSuggestionEndpointKey: String?
    private var systemInfoRowsCache: [AppLanguage: SystemInfoRowsCacheEntry] = [:]
    var benchmarkComparisonProjectionCacheEntry: BenchmarkComparisonProjectionCacheEntry?
    var monitoringStateCoordinator = MonitoringStateCoordinator()

    private static let initialLogLines = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Start, Stop, and Restart are available.",
        "[info] Memory monitoring starts after managed process launch."
    ]
    private static let portCheckCacheLifetime: TimeInterval = 1.0
    private static let systemInfoRowsCacheLifetime: TimeInterval = 5.0

    static func localizedText(language: AppLanguage, english: String, japanese: String) -> String {
        AppLocalization(language: language).text(english: english, japanese: japanese)
    }

    static func waitingHuggingFaceDownloadStatus(language: AppLanguage) -> HuggingFaceDownloadStatus {
        HuggingFaceDownloadStatus(
            phase: .waiting,
            message: localizedText(
                language: language,
                english: "Paste a Hugging Face model ID or URL, then press Download.",
                japanese: "Hugging FaceのModel IDまたはURLを貼り付けて、ダウンロードを押してください。"
            ),
            repositoryID: nil,
            destinationPath: nil,
            progress: nil,
            outputLines: []
        )
    }

    static func defaultHuggingFaceCLIMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Check Hugging Face CLI before downloading.",
            japanese: "ダウンロード前にHugging Face CLIを確認してください。"
        )
    }

    static func defaultLocalModelMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Paste an existing local model folder path, then add it to the model list.",
            japanese: "既存のローカルモデルフォルダパスを貼り付けてから、モデル一覧へ追加してください。"
        )
    }

    static func defaultHuggingFaceSearchMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Search Hugging Face explicitly, then choose a result for the download form.",
            japanese: "Hugging Faceを明示的に検索し、結果を選んでダウンロードフォームへ反映してください。"
        )
    }

    static func defaultSpeedTestMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Benchmark has not run yet.",
            japanese: "ベンチマークはまだ実行されていません。"
        )
    }

    static func defaultHermesAgentSessionMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Load recent Hermes Agent sessions from the local state database.",
            japanese: "ローカル状態データベースから最近のHermes Agentセッションを読み込みます。"
        )
    }

    static func defaultHermesAgentConfigMessage(language: AppLanguage) -> String {
        localizedText(
            language: language,
            english: "Apply the selected model connection values to the configured Hermes Agent YAML file.",
            japanese: "選択モデルの接続値を設定済みのHermes Agent YAMLファイルへ反映します。"
        )
    }

    static func notCheckedText(language: AppLanguage) -> String {
        localizedText(language: language, english: "Not checked", japanese: "未確認")
    }

    init(
        settingsStore: SettingsStore? = nil,
        portChecker: PortChecker? = nil,
        readyChecker: ReadyChecker? = nil,
        processManager: (any ModelProcessManaging)? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        modelStorageEstimateOperation: (@Sendable (String?) -> Double?)? = nil,
        systemMemorySnapshotProvider: (() -> SystemMemorySnapshot)? = nil,
        systemHardwareInfoProvider: (any SystemHardwareInfoProviding)? = nil,
        availablePortFinder: AvailablePortFinder? = nil,
        setupDiagnostics: SetupDiagnostics? = nil,
        modelProfileExportService: ModelProfileExportService? = nil,
        modelProfileImportPreviewService: ModelProfileImportPreviewService? = nil,
        modelAvailabilityChecker: LocalModelAvailabilityChecking? = nil,
        localModelIntegrityChecker: (any LocalModelIntegrityChecking)? = nil,
        huggingFaceDownloadManagerFactory: (() -> HuggingFaceModelDownloading)? = nil,
        huggingFaceCredentialStore: HuggingFaceCredentialStoring? = nil,
        huggingFaceCacheDeletionService: (any HuggingFaceCacheDeleting)? = nil,
        huggingFaceSearchService: HuggingFaceModelSearching? = nil,
        huggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing? = nil,
        downloadStorageCapacityProvider: (any DownloadStorageCapacityProviding)? = nil,
        hermesAgentConfigService: HermesAgentConfigService? = nil,
        benchmarkService: BenchmarkService? = nil,
        benchmarkSessionRunner: BenchmarkSessionRunner? = nil,
        agenticBenchmarkService: AgenticBenchmarkService? = nil,
        testChatService: TestChatService? = nil,
        mlxLMServerCapabilityProvider: (any MLXLMServerCapabilityProviding)? = nil,
        runtimeReadinessService: (any RuntimeReadinessAssessing)? = nil,
        runtimeSetupAssistantService: (any RuntimeSetupAssisting)? = nil,
        runtimeCompatibilityService: (any RuntimeCompatibilityAssessing)? = nil,
        runtimeOptionCapabilityProvider: (any RuntimeOptionCapabilityProviding)? = nil,
        registeredModelHealthService: (any RegisteredModelHealthAssessing)? = nil,
        platformCompatibilityService: PlatformCompatibilityService? = nil,
        evidenceFreshnessService: EvidenceFreshnessService? = nil,
        runtimeEnvironmentDoctorService: (any RuntimeEnvironmentDoctorAssessing)? = nil,
        modelMetadataInspectionService: (any ModelMetadataInspecting)? = nil,
        capacityPlanningService: CapacityPlanningService? = nil,
        supportBundleService: SupportBundleService? = nil,
        sessionRecoveryStore: SessionRecoveryStore? = nil
    ) {
        self.benchmarkViewState = BenchmarkViewState(
            latestSpeedTestMessage: Self.defaultSpeedTestMessage(language: .system)
        )
        self.settingsStore = settingsStore ?? SettingsStore()
        self.portChecker = portChecker ?? PortChecker()
        let resolvedReadyChecker = readyChecker ?? ReadyChecker()
        self.serverLifecycleCoordinator = ServerLifecycleCoordinator(
            processRegistry: ModelProcessRegistry(initialManager: processManager),
            readyChecker: resolvedReadyChecker
        )
        let resolvedMemoryMonitor = memoryMonitor ?? MemoryMonitor()
        self.memoryMonitor = resolvedMemoryMonitor
        self.modelStorageEstimateOperation = modelStorageEstimateOperation
            ?? { resolvedMemoryMonitor.estimatedModelStorageGigabytes(modelDirectoryPath: $0) }
        self.modelSizeEstimationCoordinator = ModelSizeEstimationCoordinator()
        self.modelMemoryMonitoringCoordinator = ModelMemoryMonitoringCoordinator(
            memoryMonitor: resolvedMemoryMonitor
        )
        self.systemUsageMonitoringCoordinator = SystemUsageMonitoringCoordinator(
            memoryMonitor: resolvedMemoryMonitor
        )
        self.systemHardwareInfoProvider = systemHardwareInfoProvider ?? SystemHardwareInfoProvider()
        self.autoUnloadMonitoringCoordinator = AutoUnloadMonitoringCoordinator()
        self.systemMemorySnapshotProvider = systemMemorySnapshotProvider
            ?? { resolvedMemoryMonitor.currentSystemSnapshot() }
        self.availablePortFinder = availablePortFinder ?? AvailablePortFinder()
        self.setupDiagnostics = setupDiagnostics ?? SetupDiagnostics(
            settingsStore: self.settingsStore,
            portChecker: self.portChecker,
            readyChecker: resolvedReadyChecker
        )
        self.diagnosticsRunCoordinator = DiagnosticsRunCoordinator()
        self.miniChatRunCoordinator = MiniChatRunCoordinator()
        self.profileDeletionUndoRunCoordinator = ProfileDeletionUndoRunCoordinator()
        self.profileDeletionCacheRunCoordinator = ProfileDeletionCacheRunCoordinator()
        self.readyCheckRunCoordinator = ReadyCheckRunCoordinator()
        self.systemHardwareInfoRunCoordinator = SystemHardwareInfoRunCoordinator()
        self.modelStartPreparationCoordinator = ModelStartPreparationCoordinator()
        self.managedStartRunCoordinator = ManagedStartRunCoordinator()
        self.lifecycleRunCoordinator = LifecycleRunCoordinator()
        self.benchmarkRunCoordinator = BenchmarkRunCoordinator()
        self.agenticBenchmarkRunCoordinator = AgenticBenchmarkRunCoordinator()
        self.huggingFaceOutputStateCoordinator = HuggingFaceOutputStateCoordinator()
        self.managedModelOutputCoordinator = ManagedModelOutputCoordinator()
        self.modelProfileExportService = modelProfileExportService ?? ModelProfileExportService()
        self.modelProfileImportPreviewService = modelProfileImportPreviewService ?? ModelProfileImportPreviewService()
        self.modelAvailabilityChecker = modelAvailabilityChecker ?? FileSystemLocalModelAvailabilityChecker()
        let resolvedLocalModelIntegrityChecker = localModelIntegrityChecker ?? FileSystemLocalModelIntegrityChecker()
        self.localModelIntegrityChecker = resolvedLocalModelIntegrityChecker
        self.modelStartPreflightEvaluator = ModelStartPreflightEvaluator(
            integrityChecker: resolvedLocalModelIntegrityChecker
        )
        self.huggingFaceDownloadManagerFactory = huggingFaceDownloadManagerFactory ?? { HuggingFaceDownloadManager() }
        self.huggingFaceCredentialStore = huggingFaceCredentialStore ?? HuggingFaceCredentialStore()
        self.huggingFaceCacheDeletionService = huggingFaceCacheDeletionService ?? HuggingFaceCacheDeletionService()
        self.huggingFaceSearchService = huggingFaceSearchService ?? HuggingFaceSearchService()
        self.huggingFaceRepositoryFileService = huggingFaceRepositoryFileService ?? HuggingFaceRepositoryFileService()
        self.downloadStorageCapacityProvider = downloadStorageCapacityProvider ?? FoundationDownloadStorageCapacityProvider()
        self.huggingFaceRequestCoordinator = HuggingFaceRequestCoordinator()
        self.huggingFaceDownloadExecutionCoordinator = HuggingFaceDownloadExecutionCoordinator()
        self.hermesAgentConfigService = hermesAgentConfigService ?? HermesAgentConfigService()
        self.benchmarkSessionRunner = benchmarkSessionRunner
            ?? BenchmarkSessionRunner(service: benchmarkService ?? BenchmarkService())
        self.agenticBenchmarkService = agenticBenchmarkService ?? AgenticBenchmarkService()
        self.testChatService = testChatService ?? TestChatService()
        let resolvedMLXLMServerCapabilityProvider = mlxLMServerCapabilityProvider ?? MLXLMServerCapabilityProvider()
        self.mlxLMServerCapabilityProvider = resolvedMLXLMServerCapabilityProvider
        self.runtimeReadinessService = runtimeReadinessService ?? RuntimeReadinessService(
            mlxLMCapabilityProvider: resolvedMLXLMServerCapabilityProvider
        )
        self.runtimeReadinessRunCoordinator = LatestRequestCoordinator()
        self.runtimeSetupAssistantService = runtimeSetupAssistantService ?? RuntimeSetupAssistantService()
        self.runtimeSetupAssistantRunCoordinator = LatestRequestCoordinator()
        self.runtimeCompatibilityService = runtimeCompatibilityService ?? RuntimeCompatibilityService()
        self.runtimeCompatibilityRunCoordinator = LatestRequestCoordinator()
        self.runtimeOptionCapabilityProvider = runtimeOptionCapabilityProvider ?? RuntimeOptionCapabilityProvider()
        self.registeredModelHealthService = registeredModelHealthService
            ?? RegisteredModelHealthService(integrityChecker: resolvedLocalModelIntegrityChecker)
        self.registeredModelHealthRunCoordinator = LatestRequestCoordinator()
        self.operationalReadinessRunCoordinator = LatestRequestCoordinator()
        self.operationsCenterRunCoordinator = LatestRequestCoordinator()
        self.launchStabilityRunCoordinator = LatestRequestCoordinator()
        self.launchPlanRunCoordinator = LatestRequestCoordinator()
        self.platformCompatibilityService = platformCompatibilityService ?? PlatformCompatibilityService()
        self.evidenceFreshnessService = evidenceFreshnessService ?? EvidenceFreshnessService()
        self.runtimeEnvironmentDoctorService = runtimeEnvironmentDoctorService ?? RuntimeEnvironmentDoctorService()
        self.modelMetadataInspectionService = modelMetadataInspectionService ?? ModelMetadataInspectionService()
        self.capacityPlanningService = capacityPlanningService ?? CapacityPlanningService()
        self.supportBundleService = supportBundleService ?? SupportBundleService()
        self.operationsReadyChecker = resolvedReadyChecker
        self.launchFailureDiagnosticCoordinator = LaunchFailureDiagnosticCoordinator()
        self.applicationTerminationCoordinator = ApplicationTerminationCoordinator()
        self.sessionRecoveryStore = sessionRecoveryStore ?? SessionRecoveryStore()
        self.sessionRecoveryCoordinator = SessionRecoveryCoordinator()
        let initialLogStateCoordinator = LogStateCoordinator(initialLines: Self.initialLogLines)
        self.logStateCoordinator = initialLogStateCoordinator
        self.logViewState = initialLogStateCoordinator.state
        loadSettings()
        operationsCenterViewState.calibrationRecords = settings.resourceCalibrationRecords
        loadPersistedHuggingFaceDownloadRetries()
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
            beginSessionRecoveryTracking()
            loadSystemHardwareInfo()
            startSystemUsageMonitoring()
            startAutoUnloadMonitoring()
        }
    }

    var isSpeedTestRunning: Bool { benchmarkViewState.isSpeedTestRunning }
    var latestSpeedTestMessage: String { benchmarkViewState.latestSpeedTestMessage }
    var latestSpeedTestDurationMS: Double? { benchmarkViewState.latestSpeedTestDurationMS }
    var latestBenchmarkResult: BenchmarkResult? { benchmarkViewState.latestBenchmarkResult }
    var benchmarkHistory: [BenchmarkResult] { benchmarkViewState.benchmarkHistory }
    var benchmarkResultsByProfileID: [ModelConfig.ID: BenchmarkResult] {
        benchmarkViewState.benchmarkResultsByProfileID
    }
    var benchmarkSessionsByProfileID: [ModelConfig.ID: BenchmarkSessionResult] {
        benchmarkViewState.benchmarkSessionsByProfileID
    }
    var benchmarkSampleIndex: Int { benchmarkViewState.benchmarkSampleIndex }
    var benchmarkSampleCount: Int { benchmarkViewState.benchmarkSampleCount }
    var isAgenticBenchmarkRunning: Bool { benchmarkViewState.isAgenticBenchmarkRunning }
    var latestAgenticBenchmarkResult: AgenticBenchmarkResult? {
        benchmarkViewState.latestAgenticBenchmarkResult
    }
    var agenticBenchmarkHistory: [AgenticBenchmarkResult] {
        benchmarkViewState.agenticBenchmarkHistory
    }
    var agenticBenchmarkResultsByProfileID: [ModelConfig.ID: AgenticBenchmarkResult] {
        benchmarkViewState.agenticBenchmarkResultsByProfileID
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

    var canRunSpeedTest: Bool {
        connectionTargetSummary.isActiveTarget && !isSpeedTestRunning && !isAgenticBenchmarkRunning
    }

    var speedTestDisabledReason: String {
        if isSpeedTestRunning { return Self.localizedText(language: settings.uiLanguage, english: "Benchmark is already running.", japanese: "ベンチマークはすでに実行中です。") }
        if isAgenticBenchmarkRunning { return Self.localizedText(language: settings.uiLanguage, english: "Agent Readiness is already running.", japanese: "Agent Readinessはすでに実行中です。") }
        if runtimeState.isDegraded { return Self.localizedText(language: settings.uiLanguage, english: "The generation worker stopped. Restart the model before running Benchmark.", japanese: "生成ワーカーが停止しています。モデルを再起動してからベンチマークを実行してください。") }
        if !connectionTargetSummary.isActiveTarget { return Self.localizedText(language: settings.uiLanguage, english: "Start or adopt a server before running Benchmark.", japanese: "ベンチマーク前にサーバーを起動するか採用してください。") }
        return Self.localizedText(language: settings.uiLanguage, english: "Ready.", japanese: "準備完了。")
    }

    var canRunAgenticBenchmark: Bool {
        connectionTargetSummary.isActiveTarget && !isSpeedTestRunning && !isAgenticBenchmarkRunning
    }

    var agenticBenchmarkDisabledReason: String {
        if isAgenticBenchmarkRunning { return Self.localizedText(language: settings.uiLanguage, english: "Agent Readiness is already running.", japanese: "Agent Readinessはすでに実行中です。") }
        if isSpeedTestRunning { return Self.localizedText(language: settings.uiLanguage, english: "Benchmark v1 is already running.", japanese: "Benchmark v1はすでに実行中です。") }
        if runtimeState.isDegraded { return Self.localizedText(language: settings.uiLanguage, english: "The generation worker stopped. Restart the model before running Agent Readiness.", japanese: "生成ワーカーが停止しています。モデルを再起動してからAgent Readinessを実行してください。") }
        if !connectionTargetSummary.isActiveTarget { return Self.localizedText(language: settings.uiLanguage, english: "Start or adopt a server before running Agent Readiness.", japanese: "Agent Readiness前にサーバーを起動するか採用してください。") }
        return Self.localizedText(language: settings.uiLanguage, english: "Runs virtual tool tasks without external dependencies.", japanese: "外部依存なしで仮想ツールタスクを実行します。")
    }

    var stopDisabledReason: String {
        canStopManagedServer
            ? Self.localizedText(language: settings.uiLanguage, english: "Ready.", japanese: "実行可能です。")
            : Self.localizedText(language: settings.uiLanguage, english: "No managed server is running.", japanese: "管理中サーバーは実行されていません。")
    }

    var restartDisabledReason: String {
        if let runtimeMemoryEmergencyBlockingMessage {
            return runtimeMemoryEmergencyBlockingMessage
        }
        return canRestartManagedServer
            ? Self.localizedText(language: settings.uiLanguage, english: "Ready.", japanese: "実行可能です。")
            : Self.localizedText(
                language: settings.uiLanguage,
                english: "Start a managed server before Restart. External server context cannot be restarted here.",
                japanese: "再起動する前に管理サーバーを起動してください。外部サーバーはここから再起動できません。"
            )
    }

    var selectedBlockingStartIssue: String? {
        guard let selectedModel else { return Self.localizedText(language: settings.uiLanguage, english: "Select a model before Start.", japanese: "起動前にモデルを選択してください。") }
        return blockingStartIssue(for: selectedModel)
    }

    func blockingStartIssue(
        for model: ModelConfig,
        knownPortCheckResult: PortCheckResult? = nil
    ) -> String? {
        if let runtimeMemoryEmergencyBlockingMessage {
            return runtimeMemoryEmergencyBlockingMessage
        }

        let executablePath = executablePath(for: model).trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = staticStartPreflightIssue(for: model, executablePath: executablePath) {
            return issue.blockingMessage(language: settings.uiLanguage)
        }

        let portCheckResult = knownPortCheckResult ?? cachedPortCheck(host: model.host, port: model.serverPort)
        return modelStartPreflightEvaluator.evaluatePort(portCheckResult)?
            .blockingMessage(language: settings.uiLanguage)
    }

    private func staticStartPreflightIssue(
        for model: ModelConfig,
        executablePath: String,
        validateModelContents: Bool = false
    ) -> ModelStartPreflightIssue? {
        if let issue = modelStartPreflightEvaluator.evaluateLocal(
            model: model,
            executablePath: executablePath,
            validateModelContents: validateModelContents
        ) {
            return issue
        }
        return modelStartPreflightEvaluator.evaluateManagedEndpoint(
            model: model,
            managedEndpointConflict: managedEndpointConflict(for: model)
        )
    }

    private func runtimeCapabilityPreflightIssue(
        for request: ModelLaunchRequest,
        logPrefix: String
    ) async -> ModelStartPreflightIssue? {
        let requestedFlags = RuntimeProfileCompatibilityAdvisor.requestedOptionalFlags(for: request)
        guard !requestedFlags.isEmpty else {
            return nil
        }

        switch await runtimeOptionCapabilityProvider.capabilities(
            executablePath: request.executablePath,
            backend: request.backend
        ) {
        case let .available(flags):
            let unsupportedFlags = requestedFlags.filter { !flags.contains($0) }
            guard !unsupportedFlags.isEmpty else {
                return nil
            }
            return .unsupportedLaunchOptions(
                backend: request.backend,
                flags: unsupportedFlags
            )
        case .unavailable:
            appendLog("[\(logPrefix)] runtime option capability check was unavailable; continuing without blocking launch.")
            return nil
        }
    }

    private var runtimeMemoryEmergencyBlockingMessage: String? {
        guard isRuntimeMemoryEmergencyActive else {
            return nil
        }

        return Self.localizedText(
            language: settings.uiLanguage,
            english: "Managed Start and Restart are blocked because available memory remains in the emergency range. Stop an unused workload and wait for sustained recovery.",
            japanese: "空きメモリが緊急域のままのため、管理サーバーの起動と再起動を停止しています。不要な処理を停止し、メモリが継続的に回復するまで待ってください。"
        )
    }

    @discardableResult
    func blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: String) -> Bool {
        guard let message = runtimeMemoryEmergencyBlockingMessage else {
            return false
        }

        appendLog("[\(logPrefix)] blocked by runtime memory emergency: \(message)")
        return true
    }

    var canStartSelectedModel: Bool {
        guard let selectedModel else {
            return false
        }
        return canRequestManagedStart(for: selectedModel)
            && selectedBlockingStartIssue == nil
    }

    var startActionReason: String {
        selectedBlockingStartIssue
            ?? Self.localizedText(language: settings.uiLanguage, english: "Ready.", japanese: "実行可能です。")
    }

    var integratedActionStateSummary: String {
        if let selectedModel, runningModelIDs.contains(selectedModel.id) {
            return Self.localizedText(language: settings.uiLanguage, english: "Loaded. Stop or restart is available.", japanese: "ロード済みです。停止または再起動できます。")
        }

        return [
            Self.localizedText(language: settings.uiLanguage, english: "Start: \(startActionReason)", japanese: "起動: \(startActionReason)"),
            Self.localizedText(language: settings.uiLanguage, english: "Stop: \(stopDisabledReason)", japanese: "停止: \(stopDisabledReason)"),
            Self.localizedText(language: settings.uiLanguage, english: "Restart: \(restartDisabledReason)", japanese: "再起動: \(restartDisabledReason)"),
            Self.localizedText(language: settings.uiLanguage, english: "Benchmark: \(speedTestDisabledReason)", japanese: "ベンチマーク: \(speedTestDisabledReason)")
        ].joined(separator: "  ")
    }

    var selectedModelSafetyRows: [(String, String)] {
        guard let selectedModel else {
            return [(
                Self.localizedText(language: settings.uiLanguage, english: "Selected model", japanese: "選択モデル"),
                Self.localizedText(language: settings.uiLanguage, english: "Missing", japanese: "未選択")
            )]
        }
        if settings.uiLanguage.resolved == .english {
            return [
                ("Executable file", executableSafetyText),
                ("Model validation", modelIdentitySafetyText(for: selectedModel)),
                ("Port / IP address", portSafetyText(for: selectedModel)),
                ("Network exposure", networkExposureSafetyText(for: selectedModel)),
                ("Duplicate check", duplicateProfileWarning(for: selectedModel) ?? "No duplicate issue"),
                ("Runtime edit safety", runtimeEditingSafetyText(for: selectedModel))
            ]
        }
        return [
            ("実行ファイル", executableSafetyText),
            ("モデル検証", modelIdentitySafetyText(for: selectedModel)),
            ("ポート / IPアドレス", portSafetyText(for: selectedModel)),
            ("ネットワーク公開", networkExposureSafetyText(for: selectedModel)),
            ("重複確認", duplicateProfileWarning(for: selectedModel) ?? "問題なし"),
            ("実行中の編集", runtimeEditingSafetyText(for: selectedModel))
        ]
    }

    var selectedModelSafetySummary: String {
        let warningCount = selectedModelSafetyRows.filter { isSafetyWarning(label: $0.0, value: $0.1) }.count
        if settings.uiLanguage.resolved == .english {
            return warningCount == 0 ? "Safety: no issues" : "Safety: \(warningCount) warning(s)"
        }
        return warningCount == 0 ? "安全性: 問題なし" : "安全性: 警告\(warningCount)件"
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
        ([
            Self.localizedText(language: settings.uiLanguage, english: "Model Operations Safety", japanese: "モデル操作の安全性"),
            Self.localizedText(
                language: settings.uiLanguage,
                english: "Runtime: \(runtimeState.localizedTitle(language: .english))",
                japanese: "ランタイム: \(runtimeState.localizedTitle(language: .japanese))"
            ),
            Self.localizedText(language: settings.uiLanguage, english: "Selected: \(selectedModelIdentifier)", japanese: "選択中: \(selectedModelIdentifier)")
        ] + selectedModelSafetyRows.map { row in
            "\(row.0): \(row.1)"
        } + [Self.localizedText(
            language: settings.uiLanguage,
            english: "Recovery: \(failedStartRecoverySummary)",
            japanese: "復旧: \(failedStartRecoverySummary)"
        )]).joined(separator: "\n")
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
        guard let selectedModel else {
            return Self.localizedText(language: settings.uiLanguage, english: "No model selected", japanese: "モデル未選択")
        }
        let executablePath = executablePath(for: selectedModel).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else { return Self.localizedText(language: settings.uiLanguage, english: "Missing executable path", japanese: "実行ファイルパスが未設定") }
        if FileManager.default.isExecutableFile(atPath: executablePath) {
            return Self.localizedText(language: settings.uiLanguage, english: "Executable OK", japanese: "実行可能")
        }
        return Self.localizedText(language: settings.uiLanguage, english: "Missing or not executable", japanese: "未設定または実行不可")
    }

    func executablePath(for model: ModelConfig) -> String {
        settings.executablePath(for: model.resolvedBackend)
    }

    private func modelIdentitySafetyText(for model: ModelConfig) -> String {
        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) {
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory) && isDirectory.boolValue
                ? Self.localizedText(language: settings.uiLanguage, english: "Local path OK", japanese: "ローカルパスOK")
                : Self.localizedText(language: settings.uiLanguage, english: "Missing local path", japanese: "ローカルパスなし")
        }
        return model.modelID.contains("/")
            ? Self.localizedText(language: settings.uiLanguage, english: "Needs review: HF ID", japanese: "要確認: HF ID")
            : Self.localizedText(language: settings.uiLanguage, english: "Needs review", japanese: "要確認")
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
            || normalized.contains("失敗")
            || normalized.contains("warning")
            || normalized.contains("警告") {
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

    func networkExposureSafetyText(for model: ModelConfig) -> String {
        NetworkExposureAdvisor.assess(host: model.host)
            .safetyText(language: settings.uiLanguage)
    }

    private func portSafetyText(for model: ModelConfig) -> String {
        if runningModelIDs.contains(model.id) {
            return Self.localizedText(language: settings.uiLanguage, english: "OK: in use by loaded model", japanese: "OK: ロード済みモデルが使用中")
        }
        return portSafetyText(host: model.host, port: model.serverPort)
    }

    private func portSafetyText(host: String, port: Int) -> String {
        portSafetyText(for: cachedPortCheck(host: host, port: port))
    }

    private func portSafetyText(for result: PortCheckResult) -> String {
        switch result {
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
        guard runningModelIDs.contains(model.id) else {
            return Self.localizedText(language: settings.uiLanguage, english: "Edit safe", japanese: "編集可能")
        }
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

    var latestRetryableHuggingFaceDownloadQueueEntry: HuggingFaceDownloadQueueEntry? {
        huggingFaceDownloadRetryStore.latestRetryableEntry(in: huggingFaceDownloadQueue)
    }

    private var latestRetryableFailedHuggingFaceDownloadQueueEntry: HuggingFaceDownloadQueueEntry? {
        huggingFaceDownloadQueue.first { entry in
            entry.phase == .failed && huggingFaceDownloadRetryStore.isRetryable(entry)
        }
    }

    var currentRecoveryIssue: RecoveryIssue {
        if let failedDownload = latestRetryableFailedHuggingFaceDownloadQueueEntry {
            return downloadRecoveryIssue(from: failedDownload)
        }
        return runtimeRecoveryIssue
    }

    private var runtimeRecoveryIssue: RecoveryIssue {
        if let selectedModelID,
           let diagnosis = launchFailureDiagnosesByModelID[selectedModelID] {
            return recoveryIssue(from: diagnosis)
        }
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
        let retryKind = huggingFaceDownloadRetryStore.retryKind(queueEntryID: entry.id)
        let category: RecoveryIssueCategory = retryKind == .profileRegistration
            ? .profileRegistration
            : classifyFailure(entry.message)
        var availableActions = actions(for: category).compactMap { action -> RecoveryAction? in
            let isRetryAction = action.kind == .retryDownload || action.kind == .retryProfileRegistration
            if isRetryAction, !canRetryHuggingFaceDownload(id: entry.id) {
                return nil
            }
            let targetsDownloadEntry = isRetryAction
                || action.kind == .restoreDownloadForm
                || action.kind == .copyURL
            return RecoveryAction(
                kind: action.kind,
                title: action.title,
                detail: action.detail,
                isPrimary: action.isPrimary,
                downloadQueueEntryID: targetsDownloadEntry ? entry.id : nil
            )
        }
        if retryKind != .profileRegistration,
           canRetryHuggingFaceDownload(id: entry.id),
           !availableActions.contains(where: { $0.kind == .retryDownload }) {
            availableActions.append(
                RecoveryAction(
                    kind: .retryDownload,
                    title: "Retry Download",
                    detail: "Retry this failed download.",
                    isPrimary: false,
                    downloadQueueEntryID: entry.id
                )
            )
        }
        return RecoveryIssue(
            category: category,
            severity: .failed,
            title: category.title,
            detail: retryKind == .profileRegistration
                ? "Download completed for \(entry.repositoryID), but its model profile could not be added: \(entry.message)"
                : "Download failed for \(entry.repositoryID): \(entry.message)",
            relatedLogLine: latestImportantLogEntry?.line,
            actions: availableActions
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
                RecoveryAction(kind: .openSettings, title: "Open Settings", detail: "Set the selected backend executable path.", isPrimary: true),
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
        case .profileRegistration:
            return [
                RecoveryAction(kind: .retryProfileRegistration, title: "Retry Profile Add", detail: "Reuse the downloaded model and retry profile registration only.", isPrimary: true),
                RecoveryAction(kind: .openDownloads, title: "Open Downloads", detail: "Review the completed download and retry status.", isPrimary: false)
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
        let runningModels = models
            .filter { runningModelIDs.contains($0.id) }
            .map { "\($0.displayName) @ \($0.host):\($0.serverPort)" }
            .joined(separator: ", ")
        return [
            Self.localizedText(language: settings.uiLanguage, english: "Benchmark Troubleshooting", japanese: "ベンチマークのトラブルシューティング"),
            Self.localizedText(
                language: settings.uiLanguage,
                english: "Runtime: \(runtimeState.localizedTitle(language: .english))",
                japanese: "ランタイム: \(runtimeState.localizedTitle(language: .japanese))"
            ),
            Self.localizedText(language: settings.uiLanguage, english: "Target: \(connectionTargetSummary.targetType)", japanese: "接続先: \(connectionTargetSummary.targetType)"),
            "Base URL: \(baseURL)",
            "Selected model: \(selectedModelIdentifier)",
            "Running models: \(runningModels.isEmpty ? "Not running" : runningModels)",
            "Restart required: \(restartRequired ? "Yes" : "No")",
            "Latest benchmark: \(latestBenchmarkResult?.summary ?? "Not run")",
            "Guidance: \(benchmarkFailureGuidance ?? "No failure guidance")"
        ].joined(separator: "\n")
    }

    var logCategoryFilterOptions: [String] {
        logViewState.categoryFilterOptions
    }

    func logCategoryFilterLabel(_ category: String) -> String {
        category == "All"
            ? Self.localizedText(language: settings.uiLanguage, english: "All", japanese: "すべて")
            : category
    }

    var visibleLogEntries: [LogEntry] {
        logViewState.visibleEntries
    }

    var latestImportantLogEntry: LogEntry? {
        logViewState.latestImportantEntry
    }

    var runtimeSelectionWarning: String? {
        nil
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
        latestRetryableHuggingFaceDownloadQueueEntry != nil
    }

    func canRetryHuggingFaceDownload(id: UUID) -> Bool {
        guard let entry = huggingFaceDownloadQueue.first(where: { $0.id == id }) else {
            return false
        }
        return huggingFaceDownloadRetryStore.isRetryable(entry)
    }

    func huggingFaceDownloadRetryTitle(id: UUID? = nil) -> String {
        let queueEntryID = id ?? latestRetryableHuggingFaceDownloadQueueEntry?.id
        let isProfileRegistration = queueEntryID.flatMap {
            huggingFaceDownloadRetryStore.retryKind(queueEntryID: $0)
        } == .profileRegistration
        return Self.localizedText(
            language: settings.uiLanguage,
            english: isProfileRegistration ? "Retry Profile Add" : "Retry",
            japanese: isProfileRegistration ? "プロファイル登録を再試行" : "再試行"
        )
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
        case .degraded:
            targetType = "Managed Server (Degraded)"
            ownershipNote = "Managed by MLX Server Manager. Restart is required before inference."
            readinessSummary = managedReadinessSummary
            isActiveTarget = false
        default:
            if isSelectedModelManagedProcessRunning {
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
        let executablePathMissing = selectedModel.map {
            executablePath(for: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? true
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
            if isSelectedModelManagedProcessRunning {
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
                    let backendName = selectedModel?.resolvedBackend.localizedTitle(language: settings.uiLanguage)
                        ?? InferenceBackend.mlxLM.localizedTitle(language: settings.uiLanguage)
                    messages.append("Set the \(backendName) executable path to start a managed server.")
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
        guard !runningModelIDs.isEmpty else {
            return Self.localizedText(language: settings.uiLanguage, english: "Running Model: Not running", japanese: "実行中モデル: 未実行")
        }

        if runningModelIDs.count > 1 {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Running Models: \(runningModelIDs.count)",
                japanese: "実行中モデル: \(runningModelIDs.count)件"
            )
        }

        let modelID = runningModelIDs.first ?? "-"
        return Self.localizedText(language: settings.uiLanguage, english: "Running Model: \(modelID)", japanese: "実行中モデル: \(modelID)")
    }

    var restartRequired: Bool {
        false
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
            return "Managed server is process RSS; other/available memory is vm_stat-based"
        }
        return "管理サーバーはプロセスRSS、その他/空き容量はvm_statベース"
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

    private var measuredRuntimeMemoryHeadroomAssessment: RuntimeMemoryHeadroomAssessment {
        RuntimeMemoryHeadroomAdvisor.assess(
            environment: RuntimeMemoryHeadroomEnvironment(
                totalMemoryGigabytes: activeSystemMemorySnapshot?.totalGigabytes,
                availableMemoryGigabytes: activeSystemMemorySnapshot?.availableGigabytes
            )
        )
    }

    var runtimeMemoryHeadroomAssessment: RuntimeMemoryHeadroomAssessment {
        runtimeMemoryProtectionState.assessment ?? measuredRuntimeMemoryHeadroomAssessment
    }

    var isRuntimeMemoryEmergencyActive: Bool {
        runtimeMemoryProtectionState.blocksManagedStart
    }

    var runtimeMemoryProtectionActionText: String? {
        guard isRuntimeMemoryEmergencyActive else {
            return nil
        }

        return Self.localizedText(
            language: settings.uiLanguage,
            english: "Managed Start and Restart are temporarily blocked. Running servers are not stopped automatically.",
            japanese: "管理サーバーの起動と再起動を一時的に停止しています。稼働中のサーバーは自動停止しません。"
        )
    }

    var shouldShowRuntimeMemoryHeadroomWarning: Bool {
        guard runtimeMemoryProtectionState.level != .normal else {
            return false
        }
        return !runningModelIDs.isEmpty || isRuntimeMemoryEmergencyActive
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
        guard let modelID = selectedModelID ?? runningModelID else { return "-" }
        return integratedUptimeText(forModelID: modelID)
    }

    func integratedUptimeText(for model: ModelConfig) -> String {
        integratedUptimeText(forModelID: model.id)
    }

    private func integratedUptimeText(forModelID modelID: ModelConfig.ID) -> String {
        guard runningModelIDs.contains(modelID),
              let startedAt = managedServerStartedAtByModelID[modelID] else { return "-" }

        let elapsed = max(Int(Date().timeIntervalSince(startedAt)), 0)
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
        let modelRuntimeState = runtimeState(for: model)
        let isRunning = runningModelIDs.contains(model.id)
        let isPortBusy = knownPortBusy ?? isModelPortBusy(for: model)
        return interactiveStatusText(
            isHovered: isHovered,
            isPortBusy: isPortBusy,
            isRunning: isRunning,
            runtimeState: modelRuntimeState
        )
    }

    func interactiveStatusText(
        isHovered: Bool,
        isPortBusy: Bool,
        isRunning: Bool,
        runtimeState modelRuntimeState: ModelRuntimeState
    ) -> String {
        if settings.uiLanguage.resolved == .english {
            if isRunning {
                switch modelRuntimeState {
                case .starting, .loading, .checkingReady:
                    return "Loading"
                case .stopping:
                    return "Unloading"
                case .degraded:
                    return isHovered ? "Unload" : "Degraded"
                default:
                    return isHovered ? "Unload" : "Loaded"
                }
            }
            if isPortBusy {
                return "Port Busy"
            }
            return isHovered ? "Load" : "Ready"
        }
        if isRunning {
            switch modelRuntimeState {
            case .starting, .loading, .checkingReady:
                return "ロード中"
            case .stopping:
                return "アンロード中"
            case .degraded:
                return isHovered ? "アンロード" : "異常"
            default:
                return isHovered ? "アンロード" : "ロード済"
            }
        }

        if isPortBusy {
            return "ポート使用中"
        }
        return isHovered ? "ロード" : "準備完了"
    }

    func isModelPortBusy(for model: ModelConfig) -> Bool {
        guard !runningModelIDs.contains(model.id) else { return false }
        if case .busy = cachedPortCheck(host: model.host, port: model.serverPort) {
            return true
        }
        return false
    }

    func isModelLoaded(_ model: ModelConfig) -> Bool {
        runningModelIDs.contains(model.id)
            && !isModelTransitioning(model)
            && !isModelDegraded(model)
    }

    func isModelDegraded(_ model: ModelConfig) -> Bool {
        runningModelIDs.contains(model.id) && runtimeState(for: model).isDegraded
    }

    func isModelRunning(_ model: ModelConfig) -> Bool {
        runningModelIDs.contains(model.id)
    }

    func canEditProfile(_ model: ModelConfig) -> Bool {
        !isModelRunning(model)
    }

    func canDeleteProfile(_ model: ModelConfig) -> Bool {
        models.count > 1 && !isModelRunning(model)
    }

    func isModelTransitioning(_ model: ModelConfig) -> Bool {
        Self.isTransitioningRuntimeState(
            runtimeState(for: model),
            hasRuntimeContext: runningModelIDs.contains(model.id) || runtimeStatesByModelID[model.id] != nil
        )
    }

    static func isTransitioningRuntimeState(
        _ runtimeState: ModelRuntimeState,
        hasRuntimeContext: Bool
    ) -> Bool {
        guard hasRuntimeContext else { return false }
        switch runtimeState {
        case .starting, .loading, .checkingReady, .stopping:
            return true
        default:
            return false
        }
    }

    func canUseStatusAction(for model: ModelConfig) -> Bool {
        if runningModelIDs.contains(model.id) {
            return serverLifecycleCoordinator.processIdentifier(for: model.id) != nil
        }

        return canStartModel(model)
    }

    func statusActionRequested(for model: ModelConfig) {
        if runningModelIDs.contains(model.id) {
            stopRequested(for: model)
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

    var profileEditorKVCacheEnvironment: KVCacheEnvironment {
        let model = models.first { $0.id == profileEditorDraft.originalModelID }
        return kvCacheEnvironment(for: model)
    }

    var addProfileKVCacheEnvironment: KVCacheEnvironment {
        kvCacheEnvironment(for: nil)
    }

    private func kvCacheEnvironment(for model: ModelConfig?) -> KVCacheEnvironment {
        let memory = activeSystemMemorySnapshot
        return KVCacheEnvironment(
            totalMemoryGigabytes: memory?.totalGigabytes
                ?? Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            availableMemoryGigabytes: memory?.availableGigabytes,
            modelStorageGigabytes: model.flatMap(modelSizeGigabytes(for:)),
            isModelLoaded: model.map { runningModelIDs.contains($0.id) } ?? false
        )
    }

    func integratedMemoryText(for model: ModelConfig) -> String {
        guard runningModelIDs.contains(model.id),
              let memoryUsageGB = memoryUsageByModelID[model.id] else {
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
        if runningModelIDs.contains(model.id) {
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

    func modelSizeGigabytes(for model: ModelConfig) -> Double? {
        guard let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
            return nil
        }

        return modelSizeGigabytes(modelDirectoryPath: modelDirectoryPath)
    }

    func modelSizeGigabytes(modelDirectoryPath: String?) -> Double? {
        guard let modelDirectoryPath,
              !modelDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let cacheKey = Self.modelSizeCacheKey(forDirectoryPath: modelDirectoryPath)
        if let cached = modelSizeGigabytesCache[cacheKey] {
            return cached
        }
        guard !unavailableModelSizeCacheKeys.contains(cacheKey) else {
            return nil
        }

        _ = beginModelSizeEstimation(
            modelDirectoryPath: modelDirectoryPath,
            cacheKey: cacheKey
        )
        return nil
    }

    func resolvedModelSizeGigabytes(for model: ModelConfig) async -> Double? {
        guard let modelDirectoryPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model),
              !modelDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let cacheKey = Self.modelSizeCacheKey(forDirectoryPath: modelDirectoryPath)
        if let cached = modelSizeGigabytesCache[cacheKey] {
            return cached
        }
        guard !unavailableModelSizeCacheKeys.contains(cacheKey) else {
            return nil
        }

        let estimation = beginModelSizeEstimation(
            modelDirectoryPath: modelDirectoryPath,
            cacheKey: cacheKey
        )
        let result = await estimation.task.value
        completeModelSizeEstimation(
            result,
            cacheKey: cacheKey,
            generation: estimation.generation
        )
        return modelSizeGigabytesCache[cacheKey]
    }

    private func beginModelSizeEstimation(
        modelDirectoryPath: String,
        cacheKey: String
    ) -> ModelSizeEstimationCoordinator.Handle {
        let estimateOperation = modelStorageEstimateOperation
        return modelSizeEstimationCoordinator.begin(
            cacheKey,
            operation: {
                estimateOperation(modelDirectoryPath)
            },
            completion: { [weak self] result, _ in
                self?.publishModelSizeEstimationResult(
                    result,
                    cacheKey: cacheKey
                )
            }
        ).handle
    }

    private func completeModelSizeEstimation(
        _ result: Double?,
        cacheKey: String,
        generation: ModelSizeEstimationCoordinator.Generation
    ) {
        guard modelSizeEstimationCoordinator.complete(
            cacheKey,
            generation: generation
        ) else {
            return
        }

        publishModelSizeEstimationResult(result, cacheKey: cacheKey)
    }

    private func publishModelSizeEstimationResult(
        _ result: Double?,
        cacheKey: String
    ) {
        if let result {
            unavailableModelSizeCacheKeys.remove(cacheKey)
            modelSizeGigabytesCache[cacheKey] = result
        } else {
            modelSizeGigabytesCache[cacheKey] = nil
            unavailableModelSizeCacheKeys.insert(cacheKey)
        }
    }

    func invalidateModelSizeCache(for model: ModelConfig) {
        cancelModelStartPreparation(modelID: model.id)
        cancelManagedStartTask(modelID: model.id)
        invalidateModelSizeCache(forDirectoryPath: ModelAvailabilityPathFormatter.localPathCandidate(for: model))
    }

    func invalidateModelSizeCache(forDirectoryPath modelDirectoryPath: String?) {
        guard let modelDirectoryPath,
              !modelDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let cacheKey = Self.modelSizeCacheKey(forDirectoryPath: modelDirectoryPath)
        modelSizeEstimationCoordinator.cancel(cacheKey)
        unavailableModelSizeCacheKeys.remove(cacheKey)
        modelSizeGigabytesCache.removeValue(forKey: cacheKey)
    }

    func invalidateModelSizeCache() {
        modelStartPreparationCoordinator.cancelAll()
        managedStartRunCoordinator.cancelAll()
        modelSizeEstimationCoordinator.cancelAll()
        unavailableModelSizeCacheKeys.removeAll()
        modelSizeGigabytesCache.removeAll()
    }

    private static func modelSizeCacheKey(forDirectoryPath modelDirectoryPath: String) -> String {
        URL(fileURLWithPath: modelDirectoryPath).standardizedFileURL.path
    }

    func cachedPortCheck(host: String, port: Int) -> PortCheckResult {
        let cacheKey = Self.portCheckCacheKey(host: host, port: port)
        if let cached = portCheckCache[cacheKey],
           Date().timeIntervalSince(cached.checkedAt) <= Self.portCheckCacheLifetime {
            return cached.result
        }

        return freshPortCheck(host: host, port: port)
    }

    func freshPortCheck(host: String, port: Int) -> PortCheckResult {
        let result = portChecker.check(host: host, port: port)
        portCheckCache[Self.portCheckCacheKey(host: host, port: port)] = PortCheckCacheEntry(
            result: result,
            checkedAt: Date()
        )
        return result
    }

    func invalidatePortCheckCache() {
        portCheckCache.removeAll()
    }

    static func portCheckCacheKey(host: String, port: Int) -> String {
        "\(normalizedHost(host)):\(port)"
    }

    private static func normalizedHost(_ host: String) -> String {
        EndpointHostMatcher.normalized(host)
    }

    private func memoryValueForSort(_ model: ModelConfig) -> Double {
        memoryUsageByModelID[model.id] ?? -1
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

    static func formatMemoryGigabytes(_ value: Double) -> String {
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

    private func loadSystemHardwareInfo() {
        let provider = systemHardwareInfoProvider
        systemHardwareInfoRunCoordinator.start { [weak self] generation in
            let hardwareInfo = await provider.loadHardwareInfo()
            guard let self,
                  self.systemHardwareInfoRunCoordinator.isCurrent(generation: generation) else {
                return
            }

            self.systemProfilerHardwareInfo = hardwareInfo
            self.systemInfoRowsCache.removeAll()
        }
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

        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
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
        case .degraded:
            "Managed generation worker degraded"
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
        selectedModel != nil
            && !hermesAgentConfigPathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hermesAgentHasBlockingDiagnostics
    }

    var hermesAgentHasBlockingDiagnostics: Bool {
        hermesAgentConfigInspection?.diagnostics.contains(where: \.blocksUpdate) == true
    }

    var hermesAgentTargetModelText: String {
        selectedModelIdentifier
    }

    var hermesAgentTargetBaseURLText: String {
        baseURL
    }

    var hermesAgentMatchingModel: ModelConfig? {
        guard let inspection = hermesAgentConfigInspection else {
            return nil
        }
        return models.first { $0.modelID == inspection.connection.modelID }
    }

    var canSelectHermesAgentMatchingModel: Bool {
        guard let matchingModel = hermesAgentMatchingModel else {
            return false
        }
        return selectedModelID != matchingModel.id
    }

    var hermesAgentConfiguredModelText: String {
        guard let modelID = hermesAgentConfigInspection?.connection.modelID, !modelID.isEmpty else {
            return "-"
        }
        return modelID
    }

    var hermesAgentConfiguredBaseURLText: String {
        guard let baseURL = hermesAgentConfigInspection?.connection.baseURL, !baseURL.isEmpty else {
            return "-"
        }
        return baseURL
    }

    var hermesAgentSessionCountText: String {
        String(hermesAgentSessions.count)
    }

    var hermesAgentLatestSessionText: String {
        guard let session = hermesAgentSessions.first else {
            return Self.localizedText(language: settings.uiLanguage, english: "No sessions loaded", japanese: "セッション未読込")
        }
        let title = session.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (title?.isEmpty == false ? title : nil) ?? session.id
    }

    var selectedHermesAgentSession: HermesAgentSessionSummary? {
        guard let selectedHermesAgentSessionID else { return hermesAgentSessions.first }
        return hermesAgentSessions.first { $0.id == selectedHermesAgentSessionID }
    }

    var selectedHermesAgentSessionDetailsText: String {
        guard let session = selectedHermesAgentSession else {
            return Self.localizedText(language: settings.uiLanguage, english: "No session selected", japanese: "セッション未選択")
        }
        let totalTokens = session.inputTokens + session.outputTokens + session.cacheReadTokens + session.cacheWriteTokens + session.reasoningTokens
        let status: String
        if session.archived != 0 {
            status = Self.localizedText(language: settings.uiLanguage, english: "Archived", japanese: "アーカイブ済み")
        } else if let endedAt = session.endedAt {
            let reason = session.endReason?.isEmpty == false ? session.endReason! : "-"
            status = "\(Date(timeIntervalSince1970: endedAt).formatted(date: .abbreviated, time: .standard)) · \(reason)"
        } else {
            status = Self.localizedText(language: settings.uiLanguage, english: "Active / no end recorded", japanese: "継続中・終了記録なし")
        }
        let cwd = session.cwd?.isEmpty == false ? session.cwd! : "-"
        return "Messages \(session.messageCount) · Tools \(session.toolCallCount) · Tokens \(totalTokens)\nInput \(session.inputTokens) · Output \(session.outputTokens) · Cache R/W \(session.cacheReadTokens)/\(session.cacheWriteTokens) · Reasoning \(session.reasoningTokens)\nWorkspace \(cwd)\nStatus \(status)"
    }

    var filteredHermesAgentSessionMessages: [HermesAgentSessionMessage] {
        let query = hermesAgentTranscriptSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return hermesAgentSessionMessages.filter { message in
            if !hermesAgentTranscriptIncludesInactive && message.active == 0 { return false }
            if !hermesAgentTranscriptIncludesCompacted && message.compacted != 0 { return false }
            if hermesAgentTranscriptRoleFilter != "all" && message.role.lowercased() != hermesAgentTranscriptRoleFilter { return false }
            if query.isEmpty { return true }
            let searchable = [message.role, message.content, message.toolName, message.toolCalls, message.finishReason]
                .compactMap { $0 }
                .joined(separator: "\n")
            return searchable.localizedCaseInsensitiveContains(query)
        }
    }

    var sortedHermesAgentSessionMessages: [HermesAgentSessionMessage] {
        filteredHermesAgentSessionMessages.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return hermesAgentTranscriptNewestFirst ? lhs.id > rhs.id : lhs.id < rhs.id
            }
            return hermesAgentTranscriptNewestFirst ? lhs.timestamp > rhs.timestamp : lhs.timestamp < rhs.timestamp
        }
    }

    var visibleHermesAgentSessionMessages: [HermesAgentSessionMessage] {
        Array(sortedHermesAgentSessionMessages.prefix(hermesAgentTranscriptDisplayLimit))
    }

    var canShowMoreHermesAgentTranscript: Bool {
        visibleHermesAgentSessionMessages.count < sortedHermesAgentSessionMessages.count
    }

    var hermesAgentTranscriptAvailableRoles: [String] {
        Array(Set(hermesAgentSessionMessages.map { $0.role.lowercased() })).sorted()
    }

    var hermesAgentTranscriptSummaryText: String {
        guard selectedHermesAgentSession != nil else {
            return Self.localizedText(language: settings.uiLanguage, english: "No session selected", japanese: "セッション未選択")
        }
        return Self.localizedText(
            language: settings.uiLanguage,
            english: "Showing \(visibleHermesAgentSessionMessages.count) of \(sortedHermesAgentSessionMessages.count) matching item(s) · \(hermesAgentSessionMessages.count) loaded",
            japanese: "読込\(hermesAgentSessionMessages.count)件・該当\(sortedHermesAgentSessionMessages.count)件中\(visibleHermesAgentSessionMessages.count)件を表示"
        )
    }

    func showMoreHermesAgentTranscript() {
        hermesAgentTranscriptDisplayLimit = min(hermesAgentTranscriptDisplayLimit + 20, max(20, sortedHermesAgentSessionMessages.count))
    }

    func resetHermesAgentTranscriptDisplayLimit() {
        hermesAgentTranscriptDisplayLimit = 20
    }

    var selectedHermesAgentMessage: HermesAgentSessionMessage? {
        guard let selectedHermesAgentMessageID else { return nil }
        return hermesAgentSessionMessages.first { $0.id == selectedHermesAgentMessageID }
    }

    func hermesAgentTranscriptContent(_ message: HermesAgentSessionMessage) -> String {
        if let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
            return content
        }
        if let toolName = message.toolName, !toolName.isEmpty {
            return "Tool: \(toolName)"
        }
        if let toolCalls = message.toolCalls?.trimmingCharacters(in: .whitespacesAndNewlines), !toolCalls.isEmpty {
            return toolCalls
        }
        return Self.localizedText(language: settings.uiLanguage, english: "No displayable content", japanese: "表示可能な内容なし")
    }

    func hermesAgentTranscriptMetadata(_ message: HermesAgentSessionMessage) -> String {
        let tokens = message.tokenCount.map(String.init) ?? "-"
        let finishReason = message.finishReason?.isEmpty == false ? message.finishReason! : "-"
        let toolName = message.toolName?.isEmpty == false ? message.toolName! : "-"
        return "ID \(message.id)\nRole \(message.role)\nTime \(Date(timeIntervalSince1970: message.timestamp).formatted(date: .abbreviated, time: .standard))\nTokens \(tokens)\nFinish reason \(finishReason)\nTool \(toolName)\nActive \(message.active != 0)\nCompacted \(message.compacted != 0)"
    }

    func hermesAgentTranscriptCopyText(_ message: HermesAgentSessionMessage) -> String {
        let toolCalls = message.toolCalls?.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = toolCalls?.isEmpty == false ? "\n\nTool calls\n\(toolCalls!)" : ""
        return "\(hermesAgentTranscriptMetadata(message))\n\nContent\n\(hermesAgentTranscriptContent(message))\(extra)"
    }

    func hermesAgentTranscriptExportText(format: HermesAgentTranscriptExportFormat) -> String {
        guard let session = selectedHermesAgentSession else { return "" }
        let title = session.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionTitle = title?.isEmpty == false ? title! : session.id
        let messages = sortedHermesAgentSessionMessages

        switch format {
        case .markdown:
            let header = "# \(sessionTitle)\n\n- Session ID: `\(session.id)`\n- Source: \(session.source)\n- Model: \(session.model ?? "-")\n- Exported messages: \(messages.count)\n"
            let body = messages.map { message in
                let role = message.role.capitalized
                let time = Date(timeIntervalSince1970: message.timestamp).formatted(date: .abbreviated, time: .standard)
                let metadata = [
                    message.tokenCount.map { "Tokens: \($0)" },
                    message.finishReason.flatMap { $0.isEmpty ? nil : "Finish reason: \($0)" },
                    message.toolName.flatMap { $0.isEmpty ? nil : "Tool: \($0)" },
                    message.active == 0 ? "Inactive" : nil,
                    message.compacted != 0 ? "Compacted" : nil
                ].compactMap { $0 }.joined(separator: " · ")
                let suffix = metadata.isEmpty ? "" : "\n\n_\(metadata)_"
                let toolCalls = message.toolCalls?.trimmingCharacters(in: .whitespacesAndNewlines)
                let toolSection = toolCalls?.isEmpty == false ? "\n\n```json\n\(toolCalls!)\n```" : ""
                return "## \(role) · \(time)\n\n\(hermesAgentTranscriptContent(message))\(toolSection)\(suffix)"
            }.joined(separator: "\n\n---\n\n")
            return header + "\n" + body + "\n"
        case .plainText:
            let header = "\(sessionTitle)\nSession ID: \(session.id)\nSource: \(session.source)\nModel: \(session.model ?? "-")\nExported messages: \(messages.count)\n"
            let body = messages.map { message in
                "[\(Date(timeIntervalSince1970: message.timestamp).formatted(date: .abbreviated, time: .standard))] \(message.role.uppercased())\n\(hermesAgentTranscriptCopyText(message))"
            }.joined(separator: "\n\n----------------------------------------\n\n")
            return header + "\n\n" + body + "\n"
        }
    }

    var hermesAgentBackupCountText: String {
        String(hermesAgentConfigBackups.count)
    }

    var hermesAgentLatestBackupText: String {
        guard let latest = hermesAgentConfigBackups.first else {
            return Self.localizedText(language: settings.uiLanguage, english: "No backup", japanese: "バックアップなし")
        }
        return ModelAvailabilityPathFormatter.compact(path: latest.url.path)
    }

    var selectedHermesAgentBackup: HermesAgentConfigBackup? {
        guard let selectedHermesAgentBackupID else { return hermesAgentConfigBackups.first }
        return hermesAgentConfigBackups.first { $0.id == selectedHermesAgentBackupID }
    }

    var selectedHermesAgentBackupSummaryText: String {
        guard let backup = selectedHermesAgentBackup else {
            return Self.localizedText(language: settings.uiLanguage, english: "No backup selected", japanese: "バックアップ未選択")
        }
        do {
            let inspection = try hermesAgentConfigService.inspectBackup(backup)
            let model = inspection.connection.modelID.isEmpty ? "-" : inspection.connection.modelID
            let url = inspection.connection.baseURL.isEmpty ? "-" : inspection.connection.baseURL
            return "\(model) · \(url)"
        } catch {
            return Self.localizedText(language: settings.uiLanguage, english: "Preview unavailable", japanese: "プレビュー不可")
        }
    }

    var hermesAgentDiagnosticsText: String {
        guard let inspection = hermesAgentConfigInspection else {
            return Self.localizedText(language: settings.uiLanguage, english: "Not checked", japanese: "未確認")
        }
        guard !inspection.diagnostics.isEmpty else {
            return Self.localizedText(language: settings.uiLanguage, english: "No structural issues", japanese: "構造上の問題なし")
        }
        return inspection.diagnostics.map { diagnostic in
            let location = diagnostic.line.map { "L\($0) " } ?? ""
            return "\(location)\(diagnostic.message)"
        }.joined(separator: "\n")
    }

    var hermesAgentConfigMatchText: String {
        guard hermesAgentConfigInspection != nil else {
            return Self.localizedText(language: settings.uiLanguage, english: "Not checked", japanese: "未確認")
        }
        return hermesAgentPendingChangeKeys.isEmpty
            ? Self.localizedText(language: settings.uiLanguage, english: "Matches selected model", japanese: "選択モデルと一致")
            : Self.localizedText(language: settings.uiLanguage, english: "Differs from selected model", japanese: "選択モデルと不一致")
    }

    var hermesAgentPendingChangeKeys: [String] {
        guard let inspection = hermesAgentConfigInspection else {
            return []
        }
        var keys: [String] = []
        if inspection.connection.modelID != selectedModelIdentifier {
            keys.append("default")
        }
        if inspection.connection.baseURL != baseURL {
            keys.append("base_url")
        }
        if inspection.connection.apiKey != apiKeyPlaceholder {
            keys.append("api_key")
        }
        return keys
    }

    var hermesAgentPendingChangesText: String {
        guard hermesAgentConfigInspection != nil else {
            return Self.localizedText(language: settings.uiLanguage, english: "Run Check to preview changes", japanese: "確認を実行すると変更内容を表示します")
        }
        guard !hermesAgentPendingChangeKeys.isEmpty else {
            return Self.localizedText(language: settings.uiLanguage, english: "No changes", japanese: "変更なし")
        }
        return hermesAgentPendingChangeKeys.joined(separator: ", ")
    }

    var hermesAgentModelChangePreviewText: String {
        hermesAgentValueChangePreview(
            current: hermesAgentConfigInspection?.connection.modelID,
            proposed: selectedModelIdentifier
        )
    }

    var hermesAgentBaseURLChangePreviewText: String {
        hermesAgentValueChangePreview(
            current: hermesAgentConfigInspection?.connection.baseURL,
            proposed: baseURL
        )
    }

    var hermesAgentAPIKeyChangePreviewText: String {
        guard let inspection = hermesAgentConfigInspection else {
            return Self.localizedText(language: settings.uiLanguage, english: "Not checked", japanese: "未確認")
        }
        return inspection.connection.apiKey == apiKeyPlaceholder
            ? Self.localizedText(language: settings.uiLanguage, english: "Unchanged", japanese: "変更なし")
            : Self.localizedText(language: settings.uiLanguage, english: "Will be updated", japanese: "更新予定")
    }

    var hermesAgentUnifiedStatusText: String {
        guard let inspection = hermesAgentConfigInspection else {
            return Self.localizedText(language: settings.uiLanguage, english: "Check required", japanese: "確認が必要")
        }
        if inspection.diagnostics.contains(where: \.blocksUpdate) {
            return Self.localizedText(language: settings.uiLanguage, english: "Blocked by YAML structure", japanese: "YAML構造エラーにより更新不可")
        }
        if !inspection.diagnostics.isEmpty {
            return Self.localizedText(language: settings.uiLanguage, english: "Repairable issues detected", japanese: "安全に補完可能な問題あり")
        }
        if hermesAgentPendingChangeKeys.isEmpty {
            return Self.localizedText(language: settings.uiLanguage, english: "Synchronized", japanese: "同期済み")
        }
        return Self.localizedText(language: settings.uiLanguage, english: "Ready to update", japanese: "更新可能")
    }

    private func hermesAgentValueChangePreview(current: String?, proposed: String) -> String {
        guard let current else {
            return Self.localizedText(language: settings.uiLanguage, english: "Not checked", japanese: "未確認")
        }
        let currentValue = current.isEmpty ? "-" : current
        let proposedValue = proposed.isEmpty ? "-" : proposed
        guard currentValue != proposedValue else {
            return Self.localizedText(language: settings.uiLanguage, english: "Unchanged", japanese: "変更なし")
        }
        return "\(currentValue) → \(proposedValue)"
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
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "MLX: \(runtimeState.localizedMenuBarStatus(language: .english)) - restart required",
                japanese: "MLX: \(runtimeState.localizedMenuBarStatus(language: .japanese)) - 再起動が必要"
            )
        }

        return "MLX: \(runtimeState.localizedMenuBarStatus(language: settings.uiLanguage))"
    }

    func startManagedServer(model: ModelConfig, logPrefix: String) async -> Bool {
        guard !Task.isCancelled else {
            appendLog("[\(logPrefix)] cancelled before managed launch began.")
            return false
        }
        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: logPrefix) else {
            return false
        }

        let host = model.host
        let port = model.serverPort
        if let processIdentifier = serverLifecycleCoordinator.processIdentifier(for: model.id) {
            let message = "A managed inference server process is already running with pid \(processIdentifier)."
            setRuntimeState(.ready(
                host: host,
                port: port,
                processIdentifier: processIdentifier
            ), for: model.id)
            appendLog("[\(logPrefix)] failed: \(message)")
            return false
        }

        let advancedValidation = modelProfileValidator.validateAdvancedLaunchOptions(
            model.advancedLaunchOptions ?? .empty,
            backend: model.resolvedBackend
        )
        guard case let .valid(advancedLaunchOptions) = advancedValidation else {
            if case let .invalid(message) = advancedValidation {
                setRuntimeState(.error(message: message), for: model.id)
                appendLog("[\(logPrefix)] failed: \(message)")
            }
            return false
        }

        let executablePath = executablePath(for: model).trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = staticStartPreflightIssue(
            for: model,
            executablePath: executablePath,
            validateModelContents: true
        ) {
            let message = issue.launchMessage(language: settings.uiLanguage)
            if issue.isManagedEndpointConflict {
                setRuntimeState(.portBusy(host: host, port: port), for: model.id)
            } else {
                setRuntimeState(.error(message: message), for: model.id)
            }
            appendLog("[\(logPrefix)] preflight failed: \(message)")
            return false
        }

        let systemMemory = systemMemorySnapshotProvider()
        let cacheSafeMode = kvCacheSafeModeResult(
            for: model,
            options: advancedLaunchOptions,
            candidateModelGigabytes: modelSizeGigabytes(for: model),
            systemMemory: systemMemory
        )
        let request = ModelLaunchRequest(
            executablePath: executablePath,
            backend: model.resolvedBackend,
            modelID: model.modelID,
            host: host,
            port: port,
            enableThinking: model.enableThinking,
            advancedLaunchOptions: cacheSafeMode.advancedLaunchOptions
        )

        if let issue = await runtimeCapabilityPreflightIssue(for: request, logPrefix: logPrefix) {
            let message = issue.launchMessage(language: settings.uiLanguage)
            setRuntimeState(.error(message: message), for: model.id)
            appendLog("[\(logPrefix)] preflight failed: \(message)")
            return false
        }

        guard !Task.isCancelled,
              models.first(where: { $0.id == model.id }) == model else {
            appendLog("[\(logPrefix)] cancelled because the model profile changed during preflight.")
            return false
        }

        appendLog("[\(logPrefix)] checking port before launch: \(host):\(port)")
        setRuntimeState(.checkingPort(host: host, port: port), for: model.id)
        switch freshPortCheck(host: host, port: port) {
        case .available:
            appendLog("[\(logPrefix)] port available: \(host):\(port)")
        case let .busy(_, _, pid):
            if let pid {
                appendLog("[\(logPrefix)] port occupied: \(host):\(port) PID=\(pid)")
            } else {
                appendLog("[\(logPrefix)] port occupied: \(host):\(port)")
            }
            if await detectExternalServer(modelID: model.id, host: host, port: port, logPrefix: logPrefix) {
                return false
            }

            setRuntimeState(.portBusy(host: host, port: port), for: model.id)
            appendLog("[\(logPrefix)] port occupied and no compatible /v1/models endpoint detected.")
            return false
        case let .invalidInput(message):
            setRuntimeState(.portCheckFailed(host: host, port: port, message: message), for: model.id)
            appendLog("[\(logPrefix)] port check failed: \(message)")
            return false
        case let .failed(_, _, message):
            setRuntimeState(.portCheckFailed(host: host, port: port, message: message), for: model.id)
            appendLog("[\(logPrefix)] port check failed for \(host):\(port): \(message)")
            return false
        }

        appendLog("[\(logPrefix)] preflight passed for selected profile.")
        appendLog("[\(logPrefix)] starting \(model.modelID) at \(host):\(port)")
        if cacheSafeMode.didAdjust {
            appendLog("[cache-safe] \(cacheSafeMode.actionText(language: settings.uiLanguage))")
        }

        setRuntimeState(.starting(host: host, port: port), for: model.id)
        launchFailureDiagnosticCoordinator.begin(modelID: model.id)
        launchFailureDiagnosesByModelID[model.id] = nil
        let outputHandler = managedModelOutputCoordinator.begin(
            modelID: model.id,
            backend: model.resolvedBackend
        ) { [weak self, modelID = model.id, host, port] line, fault in
            self?.handleManagedServerOutput(
                line,
                modelID: modelID,
                host: host,
                port: port,
                detectedFault: fault
            )
        }

        do {
            let launchResult = try serverLifecycleCoordinator.start(
                profileID: model.id,
                request: request,
                outputHandler: outputHandler,
                terminationHandler: { [weak self, modelID = model.id] status in
                    self?.handleUnexpectedProcessTermination(
                        modelID: modelID,
                        status: status
                    )
                }
            )

            appendLog("[\(logPrefix)] command: \(launchResult.commandSummary)")
            appendLog("[\(logPrefix)] pid: \(launchResult.processIdentifier)")
            startMemoryMonitoring(processIdentifier: launchResult.processIdentifier, model: model)
            setRunningModelID(model.id, logPrefix: logPrefix)
            if managedModelOutputCoordinator.hasFault(for: model.id) {
                setRuntimeState(
                    degradedRuntimeState(
                        host: host,
                        port: port,
                        processIdentifier: launchResult.processIdentifier
                    ),
                    for: model.id
                )
            } else {
                setRuntimeState(.loading(
                    host: host,
                    port: port,
                    processIdentifier: launchResult.processIdentifier
                ), for: model.id)
            }

            let ready = await waitForReadyAfterStart(
                host: host,
                port: port,
                processIdentifier: launchResult.processIdentifier,
                modelID: model.id,
                expectedModelID: model.modelID
            )
            if ready {
                appendLog("[\(logPrefix)] ready check succeeded for pid \(launchResult.processIdentifier).")
                launchFailureDiagnosticCoordinator.clear(modelID: model.id)
                launchFailureDiagnosesByModelID[model.id] = nil
            } else {
                let message = "Ready check did not complete successfully after launch."
                appendLog("[\(logPrefix)] ready check did not complete successfully for pid \(launchResult.processIdentifier).")
                recordLaunchFailureDiagnosis(for: model, fallbackMessage: message)
            }

            return ready
        } catch {
            managedModelOutputCoordinator.invalidate(model.id)
            setRuntimeState(.error(message: error.localizedDescription), for: model.id)
            appendLog("[\(logPrefix)] failed: \(error.localizedDescription)")
            recordLaunchFailureDiagnosis(for: model, fallbackMessage: error.localizedDescription)
            return false
        }
    }

    private func handleManagedServerOutput(
        _ line: String,
        modelID: ModelConfig.ID,
        host: String,
        port: Int,
        detectedFault: ManagedServerRuntimeFault?
    ) {
        launchFailureDiagnosticCoordinator.append(line, modelID: modelID)
        appendLog(line)
        guard detectedFault != nil else {
            return
        }

        let processIdentifier = serverLifecycleCoordinator.processIdentifier(for: modelID)
        setRuntimeState(
            degradedRuntimeState(
                host: host,
                port: port,
                processIdentifier: processIdentifier
            ),
            for: modelID
        )
        appendLog(
            "[runtime-health] managed mlx-lm generation worker stopped unexpectedly. "
                + "The process was left running so logs can be inspected; stop or restart the model to recover."
        )
        appendRuntimeEvent(
            category: "Runtime Health",
            severity: .failure,
            message: "Managed mlx-lm generation worker stopped. Restart is recommended.",
            japaneseMessage: "管理中のmlx-lm生成ワーカーが停止しました。再起動を推奨します。",
            modelID: models.first(where: { $0.id == modelID })?.modelID,
            endpoint: "\(host):\(port)"
        )
    }

    private func degradedRuntimeState(
        host: String,
        port: Int,
        processIdentifier: Int32?
    ) -> ModelRuntimeState {
        .degraded(
            host: host,
            port: port,
            processIdentifier: processIdentifier,
            message: Self.localizedText(
                language: settings.uiLanguage,
                english: "The managed mlx-lm generation worker stopped unexpectedly. Stop or restart the model to recover.",
                japanese: "管理中のmlx-lm生成ワーカーが予期せず停止しました。復旧するにはモデルを停止または再起動してください。"
            )
        )
    }

    func degradedRuntimeStateToPreserve(
        modelID: ModelConfig.ID?,
        host: String,
        port: Int
    ) -> ModelRuntimeState? {
        let currentState = modelID.flatMap { runtimeStatesByModelID[$0] } ?? runtimeState
        if currentState.isDegraded {
            return currentState
        }
        guard let modelID,
              managedModelOutputCoordinator.hasFault(for: modelID) else {
            return nil
        }
        return degradedRuntimeState(
            host: host,
            port: port,
            processIdentifier: serverLifecycleCoordinator.processIdentifier(for: modelID)
        )
    }

    private func managedEndpointConflict(
        for model: ModelConfig
    ) -> ManagedModelEndpointConflict? {
        guard let endpoint = serverLifecycleCoordinator.runningEndpoint(
            host: model.host,
            port: model.serverPort,
            excluding: model.id
        ),
        let owner = models.first(where: { $0.id == endpoint.profileID }) else {
            return nil
        }

        return ManagedModelEndpointConflict(
            modelDisplayName: owner.displayName,
            processIdentifier: endpoint.processIdentifier
        )
    }

    func handleReadyCheckResult(
        _ result: ReadyCheckResult,
        fallbackHost: String,
        fallbackPort: Int,
        targetModelID: ModelConfig.ID?,
        previousRuntimeState: ModelRuntimeState
    ) {
        let eventModelID = targetModelID.flatMap { id in
            models.first { $0.id == id }?.modelID
        }
        let endpoint = "\(fallbackHost):\(fallbackPort)"
        let degradedState = degradedRuntimeStateToPreserve(
            modelID: targetModelID,
            host: fallbackHost,
            port: fallbackPort
        )
        switch result {
        case let .ready(url, statusCode):
            let state: ModelRuntimeState
            if let degradedState {
                state = degradedState
            } else if previousRuntimeState.isAdoptedExternalServer {
                state = .adoptedExternalServer(
                    host: fallbackHost,
                    port: fallbackPort,
                    baseURL: "http://\(fallbackHost):\(fallbackPort)/v1",
                    message: "This server is adopted for connection context only."
                )
            } else if previousRuntimeState.isExternalServerDetected {
                state = .externalServerDetected(
                    host: fallbackHost,
                    port: fallbackPort,
                    baseURL: "http://\(fallbackHost):\(fallbackPort)/v1",
                    message: "An OpenAI-compatible server appears to be running on this host/port."
                )
            } else {
                state = .ready(
                    host: fallbackHost,
                    port: fallbackPort,
                    processIdentifier: targetModelID.flatMap {
                        serverLifecycleCoordinator.processIdentifier(for: $0)
                    }
                )
            }
            setRuntimeState(state, forOptionalModelID: targetModelID)
            appendLog("[ready] ready: \(url.absoluteString) returned HTTP \(statusCode)")
            appendRuntimeEvent(
                category: "Ready",
                severity: degradedState == nil ? .success : .warning,
                message: degradedState == nil
                    ? "Ready Check succeeded with HTTP \(statusCode)."
                    : "Endpoint responded with HTTP \(statusCode), but runtime health remains degraded.",
                japaneseMessage: degradedState == nil
                    ? "準備状態の確認に成功しました。HTTP \(statusCode)が返されました。"
                    : "接続先はHTTP \(statusCode)を返しましたが、ランタイム状態は異常のままです。",
                modelID: eventModelID,
                endpoint: endpoint
            )
            if degradedState != nil {
                appendLog("[runtime-health] /v1/models still responds, but the managed generation worker remains degraded.")
            }
        case let .notReady(url, statusCode):
            setReadyFailureState(
                host: fallbackHost,
                port: fallbackPort,
                message: "HTTP \(statusCode)",
                targetModelID: targetModelID,
                previousRuntimeState: previousRuntimeState
            )
            appendLog("[ready] not ready: \(url.absoluteString) returned HTTP \(statusCode)")
            appendRuntimeEvent(
                category: "Ready",
                severity: .warning,
                message: "Ready Check returned HTTP \(statusCode).",
                japaneseMessage: "準備状態の確認でHTTP \(statusCode)が返されました。",
                modelID: eventModelID,
                endpoint: endpoint
            )
        case let .invalidInput(message):
            setReadyFailureState(
                host: fallbackHost,
                port: fallbackPort,
                message: message,
                targetModelID: targetModelID,
                previousRuntimeState: previousRuntimeState
            )
            appendLog("[ready] ready check failed: \(message)")
            appendRuntimeEvent(
                category: "Ready",
                severity: .failure,
                message: message,
                japaneseMessage: "準備状態の確認に失敗しました: \(message)",
                modelID: eventModelID,
                endpoint: endpoint
            )
        case let .failed(url, message):
            setReadyFailureState(
                host: fallbackHost,
                port: fallbackPort,
                message: message,
                targetModelID: targetModelID,
                previousRuntimeState: previousRuntimeState
            )
            appendLog("[ready] ready check failed for \(url?.absoluteString ?? "\(fallbackHost):\(fallbackPort)"): \(message)")
            appendRuntimeEvent(
                category: "Ready",
                severity: .failure,
                message: message,
                japaneseMessage: "準備状態の確認に失敗しました: \(message)",
                modelID: eventModelID,
                endpoint: endpoint
            )
        case let .timedOut(url):
            setReadyFailureState(
                host: fallbackHost,
                port: fallbackPort,
                message: "Timed out",
                targetModelID: targetModelID,
                previousRuntimeState: previousRuntimeState
            )
            appendLog("[ready] timed out: \(url.absoluteString)")
            appendRuntimeEvent(
                category: "Ready",
                severity: .failure,
                message: "Ready Check timed out.",
                japaneseMessage: "準備状態の確認がタイムアウトしました。",
                modelID: eventModelID,
                endpoint: endpoint
            )
        }
    }

    private func setReadyFailureState(
        host: String,
        port: Int,
        message: String,
        targetModelID: ModelConfig.ID?,
        previousRuntimeState: ModelRuntimeState
    ) {
        let state: ModelRuntimeState
        if let degradedState = degradedRuntimeStateToPreserve(
            modelID: targetModelID,
            host: host,
            port: port
        ) {
            state = degradedState
            appendLog("[runtime-health] failed ready check did not replace the degraded state.")
        } else if previousRuntimeState.isAdoptedExternalServer {
            state = .adoptedExternalServer(
                host: host,
                port: port,
                baseURL: "http://\(host):\(port)/v1",
                message: "Adopted external server is not ready: \(message)"
            )
        } else {
            state = .readyCheckFailed(
                host: host,
                port: port,
                message: message
            )
        }
        setRuntimeState(state, forOptionalModelID: targetModelID)
    }

    private func waitForReadyAfterStart(
        host: String,
        port: Int,
        processIdentifier: Int32,
        modelID: ModelConfig.ID,
        expectedModelID: String
    ) async -> Bool {
        let outcome = await serverLifecycleCoordinator.waitForReadyAfterStart(
            profileID: modelID,
            host: host,
            port: port,
            processIdentifier: processIdentifier,
            expectedModelID: expectedModelID,
            isStopRequested: { [weak self] in
                guard let self else { return true }
                if case .stopping = self.runtimeStatesByModelID[modelID] {
                    return true
                }
                return false
            },
            eventHandler: { [weak self] event in
                self?.handleReadyWaitEvent(
                    event,
                    modelID: modelID,
                    host: host,
                    port: port,
                    processIdentifier: processIdentifier
                )
            }
        )
        return outcome.isReady
    }

    private func handleReadyWaitEvent(
        _ event: ServerReadyWaitEvent,
        modelID: ModelConfig.ID,
        host: String,
        port: Int,
        processIdentifier: Int32
    ) {
        switch event {
        case .waiting:
            appendLog("[ready] waiting for http://\(host):\(port)/v1/models")
        case .processNoLongerRunning:
            appendLog("[ready] wait ended because managed process is no longer running.")
        case .stopRequested:
            appendLog("[ready] wait cancelled because stop was requested.")
        case .readyResponseIgnored:
            appendLog("[ready] ready response ignored because managed process is no longer running.")
        case let .ready(url, statusCode):
            if managedModelOutputCoordinator.hasFault(for: modelID) {
                setRuntimeState(
                    degradedRuntimeState(
                        host: host,
                        port: port,
                        processIdentifier: processIdentifier
                    ),
                    for: modelID
                )
                appendLog("[runtime-health] /v1/models responded after a generation-worker failure; degraded state was preserved.")
            } else {
                setRuntimeState(.ready(
                    host: host,
                    port: port,
                    processIdentifier: processIdentifier
                ), for: modelID)
            }
            appendLog("[ready] ready after start: \(url.absoluteString) returned HTTP \(statusCode)")
        case let .notReady(attempt, url, statusCode):
            appendLog("[ready] attempt \(attempt) not ready: \(url.absoluteString) returned HTTP \(statusCode)")
        case let .invalidInput(message):
            guard !managedModelOutputCoordinator.hasFault(for: modelID) else {
                appendLog("[runtime-health] invalid ready-check input did not replace the degraded state.")
                return
            }
            setRuntimeState(.readyCheckFailed(host: host, port: port, message: message), for: modelID)
            appendLog("[ready] ready check failed: \(message)")
        case let .failed(attempt, url, message):
            appendLog("[ready] attempt \(attempt) failed for \(url?.absoluteString ?? "\(host):\(port)"): \(message)")
        case let .timedOut(attempt, url):
            appendLog("[ready] attempt \(attempt) timed out: \(url.absoluteString)")
        case .cancelled:
            guard !managedModelOutputCoordinator.hasFault(for: modelID) else {
                appendLog("[runtime-health] cancelled ready wait did not replace the degraded state.")
                return
            }
            setRuntimeState(.unknown(message: "Ready wait was cancelled."), for: modelID)
            appendLog("[ready] wait cancelled.")
        case .exhausted:
            guard !managedModelOutputCoordinator.hasFault(for: modelID) else {
                appendLog("[runtime-health] exhausted ready wait did not replace the degraded state.")
                return
            }
            let message = "Ready check did not succeed after launch."
            setRuntimeState(.unknown(message: message), for: modelID)
            appendLog("[ready] \(message)")
        }
    }

    func stopManagedServerAndWaitForPortRelease(
        modelID: ModelConfig.ID,
        host: String,
        port: Int,
        logPrefix: String = "stop"
    ) async -> Bool {
        let outcome = await serverLifecycleCoordinator.stopAndWaitForPortRelease(
            profileID: modelID,
            host: host,
            port: port,
            portCheckOperation: { host, port in
                self.freshPortCheck(host: host, port: port)
            },
            eventHandler: { event in
                self.handleServerStopEvent(
                    event,
                    modelID: modelID,
                    host: host,
                    port: port,
                    logPrefix: logPrefix
                )
            }
        )
        return outcome == .released
    }

    func handleServerStopEvent(
        _ event: ServerStopEvent,
        modelID: ModelConfig.ID?,
        host: String,
        port: Int,
        logPrefix: String
    ) {
        switch event {
        case let .processResult(result):
            guard let modelID else { return }
            switch result {
            case .notRunning:
                stopMemoryMonitoring(for: modelID)
                clearRunningModel(modelID: modelID, logPrefix: logPrefix)
            case let .stopped(processIdentifier, terminationStatus, stopMethod):
                stopMemoryMonitoring(for: modelID)
                clearRunningModel(modelID: modelID, logPrefix: logPrefix)
                switch stopMethod {
                case .terminate:
                    break
                case .interrupt:
                    appendLog("[\(logPrefix)] interrupt was sent after graceful timeout for pid \(processIdentifier).")
                case .kill:
                    appendLog("[\(logPrefix)] force kill was sent after terminate and interrupt timeouts for pid \(processIdentifier).")
                }
                appendLog("[\(logPrefix)] stopped managed pid \(processIdentifier) with status \(terminationStatus).")
            case let .timedOut(processIdentifier):
                let message = "Stop timed out for managed pid \(processIdentifier)."
                setRuntimeState(.error(message: message), for: modelID)
                appendLog("[\(logPrefix)] \(message)")
            }
        case .checkingPortRelease:
            appendLog("[\(logPrefix)] checking port release immediately: \(host):\(port)")
        case let .portCheck(result, announceBusy):
            switch result {
            case .available:
                setRuntimeState(.stopped, forOptionalModelID: modelID)
                appendLog("[\(logPrefix)] port released: \(host):\(port)")
            case .busy:
                setRuntimeState(.portBusy(host: host, port: port), forOptionalModelID: modelID)
                if announceBusy {
                    appendLog("[\(logPrefix)] port is still releasing: \(host):\(port)")
                }
            case let .invalidInput(message):
                setRuntimeState(.portCheckFailed(host: host, port: port, message: message), forOptionalModelID: modelID)
                appendLog("[\(logPrefix)] warning: port release check failed: \(message)")
            case let .failed(_, _, message):
                setRuntimeState(.portCheckFailed(host: host, port: port, message: message), forOptionalModelID: modelID)
                appendLog("[\(logPrefix)] warning: port release check failed for \(host):\(port): \(message)")
            }
        case .portReleaseWaitCancelled:
            appendLog("[\(logPrefix)] warning: port release wait cancelled.")
            if let modelID, case .portBusy = runtimeStatesByModelID[modelID] {
                appendLog("[\(logPrefix)] warning: port still busy after waiting for release: \(host):\(port)")
            }
        case .portReleaseWaitExhausted:
            if let modelID, case .portBusy = runtimeStatesByModelID[modelID] {
                appendLog("[\(logPrefix)] warning: port still busy after waiting for release: \(host):\(port)")
            }
        case .managedProcessNotRunning:
            appendLog("[\(logPrefix)] managed process is not running.")
        }
    }

    func endpointForCurrentRuntimeState() -> (host: String, port: Int) {
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
             let .ready(host, port, _),
             let .degraded(host, port, _, _):
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

        cancelDiagnostics(reason: "the selected model changed")

        invalidatePortCheckCache()

        let clearedExternalContext = oldValue.map {
            runtimeStatesByModelID[$0]?.isExternalServerContext == true
        } ?? false
        if let oldValue, clearedExternalContext {
            var nextState = runtimeViewState
            nextState.clearExternalRuntimeContext(
                for: oldValue,
                selectedModelID: selectedModelID,
                runningProfileIDs: serverLifecycleCoordinator.runningProfileIDs,
                orderedModelIDs: models.map(\.id)
            )
            if nextState != runtimeViewState {
                runtimeViewState = nextState
            }
            appendLog("[model] external server context cleared after model selection changed.")
        } else {
            projectSelectedRuntimeState()
        }

        guard let selectedModel else {
            appendLog("[model] selected model cleared.")
            return
        }

        appendLog("[model] selected modelID: \(selectedModel.modelID)")
        resetModelAvailabilityForCurrentSelection()
        logRestartRequiredIfNeeded()
    }

    func resetModelAvailabilityForCurrentSelection() {
        selectedModelAvailabilitySummary = ModelAvailabilitySummary.initial(
            for: selectedModel,
            isExternalTarget: runtimeState.isExternalServerContext
        )
    }

    private func detectExternalServer(
        modelID: ModelConfig.ID,
        host: String,
        port: Int,
        logPrefix: String
    ) async -> Bool {
        let baseURL = "http://\(host):\(port)/v1"
        appendLog("[\(logPrefix)] checking for external OpenAI-compatible server at \(baseURL)/models")

        let result = await serverLifecycleCoordinator.checkReady(host: host, port: port)

        switch result {
        case let .ready(url, statusCode):
            stopMemoryMonitoring(for: modelID)
            clearRunningModel(modelID: modelID, logPrefix: logPrefix)
            let message = "An OpenAI-compatible server appears to be running on this host/port."
            setRuntimeState(.externalServerDetected(
                host: host,
                port: port,
                baseURL: baseURL,
                message: message
            ), for: modelID)
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
        var nextState = runtimeViewState
        nextState.markRunning(
            modelID: modelID,
            startedAt: Date(),
            runningProfileIDs: serverLifecycleCoordinator.runningProfileIDs,
            selectedModelID: selectedModelID,
            orderedModelIDs: models.map(\.id)
        )
        if nextState != runtimeViewState {
            runtimeViewState = nextState
        }
        invalidatePortCheckCache()
        appendLog("[\(logPrefix)] running modelID: \(modelID)")
        updateSessionRecoveryTracking()
        logRestartRequiredIfNeeded()
    }

    func clearRunningModel(modelID: ModelConfig.ID, logPrefix: String) {
        managedModelOutputCoordinator.invalidate(modelID)
        guard runningModelIDs.contains(modelID)
            || managedServerStartedAtByModelID[modelID] != nil else {
            return
        }

        var nextState = runtimeViewState
        nextState.clearRunning(
            modelID: modelID,
            runningProfileIDs: serverLifecycleCoordinator.runningProfileIDs,
            selectedModelID: selectedModelID,
            orderedModelIDs: models.map(\.id)
        )
        if nextState != runtimeViewState {
            runtimeViewState = nextState
        }
        invalidatePortCheckCache()
        appendLog("[\(logPrefix)] running model cleared: \(modelID)")
        updateSessionRecoveryTracking()
    }

    private func handleUnexpectedProcessTermination(modelID: ModelConfig.ID, status: Int32) {
        let wasStopping: Bool
        if case .stopping = runtimeStatesByModelID[modelID] {
            wasStopping = true
        } else {
            wasStopping = false
        }

        stopMemoryMonitoring(for: modelID)
        clearRunningModel(modelID: modelID, logPrefix: "process")
        appendLog("[process] managed server for \(modelID) exited with status \(status)")

        guard !wasStopping else { return }
        if status == 0 {
            setRuntimeState(.stopped, for: modelID)
        } else {
            let message = "Managed server exited with status \(status)."
            setRuntimeState(.error(message: message), for: modelID)
            if let model = models.first(where: { $0.id == modelID }) {
                recordLaunchFailureDiagnosis(for: model, fallbackMessage: message)
            }
        }
    }

    private func logRestartRequiredIfNeeded() {
        guard restartRequired,
              let runningModelID,
              let selectedModel else {
            return
        }

        appendLog("[model] selected model differs from running model. Restart required to apply selected model. selected: \(selectedModel.modelID), running: \(runningModelID)")
    }
}
