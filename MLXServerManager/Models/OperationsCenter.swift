import Foundation

nonisolated enum OperationsCenterStatus: String, Codable, Hashable, Sendable {
    case ready
    case review
    case blocking
    case unknown

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .ready:
            strings.text(english: "Ready", japanese: "準備完了")
        case .review:
            strings.text(english: "Review", japanese: "要確認")
        case .blocking:
            strings.text(english: "Blocking", japanese: "起動不可")
        case .unknown:
            strings.text(english: "Unknown", japanese: "未確認")
        }
    }
}

nonisolated struct PlatformCompatibilityReport: Equatable, Sendable {
    let minimumSupportedVersion: String
    let currentVersion: String
    let architecture: String
    let isAppleSilicon: Bool
    let status: OperationsCenterStatus
    let checkedAt: Date

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        if !isAppleSilicon {
            return strings.text(
                english: "This build supports Apple Silicon only. Detected architecture: \(architecture).",
                japanese: "このビルドはApple Silicon専用です。検出したアーキテクチャ: \(architecture)。"
            )
        }
        return strings.text(
            english: "macOS \(currentVersion) on \(architecture). The declared minimum supported version is macOS \(minimumSupportedVersion).",
            japanese: "macOS \(currentVersion)・\(architecture)環境です。宣言済みの最低対応バージョンはmacOS \(minimumSupportedVersion)です。"
        )
    }
}

nonisolated enum EvidenceDomain: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case runtime
    case profile
    case model
    case endpoint
    case memory
    case benchmark
    case hermes

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .runtime:
            strings.text(english: "Runtime", japanese: "ランタイム")
        case .profile:
            strings.text(english: "Profile", japanese: "プロファイル")
        case .model:
            strings.text(english: "Model files", japanese: "モデルファイル")
        case .endpoint:
            strings.text(english: "Endpoint", japanese: "エンドポイント")
        case .memory:
            strings.text(english: "Memory", japanese: "メモリ")
        case .benchmark:
            strings.text(english: "Benchmark", japanese: "ベンチマーク")
        case .hermes:
            strings.text(english: "Hermes Agent", japanese: "Hermes Agent設定")
        }
    }
}

nonisolated enum EvidenceFreshnessStatus: String, Codable, Hashable, Sendable {
    case current
    case stale
    case unavailable

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .current:
            strings.text(english: "Current", japanese: "最新")
        case .stale:
            strings.text(english: "Stale", japanese: "再確認が必要")
        case .unavailable:
            strings.text(english: "Unavailable", japanese: "判定不可")
        }
    }
}

nonisolated struct EvidenceFingerprint: Codable, Hashable, Sendable {
    let domain: EvidenceDomain
    let value: String?
    let capturedAt: Date
}

nonisolated struct EvidenceFreshnessItem: Identifiable, Equatable, Sendable {
    let domain: EvidenceDomain
    let status: EvidenceFreshnessStatus
    let capturedAt: Date?
    let currentFingerprint: String?
    let capturedFingerprint: String?
    let reason: String?

    var id: EvidenceDomain { domain }

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch status {
        case .current:
            return strings.text(
                english: "The inputs used by the latest check still match the current configuration.",
                japanese: "最新の確認で使用した入力情報は現在の構成と一致しています。"
            )
        case .stale:
            return reason ?? strings.text(
                english: "A related input changed after the latest check. Run the check again.",
                japanese: "最新の確認後に関連情報が変更されました。もう一度確認してください。"
            )
        case .unavailable:
            return strings.text(
                english: "No captured evidence is available for comparison.",
                japanese: "比較できる確認済み情報がありません。"
            )
        }
    }
}

nonisolated enum RuntimeDoctorSeverity: String, Codable, Hashable, Sendable {
    case info
    case warning
    case blocking
}

nonisolated enum RuntimeDoctorIssueKind: String, Codable, Hashable, Sendable {
    case pathNotConfigured
    case pathMissing
    case notExecutable
    case unsupportedArchitecture
    case interpreterMissing
    case dependencyFailure
    case helpUnavailable
    case versionUnavailable
    case duplicateCandidate
    case ready
}

