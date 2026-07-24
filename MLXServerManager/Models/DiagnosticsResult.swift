import Foundation

nonisolated enum DiagnosticsStatus: String, Hashable, Sendable {
    case pass
    case warning
    case fail

    var logLabel: String {
        rawValue
    }
}

nonisolated struct DiagnosticsResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let check: DiagnosticsCheck
    let status: DiagnosticsStatus
    let message: String
    let detail: String?

    init(
        check: DiagnosticsCheck,
        status: DiagnosticsStatus,
        message: String,
        detail: String? = nil
    ) {
        self.id = UUID()
        self.check = check
        self.status = status
        self.message = message
        self.detail = detail
    }

    var logLine: String {
        if let detail, !detail.isEmpty {
            return "[diagnostics] \(status.logLabel): \(check.title) - \(message) (\(detail))"
        }

        return "[diagnostics] \(status.logLabel): \(check.title) - \(message)"
    }
}
