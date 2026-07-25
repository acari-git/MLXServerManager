import Foundation

nonisolated enum RuntimeEventSeverity: String, CaseIterable, Equatable, Sendable {
    case info
    case success
    case warning
    case failure

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .info:
            return strings.text(english: "Info", japanese: "情報")
        case .success:
            return strings.text(english: "Success", japanese: "成功")
        case .warning:
            return strings.text(english: "Warning", japanese: "警告")
        case .failure:
            return strings.text(english: "Failure", japanese: "失敗")
        }
    }
}

nonisolated enum OperationalHistorySeverityFilter: String, CaseIterable, Identifiable, Equatable, Sendable {
    case all
    case info
    case success
    case warning
    case failure

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .all:
            return strings.text(english: "All severities", japanese: "すべての重要度")
        case .info:
            return RuntimeEventSeverity.info.localizedTitle(language: language)
        case .success:
            return RuntimeEventSeverity.success.localizedTitle(language: language)
        case .warning:
            return RuntimeEventSeverity.warning.localizedTitle(language: language)
        case .failure:
            return RuntimeEventSeverity.failure.localizedTitle(language: language)
        }
    }

    func includes(_ severity: RuntimeEventSeverity) -> Bool {
        switch self {
        case .all:
            return true
        case .info:
            return severity == .info
        case .success:
            return severity == .success
        case .warning:
            return severity == .warning
        case .failure:
            return severity == .failure
        }
    }
}

nonisolated struct RuntimeEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: String
    let severity: RuntimeEventSeverity
    let message: String
    let japaneseMessage: String?
    let modelID: String?
    let endpoint: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: String,
        severity: RuntimeEventSeverity = .info,
        message: String,
        japaneseMessage: String? = nil,
        modelID: String? = nil,
        endpoint: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "General"
            : category.trimmingCharacters(in: .whitespacesAndNewlines)
        self.severity = severity
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.japaneseMessage = Self.normalized(japaneseMessage)
        self.modelID = Self.normalized(modelID)
        self.endpoint = Self.normalized(endpoint)
    }

    var summary: String {
        localizedSummary(language: .english)
    }

    func localizedMessage(language: AppLanguage) -> String {
        language.resolved == .japanese ? (japaneseMessage ?? message) : message
    }

    func localizedSummary(language: AppLanguage) -> String {
        var components = ["[\(severity.rawValue)]", category]
        if let modelID {
            components.append(modelID)
        }
        if let endpoint {
            components.append(endpoint)
        }
        return "\(components.joined(separator: " · ")): \(localizedMessage(language: language))"
    }

    func copyText(language: AppLanguage = .english) -> String {
        let timestampText = ISO8601DateFormatter().string(from: timestamp)
        return "\(timestampText) \(localizedSummary(language: language))"
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum OperationalHistoryProjection {
    static let allCategories = "All"

    static func availableCategories(events: [RuntimeEvent]) -> [String] {
        [allCategories] + Set(events.map(\.category)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    static func project(
        events: [RuntimeEvent],
        category: String,
        severity: OperationalHistorySeverityFilter
    ) -> [RuntimeEvent] {
        events.filter { event in
            (category == allCategories || event.category == category)
                && severity.includes(event.severity)
        }
    }

    static func copyText(
        events: [RuntimeEvent],
        language: AppLanguage = .english
    ) -> String {
        let strings = AppLocalization(language: language)
        guard !events.isEmpty else {
            return strings.text(
                english: "MLX Server Manager Operational History\nNo events.",
                japanese: "MLX Server Manager 操作履歴\n履歴はありません。"
            )
        }
        let title = strings.text(
            english: "MLX Server Manager Operational History",
            japanese: "MLX Server Manager 操作履歴"
        )
        return ([title] + events.map { $0.copyText(language: language) })
            .joined(separator: "\n")
    }
}
