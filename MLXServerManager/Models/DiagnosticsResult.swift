import Foundation

enum DiagnosticsStatus: String, Hashable {
    case pass
    case warning
    case fail

    var logLabel: String {
        rawValue
    }
}

struct DiagnosticsResult: Identifiable, Hashable {
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
