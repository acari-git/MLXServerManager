import Foundation

enum RecoverySeverity: String, Codable, Hashable {
    case ok = "OK"
    case warning = "Warning"
    case failed = "Failed"
    case review = "Needs Review"
}

enum RecoveryIssueCategory: String, Codable, CaseIterable, Hashable {
    case none
    case executableMissing
    case executableNotExecutable
    case modelPathMissing
    case portBusy
    case permissionDenied
    case readinessTimeout
    case processExitedEarly
    case huggingFaceCLIMissing
    case huggingFaceAccess
    case network
    case destination
    case unknown

    var title: String {
        switch self {
        case .none: "No recovery needed"
        case .executableMissing: "Executable Missing"
        case .executableNotExecutable: "Executable Not Executable"
        case .modelPathMissing: "Model Path Missing"
        case .portBusy: "Port Busy"
        case .permissionDenied: "Permission Denied"
        case .readinessTimeout: "Readiness Timeout"
        case .processExitedEarly: "Process Exited Early"
        case .huggingFaceCLIMissing: "HF CLI Missing"
        case .huggingFaceAccess: "HF Access / Gated Model"
        case .network: "Network Error"
        case .destination: "Destination Error"
        case .unknown: "Unknown Issue"
        }
    }
}

struct RecoveryAction: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case openSettings
        case openModels
        case openDownloads
        case openLogs
        case editProfile
        case checkPort
        case runDiagnostics
        case runReadyCheck
        case retryDownload
        case restoreDownloadForm
        case copyURL
        case copyTroubleshooting
        case copySafety
    }

    var id: String { kind.rawValue }
    let kind: Kind
    let title: String
    let detail: String
    let isPrimary: Bool
}

struct RecoveryIssue: Identifiable, Hashable {
    var id: String { category.rawValue }
    let category: RecoveryIssueCategory
    let severity: RecoverySeverity
    let title: String
    let detail: String
    let relatedLogLine: String?
    let actions: [RecoveryAction]

    static let none = RecoveryIssue(
        category: .none,
        severity: .ok,
        title: RecoveryIssueCategory.none.title,
        detail: "No recovery action is currently needed.",
        relatedLogLine: nil,
        actions: []
    )
}
