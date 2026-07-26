import Foundation

extension AppViewModel {
    func updateProfileEditorViewState(
        _ update: (inout ProfileFormViewState) -> Void
    ) {
        var nextState = profileEditorViewState
        update(&nextState)
        guard nextState != profileEditorViewState else {
            return
        }
        profileEditorViewState = nextState
    }

    func updateAddProfileViewState(
        _ update: (inout ProfileFormViewState) -> Void
    ) {
        var nextState = addProfileViewState
        update(&nextState)
        guard nextState != addProfileViewState else {
            return
        }
        addProfileViewState = nextState
    }

    func editProfileRequested(for model: ModelConfig) {
        selectedModelID = model.id
        editProfileRequested()
    }

    func editProfileRequested() {
        guard let selectedModel else {
            updateProfileEditorViewState { state in
                state.setMessage(Self.localizedText(
                    language: settings.uiLanguage,
                    english: "No model is selected.",
                    japanese: "モデルが選択されていません。"
                ))
            }
            appendLog("[profile] edit failed: No model is selected.")
            return
        }

        addProfilePortSuggestionEndpointKey = nil
        updateAddProfileViewState { $0.dismiss() }
        profileEditorPortSuggestionEndpointKey = nil
        updateProfileEditorViewState { state in
            state.present(draft: ModelProfileDraft(model: selectedModel))
        }
        appendLog("[profile] editing \(selectedModel.modelID)")
    }

    func duplicateProfileRequested(for model: ModelConfig) {
        profileEditorPortSuggestionEndpointKey = nil
        updateProfileEditorViewState { $0.dismiss() }
        addProfilePortSuggestionEndpointKey = nil

        let usedPorts = Set(models.filter { $0.host == model.host }.map(\.serverPort))
        var suggestedPort = min(model.serverPort + 1, 65_535)
        while usedPorts.contains(suggestedPort), suggestedPort < 65_535 {
            suggestedPort += 1
        }
        let draft = ProfileLibrary.duplicateDraft(from: model, suggestedPort: suggestedPort)
        updateAddProfileViewState { state in
            state.present(draft: draft)
        }
        appendLog("[profile] duplicating \(model.modelID) as a new draft on port \(suggestedPort).")
    }

    func composeProfileRequested(models sourceModels: [ModelConfig], selection: ProfileCompositionSelection) {
        guard let runtime = sourceModels.first(where: { $0.id == selection.runtimeModelID }) else { return }
        profileEditorPortSuggestionEndpointKey = nil
        updateProfileEditorViewState { $0.dismiss() }
        addProfilePortSuggestionEndpointKey = nil

        let usedPorts = Set(models.filter { $0.host == runtime.host }.map(\.serverPort))
        var suggestedPort = min(runtime.serverPort + 1, 65_535)
        while usedPorts.contains(suggestedPort), suggestedPort < 65_535 {
            suggestedPort += 1
        }
        guard let draft = ProfileLibrary.composedDraft(
            models: sourceModels,
            selection: selection,
            suggestedPort: suggestedPort
        ) else { return }
        updateAddProfileViewState { state in
            state.present(draft: draft)
        }
        appendLog("[profile] composed a new draft from \(sourceModels.count) compared profiles on port \(suggestedPort).")
    }

    func cancelProfileEditing() {
        profileEditorPortSuggestionEndpointKey = nil
        updateProfileEditorViewState { $0.dismiss() }
        appendLog("[profile] edit cancelled.")
    }

