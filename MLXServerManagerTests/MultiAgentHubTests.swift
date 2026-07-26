import XCTest
@testable import MLXServerManager

final class MultiAgentHubTests: XCTestCase {
    func testDefaultAssignmentsCoverHermesCodexAndLocalAgents() {
        let providers = Set(AgentAssignmentStore.defaultsValue.map(\.provider))
        XCTAssertEqual(providers, Set(AgentProvider.allCases))
        XCTAssertTrue(AgentAssignmentStore.defaultsValue.first { $0.provider == .hermes }?.isEnabled == true)
    }

    func testAssignmentsPersist() {
        let suiteName = "MultiAgentHubTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let values = [AgentAssignment(provider: .codex, role: .coding, profileID: "model-a", notes: "Swift", isEnabled: true)]
        AgentAssignmentStore.save(values, defaults: defaults)
        XCTAssertEqual(AgentAssignmentStore.load(defaults: defaults), values)
    }

    func testHermesActivityAggregatesSessions() {
        let sessions = [
            session(id: "1", model: "model-a", cwd: "/workspace/a", messages: 4, tools: 2, input: 100, output: 50, reasoning: 20),
            session(id: "2", model: "model-b", cwd: "/workspace/a", messages: 6, tools: 3, input: 200, output: 80, reasoning: 30)
        ]
        let summary = AgentActivitySummary.hermes(sessions: sessions)
        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.messageCount, 10)
        XCTAssertEqual(summary.toolCallCount, 5)
        XCTAssertEqual(summary.totalTokens, 480)
        XCTAssertEqual(summary.models, ["model-a", "model-b"])
        XCTAssertEqual(summary.workspaces, ["/workspace/a"])
    }

    private func session(
        id: String,
        model: String,
        cwd: String,
        messages: Int,
        tools: Int,
        input: Int,
        output: Int,
        reasoning: Int
    ) -> HermesAgentSessionSummary {
        HermesAgentSessionSummary(
            id: id,
            title: nil,
            source: "cli",
            model: model,
            startedAt: Date().timeIntervalSince1970,
            endedAt: nil,
            messageCount: messages,
            toolCallCount: tools,
            inputTokens: input,
            outputTokens: output,
            cacheReadTokens: 0,
            cacheWriteTokens: 0,
            reasoningTokens: reasoning,
            cwd: cwd,
            endReason: nil,
            archived: 0
        )
    }
}
