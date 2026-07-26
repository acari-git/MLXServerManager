import Foundation

nonisolated enum WorkspaceSortOrder: String, CaseIterable, Identifiable {
    case recent
    case name
    case sessionCount

    var id: String { rawValue }
}

nonisolated enum WorkspaceExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case csv

    var id: String { rawValue }
    var fileExtension: String { self == .markdown ? "md" : "csv" }
}

nonisolated struct WorkspaceGroup: Identifiable, Equatable {
    let path: String
    let sessions: [HermesAgentSessionSummary]

    var id: String { path }
    var displayName: String {
        let lastPathComponent = URL(fileURLWithPath: path).lastPathComponent
        return lastPathComponent.isEmpty ? path : lastPathComponent
    }
    var latestStartedAt: Double { sessions.map(\.startedAt).max() ?? 0 }
    var messageCount: Int { sessions.reduce(0) { $0 + $1.messageCount } }
    var toolCallCount: Int { sessions.reduce(0) { $0 + $1.toolCallCount } }
    var hasRunningSession: Bool { sessions.contains { $0.endedAt == nil } }
    var totalTokens: Int {
        sessions.reduce(0) {
            $0 + $1.inputTokens + $1.outputTokens + $1.cacheReadTokens + $1.cacheWriteTokens + $1.reasoningTokens
        }
    }
    var averageMessagesPerSession: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(messageCount) / Double(sessions.count)
    }
    var averageTokensPerSession: Int {
        guard !sessions.isEmpty else { return 0 }
        return totalTokens / sessions.count
    }
    var activityDayCount: Int {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0.startedAt)) }).count
    }
    var activityPeriodText: String {
        guard let first = sessions.map(\.startedAt).min(), let last = sessions.map(\.startedAt).max() else { return "-" }
        let firstText = Date(timeIntervalSince1970: first).formatted(date: .abbreviated, time: .omitted)
        let lastText = Date(timeIntervalSince1970: last).formatted(date: .abbreviated, time: .omitted)
        return firstText == lastText ? firstText : "\(firstText) – \(lastText)"
    }
    var modelUsage: [(model: String, count: Int)] {
        Dictionary(grouping: sessions.compactMap(\.model), by: { $0 })
            .map { (model: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.model.localizedCaseInsensitiveCompare($1.model) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }
}

nonisolated enum WorkspaceAnalytics {
    static func groups(
        from sessions: [HermesAgentSessionSummary],
        unknownWorkspaceName: String,
        searchText: String,
        runningOnly: Bool,
        sortOrder: WorkspaceSortOrder
    ) -> [WorkspaceGroup] {
        let grouped = Dictionary(grouping: sessions) { session in
            let path = session.cwd?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return path.isEmpty ? unknownWorkspaceName : path
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = grouped.map { path, groupedSessions in
            WorkspaceGroup(path: path, sessions: groupedSessions.sorted { $0.startedAt > $1.startedAt })
        }
        .filter { group in
            if runningOnly && !group.hasRunningSession { return false }
            guard !query.isEmpty else { return true }
            let searchable = [
                group.path,
                group.displayName,
                group.sessions.compactMap(\.title).joined(separator: "\n"),
                group.sessions.compactMap(\.model).joined(separator: "\n")
            ].joined(separator: "\n")
            return searchable.localizedCaseInsensitiveContains(query)
        }

        switch sortOrder {
        case .recent:
            return groups.sorted { $0.latestStartedAt > $1.latestStartedAt }
        case .name:
            return groups.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .sessionCount:
            return groups.sorted {
                if $0.sessions.count == $1.sessions.count {
                    return $0.latestStartedAt > $1.latestStartedAt
                }
                return $0.sessions.count > $1.sessions.count
            }
        }
    }

    static func markdown(for group: WorkspaceGroup) -> String {
        let modelRows = group.modelUsage.isEmpty
            ? "- No model data"
            : group.modelUsage.map { "- \($0.model): \($0.count) session(s)" }.joined(separator: "\n")
        let sessionRows = group.sessions.map { session in
            let title = session.title?.isEmpty == false ? session.title! : session.id
            let status = session.endedAt == nil ? "Running" : "Completed"
            let started = Date(timeIntervalSince1970: session.startedAt).formatted(date: .abbreviated, time: .standard)
            return "| \(escapeMarkdown(title)) | \(session.model ?? "-") | \(status) | \(session.messageCount) | \(session.toolCallCount) | \(sessionTotalTokens(session)) | \(started) |"
        }.joined(separator: "\n")
        return """
        # Workspace Analysis

        - Workspace: \(group.displayName)
        - Path: \(group.path)
        - Sessions: \(group.sessions.count)
        - Messages: \(group.messageCount)
        - Tool calls: \(group.toolCallCount)
        - Total tokens: \(group.totalTokens)
        - Average messages per session: \(String(format: "%.1f", group.averageMessagesPerSession))
        - Average tokens per session: \(group.averageTokensPerSession)
        - Active days: \(group.activityDayCount)
        - Activity period: \(group.activityPeriodText)

        ## Model Usage

        \(modelRows)

        ## Sessions

        | Session | Model | Status | Messages | Tool Calls | Tokens | Started |
        |---|---|---:|---:|---:|---:|---|
        \(sessionRows)
        """
    }

    static func csv(for group: WorkspaceGroup) -> String {
        var rows = [["workspace", "path", "session_id", "title", "model", "source", "status", "messages", "tool_calls", "input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens", "reasoning_tokens", "total_tokens", "started_at", "ended_at"]]
        rows.append(contentsOf: group.sessions.map { session in
            [group.displayName, group.path, session.id, session.title ?? "", session.model ?? "", session.source,
             session.endedAt == nil ? "running" : "completed", String(session.messageCount), String(session.toolCallCount),
             String(session.inputTokens), String(session.outputTokens), String(session.cacheReadTokens), String(session.cacheWriteTokens),
             String(session.reasoningTokens), String(sessionTotalTokens(session)), Date(timeIntervalSince1970: session.startedAt).ISO8601Format(),
             session.endedAt.map { Date(timeIntervalSince1970: $0).ISO8601Format() } ?? ""]
        })
        return rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    static func sanitizedFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let result = value.components(separatedBy: invalid).filter { !$0.isEmpty }.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "workspace" : result
    }

    private static func sessionTotalTokens(_ session: HermesAgentSessionSummary) -> Int {
        session.inputTokens + session.outputTokens + session.cacheReadTokens + session.cacheWriteTokens + session.reasoningTokens
    }
    private static func csvField(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
    private static func escapeMarkdown(_ value: String) -> String { value.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ") }
}
