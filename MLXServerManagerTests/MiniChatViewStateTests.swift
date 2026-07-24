import XCTest
@testable import MLXServerManager

final class MiniChatViewStateTests: XCTestCase {
    func testBeginRequestResetsTransientFieldsAndAppendsUserMessage() {
        var state = MiniChatViewState.ready
        state.beginRequest(prompt: "first", status: "Sending")
        state.completeRequest(
            response: "old response",
            sender: .assistant,
            status: "Received",
            httpStatusText: "HTTP 200",
            durationText: "10 ms"
        )
        state.setPrompt("draft")

        state.beginRequest(prompt: "second", status: "Sending again")

        XCTAssertEqual(state.prompt, "")
        XCTAssertEqual(state.messages.map(\.content), ["first", "old response", "second"])
        XCTAssertEqual(state.messages.last?.sender, .user)
        XCTAssertEqual(state.response, "")
        XCTAssertEqual(state.status, "Sending again")
        XCTAssertEqual(state.httpStatusText, "-")
        XCTAssertEqual(state.durationText, "-")
        XCTAssertTrue(state.isRunning)
    }

    func testCompleteRequestPublishesResponseMetadataAndTranscriptTogether() {
        var state = MiniChatViewState.ready
        state.beginRequest(prompt: "hello", status: "Sending")

        state.completeRequest(
            response: "world",
            sender: .assistant,
            status: "Received",
            httpStatusText: "HTTP 200",
            durationText: "15 ms"
        )

        XCTAssertEqual(state.messages.map(\.content), ["hello", "world"])
        XCTAssertEqual(state.messages.last?.sender, .assistant)
        XCTAssertEqual(state.response, "world")
        XCTAssertEqual(state.status, "Received")
        XCTAssertEqual(state.httpStatusText, "HTTP 200")
        XCTAssertEqual(state.durationText, "15 ms")
        XCTAssertFalse(state.isRunning)
    }

    func testFailureAndCancellationUseSystemTranscriptWithoutPartialRunningState() {
        var failedState = MiniChatViewState.ready
        failedState.beginRequest(prompt: "hello", status: "Sending")
        failedState.failRequest(message: "offline", status: "Failed")

        XCTAssertEqual(failedState.messages.map(\.content), ["hello", "offline"])
        XCTAssertEqual(failedState.messages.last?.sender, .system)
        XCTAssertEqual(failedState.response, "offline")
        XCTAssertEqual(failedState.status, "Failed")
        XCTAssertEqual(failedState.httpStatusText, "-")
        XCTAssertEqual(failedState.durationText, "-")
        XCTAssertFalse(failedState.isRunning)

        var cancelledState = MiniChatViewState.ready
        cancelledState.beginRequest(prompt: "hello", status: "Sending")
        cancelledState.cancelRequest(status: "Cancelled", appendTranscript: true)

        XCTAssertEqual(cancelledState.messages.map(\.content), ["hello", "Cancelled"])
        XCTAssertEqual(cancelledState.messages.last?.sender, .system)
        XCTAssertEqual(cancelledState.status, "Cancelled")
        XCTAssertFalse(cancelledState.isRunning)
    }

    func testClearConversationPreservesActiveRequestFlag() {
        var state = MiniChatViewState.ready
        state.beginRequest(prompt: "hello", status: "Sending")

        state.clearConversation()

        XCTAssertEqual(state.prompt, "")
        XCTAssertTrue(state.messages.isEmpty)
        XCTAssertEqual(state.response, "")
        XCTAssertEqual(state.status, "Ready.")
        XCTAssertEqual(state.httpStatusText, "-")
        XCTAssertEqual(state.durationText, "-")
        XCTAssertTrue(state.isRunning)
    }
}

@MainActor
final class MiniChatConcurrencyTests: XCTestCase {
    func testStaleCancelledRequestCannotOverwriteReplacementResponse() async throws {
        let responder = ControlledMiniChatResponder()
        let service = TestChatService { _, _, prompt in
            await responder.send(prompt: prompt)
        }
        let store = SettingsStore(appDirectoryName: "MLXServerManagerMiniChatConcurrencyTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(
            settingsStore: store,
            testChatService: service
        )

        viewModel.miniChatPrompt = "first"
        viewModel.sendMiniChatRequested()
        await waitForPending(prompt: "first", responder: responder)

        viewModel.miniChatPrompt = "second"
        viewModel.sendMiniChatRequested()
        await waitForPending(prompt: "second", responder: responder)

        await responder.resume(
            prompt: "second",
            result: TestChatServiceResult(
                responseText: "second response",
                apiErrorMessage: nil,
                statusCode: 200,
                durationMilliseconds: 20
            )
        )
        await waitUntil {
            viewModel.miniChatResponse == "second response"
                && !viewModel.isMiniChatRunning
        }

        await responder.resume(
            prompt: "first",
            result: TestChatServiceResult(
                responseText: "stale first response",
                apiErrorMessage: nil,
                statusCode: 200,
                durationMilliseconds: 100
            )
        )
        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.miniChatResponse, "second response")
        XCTAssertEqual(viewModel.miniChatMessages.map(\.content), ["first", "second", "second response"])
        XCTAssertEqual(viewModel.miniChatHTTPStatusText, "HTTP 200")
        XCTAssertEqual(viewModel.miniChatDurationText, "20 ms")
        XCTAssertFalse(viewModel.isMiniChatRunning)
    }

    private func waitForPending(
        prompt: String,
        responder: ControlledMiniChatResponder
    ) async {
        await waitUntil {
            await responder.hasPending(prompt: prompt)
        }
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0..<200 {
            if await condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Condition was not met before timeout.")
    }
}

private actor ControlledMiniChatResponder {
    private var pending: [String: CheckedContinuation<TestChatServiceResult, Never>] = [:]

    func send(prompt: String) async -> TestChatServiceResult {
        await withCheckedContinuation { continuation in
            pending[prompt] = continuation
        }
    }

    func hasPending(prompt: String) -> Bool {
        pending[prompt] != nil
    }

    func resume(
        prompt: String,
        result: TestChatServiceResult
    ) {
        pending.removeValue(forKey: prompt)?.resume(returning: result)
    }
}
