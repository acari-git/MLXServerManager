import XCTest
@testable import MLXServerManager

final class WorkspaceAnalyticsTests: XCTestCase {
    func testGroupsSearchFilterAndSortSessions() {
        let sessions = [
            makeSession(id: "a1", title: "Alpha task", model: "model-b", startedAt: 100, endedAt: nil, messages: 4, cwd: "/tmp/Alpha"),
            makeSession(id: "a2", title: "Older", model: "model-a", startedAt: 50, endedAt: 60, messages: 2, cwd: "/tmp/Alpha"),
            makeSession(id: "b1", title: "Beta task", model: "model-c", startedAt: 200, endedAt: 210, messages: 8, cwd: "/tmp/Beta")
        ]

        let running = WorkspaceAnalytics.groups(from: sessions, unknownWorkspaceName: "Unknown", searchText: "", runningOnly: true, sortOrder: .recent)
        XCTAssertEqual(running.map(\.displayName), ["Alpha"])
        XCTAssertEqual(running[0].sessions.map(\.id), ["a1", "a2"])

        let searched = WorkspaceAnalytics.groups(from: sessions, unknownWorkspaceName: "Unknown", searchText: "model-c", runningOnly: false, sortOrder: .name)
        XCTAssertEqual(searched.map(\.displayName), ["Beta"])

        let counted = WorkspaceAnalytics.groups(from: sessions, unknownWorkspaceName: "Unknown", searchText: "", runningOnly: false, sortOrder: .sessionCount)
        XCTAssertEqual(counted.map(\.displayName), ["Alpha", "Beta"])
    }

    func testGroupAnalyticsTotalsAndModelUsage() {
        let group = WorkspaceGroup(path: "/tmp/Project", sessions: [
            makeSession(id: "1", model: "model-b", startedAt: 0, endedAt: 1, messages: 2, input: 10, output: 20, cacheRead: 3, cacheWrite: 4, reasoning: 5, cwd: "/tmp/Project"),
            makeSession(id: "2", model: "model-a", startedAt: 86_400, endedAt: nil, messages: 4, input: 5, output: 6, cacheRead: 1, cacheWrite: 2, reasoning: 3, cwd: "/tmp/Project"),
            makeSession(id: "3", model: "model-b", startedAt: 86_500, endedAt: 86_600, messages: 6, input: 1, output: 2, cwd: "/tmp/Project")
        ])

        XCTAssertEqual(group.messageCount, 12)
        XCTAssertEqual(group.totalTokens, 62)
        XCTAssertEqual(group.averageMessagesPerSession, 4)
        XCTAssertEqual(group.averageTokensPerSession, 20)
        XCTAssertEqual(group.activityDayCount, 2)
        XCTAssertTrue(group.hasRunningSession)
        XCTAssertEqual(group.modelUsage.map(\.model), ["model-b", "model-a"])
        XCTAssertEqual(group.modelUsage.map(\.count), [2, 1])
    }

    func testExportsEscapeStructuredValues() {
        let group = WorkspaceGroup(path: "/tmp/Project", sessions: [
            makeSession(id: "id,1", title: "Title | \"quoted\"", model: "model-a", startedAt: 100, endedAt: nil, messages: 1, input: 2, output: 3, cwd: "/tmp/Project")
        ])

        let markdown = WorkspaceAnalytics.markdown(for: group)
        XCTAssertTrue(markdown.contains("Title \\| \"quoted\""))
        XCTAssertTrue(markdown.contains("| Running | 1 |"))

        let csv = WorkspaceAnalytics.csv(for: group)
        XCTAssertTrue(csv.contains("\"id,1\""))
        XCTAssertTrue(csv.contains("\"Title | \"\"quoted\"\"\""))
        XCTAssertTrue(csv.hasSuffix("\n"))
    }

    func testSanitizedFileNameRemovesUnsafeCharacters() {
        XCTAssertEqual(WorkspaceAnalytics.sanitizedFileName("Project/A:B"), "Project-A-B")
        XCTAssertEqual(WorkspaceAnalytics.sanitizedFileName("/:?"), "workspace")
    }

    private func makeSession(
        id: String,
        title: String? = nil,
        model: String? = nil,
        startedAt: Double,
        endedAt: Double?,
        messages: Int,
        input: Int = 0,
        output: Int = 0,
        cacheRead: Int = 0,
        cacheWrite: Int = 0,
        reasoning: Int = 0,
        cwd: String?
    ) -> HermesAgentSessionSummary {
        HermesAgentSessionSummary(
            id: id,
            title: title,
            source: "cli",
            model: model,
            startedAt: startedAt,
            endedAt: endedAt,
            messageCount: messages,
            toolCallCount: 1,
            inputTokens: input,
            outputTokens: output,
            cacheReadTokens: cacheRead,
            cacheWriteTokens: cacheWrite,
            reasoningTokens: reasoning,
            cwd: cwd,
            endReason: nil,
            archived: 0
        )
    }
}
