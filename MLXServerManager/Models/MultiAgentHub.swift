import Foundation

nonisolated enum AgentProvider: String, Codable, CaseIterable, Identifiable {
    case hermes
    case codex
    case local

    var id: String { rawValue }
}

nonisolated enum AgentRole: String, Codable, CaseIterable, Identifiable {
    case coordinator
    case coding
    case review
    case research
    case general

    var id: String { rawValue }
}

nonisolated struct AgentAssignment: Codable, Equatable, Identifiable {
    let id: UUID
    var provider: AgentProvider
    var role: AgentRole
    var profileID: String?
    var notes: String
    var isEnabled: Bool

    init(id: UUID = UUID(), provider: AgentProvider, role: AgentRole, profileID: String? = nil, notes: String = "", isEnabled: Bool = true) {
        self.id = id
        self.provider = provider
        self.role = role
        self.profileID = profileID
        self.notes = notes
        self.isEnabled = isEnabled
    }
}

nonisolated struct AgentActivitySummary: Equatable, Identifiable {
    let provider: AgentProvider
    let sessionCount: Int
    let activeSessionCount: Int
    let messageCount: Int
    let toolCallCount: Int
    let totalTokens: Int
    let models: [String]
    let workspaces: [String]

    var id: String { provider.rawValue }

    static func hermes(sessions: [HermesAgentSessionSummary]) -> AgentActivitySummary {
        let now = Date().timeIntervalSince1970
        return AgentActivitySummary(
            provider: .hermes,
            sessionCount: sessions.count,
            activeSessionCount: sessions.filter { $0.endedAt == nil || now - ($0.endedAt ?? $0.startedAt) < 900 }.count,
            messageCount: sessions.reduce(0) { $0 + $1.messageCount },
            toolCallCount: sessions.reduce(0) { $0 + $1.toolCallCount },
            totalTokens: sessions.reduce(0) { $0 + $1.inputTokens + $1.outputTokens + $1.reasoningTokens },
            models: Array(Set(sessions.compactMap(\.model))).sorted(),
            workspaces: Array(Set(sessions.compactMap(\.cwd))).sorted()
        )
    }
}

nonisolated enum AgentAssignmentStore {
    static let defaultsKey = "multi-agent-assignments-v1"

    static func load(defaults: UserDefaults = .standard) -> [AgentAssignment] {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode([AgentAssignment].self, from: data) else { return defaultsValue }
        return value
    }

    static func save(_ assignments: [AgentAssignment], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(assignments) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static let defaultsValue: [AgentAssignment] = [
        AgentAssignment(provider: .hermes, role: .coordinator),
        AgentAssignment(provider: .codex, role: .coding, isEnabled: false),
        AgentAssignment(provider: .local, role: .review, isEnabled: false)
    ]
}
