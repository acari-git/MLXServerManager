import Foundation

extension AppViewModel {
    var canSendMiniChat: Bool {
        !isMiniChatRunning
            && !miniChatPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedModel != nil
            && !runtimeState.isDegraded
    }

    func updateMiniChatViewState(
        _ update: (inout MiniChatViewState) -> Void
    ) {
        var nextState = miniChatViewState
        update(&nextState)
        guard nextState != miniChatViewState else {
            return
        }
        miniChatViewState = nextState
    }

    func applyMiniChatRequestStart(
        prompt: String,
        status: String
    ) {
        updateMiniChatViewState { state in
            state.beginRequest(prompt: prompt, status: status)
        }
    }

    func applyMiniChatRequestCompletion(
        response: String,
        sender: MiniChatTranscriptMessage.Sender,
        status: String,
        httpStatusText: String,
        durationText: String
    ) {
        updateMiniChatViewState { state in
            state.completeRequest(
                response: response,
                sender: sender,
                status: status,
                httpStatusText: httpStatusText,
                durationText: durationText
            )
        }
    }

    private func setMiniChatStatus(_ status: String) {
        updateMiniChatViewState { state in
            state.setStatus(status)
        }
    }

    func sendMiniChatRequested() {
        let prompt = miniChatPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            setMiniChatStatus(
                Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Enter a test message.",
                    japanese: "テストメッセージを入力してください。"
                )
            )
            return
        }
        guard selectedModel != nil else {
            setMiniChatStatus(
                Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Select a model before sending.",
                    japanese: "送信前にモデルを選択してください。"
                )
            )
            return
        }
        guard !runtimeState.isDegraded else {
            let message = Self.localizedText(
                language: settings.uiLanguage,
                english: "The generation worker stopped. Restart the model before sending a test request.",
                japanese: "生成ワーカーが停止しています。モデルを再起動してからテストリクエストを送信してください。"
            )
            setMiniChatStatus(message)
            appendLog("[test-chat] skipped: \(message)")
            return
        }
        guard TestChatService.chatCompletionsURL(from: baseURL) != nil else {
            setMiniChatStatus(
                Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Invalid base URL.",
                    japanese: "Base URLが無効です。"
                )
            )
            return
        }

        let modelID = selectedModelIdentifier
        let targetBaseURL = baseURL
        let service = testChatService
        applyMiniChatRequestStart(
            prompt: prompt,
            status: Self.localizedText(
                language: settings.uiLanguage,
                english: "Sending test request...",
                japanese: "テストリクエストを送信中..."
            )
        )
        appendLog("[test-chat] request started: \(targetBaseURL)/chat/completions model=\(modelID)")

        miniChatRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            do {
                let result = try await service.send(
                    baseURL: targetBaseURL,
                    modelID: modelID,
                    prompt: prompt
                )
                guard self.miniChatRunCoordinator.isCurrent(generation: generation) else {
                    return
                }

                let elapsedMS = result.durationMilliseconds
                let httpStatusText = result.statusCode.map { "HTTP \($0)" } ?? "-"
                let durationText = "\(Int(elapsedMS)) ms"
                if let message = result.apiErrorMessage {
                    applyMiniChatRequestCompletion(
                        response: message,
                        sender: .system,
                        status: Self.localizedText(
                            language: settings.uiLanguage,
                            english: "Request failed.",
                            japanese: "リクエストに失敗しました。"
                        ),
                        httpStatusText: httpStatusText,
                        durationText: durationText
                    )
                    appendLog("[test-chat] failed: \(httpStatusText) \(message)")
                } else {
                    let status: String
                    if let statusCode = result.statusCode, (200..<300).contains(statusCode) {
                        status = Self.localizedText(
                            language: settings.uiLanguage,
                            english: "Response received.",
                            japanese: "応答を受信しました。"
                        )
                    } else {
                        status = Self.localizedText(
                            language: settings.uiLanguage,
                            english: "Response returned non-success status.",
                            japanese: "成功以外のHTTPステータスが返りました。"
                        )
                    }
                    applyMiniChatRequestCompletion(
                        response: result.responseText,
                        sender: .assistant,
                        status: status,
                        httpStatusText: httpStatusText,
                        durationText: durationText
                    )
                    appendLog("[test-chat] response received: \(httpStatusText) in \(Int(elapsedMS)) ms.")
                }
            } catch is CancellationError {
                guard self.miniChatRunCoordinator.isCurrent(generation: generation) else {
                    return
                }
                let status = Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Cancelled.",
                    japanese: "キャンセルしました。"
                )
                updateMiniChatViewState { state in
                    state.cancelRequest(status: status, appendTranscript: true)
                }
                appendLog("[test-chat] cancelled.")
            } catch {
                guard self.miniChatRunCoordinator.isCurrent(generation: generation) else {
                    return
                }
                updateMiniChatViewState { state in
                    state.failRequest(
                        message: error.localizedDescription,
                        status: Self.localizedText(
                            language: self.settings.uiLanguage,
                            english: "Request failed.",
                            japanese: "リクエストに失敗しました。"
                        )
                    )
                }
                appendLog("[test-chat] failed: \(error.localizedDescription)")
            }
        }
    }

    func cancelMiniChatRequested() {
        miniChatRunCoordinator.cancel()
        let status = Self.localizedText(
            language: settings.uiLanguage,
            english: "Cancelled.",
            japanese: "キャンセルしました。"
        )
        updateMiniChatViewState { state in
            state.cancelRequest(status: status, appendTranscript: false)
        }
        appendLog("[test-chat] cancelled by user.")
    }

    func clearMiniChatRequested() {
        updateMiniChatViewState { state in
            state.clearConversation()
        }
    }

    func copyMiniChatResponseRequested() {
        guard !miniChatResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = copyToPasteboard(miniChatResponse)
    }

    func copyMiniChatMessageRequested(_ message: MiniChatTranscriptMessage) {
        guard message.sender == .assistant,
              !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        if copyToPasteboard(message.content) {
            setMiniChatStatus(
                Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Copied response.",
                    japanese: "返答をコピーしました。"
                )
            )
        }
    }
}
