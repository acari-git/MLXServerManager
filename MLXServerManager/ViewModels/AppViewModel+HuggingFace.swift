import AppKit
import Foundation

extension AppViewModel {
    var huggingFaceDownloadPreview: HuggingFaceDownloadPreview {
        HuggingFaceDownloadPreview.make(draft: huggingFaceDownloadDraft)
    }

    var isHuggingFaceDownloadRunning: Bool {
        huggingFaceDownloadExecutionCoordinator.isRunning
    }

    var canStartHuggingFaceDownload: Bool {
        huggingFaceDownloadPreview.canDownload
            && isHuggingFaceCLIAvailable
            && selectedHuggingFaceSearchResult?.isSupportedForDownload == true
            && selectedHuggingFaceSearchResult?.id == huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines)
            && huggingFaceDownloadFileSelection.hasValidExplicitSelection
    }

    var huggingFaceDownloadFileSelection: HuggingFaceDownloadFileSelection {
        HuggingFaceDownloadFileSelectionPlanner.make(
            files: huggingFaceFilePreviewMatchesCurrentDraft ? huggingFaceFilePreview.files : [],
            draft: huggingFaceDownloadDraft,
            selectedFileIDs: selectedHuggingFacePreviewFileIDs
        )
    }

    var huggingFaceDownloadStorageAssessment: DownloadStorageAssessment? {
        makeHuggingFaceDownloadStorageAssessment(forceRefresh: false)
    }

    func huggingFaceSelectedPreviewSummary(for selection: HuggingFaceDownloadFileSelection) -> String {
        guard !selection.downloadFiles.isEmpty else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "No preview files selected.",
                japanese: "プレビューファイルが選択されていません。"
            )
        }
        let sizeText = selection.hasUnknownDownloadSize
            ? Self.localizedText(language: settings.uiLanguage, english: "unknown size", japanese: "サイズ不明")
            : ByteCountFormatter.string(fromByteCount: selection.knownDownloadByteCount, countStyle: .file)
        return Self.localizedText(
            language: settings.uiLanguage,
            english: "\(selection.downloadFiles.count) files • \(sizeText)",
            japanese: "\(selection.downloadFiles.count)ファイル • \(sizeText)"
        )
    }

    var visibleHuggingFaceSearchResults: [HuggingFaceSearchResult] {
        HuggingFaceDiscoveryProjection.project(
            results: huggingFaceSearchResults,
            filter: HuggingFaceDiscoveryFilter(
                showOnlySupported: showOnlyMLXLikelySearchResults,
                minimumDownloads: huggingFaceMinimumDownloads,
                sort: huggingFaceDiscoverySort
            )
        )
    }

    var huggingFaceDiscoverySummary: String {
        let visibleCount = visibleHuggingFaceSearchResults.count
        let totalCount = huggingFaceSearchResults.count
        return Self.localizedText(
            language: settings.uiLanguage,
            english: "Showing \(visibleCount) of \(totalCount) results. Filters are local and do not run another search.",
            japanese: "\(totalCount)件中\(visibleCount)件を表示しています。フィルターはローカル処理で、再検索は行いません。"
        )
    }

    func updateHuggingFaceFilePreviewViewState(
        _ update: (inout HuggingFaceFilePreviewViewState) -> Void
    ) {
        var nextState = huggingFaceFilePreviewViewState
        update(&nextState)
        guard nextState != huggingFaceFilePreviewViewState else {
            return
        }
        huggingFaceFilePreviewViewState = nextState
    }

    func previewHuggingFaceFilesRequested() {
        let preview = huggingFaceDownloadPreview
        guard let reference = preview.reference else {
            huggingFaceRequestCoordinator.cancel(.filePreview)
            updateHuggingFaceFilePreviewViewState { state in
                state.reject(message: preview.localizedMessage(language: settings.uiLanguage))
            }
            return
        }

        requestHuggingFaceFilePreview(
            identity: HuggingFaceFilePreviewIdentity(
                repositoryID: reference.repositoryID,
                revision: normalizedHuggingFaceRevision
            )
        )
    }

    func toggleHuggingFacePreviewFile(_ file: HuggingFaceDownloadPreviewFile) {
        updateHuggingFaceFilePreviewViewState { state in
            state.toggle(fileID: file.id)
        }
    }

    func selectAllHuggingFacePreviewFiles() {
        let fileIDs = Set(huggingFaceDownloadFileSelection.filteredFiles.map(\.id))
        updateHuggingFaceFilePreviewViewState { state in
            state.select(fileIDs: fileIDs)
        }
    }

    func applyHuggingFaceMLXPreset() {
        huggingFaceDownloadDraft.includePatterns = "*.safetensors, *.json, tokenizer.*, *.model, *.txt"
        huggingFaceDownloadDraft.excludePatterns = "*.h5, *.onnx, *.msgpack, *.bin"
        appendLog("[hf] applied MLX model file filter preset.")
    }

    func applyHuggingFaceSafeTensorPreset() {
        huggingFaceDownloadDraft.includePatterns = "*.safetensors, *.json, tokenizer.*"
        huggingFaceDownloadDraft.excludePatterns = "*.bin, *.h5, *.onnx, *.msgpack"
        appendLog("[hf] applied safetensors-focused file filter preset.")
    }

    func clearHuggingFaceFileFilters() {
        huggingFaceDownloadDraft.includePatterns = ""
        huggingFaceDownloadDraft.excludePatterns = ""
        appendLog("[hf] cleared file filters.")
    }

    func clearHuggingFacePreviewSelection() {
        updateHuggingFaceFilePreviewViewState { state in
            state.clearSelection()
        }
    }

    private func requestHuggingFaceFilePreview(
        identity: HuggingFaceFilePreviewIdentity,
        completion: (() -> Void)? = nil
    ) {
        let loadingMessage = Self.localizedText(
            language: settings.uiLanguage,
            english: "Fetching file list...",
            japanese: "ファイル一覧を取得中..."
        )
        updateHuggingFaceFilePreviewViewState { state in
            state.begin(identity: identity, message: loadingMessage)
        }

        let repositoryFileService = huggingFaceRepositoryFileService
        let credential = huggingFaceCredentialStore.readValue()
        huggingFaceRequestCoordinator.start(.filePreview) { [weak self] generation in
            do {
                let files = try await repositoryFileService.fetchFiles(
                    repositoryID: identity.repositoryID,
                    revision: identity.revision,
                    token: credential
                )
                guard let self,
                      !Task.isCancelled,
                      self.huggingFaceRequestCoordinator.isCurrent(.filePreview, generation: generation),
                      self.huggingFaceFilePreviewIdentity == identity,
                      self.currentHuggingFaceDraftIdentity == identity else {
                    return
                }

                let message = files.isEmpty
                    ? Self.localizedText(
                        language: self.settings.uiLanguage,
                        english: "No downloadable files found.",
                        japanese: "ダウンロード対象ファイルが見つかりません。"
                    )
                    : Self.localizedText(
                        language: self.settings.uiLanguage,
                        english: "File list is ready.",
                        japanese: "ファイル一覧を取得しました。"
                    )
                self.updateHuggingFaceFilePreviewViewState { state in
                    state.complete(files: files, message: message)
                }
                self.appendLog("[hf] preview fetched \(files.count) files for \(identity.repositoryID) at \(identity.revision).")
                completion?()
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      self.huggingFaceRequestCoordinator.isCurrent(.filePreview, generation: generation),
                      self.huggingFaceFilePreviewIdentity == identity,
                      self.currentHuggingFaceDraftIdentity == identity else {
                    return
                }
                self.updateHuggingFaceFilePreviewViewState { state in
                    state.fail(message: error.localizedDescription)
                }
                self.appendLog("[hf] preview failed for \(identity.repositoryID) at \(identity.revision): \(error.localizedDescription)")
            }
        }
    }

    func invalidateHuggingFaceFilePreview() {
        huggingFaceRequestCoordinator.cancel(.filePreview)
        updateHuggingFaceFilePreviewViewState { state in
            state.reset()
        }
    }

    func huggingFaceDownloadIdentityChanged() {
        guard let previewIdentity = huggingFaceFilePreviewIdentity,
              previewIdentity != currentHuggingFaceDraftIdentity else {
            return
        }

        let wasPreparingFileList = huggingFaceFilePreview.isLoading
            && huggingFaceDownloadStatus.phase == .preparing
        invalidateHuggingFaceFilePreview()

        guard wasPreparingFileList else {
            return
        }
        if huggingFaceDownloadQueue.contains(where: { !$0.phase.isTerminal }) {
            refreshAggregateHuggingFaceDownloadStatus()
        } else {
            setHuggingFaceDownloadStatus(
                Self.waitingHuggingFaceDownloadStatus(language: settings.uiLanguage)
            )
        }
    }

    func chooseHuggingFaceDownloadDirectoryRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose Hugging Face download save directory", japanese: "Hugging Faceダウンロード保存先を選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[hf] download directory picker cancelled.")
            return
        }
        var nextSettings = settings
        nextSettings.downloadSaveDirectory = url.path
        if saveSettingsRequested(nextSettings) {
            appendLog("[hf] download save directory selected: \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
        }
    }

    func startHuggingFaceDownloadRequested() {
        refreshHuggingFaceCLIStatus(logResult: false)
        guard isHuggingFaceCLIAvailable else {
            setHuggingFaceDownloadStatus(
                HuggingFaceDownloadStatus(
                    phase: .failed,
                    message: huggingFaceCLIMessage,
                    repositoryID: nil,
                    destinationPath: nil,
                    progress: nil,
                    outputLines: []
                )
            )
            appendLog("[hf] download not started: hf CLI is not available.")
            return
        }

        applyDownloadSettingsToDraft()
        let preview = huggingFaceDownloadPreview
        guard let reference = preview.reference,
              let destinationPath = preview.destinationPath else {
            setHuggingFaceDownloadStatus(
                HuggingFaceDownloadStatus(
                    phase: .failed,
                    message: downloadReadinessMessage(
                        previewMessage: preview.localizedMessage(language: settings.uiLanguage)
                    ),
                    repositoryID: nil,
                    destinationPath: nil,
                    progress: nil,
                    outputLines: []
                )
            )
            appendLog("[hf] download not started: \(preview.message)")
            return
        }

        guard canStartHuggingFaceDownload else {
            let readinessMessage = downloadReadinessMessage(
                previewMessage: preview.localizedMessage(language: settings.uiLanguage)
            )
            setHuggingFaceDownloadStatus(
                HuggingFaceDownloadStatus(
                    phase: .failed,
                    message: readinessMessage,
                    repositoryID: reference.repositoryID,
                    destinationPath: destinationPath,
                    progress: nil,
                    outputLines: []
                )
            )
            appendLog("[hf] download blocked for \(reference.repositoryID): \(readinessMessage)")
            return
        }

        guard prepareHuggingFaceFileListForDownload(reference: reference, destinationPath: destinationPath) else {
            return
        }

        let displayName = preview.displayName
        let draft = huggingFaceDownloadDraft
        let fileSelection = huggingFaceDownloadFileSelection
        let expectedDownloadFiles = fileSelection.downloadFiles
        let expectedDownloadBytes = fileSelection.totalDownloadBytes
        if let storageAssessment = makeHuggingFaceDownloadStorageAssessment(forceRefresh: true),
           storageAssessment.blocksDownload {
            let message = "\(storageAssessment.title(language: settings.uiLanguage)) \(storageAssessment.detail(language: settings.uiLanguage))"
            setHuggingFaceDownloadStatus(
                HuggingFaceDownloadStatus(
                    phase: .failed,
                    message: message,
                    repositoryID: reference.repositoryID,
                    destinationPath: destinationPath,
                    progress: nil,
                    outputLines: []
                )
            )
            appendLog("[hf] download blocked: insufficient storage for \(reference.repositoryID).")
            return
        }
        let queueEntryID = UUID()
        let canStartImmediately = huggingFaceDownloadExecutionCoordinator.activeCount < settings.maxConcurrentModelDownloads
            && !isHuggingFaceDownloadDestinationReserved(destinationPath)
        let entryPhase: HuggingFaceDownloadPhase = canStartImmediately ? .preparing : .waiting
        insertHuggingFaceDownloadQueueEntry(
            HuggingFaceDownloadQueueEntry(
                id: queueEntryID,
                repositoryID: reference.repositoryID,
                destinationPath: destinationPath,
                phase: entryPhase,
                message: entryPhase == .waiting
                    ? Self.localizedText(language: settings.uiLanguage, english: "Waiting for an available download slot.", japanese: "ダウンロードの空きを待っています。")
                    : Self.localizedText(language: settings.uiLanguage, english: "Preparing", japanese: "準備中"),
                fileCount: expectedDownloadFiles.isEmpty ? nil : expectedDownloadFiles.count,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: expectedDownloadBytes,
                speedBytesPerSecond: nil
            )
        )
        let job = HuggingFaceDownloadJob(
            id: queueEntryID,
            reference: reference,
            destinationPath: destinationPath,
            displayName: displayName,
            draft: draft,
            expectedFiles: expectedDownloadFiles,
            expectedBytes: expectedDownloadBytes,
            includePatterns: fileSelection.downloadIncludePatterns,
            excludePatterns: fileSelection.downloadExcludePatterns
        )
        queuedHuggingFaceDownloads[queueEntryID] = job
        recordHuggingFaceDownloadRetry(job)
        huggingFaceOutputStateCoordinator.selectPrimaryIfNeeded(queueEntryID)
        downloadCompletionMarkerDate = nil
        refreshAggregateHuggingFaceDownloadStatus()
        appendLog("[hf] queued Hugging Face download for \(reference.repositoryID).")
        appendRuntimeEvent(
            category: "Download",
            message: entryPhase == .waiting ? "Download queued." : "Download preparation started.",
            japaneseMessage: entryPhase == .waiting ? "ダウンロードをキューへ追加しました。" : "ダウンロードの準備を開始しました。",
            modelID: reference.repositoryID
        )
        appendLog("[hf] destination: \(ModelAvailabilityPathFormatter.compact(path: destinationPath))")
        drainHuggingFaceDownloadQueue()
    }

    private func makeHuggingFaceDownloadStorageAssessment(
        forceRefresh: Bool
    ) -> DownloadStorageAssessment? {
        let preview = huggingFaceDownloadPreview
        let selection = huggingFaceDownloadFileSelection
        guard let destinationPath = preview.destinationPath,
              !selection.downloadFiles.isEmpty else {
            downloadStorageAssessmentCache = nil
            return nil
        }

        let key = DownloadStorageAssessmentCacheKey(
            destinationPath: destinationPath,
            files: selection.downloadFiles
        )
        if !forceRefresh,
           let cached = downloadStorageAssessmentCache,
           cached.key == key {
            return cached.assessment
        }

        let destinationURL = URL(fileURLWithPath: destinationPath, isDirectory: true).standardizedFileURL
        let expectedFiles = selection.downloadFiles.map { file in
            DownloadStorageExpectedFile(
                path: file.path,
                expectedSizeBytes: file.size,
                existingSizeBytes: existingDownloadFileSize(
                    relativePath: file.path,
                    destinationURL: destinationURL
                )
            )
        }
        let assessment = DownloadStorageAdvisor.assess(
            files: expectedFiles,
            destinationDirectoryURL: destinationURL,
            capacityProvider: downloadStorageCapacityProvider
        )
        downloadStorageAssessmentCache = DownloadStorageAssessmentCacheEntry(
            key: key,
            assessment: assessment
        )
        return assessment
    }

    private func existingDownloadFileSize(relativePath: String, destinationURL: URL) -> Int64? {
        let candidateURL = destinationURL
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        let destinationPrefix = destinationURL.path.hasSuffix("/")
            ? destinationURL.path
            : destinationURL.path + "/"
        guard candidateURL.path.hasPrefix(destinationPrefix),
              let attributes = try? FileManager.default.attributesOfItem(atPath: candidateURL.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return nil
        }
        return fileSize.int64Value
    }

    private func prepareHuggingFaceFileListForDownload(
        reference: HuggingFaceModelReference,
        destinationPath: String
    ) -> Bool {
        let identity = HuggingFaceFilePreviewIdentity(
            repositoryID: reference.repositoryID,
            revision: normalizedHuggingFaceRevision
        )

        if huggingFaceFilePreviewIdentity == identity,
           !huggingFaceDownloadFileSelection.filteredFiles.isEmpty {
            return true
        }

        setHuggingFaceDownloadStatus(
            HuggingFaceDownloadStatus(
                phase: .preparing,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Preparing file list before download...",
                    japanese: "ダウンロード前にファイル一覧を取得しています..."
                ),
                repositoryID: reference.repositoryID,
                destinationPath: destinationPath,
                progress: nil,
                outputLines: []
            )
        )

        if huggingFaceFilePreview.isLoading,
           huggingFaceFilePreviewIdentity == identity {
            return false
        }

        appendLog("[hf] preparing file list before download for \(reference.repositoryID) at \(identity.revision).")
        requestHuggingFaceFilePreview(identity: identity) { [weak self] in
            guard let self,
                  self.huggingFaceFilePreviewIdentity == identity,
                  self.currentHuggingFaceDraftIdentity == identity else {
                return
            }

            guard !self.huggingFaceDownloadFileSelection.filteredFiles.isEmpty else {
                self.setHuggingFaceDownloadStatus(
                    HuggingFaceDownloadStatus(
                        phase: .failed,
                        message: Self.localizedText(
                            language: self.settings.uiLanguage,
                            english: "No downloadable files were found. Choose another model or check the repository.",
                            japanese: "ダウンロード対象ファイルが見つかりません。別のモデルを選ぶか、リポジトリを確認してください。"
                        ),
                        repositoryID: reference.repositoryID,
                        destinationPath: destinationPath,
                        progress: nil,
                        outputLines: []
                    )
                )
                return
            }

            self.startHuggingFaceDownloadRequested()
        }

        return false
    }

    private func downloadReadinessMessage(previewMessage: String) -> String {
        let trimmedSource = huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return previewMessage
        }
        guard let selectedHuggingFaceSearchResult,
              selectedHuggingFaceSearchResult.id == trimmedSource else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Search the model first to verify the required MLX tag.",
                japanese: "必要なMLXタグを確認するため、先にモデルを検索してください。"
            )
        }
        guard selectedHuggingFaceSearchResult.isSupportedForDownload else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "This model does not have the required MLX tag and cannot be downloaded.",
                japanese: "このモデルには必要なMLXタグがないため、ダウンロードできません。"
            )
        }
        guard huggingFaceDownloadFileSelection.hasValidExplicitSelection else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Select at least one preview file, or turn off selected-file mode.",
                japanese: "プレビューファイルを1件以上選択するか、選択ファイルモードをOFFにしてください。"
            )
        }
        return previewMessage
    }

    func restoreHuggingFaceDownloadForm(from entry: HuggingFaceDownloadQueueEntry) {
        huggingFaceDownloadDraft.source = entry.repositoryID
        let destinationURL = URL(fileURLWithPath: entry.destinationPath, isDirectory: true)
        huggingFaceDownloadDraft.saveDirectory = HuggingFaceDownloadPlanner.baseDirectory(
            forDestinationPath: entry.destinationPath,
            repositoryID: entry.repositoryID
        )
        huggingFaceDownloadDraft.displayName = destinationURL.lastPathComponent
        setHuggingFaceDownloadStatus(
            HuggingFaceDownloadStatus(
                phase: .waiting,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Restored download form from queue entry. Review it, then press Download or Retry.",
                    japanese: "キュー項目からダウンロードフォームを復元しました。内容を確認して、ダウンロードまたは再試行を押してください。"
                ),
                repositoryID: entry.repositoryID,
                destinationPath: entry.destinationPath,
                progress: nil,
                outputLines: []
            )
        )
        appendLog("[hf] restored download form from queue entry: \(entry.repositoryID)")
    }

    func copyHuggingFaceDownloadURL(from entry: HuggingFaceDownloadQueueEntry) {
        copyToPasteboard("https://huggingface.co/\(entry.repositoryID)")
        appendLog("[hf] copied queue entry URL for \(entry.repositoryID).")
    }

    func retryHuggingFaceDownloadRequested() {
        guard let sourceEntry = latestRetryableHuggingFaceDownloadQueueEntry else {
            appendLog("[hf] retry skipped: no failed or cancelled download is ready to retry.")
            return
        }

        retryHuggingFaceDownload(id: sourceEntry.id)
    }

    func recordHuggingFaceDownloadRetry(
        _ job: HuggingFaceDownloadJob,
        kind: HuggingFaceDownloadRetryKind = .download
    ) {
        huggingFaceDownloadRetryStore.record(job, kind: kind)
        persistHuggingFaceDownloadRetries()
    }

    func discardHuggingFaceDownloadRetry(queueEntryID: UUID) {
        huggingFaceDownloadRetryStore.discard(queueEntryID: queueEntryID)
        persistHuggingFaceDownloadRetries()
    }

    private func consumeHuggingFaceDownloadRetry(
        queueEntryID: UUID,
        newQueueEntryID: UUID
    ) -> HuggingFaceDownloadJob? {
        let job = huggingFaceDownloadRetryStore.consumeRetry(
            queueEntryID: queueEntryID,
            newQueueEntryID: newQueueEntryID
        )
        persistHuggingFaceDownloadRetries()
        return job
    }

    func retryHuggingFaceDownload(id sourceEntryID: UUID) {
        guard let sourceEntry = huggingFaceDownloadQueue.first(where: { $0.id == sourceEntryID }),
              canRetryHuggingFaceDownload(id: sourceEntry.id) else {
            appendLog("[hf] retry skipped: the selected download is no longer retryable.")
            return
        }

        let queueEntryID = UUID()
        guard let retryKind = huggingFaceDownloadRetryStore.retryKind(queueEntryID: sourceEntryID) else {
            appendLog("[hf] retry skipped: the original retry kind is no longer available.")
            return
        }
        guard let job = consumeHuggingFaceDownloadRetry(
            queueEntryID: sourceEntryID,
            newQueueEntryID: queueEntryID
        ) else {
            appendLog("[hf] retry skipped: the original download snapshot is no longer available.")
            return
        }

        switch retryKind {
        case .download:
            enqueueHuggingFaceDownloadRetry(job)
        case .profileRegistration:
            retryDownloadedHuggingFaceModelProfile(job)
        }
    }

    private func enqueueHuggingFaceDownloadRetry(_ job: HuggingFaceDownloadJob) {
        let canStartImmediately = huggingFaceDownloadExecutionCoordinator.activeCount < settings.maxConcurrentModelDownloads
            && !isHuggingFaceDownloadDestinationReserved(job.destinationPath)
        let entryPhase: HuggingFaceDownloadPhase = canStartImmediately ? .preparing : .waiting
        insertHuggingFaceDownloadQueueEntry(
            HuggingFaceDownloadQueueEntry(
                id: job.id,
                repositoryID: job.reference.repositoryID,
                destinationPath: job.destinationPath,
                phase: entryPhase,
                message: entryPhase == .waiting
                    ? Self.localizedText(language: settings.uiLanguage, english: "Waiting for an available download slot.", japanese: "ダウンロードの空きを待っています。")
                    : Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Preparing retry from the original download settings.",
                        japanese: "元のダウンロード設定で再試行を準備しています。"
                    ),
                fileCount: job.expectedFiles.isEmpty ? nil : job.expectedFiles.count,
                downloadedFileCount: nil,
                downloadedBytes: nil,
                totalBytes: job.expectedBytes,
                speedBytesPerSecond: nil
            )
        )
        queuedHuggingFaceDownloads[job.id] = job
        recordHuggingFaceDownloadRetry(job)
        huggingFaceOutputStateCoordinator.selectPrimaryIfNeeded(job.id)
        downloadCompletionMarkerDate = nil
        refreshAggregateHuggingFaceDownloadStatus()
        appendLog("[hf] retry queued with original settings for \(job.reference.repositoryID).")
        appendLog("[hf] destination: \(ModelAvailabilityPathFormatter.compact(path: job.destinationPath))")
        drainHuggingFaceDownloadQueue()
    }

    private func isHuggingFaceDownloadDestinationReserved(_ destinationPath: String) -> Bool {
        let destinationIdentity = HuggingFaceDownloadPlanner.destinationIdentity(path: destinationPath)
        let destinationAlreadyQueued = huggingFaceDownloadQueue.contains { entry in
            !entry.phase.isTerminal
                && HuggingFaceDownloadPlanner.destinationIdentity(path: entry.destinationPath) == destinationIdentity
        }
        return destinationAlreadyQueued
            || huggingFaceDownloadExecutionCoordinator.isDestinationActive(destinationPath)
    }

    private func retryDownloadedHuggingFaceModelProfile(_ job: HuggingFaceDownloadJob) {
        insertHuggingFaceDownloadQueueEntry(
            HuggingFaceDownloadQueueEntry(
                id: job.id,
                repositoryID: job.reference.repositoryID,
                destinationPath: job.destinationPath,
                phase: .finalizing,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Retrying model profile registration without downloading again.",
                    japanese: "再ダウンロードせずにモデルプロファイル登録を再試行しています。"
                ),
                fileCount: job.expectedFiles.isEmpty ? nil : job.expectedFiles.count,
                downloadedFileCount: job.expectedFiles.isEmpty ? nil : job.expectedFiles.count,
                downloadedBytes: job.expectedBytes,
                totalBytes: job.expectedBytes,
                speedBytesPerSecond: nil
            )
        )
        downloadCompletionMarkerDate = nil
        refreshAggregateHuggingFaceDownloadStatus()
        appendLog("[hf] retrying profile registration for existing download at \(ModelAvailabilityPathFormatter.compact(path: job.destinationPath)).")

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: job.destinationPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            let message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Downloaded model folder no longer exists. Retry the download.",
                japanese: "ダウンロード済みモデルのフォルダが存在しません。ダウンロードを再試行してください。"
            )
            updateHuggingFaceQueueEntry(job.id, phase: .failed, message: message)
            recordHuggingFaceDownloadRetry(job, kind: .download)
            appendLog("[hf] profile retry requires a new download because the local folder is missing.")
            return
        }

        if let integrityFailure = downloadedModelIntegrityFailureMessage(path: job.destinationPath) {
            updateHuggingFaceQueueEntry(job.id, phase: .failed, message: integrityFailure)
            recordHuggingFaceDownloadRetry(job, kind: .download)
            appendLog("[hf] profile retry requires a new download: \(integrityFailure)")
            return
        }

        if let profileAddError = addDownloadedHuggingFaceModelProfile(
            reference: job.reference,
            destinationPath: job.destinationPath,
            displayName: job.displayName,
            draft: job.draft
        ) {
            updateHuggingFaceQueueEntry(job.id, phase: .failed, message: profileAddError)
            recordHuggingFaceDownloadRetry(job, kind: .profileRegistration)
            return
        }

        downloadCompletionMarkerDate = Date()
        updateHuggingFaceQueueEntry(
            job.id,
            phase: .completed,
            message: job.draft.autoSelectAfterAdd
                ? Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Download already completed. Added to model list and selected without downloading again.",
                    japanese: "ダウンロード済みです。再ダウンロードせずにモデル一覧へ追加し、選択しました。"
                )
                : Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Download already completed. Added to model list without downloading again.",
                    japanese: "ダウンロード済みです。再ダウンロードせずにモデル一覧へ追加しました。"
                ),
            progress: 1
        )
        discardHuggingFaceDownloadRetry(queueEntryID: job.id)
        appendLog("[hf] profile registration retry completed without downloading \(job.reference.repositoryID) again.")
    }

    func cancelHuggingFaceDownloadRequested() {
        let cancellableIDs = HuggingFaceDownloadQueueScheduler.cancellableIDs(
            entries: huggingFaceDownloadQueue
        )
        guard !cancellableIDs.isEmpty else {
            appendLog("[hf] no active download to cancel.")
            return
        }

        cancelHuggingFaceDownloads(ids: cancellableIDs)
        appendLog("[hf] cancel requested for \(cancellableIDs.count) download(s).")
    }

    func cancelHuggingFaceDownload(id: UUID) {
        let cancellableIDs = HuggingFaceDownloadQueueScheduler.cancellableIDs(
            entries: huggingFaceDownloadQueue,
            requestedID: id
        )
        guard !cancellableIDs.isEmpty else {
            appendLog("[hf] cancel skipped: queue entry is not cancellable.")
            return
        }

        cancelHuggingFaceDownloads(ids: cancellableIDs)
        appendLog("[hf] cancel requested for queue entry \(id.uuidString).")
    }

    private func cancelHuggingFaceDownloads(ids: Set<UUID>) {
        for id in ids {
            if !huggingFaceDownloadExecutionCoordinator.isActive(id) {
                updateHuggingFaceQueueEntry(
                    id,
                    phase: .cancelled,
                    message: Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Download cancelled. The model was not added.",
                        japanese: "ダウンロードをキャンセルしました。モデルは追加されていません。"
                    )
                )
                if let job = queuedHuggingFaceDownloads[id] {
                    recordHuggingFaceDownloadRetry(job)
                }
                queuedHuggingFaceDownloads[id] = nil
                continue
            }

            huggingFaceDownloadExecutionCoordinator.cancel(id)
        }

        refreshAggregateHuggingFaceDownloadStatus()
        drainHuggingFaceDownloadQueue()
    }

    func resetHuggingFaceDownloadStatus() {
        guard !isHuggingFaceDownloadRunning else {
            return
        }

        setHuggingFaceDownloadStatus(
            Self.waitingHuggingFaceDownloadStatus(language: settings.uiLanguage)
        )
    }

    func refreshHuggingFaceCLIRequested() {
        refreshHuggingFaceCLIStatus(logResult: true)
    }

    func refreshAria2Status() {
        aria2Availability = Aria2AvailabilityChecker.check()
    }

    func refreshHuggingFaceCLIStatus(logResult: Bool) {
        if let resolution = HuggingFaceDownloadManager.resolveCLI() {
            isHuggingFaceCLIAvailable = true
            huggingFaceCLIPath = resolution.displayPath
            huggingFaceCLIMessage = Self.localizedText(language: settings.uiLanguage, english: "Available", japanese: "利用可能")
            if logResult {
                appendLog("[hf] CLI detected at \(resolution.displayPath).")
            }
        } else {
            let candidates = HuggingFaceDownloadManager.candidateExecutablePaths()
            let checked = candidates
                .map { ModelAvailabilityPathFormatter.compact(path: $0) }
                .joined(separator: ", ")
            isHuggingFaceCLIAvailable = false
            huggingFaceCLIPath = Self.localizedText(language: settings.uiLanguage, english: "Not found", japanese: "見つかりません")
            huggingFaceCLIMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Install Hugging Face CLI, then press Retry CLI or restart the app.",
                japanese: "Hugging Face CLIをインストールしてから、CLI再確認を押すかアプリを再起動してください。"
            )
            if logResult {
                appendLog("[hf] CLI not found. Checked: \(checked)")
            }
        }
    }

    func updateHuggingFaceSearchViewState(
        _ update: (inout HuggingFaceSearchViewState) -> Void
    ) {
        var nextState = huggingFaceSearchViewState
        update(&nextState)
        guard nextState != huggingFaceSearchViewState else {
            return
        }
        huggingFaceSearchViewState = nextState
    }

    private func applyHuggingFaceSearchResultToDownloadDraft(_ result: HuggingFaceSearchResult) {
        let previousIdentity = currentHuggingFaceDraftIdentity
        huggingFaceDownloadDraft.source = result.id
        huggingFaceDownloadDraft.displayName = result.name
        if previousIdentity != currentHuggingFaceDraftIdentity {
            invalidateHuggingFaceFilePreview()
        }
    }

    func performHuggingFaceSearchRequested() {
        let query = huggingFaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        huggingFaceRequestCoordinator.cancel(.search)

        guard !query.isEmpty else {
            updateHuggingFaceSearchViewState { state in
                state.resetForEmptyQuery(
                    message: Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Enter a search term before searching.",
                        japanese: "検索前に検索語を入力してください。"
                    )
                )
            }
            invalidateHuggingFaceFilePreview()
            appendLog("[hf] search skipped: empty query.")
            return
        }

        updateHuggingFaceSearchViewState { state in
            state.beginSearch(
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Searching Hugging Face for: \(query)",
                    japanese: "Hugging Faceを検索中: \(query)"
                )
            )
        }
        appendLog("[hf] search started: \(query)")

        let searchService = huggingFaceSearchService
        huggingFaceRequestCoordinator.start(.search) { [weak self] generation in
            defer {
                if let self,
                   self.huggingFaceRequestCoordinator.isCurrent(.search, generation: generation) {
                    self.updateHuggingFaceSearchViewState { state in
                        state.finishSearch()
                    }
                }
            }

            do {
                let results = try await searchService.search(query: query, limit: 10)
                guard let self,
                      !Task.isCancelled,
                      self.huggingFaceRequestCoordinator.isCurrent(.search, generation: generation),
                      self.huggingFaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                      self.huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    return
                }

                if let selectedResult = results.first(where: {
                    $0.id.caseInsensitiveCompare(query) == .orderedSame
                }) ?? results.first {
                    self.applyHuggingFaceSearchResultToDownloadDraft(selectedResult)
                    self.updateHuggingFaceSearchViewState { state in
                        state.completeSearch(
                            results: results,
                            selectedResult: selectedResult,
                            message: Self.localizedText(
                                language: self.settings.uiLanguage,
                                english: "Selected search result. Review the details, then press Download.",
                                japanese: "検索結果を選択しました。内容を確認してからダウンロードしてください。"
                            )
                        )
                    }
                    self.appendLog("[hf] search result selected for download: \(selectedResult.id) — \(selectedResult.qualitySummary)")
                } else {
                    self.invalidateHuggingFaceFilePreview()
                    self.updateHuggingFaceSearchViewState { state in
                        state.completeSearch(
                            results: results,
                            selectedResult: nil,
                            message: Self.localizedText(
                                language: self.settings.uiLanguage,
                                english: "No matching models found. Try another query or paste an exact ID / URL.",
                                japanese: "一致するモデルが見つかりません。別の語句で検索するか、正確なModel ID / URLを貼り付けてください。"
                            )
                        )
                    }
                }
                self.appendLog("[hf] search completed with \(results.count) results.")
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      self.huggingFaceRequestCoordinator.isCurrent(.search, generation: generation),
                      self.huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    return
                }
                self.invalidateHuggingFaceFilePreview()
                self.updateHuggingFaceSearchViewState { state in
                    state.failSearch(message: error.localizedDescription)
                }
                self.appendLog("[hf] search failed: \(error.localizedDescription)")
            }
        }
    }

    func selectHuggingFaceSearchResult(_ result: HuggingFaceSearchResult) {
        applyHuggingFaceSearchResultToDownloadDraft(result)
        updateHuggingFaceSearchViewState { state in
            state.selectResult(
                result,
                message: result.selectionMessage(language: settings.uiLanguage)
            )
        }
        appendLog("[hf] search result selected for download: \(result.id) — \(result.qualitySummary)")
    }

    func copySelectedHuggingFaceModelURL() {
        guard let selectedHuggingFaceSearchResult else {
            appendLog("[hf] no selected search result URL to copy.")
            return
        }
        copyToPasteboard(selectedHuggingFaceSearchResult.webURL)
        appendLog("[hf] copied Hugging Face URL for \(selectedHuggingFaceSearchResult.id).")
    }

    func registerLocalModelRequested() {
        let trimmedPath = localModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expandedPath = HuggingFaceDownloadPlanner.expandedLocalPath(from: trimmedPath) else {
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Enter a local folder path such as ~/Models/mlx/model-name.", japanese: "~/Models/mlx/model-name のようなローカルフォルダパスを入力してください。")
            appendLog("[profile] local model add failed: invalid local path.")
            return
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Local model folder was not found.", japanese: "ローカルモデルフォルダが見つかりません。")
            appendLog("[profile] local model add failed: folder not found at \(ModelAvailabilityPathFormatter.compact(path: expandedPath)).")
            return
        }

        if models.contains(where: { $0.modelID == expandedPath }) {
            selectedModelID = expandedPath
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Existing local model profile selected.", japanese: "既存のローカルモデルプロファイルを選択しました。")
            appendLog("[profile] existing local model profile selected: \(ModelAvailabilityPathFormatter.compact(path: expandedPath)).")
            return
        }

        let displayName = localModelDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? URL(fileURLWithPath: expandedPath, isDirectory: true).lastPathComponent
            : localModelDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(localModelPortText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings.defaultPort
        let model = ModelConfig(
            modelID: expandedPath,
            displayName: displayName,
            family: "Local",
            quantization: "Existing Folder",
            localName: URL(fileURLWithPath: expandedPath, isDirectory: true).lastPathComponent,
            host: settings.defaultHost,
            serverPort: port,
            enableThinking: localModelEnableThinking,
            notes: "Registered from an existing local model folder.",
            advancedLaunchOptions: nil
        )

        let nextModels = models + [model]
        do {
            let outcome = try settingsStore.save(models: nextModels)
            invalidateModelSizeCache(for: model)
            invalidatePortCheckCache()
            models = nextModels
            selectedModelID = model.id
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(
                for: model,
                result: .present(path: expandedPath)
            )
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Local model added and selected.", japanese: "ローカルモデルを追加して選択しました。")
            appendLog("[profile] local model added: \(displayName).")
            appendSettingsSaveWarnings(outcome)
        } catch {
            localModelMessage = Self.localizedText(language: settings.uiLanguage, english: "Could not save local model profile: \(error.localizedDescription)", japanese: "ローカルモデルプロファイルを保存できませんでした: \(error.localizedDescription)")
            appendLog("[profile] local model add failed: \(error.localizedDescription)")
        }
    }

    func checkModelAvailabilityRequested() {
        guard let selectedModel else {
            selectedModelAvailabilitySummary = .noSelection
            appendLog("[availability] check skipped: no selected profile.")
            return
        }

        guard !runtimeState.isExternalServerContext else {
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.external(for: selectedModel)
            appendLog("[availability] check skipped: external targets are not managed by MLX Server Manager.")
            return
        }

        guard let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: selectedModel) else {
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.initial(
                for: selectedModel,
                isExternalTarget: false
            )
            appendLog("[availability] check skipped: selected profile uses a model identifier, not a local path.")
            return
        }

        let result = modelAvailabilityChecker.check(path: localPath)
        selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(for: selectedModel, result: result)

        switch result {
        case .present:
            appendLog("[availability] configured local path appears present for selected profile. Compatibility is not verified.")
        case .missing:
            appendLog("[availability] configured local path was not found for selected profile.")
        case let .notInspectable(message):
            appendLog("[availability] check unavailable: \(message)")
        }
    }

    func drainHuggingFaceDownloadQueue() {
        let startableIDs = HuggingFaceDownloadQueueScheduler.startableIDs(
            entries: huggingFaceDownloadQueue,
            queuedIDs: Set(queuedHuggingFaceDownloads.keys),
            activeIDs: huggingFaceDownloadExecutionCoordinator.activeIDs,
            activeDestinationPaths: huggingFaceDownloadExecutionCoordinator.activeDestinationPaths,
            maximumConcurrentDownloads: settings.maxConcurrentModelDownloads
        )

        for id in startableIDs {
            guard let job = queuedHuggingFaceDownloads[id] else {
                continue
            }
            startQueuedHuggingFaceDownload(job)
        }
    }

    private func startQueuedHuggingFaceDownload(_ job: HuggingFaceDownloadJob) {
        updateHuggingFaceQueueEntry(
            job.id,
            phase: .preparing,
            message: Self.localizedText(
                language: settings.uiLanguage,
                english: "Preparing destination: \(ModelAvailabilityPathFormatter.compact(path: job.destinationPath))",
                japanese: "保存先を準備中: \(ModelAvailabilityPathFormatter.compact(path: job.destinationPath))"
            )
        )
        appendLog("[hf] starting Hugging Face download for \(job.reference.repositoryID).")
        let manager = huggingFaceDownloadManagerFactory()
        let revision = job.draft.revision.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = HuggingFaceDownloadRequest(
            repositoryID: job.reference.repositoryID,
            destinationPath: job.destinationPath,
            revision: revision.isEmpty ? "main" : revision,
            includePatterns: job.includePatterns,
            excludePatterns: job.excludePatterns,
            authorizationValue: huggingFaceCredentialStore.readValue()
        )
        let didStart = huggingFaceDownloadExecutionCoordinator.start(
            id: job.id,
            manager: manager,
            request: request,
            expectedFiles: job.expectedFiles,
            totalBytes: job.expectedBytes,
            outputHandler: { [weak self, queueEntryID = job.id] line in
                self?.appendHuggingFaceOutputLine(line, queueEntryID: queueEntryID)
            },
            progressHandler: { [weak self, queueEntryID = job.id] progress in
                self?.updateMeasuredHuggingFaceProgress(
                    queueEntryID: queueEntryID,
                    downloadedBytes: progress.downloadedBytes,
                    downloadedFileCount: progress.downloadedFileCount,
                    totalBytes: progress.totalBytes,
                    speedBytesPerSecond: progress.speedBytesPerSecond
                )
            },
            completionHandler: { [weak self] completion in
                self?.handleHuggingFaceDownloadCompletion(job: job, completion: completion)
            }
        )

        guard didStart else {
            let message = Self.localizedText(
                language: settings.uiLanguage,
                english: "A download is already active for this queue entry or destination.",
                japanese: "このキュー項目または保存先では、すでにダウンロードが実行中です。"
            )
            updateHuggingFaceQueueEntry(job.id, phase: .failed, message: message)
            recordHuggingFaceDownloadRetry(job)
            queuedHuggingFaceDownloads[job.id] = nil
            appendLog("[hf] download not started for \(job.reference.repositoryID): \(message)")
            appendRuntimeEvent(
                category: "Download",
                severity: .failure,
                message: message,
                japaneseMessage: "ダウンロードを開始できませんでした: \(message)",
                modelID: job.reference.repositoryID
            )
            refreshAggregateHuggingFaceDownloadStatus()
            return
        }
    }

    private func handleHuggingFaceDownloadCompletion(
        job: HuggingFaceDownloadJob,
        completion: HuggingFaceDownloadExecutionCoordinator.Completion
    ) {
        flushPendingHuggingFaceOutput(queueEntryID: job.id)

        switch completion.outcome {
        case let .succeeded(result):
            guard !completion.cancellationRequested else {
                updateHuggingFaceQueueEntry(
                    job.id,
                    phase: .cancelled,
                    message: Self.localizedText(language: settings.uiLanguage, english: "Cancelled", japanese: "キャンセル済み")
                )
                appendLog("[hf] download cancelled for \(job.reference.repositoryID).")
                appendRuntimeEvent(
                    category: "Download",
                    severity: .warning,
                    message: "Download cancelled.",
                    japaneseMessage: "ダウンロードをキャンセルしました。",
                    modelID: job.reference.repositoryID
                )
                recordHuggingFaceDownloadRetry(job)
                finishHuggingFaceDownload(job.id)
                drainHuggingFaceDownloadQueue()
                return
            }

            updateHuggingFaceQueueEntry(
                job.id,
                phase: .finalizing,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Finalizing downloaded model profile...",
                    japanese: "ダウンロード済みモデルのプロファイルを仕上げています..."
                ),
                progress: 1
            )

            if job.draft.autoAddToModelList,
               let integrityFailure = downloadedModelIntegrityFailureMessage(path: result.destinationPath) {
                updateHuggingFaceQueueEntry(job.id, phase: .failed, message: integrityFailure)
                recordHuggingFaceDownloadRetry(job)
                appendLog("[hf] downloaded model validation failed for \(job.reference.repositoryID): \(integrityFailure)")
                appendRuntimeEvent(
                    category: "Download",
                    severity: .failure,
                    message: integrityFailure,
                    japaneseMessage: "ダウンロード済みモデルの検証に失敗しました: \(integrityFailure)",
                    modelID: job.reference.repositoryID
                )
                finishHuggingFaceDownload(job.id)
                drainHuggingFaceDownloadQueue()
                return
            }

            if job.draft.autoAddToModelList,
               let profileAddError = addDownloadedHuggingFaceModelProfile(
                   reference: job.reference,
                   destinationPath: result.destinationPath,
                   displayName: job.displayName,
                   draft: job.draft
            ) {
                updateHuggingFaceQueueEntry(job.id, phase: .failed, message: profileAddError)
                recordHuggingFaceDownloadRetry(job, kind: .profileRegistration)
                appendRuntimeEvent(
                    category: "Download",
                    severity: .failure,
                    message: profileAddError,
                    japaneseMessage: "ダウンロード後のプロファイル追加に失敗しました: \(profileAddError)",
                    modelID: job.reference.repositoryID
                )
                finishHuggingFaceDownload(job.id)
                drainHuggingFaceDownloadQueue()
                return
            }

            downloadCompletionMarkerDate = Date()
            updateHuggingFaceQueueEntry(
                job.id,
                phase: .completed,
                message: downloadCompletionMessage(for: job.draft),
                progress: 1
            )
            appendLog("[hf] download completed for \(job.reference.repositoryID).")
            appendRuntimeEvent(
                category: "Download",
                severity: .success,
                message: job.draft.autoAddToModelList
                    ? "Download completed and profile registration finished."
                    : "Download completed. Auto-add was disabled.",
                japaneseMessage: job.draft.autoAddToModelList
                    ? "ダウンロードとプロファイル登録が完了しました。"
                    : "ダウンロードが完了しました。自動追加は無効です。",
                modelID: job.reference.repositoryID
            )
            appendLog("[hf] saved to \(ModelAvailabilityPathFormatter.compact(path: result.destinationPath)).")
            discardHuggingFaceDownloadRetry(queueEntryID: job.id)
            finishHuggingFaceDownload(job.id)
            drainHuggingFaceDownloadQueue()
        case let .failed(error):
            if completion.cancellationRequested || error is CancellationError || error as? HuggingFaceDownloadError == .cancelled {
                updateHuggingFaceQueueEntry(
                    job.id,
                    phase: .cancelled,
                    message: Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Download cancelled. The model was not added.",
                        japanese: "ダウンロードをキャンセルしました。モデルは追加されていません。"
                    )
                )
                appendLog("[hf] download cancelled for \(job.reference.repositoryID).")
                appendRuntimeEvent(
                    category: "Download",
                    severity: .warning,
                    message: "Download cancelled.",
                    japaneseMessage: "ダウンロードをキャンセルしました。",
                    modelID: job.reference.repositoryID
                )
            } else {
                let guidance = huggingFaceDownloadFailureGuidance(from: error)
                updateHuggingFaceQueueEntry(job.id, phase: .failed, message: guidance)
                appendLog("[hf] download failed for \(job.reference.repositoryID): \(guidance)")
                appendRuntimeEvent(
                    category: "Download",
                    severity: .failure,
                    message: guidance,
                    japaneseMessage: "ダウンロードに失敗しました: \(guidance)",
                    modelID: job.reference.repositoryID
                )
            }
            recordHuggingFaceDownloadRetry(job)
            finishHuggingFaceDownload(job.id)
            drainHuggingFaceDownloadQueue()
        }
    }

    func downloadedModelIntegrityFailureMessage(path: String) -> String? {
        switch localModelIntegrityChecker.check(path: path) {
        case .ready:
            return nil
        case let .incomplete(issue):
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Download completed, but the model files are incomplete: \(issue.message(language: .english))",
                japanese: "ダウンロードは完了しましたが、モデルファイルが不完全です: \(issue.message(language: .japanese))"
            )
        case let .notInspectable(message):
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Download completed, but the model files could not be verified: \(message)",
                japanese: "ダウンロードは完了しましたが、モデルファイルを検証できませんでした: \(message)"
            )
        }
    }

    private func finishHuggingFaceDownload(_ id: UUID) {
        huggingFaceOutputStateCoordinator.discard(queueEntryID: id)
        queuedHuggingFaceDownloads[id] = nil
        refreshAggregateHuggingFaceDownloadStatus()
    }

    var normalizedHuggingFaceRevision: String {
        let value = huggingFaceDownloadDraft.revision.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "main" : value
    }

    var currentHuggingFaceDraftIdentity: HuggingFaceFilePreviewIdentity? {
        guard let reference = huggingFaceDownloadPreview.reference else {
            return nil
        }
        return HuggingFaceFilePreviewIdentity(
            repositoryID: reference.repositoryID,
            revision: normalizedHuggingFaceRevision
        )
    }

    var huggingFaceFilePreviewMatchesCurrentDraft: Bool {
        guard let huggingFaceFilePreviewIdentity,
              let currentHuggingFaceDraftIdentity else {
            return false
        }
        return huggingFaceFilePreviewIdentity == currentHuggingFaceDraftIdentity
    }

    private func huggingFaceDownloadFailureGuidance(from error: Error) -> String {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        if lowercased.contains("command is not available") || lowercased.contains("no such file") {
            return Self.localizedText(language: settings.uiLanguage, english: "Hugging Face CLI was not found. Install `hf`, then press Retry CLI.", japanese: "Hugging Face CLIが見つかりません。`hf`をインストールしてからCLI再確認を押してください。")
        }
        if lowercased.contains("401") || lowercased.contains("403") || lowercased.contains("gated") || lowercased.contains("unauthorized") {
            return Self.localizedText(language: settings.uiLanguage, english: "This may be gated or require authentication. Open the model page in a browser and confirm access.", japanese: "ゲート付き、または認証が必要な可能性があります。ブラウザでモデルページを開き、アクセス権を確認してください。")
        }
        if lowercased.contains("404") || lowercased.contains("not found") || lowercased.contains("invalid") {
            return Self.localizedText(language: settings.uiLanguage, english: "Repository was not found. Confirm the model ID or choose another search result.", japanese: "リポジトリが見つかりません。Model IDを確認するか、別の検索結果を選択してください。")
        }
        if lowercased.contains("permission") || lowercased.contains("denied") {
            return Self.localizedText(language: settings.uiLanguage, english: "Permission denied. Choose another save folder or check folder permissions.", japanese: "権限がありません。別の保存フォルダを選択するか、フォルダ権限を確認してください。")
        }
        if lowercased.contains("network") || lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("could not resolve") {
            return Self.localizedText(language: settings.uiLanguage, english: "Network failure. Check the connection and retry the download.", japanese: "ネットワーク障害です。接続を確認し、ダウンロードを再試行してください。")
        }
        if lowercased.contains("disk") || lowercased.contains("space") || lowercased.contains("no space") {
            return Self.localizedText(language: settings.uiLanguage, english: "Disk or destination problem. Check free space and the save folder.", japanese: "ディスクまたは保存先の問題です。空き容量と保存フォルダを確認してください。")
        }
        return message
    }

    func setHuggingFaceDownloadStatus(_ status: HuggingFaceDownloadStatus) {
        var nextState = huggingFaceDownloadViewState
        nextState.setStatus(status)
        guard nextState != huggingFaceDownloadViewState else {
            return
        }
        huggingFaceDownloadViewState = nextState
    }

    private func refreshAggregateHuggingFaceDownloadStatus(
        in state: inout HuggingFaceDownloadViewState
    ) {
        let primaryID = state.refreshAggregateStatus(
            primaryID: huggingFaceOutputStateCoordinator.primaryID,
            outputLinesByID: huggingFaceOutputStateCoordinator.outputLinesByID
        )
        huggingFaceOutputStateCoordinator.setPrimary(primaryID)
    }

    func insertHuggingFaceDownloadQueueEntry(_ entry: HuggingFaceDownloadQueueEntry) {
        var nextState = huggingFaceDownloadViewState
        nextState.insert(entry)
        refreshAggregateHuggingFaceDownloadStatus(in: &nextState)
        huggingFaceDownloadViewState = nextState
    }

    func replaceHuggingFaceDownloadQueue(
        _ entries: [HuggingFaceDownloadQueueEntry],
        refreshAggregateStatus: Bool = true
    ) {
        var nextState = huggingFaceDownloadViewState
        nextState.replaceEntries(entries)
        if refreshAggregateStatus {
            refreshAggregateHuggingFaceDownloadStatus(in: &nextState)
        }
        guard nextState != huggingFaceDownloadViewState else {
            return
        }
        huggingFaceDownloadViewState = nextState
    }

    func updateHuggingFaceQueueEntry(
        _ id: UUID,
        phase: HuggingFaceDownloadPhase,
        message: String,
        progress: Double? = nil
    ) {
        var nextState = huggingFaceDownloadViewState
        guard nextState.updateEntry(
            id: id,
            phase: phase,
            message: message,
            progress: progress
        ) else {
            return
        }

        var removedIDs: Set<UUID> = []
        if phase.isTerminal {
            let result = HuggingFaceDownloadQueueScheduler.pruningTerminalHistory(
                entries: nextState.entries,
                maximumTerminalEntries: Self.maximumTerminalHuggingFaceDownloadHistory
            )
            if !result.removedIDs.isEmpty {
                nextState.replaceEntries(result.entries)
                removedIDs = result.removedIDs
                huggingFaceOutputStateCoordinator.clearPrimaryIfRemoved(removedIDs)
            }
        }

        refreshAggregateHuggingFaceDownloadStatus(in: &nextState)
        huggingFaceDownloadViewState = nextState

        guard !removedIDs.isEmpty else {
            return
        }
        huggingFaceDownloadRetryStore.retain(queueEntryIDs: Set(nextState.entries.map(\.id)))
        persistHuggingFaceDownloadRetries()
        for removedID in removedIDs {
            huggingFaceOutputStateCoordinator.discard(queueEntryID: removedID)
            queuedHuggingFaceDownloads[removedID] = nil
        }
    }

    func refreshAggregateHuggingFaceDownloadStatus() {
        var nextState = huggingFaceDownloadViewState
        refreshAggregateHuggingFaceDownloadStatus(in: &nextState)
        guard nextState != huggingFaceDownloadViewState else {
            return
        }
        huggingFaceDownloadViewState = nextState
    }

    func updateMeasuredHuggingFaceProgress(
        queueEntryID: UUID,
        downloadedBytes: Int64,
        downloadedFileCount: Int,
        totalBytes: Int64?,
        speedBytesPerSecond: Int64?
    ) {
        var nextState = huggingFaceDownloadViewState
        guard nextState.updateMeasuredProgress(
            queueEntryID: queueEntryID,
            downloadedBytes: downloadedBytes,
            downloadedFileCount: downloadedFileCount,
            totalBytes: totalBytes,
            speedBytesPerSecond: speedBytesPerSecond,
            language: settings.uiLanguage
        ) else {
            return
        }

        refreshAggregateHuggingFaceDownloadStatus(in: &nextState)
        huggingFaceDownloadViewState = nextState
    }

    func appendHuggingFaceOutputLine(_ line: String, queueEntryID: UUID? = nil) {
        let sanitizedLine = HuggingFaceDownloadPlanner.sanitizedOutputLine(line)
        guard !sanitizedLine.isEmpty else {
            return
        }

        guard let queueEntryID,
              let queueEntry = huggingFaceDownloadQueue.first(where: { $0.id == queueEntryID }),
              !queueEntry.phase.isTerminal else {
            appendLog(sanitizedLine)
            return
        }

        let requiresImmediateFlush = huggingFaceOutputStateCoordinator.appendPending(
            sanitizedLine,
            queueEntryID: queueEntryID,
            flushDelayNanoseconds: Self.huggingFaceOutputFlushDelayNanoseconds
        ) { [weak self] in
            self?.flushPendingHuggingFaceOutput(
                queueEntryID: queueEntryID,
                cancelScheduledTask: false
            )
        }
        if requiresImmediateFlush {
            flushPendingHuggingFaceOutput(queueEntryID: queueEntryID)
        }
    }

    func flushPendingHuggingFaceOutput(queueEntryID: UUID) {
        flushPendingHuggingFaceOutput(
            queueEntryID: queueEntryID,
            cancelScheduledTask: true
        )
    }

    private func flushPendingHuggingFaceOutput(
        queueEntryID: UUID,
        cancelScheduledTask: Bool
    ) {
        let lines = huggingFaceOutputStateCoordinator.drainPending(
            queueEntryID: queueEntryID,
            cancelScheduledFlush: cancelScheduledTask
        )
        applyHuggingFaceOutputBatch(lines, queueEntryID: queueEntryID)
    }

    func applyHuggingFaceOutputBatch(_ lines: [String], queueEntryID: UUID) {
        guard !lines.isEmpty else {
            return
        }

        if let queueEntry = huggingFaceDownloadQueue.first(where: { $0.id == queueEntryID }),
           !queueEntry.phase.isTerminal {
            huggingFaceOutputStateCoordinator.appendHistory(
                lines,
                queueEntryID: queueEntryID,
                maximumCount: Self.maximumVisibleHuggingFaceOutputLines
            )

            var nextState = huggingFaceDownloadViewState
            if lines.contains(where: { HuggingFaceDownloadPlanner.progressFraction(from: $0) != nil }) {
                _ = nextState.updateEntry(
                    id: queueEntryID,
                    phase: .downloading,
                    message: Self.localizedText(
                        language: settings.uiLanguage,
                        english: "Downloading",
                        japanese: "ダウンロード中"
                    )
                )
            }
            refreshAggregateHuggingFaceDownloadStatus(in: &nextState)
            if nextState != huggingFaceDownloadViewState {
                huggingFaceDownloadViewState = nextState
            }
        }

        appendLogs(lines)
    }

    func addDownloadedHuggingFaceModelProfile(
        reference: HuggingFaceModelReference,
        destinationPath: String,
        displayName: String,
        draft: HuggingFaceDownloadDraft
    ) -> String? {
        if models.contains(where: { $0.modelID == destinationPath }) {
            invalidateModelSizeCache(forDirectoryPath: destinationPath)
            lastAddedDownloadedModelID = destinationPath
            if draft.autoSelectAfterAdd {
                selectedModelID = destinationPath
            }
            appendLog(
                draft.autoSelectAfterAdd
                    ? "[hf] existing profile selected for \(ModelAvailabilityPathFormatter.compact(path: destinationPath))."
                    : "[hf] existing profile retained for \(ModelAvailabilityPathFormatter.compact(path: destinationPath))."
            )
            return nil
        }

        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? settings.defaultHost
            : draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings.defaultPort

        let model = ModelConfig(
            modelID: destinationPath,
            displayName: displayName,
            family: "Downloaded",
            quantization: "Hugging Face",
            localName: reference.name,
            host: host,
            serverPort: port,
            enableThinking: draft.enableThinking,
            notes: "Downloaded from \(reference.repositoryID).",
            advancedLaunchOptions: nil
        )

        let nextModels = models + [model]
        do {
            let outcome = try settingsStore.save(models: nextModels)
            invalidateModelSizeCache(for: model)
            invalidatePortCheckCache()
            models = nextModels
            lastAddedDownloadedModelID = model.id
            if draft.autoSelectAfterAdd {
                selectedModelID = model.id
            }
            selectedModelAvailabilitySummary = ModelAvailabilitySummary.checked(
                for: model,
                result: .present(path: destinationPath)
            )
            appendLog("[hf] added downloaded model to list: \(displayName).")
            appendSettingsSaveWarnings(outcome)
            return nil
        } catch {
            let message = "Downloaded, but profile add failed: \(error.localizedDescription)"
            appendLog("[hf] profile add failed after download: \(error.localizedDescription)")
            return message
        }
    }

    private func downloadCompletionMessage(for draft: HuggingFaceDownloadDraft) -> String {
        guard draft.autoAddToModelList else {
            return Self.localizedText(
                language: settings.uiLanguage,
                english: "Download completed. Auto-add was disabled.",
                japanese: "ダウンロードが完了しました。モデル一覧への自動追加は無効です。"
            )
        }
        return draft.autoSelectAfterAdd
            ? Self.localizedText(
                language: settings.uiLanguage,
                english: "Download completed. Added to model list and selected. Ready to start.",
                japanese: "ダウンロードが完了しました。モデル一覧へ追加して選択しました。起動できます。"
            )
            : Self.localizedText(
                language: settings.uiLanguage,
                english: "Download completed. Added to model list.",
                japanese: "ダウンロードが完了し、モデル一覧へ追加しました。"
            )
    }
}