nonisolated struct RuntimeDoctorIssue: Identifiable, Equatable, Sendable {
    let id: String
    let backend: InferenceBackend
    let kind: RuntimeDoctorIssueKind
    let severity: RuntimeDoctorSeverity
    let title: String
    let detail: String
    let commandPreview: String?
}

nonisolated struct RuntimeDoctorReport: Identifiable, Equatable, Sendable {
    let backend: InferenceBackend
    let executablePath: String
    let version: String?
    let interpreterPath: String?
    let issues: [RuntimeDoctorIssue]
    let checkedAt: Date

    var id: InferenceBackend { backend }

    var status: OperationsCenterStatus {
        if issues.contains(where: { $0.severity == .blocking }) { return .blocking }
        if issues.contains(where: { $0.severity == .warning }) { return .review }
        return .ready
    }
}

nonisolated enum ModelMetadataStatus: String, Codable, Hashable, Sendable {
    case compatibleCandidate
    case review
    case incomplete
    case externalIdentifier
    case unavailable

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .compatibleCandidate:
            strings.text(english: "Compatible candidate", japanese: "互換候補")
        case .review:
            strings.text(english: "Review metadata", japanese: "メタデータ要確認")
        case .incomplete:
            strings.text(english: "Incomplete", japanese: "構成不足")
        case .externalIdentifier:
            strings.text(english: "External identifier", japanese: "外部Model ID")
        case .unavailable:
            strings.text(english: "Unavailable", japanese: "解析不可")
        }
    }
}

nonisolated struct ModelMetadataReport: Identifiable, Equatable, Sendable {
    let profileID: String
    let modelID: String
    let localPath: String?
    let status: ModelMetadataStatus
    let modelType: String?
    let architectures: [String]
    let quantization: String?
    let contextLength: Int?
    let vocabularySize: Int?
    let hasTokenizer: Bool
    let hasChatTemplate: Bool
    let reasoningCandidate: Bool
    let toolCallingCandidate: Bool
    let weightFileCount: Int
    let shardCount: Int?
    let totalWeightBytes: UInt64?
    let warnings: [String]
    let checkedAt: Date

    var id: String { profileID }
}

nonisolated enum LaunchStabilityStatus: String, Codable, Hashable, Sendable {
    case notRunning
    case stabilizing
    case stable
    case degraded
    case unstable
    case exited

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .notRunning:
            strings.text(english: "Not running", japanese: "未起動")
        case .stabilizing:
            strings.text(english: "Stabilizing", japanese: "安定性確認中")
        case .stable:
            strings.text(english: "Stable", japanese: "安定")
        case .degraded:
            strings.text(english: "Degraded", japanese: "異常あり")
        case .unstable:
            strings.text(english: "Unstable", japanese: "不安定")
        case .exited:
            strings.text(english: "Exited", japanese: "終了済み")
        }
    }
}

nonisolated struct LaunchStabilitySample: Equatable, Sendable {
    let timestamp: Date
    let ready: Bool
    let processIdentifier: Int32?
    let managedMemoryGigabytes: Double?
    let message: String?
}

nonisolated struct LaunchStabilityReport: Identifiable, Equatable, Sendable {
    let profileID: String
    let status: LaunchStabilityStatus
    let samples: [LaunchStabilitySample]
    let startedAt: Date
    let completedAt: Date

    var id: String { profileID }
}

nonisolated struct ResourceCalibrationRecord: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let profileID: String
    let modelID: String
    let backend: InferenceBackend
    let executionFingerprint: String
    let totalMemoryGigabytes: Double
    let availableMemoryGigabytes: Double?
    let predictedManagedMemoryGigabytes: Double?
    let observedManagedMemoryGigabytes: Double?
    let benchmarkTTFTMS: Double?
    let benchmarkTokensPerSecond: Double?
    let benchmarkStabilityPercent: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        profileID: String,
        modelID: String,
        backend: InferenceBackend,
        executionFingerprint: String,
        totalMemoryGigabytes: Double,
        availableMemoryGigabytes: Double?,
        predictedManagedMemoryGigabytes: Double?,
        observedManagedMemoryGigabytes: Double?,
        benchmarkTTFTMS: Double?,
        benchmarkTokensPerSecond: Double?,
        benchmarkStabilityPercent: Int?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.profileID = profileID
        self.modelID = modelID
        self.backend = backend
        self.executionFingerprint = executionFingerprint
        self.totalMemoryGigabytes = totalMemoryGigabytes
        self.availableMemoryGigabytes = availableMemoryGigabytes
        self.predictedManagedMemoryGigabytes = predictedManagedMemoryGigabytes
        self.observedManagedMemoryGigabytes = observedManagedMemoryGigabytes
        self.benchmarkTTFTMS = benchmarkTTFTMS
        self.benchmarkTokensPerSecond = benchmarkTokensPerSecond
        self.benchmarkStabilityPercent = benchmarkStabilityPercent
    }
}

