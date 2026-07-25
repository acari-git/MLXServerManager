import Foundation

nonisolated enum PreviousSessionDisposition: String, Codable, Equatable, Sendable {
    case active
    case leftRunning
    case systemShutdown
    case clean

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .active:
            return strings.text(
                english: "Previous session ended unexpectedly",
                japanese: "前回のセッションが予期せず終了しました"
            )
        case .leftRunning:
            return strings.text(
                english: "Managed servers were intentionally left running",
                japanese: "管理サーバーを残して終了しました"
            )
        case .systemShutdown:
            return strings.text(
                english: "The previous session ended during macOS shutdown",
                japanese: "前回のセッションはmacOS終了時に終了しました"
            )
        case .clean:
            return strings.text(
                english: "Previous session closed normally",
                japanese: "前回のセッションは正常に終了しました"
            )
        }
    }
}

nonisolated struct SessionRecoveryEndpoint: Identifiable, Codable, Equatable, Sendable {
    let profileID: ModelConfig.ID
    let displayName: String
    let modelID: String
    let host: String
    let port: Int

    var id: ModelConfig.ID { profileID }
    var baseURL: String { "http://\(host):\(port)/v1" }
}

nonisolated struct SessionRecoveryRecord: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let sessionID: UUID
    let disposition: PreviousSessionDisposition
    let updatedAt: Date
    let endpoints: [SessionRecoveryEndpoint]

    init(
        sessionID: UUID,
        disposition: PreviousSessionDisposition,
        updatedAt: Date = Date(),
        endpoints: [SessionRecoveryEndpoint]
    ) {
        self.schemaVersion = Self.schemaVersion
        self.sessionID = sessionID
        self.disposition = disposition
        self.updatedAt = updatedAt
        self.endpoints = endpoints
    }
}

nonisolated enum SessionRecoveryCheckStatus: Equatable, Sendable {
    case notChecked
    case checking
    case available(statusCode: Int)
    case unavailable(message: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .notChecked:
            return strings.text(english: "Not checked", japanese: "未確認")
        case .checking:
            return strings.text(english: "Checking", japanese: "確認中")
        case let .available(statusCode):
            return strings.text(
                english: "Available (HTTP \(statusCode))",
                japanese: "利用可能（HTTP \(statusCode)）"
            )
        case let .unavailable(message):
            return strings.text(
                english: "Unavailable: \(message)",
                japanese: "利用不可: \(message)"
            )
        }
    }
}

nonisolated struct SessionRecoveryCandidate: Identifiable, Equatable, Sendable {
    let endpoint: SessionRecoveryEndpoint
    var status: SessionRecoveryCheckStatus
    var isAdopted: Bool

    var id: ModelConfig.ID { endpoint.profileID }
}

nonisolated struct SessionRecoveryViewState: Equatable, Sendable {
    var previousDisposition: PreviousSessionDisposition?
    var candidates: [SessionRecoveryCandidate]
    var isPresented: Bool
    var isChecking: Bool

    static let hidden = SessionRecoveryViewState(
        previousDisposition: nil,
        candidates: [],
        isPresented: false,
        isChecking: false
    )

    static func presenting(record: SessionRecoveryRecord) -> SessionRecoveryViewState {
        SessionRecoveryViewState(
            previousDisposition: record.disposition,
            candidates: record.endpoints.map {
                SessionRecoveryCandidate(endpoint: $0, status: .notChecked, isAdopted: false)
            },
            isPresented: !record.endpoints.isEmpty,
            isChecking: false
        )
    }

    mutating func beginCheck() {
        isChecking = true
        candidates = candidates.map {
            var next = $0
            next.status = .checking
            return next
        }
    }

    mutating func complete(_ results: [ModelConfig.ID: SessionRecoveryCheckStatus]) {
        candidates = candidates.map {
            var next = $0
            next.status = results[$0.id] ?? .unavailable(message: "No result")
            return next
        }
        isChecking = false
    }

    mutating func markAdopted(_ id: ModelConfig.ID) {
        candidates = candidates.map {
            var next = $0
            if next.id == id { next.isAdopted = true }
            return next
        }
    }
}
