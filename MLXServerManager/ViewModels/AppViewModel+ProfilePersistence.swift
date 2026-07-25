import Foundation

extension AppViewModel {
    func cancelAddProfile() {
        addProfilePortSuggestionEndpointKey = nil
        updateAddProfileViewState { $0.dismiss() }
        appendLog("[profile] add cancelled.")
    }

    @discardableResult
    func saveNewProfile() -> Bool {
        guard isAddProfilePresented else {
            return false
        }

        switch modelProfileValidator.validateNewProfile(addProfileDraft, existingModels: models) {
        case let .valid(newModel):
            let nextModels = models + [newModel]

            do {
                let outcome = try settingsStore.save(models: nextModels)
                invalidateModelSizeCache(for: newModel)
                invalidatePortCheckCache()
                models = nextModels
                addProfilePortSuggestionEndpointKey = nil
                updateAddProfileViewState { $0.dismiss() }

                selectedModelID = newModel.id
                appendLog("[profile] added and selected \(newModel.modelID). Existing managed servers were not changed.")
                appendRuntimeEvent(
                    category: "Profile",
                    severity: .success,
                    message: "Profile added and selected. Existing managed servers were not changed.",
                    japaneseMessage: "プロファイルを追加して選択しました。既存の管理サーバーは変更していません。",
                    modelID: newModel.modelID,
                    endpoint: "\(newModel.host):\(newModel.serverPort)"
                )
                appendSettingsSaveWarnings(outcome)
                return true
            } catch {
                updateAddProfileViewState { state in
                    state.setMessage(error.localizedDescription)
                }
                appendLog("[profile] add failed: \(error.localizedDescription)")
                return false
            }
        case let .invalid(message):
            updateAddProfileViewState { state in
                state.setMessage(message)
            }
            appendLog("[profile] add failed: \(message)")
            return false
        }
    }

    func deleteProfileRequested(for model: ModelConfig) {
        selectedModelID = model.id
        deleteProfileRequested()
    }