nonisolated struct LaunchPlanStep: Codable, Hashable, Sendable, Identifiable {
    let profileID: String
    var isRequired: Bool

    var id: String { profileID }
}

nonisolated struct LaunchPlanDefinition: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var steps: [LaunchPlanStep]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        steps: [LaunchPlanStep],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated enum LaunchPlanExecutionPhase: String, Equatable, Sendable {
    case idle
    case validating
    case starting
    case completed
    case failed
    case cancelled
    case stopping
}

nonisolated struct LaunchPlanExecutionState: Equatable, Sendable {
    var planID: UUID?
    var phase: LaunchPlanExecutionPhase
    var currentProfileID: String?
    var completedProfileIDs: [String]
    var startedByPlanProfileIDs: [String]
    var message: String?

    static let idle = LaunchPlanExecutionState(
        planID: nil,
        phase: .idle,
        currentProfileID: nil,
        completedProfileIDs: [],
        startedByPlanProfileIDs: [],
        message: nil
    )
}

nonisolated enum CapacityAssessmentLevel: String, Codable, Hashable, Sendable {
    case safe
    case caution
    case critical
    case unavailable

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .safe:
            strings.text(english: "Safe", japanese: "安全")
        case .caution:
            strings.text(english: "Caution", japanese: "注意")
        case .critical:
            strings.text(english: "Critical", japanese: "危険")
        case .unavailable:
            strings.text(english: "Unavailable", japanese: "判定不可")
        }
    }
}

nonisolated struct CapacityPlanItem: Identifiable, Equatable, Sendable {
    let profileID: String
    let displayName: String
    let estimatedGigabytes: Double?
    let isAlreadyRunning: Bool

    var id: String { profileID }
}

nonisolated struct CapacityPlanAssessment: Equatable, Sendable {
    let level: CapacityAssessmentLevel
    let items: [CapacityPlanItem]
    let currentManagedGigabytes: Double
    let candidateGigabytes: Double?
    let projectedManagedGigabytes: Double?
    let availableGigabytes: Double?
    let recommendedOrder: [String]
    let message: String
}

nonisolated struct SupportBundleReport: Equatable, Sendable {
    let generatedAt: Date
    let text: String
}

nonisolated struct OperationsCenterViewState: Equatable, Sendable {
    var isPresented: Bool
    var isChecking: Bool
    var platform: PlatformCompatibilityReport?
    var evidence: [EvidenceFreshnessItem]
    var capturedEvidence: [EvidenceFingerprint]
    var runtimeReports: [RuntimeDoctorReport]
    var operationalReadiness: OperationalReadinessReport?
    var modelMetadata: ModelMetadataReport?
    var stability: LaunchStabilityReport?
    var calibrationRecords: [ResourceCalibrationRecord]
    var capacity: CapacityPlanAssessment?
    var launchPlanExecution: LaunchPlanExecutionState
    var supportBundle: SupportBundleReport?
    var message: String?

    static let hidden = OperationsCenterViewState(
        isPresented: false,
        isChecking: false,
        platform: nil,
        evidence: [],
        capturedEvidence: [],
        runtimeReports: [],
        operationalReadiness: nil,
        modelMetadata: nil,
        stability: nil,
        calibrationRecords: [],
        capacity: nil,
        launchPlanExecution: .idle,
        supportBundle: nil,
        message: nil
    )

    mutating func begin() {
        isChecking = true
        message = nil
    }

    mutating func cancel() {
        isChecking = false
    }
}