    func addProfileRequested() {
        profileEditorPortSuggestionEndpointKey = nil
        updateProfileEditorViewState { $0.dismiss() }
        addProfilePortSuggestionEndpointKey = nil

        var draft = ModelProfileDraft.newProfile(
            defaultHost: settings.defaultHost,
            defaultPort: settings.defaultPort
        )
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedPort = normalizedPortSuggestionInput(draft.serverPortText)
        let reservedPorts = reservedPorts(on: host)
        let suggestedPort = availablePortFinder.firstAvailablePort(
            host: host,
            preferredPort: requestedPort,
            reservedPorts: reservedPorts
        )
        let portSuggestionMessage: String
        let suggestionLogLine: String
        if let suggestedPort {
            draft.serverPortText = String(suggestedPort)
            addProfilePortSuggestionEndpointKey = Self.portCheckCacheKey(host: host, port: suggestedPort)
            portSuggestionMessage = availablePortSuggestionMessage(
                requestedPort: requestedPort,
                availablePort: suggestedPort
            )
            suggestionLogLine = "[profile] available port suggestion: \(host):\(suggestedPort)."
        } else {
            let upperBound = min(requestedPort + 99, 65_535)
            addProfilePortSuggestionEndpointKey = Self.portCheckCacheKey(host: host, port: requestedPort)
            portSuggestionMessage = noAvailablePortSuggestionMessage(
                requestedPort: requestedPort,
                upperBound: upperBound
            )
            suggestionLogLine = "[profile] no available port suggestion found for \(host) from \(requestedPort)."
        }

        updateAddProfileViewState { state in
            state.present(
                draft: draft,
                portSuggestionMessage: portSuggestionMessage
            )
        }
        appendLogs([
            suggestionLogLine,
            "[profile] adding new model profile."
        ])
    }

    var profileEditorNoticeMessage: String? {
        profileNoticeMessage(
            host: profileEditorDraft.host,
            includesRunningServerNotice: isProfileEditorRuntimeLocked,
            runningServerEnglish: "Runtime fields are locked while the managed server is running.",
            runningServerJapanese: "管理中サーバーの実行中はランタイム項目を編集できません。"
        )
    }

    var addProfileNoticeMessage: String? {
        profileNoticeMessage(
            host: addProfileDraft.host,
            includesRunningServerNotice: isManagedProcessRunning,
            runningServerEnglish: "Saving a new profile will not change running managed servers.",
            runningServerJapanese: "新規プロファイルを保存しても、実行中の管理サーバーは変更されません。"
        )
    }

