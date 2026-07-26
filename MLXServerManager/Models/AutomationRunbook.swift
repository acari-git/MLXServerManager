import Foundation

nonisolated enum AutomationStepKind: String, Codable, CaseIterable, Identifiable {
    case diagnostics
    case hermesInspection
    case openDiagnostics
    case openSettings

    var id: String { rawValue }
}

nonisolated struct AutomationRunbook: Codable, Equatable, Identifiable {
    let id: String
    var isEnabled: Bool
    let nameKey: String
    let descriptionKey: String
    let steps: [AutomationStepKind]

    static let defaults: [AutomationRunbook] = [
        AutomationRunbook(
            id: "readiness-audit",
            isEnabled: true,
            nameKey: "readinessAudit",
            descriptionKey: "readinessAuditDescription",
            steps: [.diagnostics, .hermesInspection]
        ),
        AutomationRunbook(
            id: "diagnostics-check",
            isEnabled: true,
            nameKey: "diagnosticsCheck",
            descriptionKey: "diagnosticsCheckDescription",
            steps: [.diagnostics, .openDiagnostics]
        ),
        AutomationRunbook(
            id: "hermes-audit",
            isEnabled: true,
            nameKey: "hermesAudit",
            descriptionKey: "hermesAuditDescription",
            steps: [.hermesInspection, .openSettings]
        )
    ]
}

nonisolated enum AutomationRunStatus: String, Codable, Equatable {
    case succeeded
    case completedWithAttention
    case cancelled
}

nonisolated struct AutomationRunRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let runbookID: String
    let runbookName: String
    let targetName: String
    let startedAt: Date
    let completedAt: Date
    let status: AutomationRunStatus
    let completedSteps: [AutomationStepKind]
    let summary: String

    init(
        id: UUID = UUID(),
        runbookID: String,
        runbookName: String,
        targetName: String,
        startedAt: Date,
        completedAt: Date = Date(),
        status: AutomationRunStatus,
        completedSteps: [AutomationStepKind],
        summary: String
    ) {
        self.id = id
        self.runbookID = runbookID
        self.runbookName = runbookName
        self.targetName = targetName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.completedSteps = completedSteps
        self.summary = summary
    }
}

nonisolated enum AutomationStore {
    static let runbooksKey = "automation-runbooks-v1"
    static let historyKey = "automation-history-v1"
    static let maximumHistory = 50

    static func loadRunbooks(defaults: UserDefaults = .standard) -> [AutomationRunbook] {
        guard let data = defaults.data(forKey: runbooksKey),
              let decoded = try? JSONDecoder().decode([AutomationRunbook].self, from: data) else {
            return AutomationRunbook.defaults
        }
        let existing = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        return AutomationRunbook.defaults.map { existing[$0.id] ?? $0 }
    }

    static func saveRunbooks(_ runbooks: [AutomationRunbook], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(runbooks) else { return }
        defaults.set(data, forKey: runbooksKey)
    }

    static func loadHistory(defaults: UserDefaults = .standard) -> [AutomationRunRecord] {
        guard let data = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([AutomationRunRecord].self, from: data) else { return [] }
        return decoded.sorted { $0.startedAt > $1.startedAt }
    }

    static func record(
        _ record: AutomationRunRecord,
        history: [AutomationRunRecord],
        defaults: UserDefaults = .standard
    ) -> [AutomationRunRecord] {
        let next = Array(([record] + history).prefix(maximumHistory))
        if let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: historyKey)
        }
        return next
    }

    static func clearHistory(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: historyKey)
    }
}