    func deleteProfileRequested() {
        guard let selectedModel else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "No model is selected.", japanese: "モデルが選択されていません。")
            profileDeletionMessage = message
            appendLog("[profile] delete failed: No model is selected.")
            return
        }

        guard models.count > 1 else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "At least one model profile is required.", japanese: "少なくとも1件のモデルプロファイルが必要です。")
            profileDeletionMessage = message
            appendLog("[profile] delete failed: At least one model profile is required.")
            return
        }

        guard !isModelRunning(selectedModel) else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "Stop this model before deleting its profile.", japanese: "このモデルを停止してからプロファイルを削除してください。")
            profileDeletionMessage = message
            appendLog("[profile] delete failed: Stop this model before deleting its profile.")
            return
        }

        pendingDeleteModelID = selectedModel.id
        profileDeletionMessage = nil
        isDeleteProfileConfirmationPresented = true
        appendLog("[profile] delete confirmation requested for \(selectedModel.modelID).")
    }

    func cancelDeleteProfile() {
        pendingDeleteModelID = nil
        isDeleteProfileConfirmationPresented = false
        appendLog("[profile] delete cancelled.")
    }

    func confirmDeleteProfile(deleteHuggingFaceCache: Bool = false) {
        guard let pendingDeleteModelID else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "No model profile is pending deletion.", japanese: "削除待ちのモデルプロファイルはありません。")
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: No model profile is pending deletion.")
            return
        }

        guard models.count > 1 else {
            let message = "At least one model profile is required."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard !serverLifecycleCoordinator.isRunning(pendingDeleteModelID) else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "Stop this model before deleting its profile.", japanese: "このモデルを停止してからプロファイルを削除してください。")
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        guard let index = models.firstIndex(where: { $0.id == pendingDeleteModelID }) else {
            let message = "Selected model profile no longer exists."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        let deletedModel = models[index]
        let previousSelectedModelID = selectedModelID
        let previousAutoUnloadEnabled = settings.autoUnloadEnabledByModelID[deletedModel.id]
        let previousAutoUnloadMinutes = settings.autoUnloadMinutesByModelID[deletedModel.id]
        var nextModels = models
        nextModels.remove(at: index)

        guard let fallbackModel = nextModels.first else {
            let message = "At least one model profile is required."
            profileDeletionMessage = message
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(message)")
            return
        }

        var nextSettings = settings
        nextSettings.autoUnloadEnabledByModelID.removeValue(forKey: deletedModel.id)
        nextSettings.autoUnloadMinutesByModelID.removeValue(forKey: deletedModel.id)

        do {
            let outcome = try settingsStore.save(settings: nextSettings, models: nextModels)
            invalidateModelSizeCache(for: deletedModel)
            invalidatePortCheckCache()
            settings = nextSettings
            autoUnloadEnabledByModelID = nextSettings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = nextSettings.autoUnloadMinutesByModelID
            models = nextModels

            let shouldSelectFallback = selectedModelID == deletedModel.id
                || selectedModelID.map { selectedID in
                    !nextModels.contains { $0.id == selectedID }
                } ?? true

            if shouldSelectFallback {
                selectedModelID = fallbackModel.id
                appendLog("[profile] deleted \(deletedModel.modelID) from models.json.")
                appendLog("[profile] selected fallback profile \(fallbackModel.modelID).")
            } else {
                appendLog("[profile] deleted \(deletedModel.modelID) from models.json.")
            }

            profileEditorPortSuggestionEndpointKey = nil
            updateProfileEditorViewState { $0.dismiss() }
            addProfilePortSuggestionEndpointKey = nil
            updateAddProfileViewState { $0.dismiss() }

            if deleteHuggingFaceCache {
                clearProfileDeletionUndo()
                beginHuggingFaceCacheDeletionIfAvailable(for: deletedModel)
            } else {
                profileDeletionMessage = nil
                presentProfileDeletionUndo(
                    model: deletedModel,
                    originalIndex: index,
                    previousSelectedModelID: previousSelectedModelID,
                    autoUnloadEnabled: previousAutoUnloadEnabled,
                    autoUnloadMinutes: previousAutoUnloadMinutes
                )
            }

            self.pendingDeleteModelID = nil
            isDeleteProfileConfirmationPresented = false
            appendRuntimeEvent(
                category: "Profile",
                severity: .success,
                message: deleteHuggingFaceCache
                    ? "Profile deleted and matching Hugging Face cache deletion requested."
                    : "Profile deleted. Undo is temporarily available.",
                japaneseMessage: deleteHuggingFaceCache
                    ? "プロファイルを削除し、一致するHugging Faceキャッシュの削除を要求しました。"
                    : "プロファイルを削除しました。一時的に元へ戻せます。",
                modelID: deletedModel.modelID,
                endpoint: "\(deletedModel.host):\(deletedModel.serverPort)"
            )
            appendSettingsSaveWarnings(outcome)
        } catch {
            profileDeletionMessage = error.localizedDescription
            self.pendingDeleteModelID = nil
            isDeleteProfileConfirmationPresented = false
            appendLog("[profile] delete failed: \(error.localizedDescription)")
        }
    }

    func undoProfileDeletionRequested() {
        guard let payload = profileDeletionUndoPayload else {
            return
        }

        guard !models.contains(where: { $0.id == payload.model.id }) else {
            profileDeletionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "The deleted profile could not be restored because a profile with the same identity already exists.",
                japanese: "同じ識別子のプロファイルがすでに存在するため、削除したプロファイルを復元できませんでした。"
            )
            appendLog("[profile] undo delete failed: profile identity already exists.")
            clearProfileDeletionUndo()
            return
        }

        var restoredModels = models
        restoredModels.insert(payload.model, at: min(max(payload.originalIndex, 0), restoredModels.count))

        var restoredSettings = settings
        if let enabled = payload.autoUnloadEnabled {
            restoredSettings.autoUnloadEnabledByModelID[payload.model.id] = enabled
        }
        if let minutes = payload.autoUnloadMinutes {
            restoredSettings.autoUnloadMinutesByModelID[payload.model.id] = minutes
        }

        do {
            let outcome = try settingsStore.save(settings: restoredSettings, models: restoredModels)
            settings = restoredSettings
            autoUnloadEnabledByModelID = restoredSettings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = restoredSettings.autoUnloadMinutesByModelID
            models = restoredModels
            selectedModelID = payload.previousSelectedModelID.flatMap { previousID in
                restoredModels.contains(where: { $0.id == previousID }) ? previousID : nil
            } ?? payload.model.id
            invalidateModelSizeCache(for: payload.model)
            invalidatePortCheckCache()
            profileDeletionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Restored \(payload.model.displayName).",
                japanese: "\(payload.model.displayName)を復元しました。"
            )
            appendLog("[profile] restored deleted profile \(payload.model.modelID).")
            appendRuntimeEvent(
                category: "Profile",
                severity: .success,
                message: "Deleted profile restored.",
                japaneseMessage: "削除したプロファイルを復元しました。",
                modelID: payload.model.modelID,
                endpoint: "\(payload.model.host):\(payload.model.serverPort)"
            )
            clearProfileDeletionUndo()
            appendSettingsSaveWarnings(outcome)
        } catch {
            profileDeletionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not restore the deleted profile: \(error.localizedDescription)",
                japanese: "削除したプロファイルを復元できませんでした: \(error.localizedDescription)"
            )
            appendLog("[profile] undo delete failed: \(error.localizedDescription)")
            clearProfileDeletionUndo()
        }
    }

    func dismissProfileDeletionUndo() {
        clearProfileDeletionUndo()
    }

    func dismissProfileDeletionMessage() {
        profileDeletionCacheRunCoordinator.cancel()
        profileDeletionMessage = nil
    }

    private func presentProfileDeletionUndo(
        model: ModelConfig,
        originalIndex: Int,
        previousSelectedModelID: ModelConfig.ID?,
        autoUnloadEnabled: Bool?,
        autoUnloadMinutes: Int?
    ) {
        clearProfileDeletionUndo()

        let state = ProfileDeletionUndoState(
            id: UUID(),
            modelID: model.id,
            displayName: model.displayName,
            expiresAt: Date().addingTimeInterval(4)
        )
        profileDeletionUndoPayload = ProfileDeletionUndoPayload(
            state: state,
            model: model,
            originalIndex: originalIndex,
            previousSelectedModelID: previousSelectedModelID,
            autoUnloadEnabled: autoUnloadEnabled,
            autoUnloadMinutes: autoUnloadMinutes
        )
        profileDeletionUndoState = state
        profileDeletionUndoRunCoordinator.start { [weak self] generation in
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }
            guard let self,
                  self.profileDeletionUndoRunCoordinator.isCurrent(generation: generation),
                  self.profileDeletionUndoState?.id == state.id else {
                return
            }
            self.clearProfileDeletionUndo()
        }
    }

    private func clearProfileDeletionUndo() {
        profileDeletionUndoRunCoordinator.cancel()
        profileDeletionUndoPayload = nil
        profileDeletionUndoState = nil
    }

    private func beginHuggingFaceCacheDeletionIfAvailable(for model: ModelConfig) {
        guard let cacheURL = huggingFaceCacheURL(for: model) else {
            appendLog("[profile] Hugging Face cache delete skipped: repository ID could not be resolved for \(model.modelID).")
            profileDeletionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile deleted. Hugging Face cache was not deleted because the repository ID could not be resolved.",
                japanese: "プロファイルを削除しました。リポジトリIDを特定できなかったため、Hugging Faceキャッシュは削除していません。"
            )
            return
        }

        let homeURL = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let standardizedCacheURL = cacheURL.standardizedFileURL
        let homePrefix = homeURL.path.hasSuffix("/") ? homeURL.path : homeURL.path + "/"
        guard standardizedCacheURL.path.hasPrefix(homePrefix) else {
            appendLog("[profile] Hugging Face cache delete skipped: resolved path is outside the home directory.")
            profileDeletionMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Profile deleted. Hugging Face cache was not deleted because the resolved cache path was outside the home directory.",
                japanese: "プロファイルを削除しました。解決されたキャッシュパスがホームディレクトリ外だったため、Hugging Faceキャッシュは削除していません。"
            )
            return
        }

        profileDeletionMessage = Self.localizedText(
            language: settings.uiLanguage,
            english: "Profile deleted. Deleting the matching Hugging Face cache…",
            japanese: "プロファイルを削除しました。一致するHugging Faceキャッシュを削除しています…"
        )
        appendLog("[profile] deleting Hugging Face cache at \(ModelAvailabilityPathFormatter.compact(path: standardizedCacheURL.path)).")

        let deletionService = huggingFaceCacheDeletionService
        profileDeletionCacheRunCoordinator.start { [weak self] generation in
            let outcome = await deletionService.deleteCache(at: standardizedCacheURL)
            guard let self,
                  self.profileDeletionCacheRunCoordinator.isCurrent(generation: generation) else {
                return
            }

            let message: String
            switch outcome {
            case .deleted:
                self.appendLog("[profile] deleted Hugging Face cache at \(ModelAvailabilityPathFormatter.compact(path: standardizedCacheURL.path)).")
                message = Self.localizedText(
                    language: self.settings.uiLanguage,
                    english: "Profile and matching Hugging Face cache were deleted.",
                    japanese: "プロファイルと一致するHugging Faceキャッシュを削除しました。"
                )
            case .notFound:
                self.appendLog("[profile] Hugging Face cache was not present at \(ModelAvailabilityPathFormatter.compact(path: standardizedCacheURL.path)).")
                message = Self.localizedText(
                    language: self.settings.uiLanguage,
                    english: "Profile deleted. Matching Hugging Face cache was not found.",
                    japanese: "プロファイルを削除しました。一致するHugging Faceキャッシュは見つかりませんでした。"
                )
            case let .failed(errorMessage):
                self.appendLog("[profile] Hugging Face cache delete failed: \(errorMessage)")
                message = Self.localizedText(
                    language: self.settings.uiLanguage,
                    english: "Profile deleted, but Hugging Face cache deletion failed: \(errorMessage)",
                    japanese: "プロファイルは削除しましたが、Hugging Faceキャッシュの削除に失敗しました: \(errorMessage)"
                )
            }

            guard self.profileDeletionCacheRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            self.profileDeletionMessage = message
        }
    }

    private func huggingFaceCacheURL(for model: ModelConfig) -> URL? {
        guard let repositoryID = huggingFaceRepositoryID(for: model) else {
            return nil
        }

        let parts = repositoryID.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return nil
        }

        let cacheFolderName = "models--\(parts[0])--\(parts[1])"
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
            .appendingPathComponent(cacheFolderName, isDirectory: true)
    }

    private func huggingFaceRepositoryID(for model: ModelConfig) -> String? {
        if let repositoryID = Self.validHuggingFaceRepositoryID(model.modelID) {
            return repositoryID
        }

        return Self.huggingFaceRepositoryID(in: model.notes)
    }

    nonisolated private static func validHuggingFaceRepositoryID(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~"),
              !trimmed.localizedCaseInsensitiveContains("file:"),
              trimmed.split(separator: "/").count == 2,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        return trimmed
    }

    nonisolated private static func huggingFaceRepositoryID(in text: String) -> String? {
        let pattern = #"(?:huggingface\.co/|Downloaded from\s+)([A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let repositoryRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return validHuggingFaceRepositoryID(String(text[repositoryRange]))
    }

    @discardableResult
    func saveProfileEditing() -> Bool {
        guard isProfileEditorPresented else {
            return false
        }

        guard let index = models.firstIndex(where: { $0.modelID == profileEditorDraft.originalModelID }) else {
            let message = "Selected model profile no longer exists."
            updateProfileEditorViewState { state in
                state.setMessage(message)
            }
            appendLog("[profile] save failed: \(message)")
            return false
        }

        let existingModel = models[index]

        switch modelProfileValidator.validateProfileEdit(
            profileEditorDraft,
            existingModel: existingModel,
            isRunning: serverLifecycleCoordinator.isRunning(existingModel.id),
            language: settings.uiLanguage
        ) {
        case let .valid(updatedModel):
            var nextModels = models
            nextModels[index] = updatedModel
            var nextSettings = settings
            if existingModel.id != updatedModel.id {
                if let enabled = nextSettings.autoUnloadEnabledByModelID.removeValue(forKey: existingModel.id) {
                    nextSettings.autoUnloadEnabledByModelID[updatedModel.id] = enabled
                }
                if let minutes = nextSettings.autoUnloadMinutesByModelID.removeValue(forKey: existingModel.id) {
                    nextSettings.autoUnloadMinutesByModelID[updatedModel.id] = minutes
                }
            }

            do {
                let outcome = try settingsStore.save(settings: nextSettings, models: nextModels)
                invalidateModelSizeCache(for: existingModel)
                invalidateModelSizeCache(for: updatedModel)
                invalidatePortCheckCache()
                if selectedModelID == existingModel.id,
                   (existingModel.host != updatedModel.host
                       || existingModel.serverPort != updatedModel.serverPort) {
                    cancelDiagnostics(reason: "the selected model connection target changed")
                }
                settings = nextSettings
                autoUnloadEnabledByModelID = nextSettings.autoUnloadEnabledByModelID
                autoUnloadMinutesByModelID = nextSettings.autoUnloadMinutesByModelID
                models = nextModels
                selectedModelID = updatedModel.id
                profileEditorPortSuggestionEndpointKey = nil
                updateProfileEditorViewState { $0.dismiss() }
                appendLog("[profile] saved \(updatedModel.modelID) to models.json.")
                appendRuntimeEvent(
                    category: "Profile",
                    severity: .success,
                    message: "Profile changes saved.",
                    japaneseMessage: "プロファイルの変更を保存しました。",
                    modelID: updatedModel.modelID,
                    endpoint: "\(updatedModel.host):\(updatedModel.serverPort)"
                )
                appendSettingsSaveWarnings(outcome)
                return true
            } catch {
                updateProfileEditorViewState { state in
                    state.setMessage(error.localizedDescription)
                }
                appendLog("[profile] save failed: \(error.localizedDescription)")
                return false
            }
        case let .invalid(message):
            updateProfileEditorViewState { state in
                state.setMessage(message)
            }
            appendLog("[profile] save failed: \(message)")
            return false
        }
    }
}