    private func profileNoticeMessage(
        host: String,
        includesRunningServerNotice: Bool,
        runningServerEnglish: String,
        runningServerJapanese: String
    ) -> String? {
        var messages: [String] = []
        if includesRunningServerNotice {
            messages.append(Self.localizedText(
                language: settings.uiLanguage,
                english: runningServerEnglish,
                japanese: runningServerJapanese
            ))
        }

        let assessment = NetworkExposureAdvisor.assess(host: host)
        if assessment.requiresExplicitStartConfirmation {
            messages.append(assessment.confirmationDetail(language: settings.uiLanguage))
        }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    func suggestAvailablePortForProfileEditor() {
        guard isProfileEditorPresented, !isProfileEditorRuntimeLocked else { return }

        let host = profileEditorDraft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedPort = normalizedPortSuggestionInput(profileEditorDraft.serverPortText)
        let reservedPorts = reservedPorts(
            on: host,
            excludingModelID: profileEditorDraft.originalModelID
        )
        let suggestedPort = availablePortFinder.firstAvailablePort(
            host: host,
            preferredPort: requestedPort,
            reservedPorts: reservedPorts
        )

        if let suggestedPort {
            profileEditorPortSuggestionEndpointKey = Self.portCheckCacheKey(host: host, port: suggestedPort)
            updateProfileEditorViewState { state in
                state.applyPortSuggestion(
                    portText: String(suggestedPort),
                    message: availablePortSuggestionMessage(
                        requestedPort: requestedPort,
                        availablePort: suggestedPort
                    )
                )
            }
            appendLog("[profile] available port suggestion for edited profile: \(host):\(suggestedPort).")
        } else {
            let upperBound = min(requestedPort + 99, 65_535)
            profileEditorPortSuggestionEndpointKey = Self.portCheckCacheKey(host: host, port: requestedPort)
            updateProfileEditorViewState { state in
                state.applyPortSuggestion(
                    portText: String(requestedPort),
                    message: noAvailablePortSuggestionMessage(
                        requestedPort: requestedPort,
                        upperBound: upperBound
                    )
                )
            }
            appendLog("[profile] no available port suggestion found for edited profile at \(host) from \(requestedPort).")
        }
    }

    func profileEditorEndpointInputChanged() {
        guard let profileEditorPortSuggestionEndpointKey else { return }
        let host = profileEditorDraft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = profileEditorDraft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(portText),
              (1...65_535).contains(port),
              Self.portCheckCacheKey(host: host, port: port) == profileEditorPortSuggestionEndpointKey else {
            clearProfileEditorPortSuggestion()
            return
        }
    }

    private func clearProfileEditorPortSuggestion() {
        profileEditorPortSuggestionEndpointKey = nil
        updateProfileEditorViewState { state in
            state.setPortSuggestionMessage(nil)
        }
    }

    func suggestAvailablePortForAddProfile() {
        let host = addProfileDraft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedPort = normalizedPortSuggestionInput(addProfileDraft.serverPortText)
        let reservedPorts = reservedPorts(on: host)
        let suggestedPort = availablePortFinder.firstAvailablePort(
            host: host,
            preferredPort: requestedPort,
            reservedPorts: reservedPorts
        )

        if let suggestedPort {
            addProfilePortSuggestionEndpointKey = Self.portCheckCacheKey(host: host, port: suggestedPort)
            updateAddProfileViewState { state in
                state.applyPortSuggestion(
                    portText: String(suggestedPort),
                    message: availablePortSuggestionMessage(
                        requestedPort: requestedPort,
                        availablePort: suggestedPort
                    )
                )
            }
            appendLog("[profile] available port suggestion: \(host):\(suggestedPort).")
        } else {
            let upperBound = min(requestedPort + 99, 65_535)
            addProfilePortSuggestionEndpointKey = Self.portCheckCacheKey(host: host, port: requestedPort)
            updateAddProfileViewState { state in
                state.applyPortSuggestion(
                    portText: String(requestedPort),
                    message: noAvailablePortSuggestionMessage(
                        requestedPort: requestedPort,
                        upperBound: upperBound
                    )
                )
            }
            appendLog("[profile] no available port suggestion found for \(host) from \(requestedPort).")
        }
    }

    func addProfileEndpointInputChanged() {
        guard let addProfilePortSuggestionEndpointKey else { return }
        let host = addProfileDraft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = addProfileDraft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(portText),
              (1...65_535).contains(port),
              Self.portCheckCacheKey(host: host, port: port) == addProfilePortSuggestionEndpointKey else {
            clearAddProfilePortSuggestion()
            return
        }
    }

    private func clearAddProfilePortSuggestion() {
        addProfilePortSuggestionEndpointKey = nil
        updateAddProfileViewState { state in
            state.setPortSuggestionMessage(nil)
        }
    }

    private func normalizedPortSuggestionInput(_ portText: String) -> Int {
        let parsedPort = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines))
        return parsedPort.flatMap { (1...65_535).contains($0) ? $0 : nil }
            ?? min(max(settings.defaultPort, 1), 65_535)
    }

    private func reservedPorts(
        on host: String,
        excludingModelID: ModelConfig.ID? = nil
    ) -> Set<Int> {
        Set(models.compactMap { model in
            guard model.id != excludingModelID,
                  EndpointHostMatcher.conflicts(model.host, host) else {
                return nil
            }
            return model.serverPort
        })
    }

    private func availablePortSuggestionMessage(
        requestedPort: Int,
        availablePort: Int
    ) -> String {
        if availablePort == requestedPort {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Port \(availablePort) is available.",
                japanese: "ポート\(availablePort)は利用可能です。"
            )
        }
        return Self.localizedText(
            language: settings.uiLanguage,
            english: "Port \(availablePort) was selected because earlier ports are assigned or in use.",
            japanese: "手前のポートが割り当て済みまたは使用中のため、ポート\(availablePort)を選択しました。"
        )
    }

    private func noAvailablePortSuggestionMessage(
        requestedPort: Int,
        upperBound: Int
    ) -> String {
        Self.localizedText(
            language: settings.uiLanguage,
            english: "No available port was found from \(requestedPort) through \(upperBound). You can enter another port manually.",
            japanese: "\(requestedPort)〜\(upperBound)で利用可能なポートが見つかりませんでした。別のポートを手動で入力できます。"
        )
    }
}
