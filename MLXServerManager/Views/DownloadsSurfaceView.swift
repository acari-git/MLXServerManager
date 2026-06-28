import AppKit
import SwiftUI

struct DownloadsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenModels: () -> Void = {}

    private let contentWidth: CGFloat = 660
    private let controlWidth: CGFloat = 248
    private let cardCornerRadius: CGFloat = 8

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var downloadProgressText: String {
        if let progress = viewModel.huggingFaceDownloadStatus.progress {
            return "\(Int(progress * 100))%"
        }

        switch viewModel.huggingFaceDownloadStatus.phase {
        case .waiting:
            return t("Waiting", "待機中")
        case .preparing:
            return t("Preparing", "準備中")
        case .downloading:
            return t("Reading progress", "進捗取得中")
        case .finalizing:
            return t("Finalizing", "最終処理中")
        case .completed:
            return "100%"
        case .failed:
            return t("Failed", "失敗")
        case .cancelled:
            return t("Cancelled", "キャンセル")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                settingsSection(title: t("Status", "状態"), content: statusSectionContent)

                if viewModel.latestFailedHuggingFaceDownloadQueueEntry != nil {
                    settingsSection(title: t("Recovery", "復旧"), content: recoveryCard)
                }

                settingsSection(title: t("Tools", "ツール"), content: downloadEnvironmentCard)
                settingsSection(title: t("Search", "検索"), content: searchCard)
                settingsSection(title: strings.text(.download), content: downloadFormCard)
            }
            .padding(.top, 64)
            .padding(.bottom, 56)
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("downloads-surface")
    }

    private var header: some View {
        Text(strings.text(.downloads))
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
    }

    private func settingsSection<Content: View>(title: String, content: Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
                )
        }
    }

    private var statusSectionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            downloadCommandDeck
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.80))
                .frame(height: 1.0)
                .padding(.horizontal, -16)
                .padding(.vertical, 16)
            queueCard
        }
    }

    private var downloadCommandDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                downloadStateHero
                VStack(spacing: 10) {
                    downloadMetricCard(
                        title: t("Queue", "キュー"),
                        value: String(viewModel.huggingFaceDownloadQueue.count),
                        detail: viewModel.huggingFaceDownloadQueueSummary,
                        systemImage: "tray.full"
                    )
                    downloadMetricCard(
                        title: "aria2c",
                        value: viewModel.aria2Availability.displayPath,
                        detail: t("Downloader availability", "ダウンローダー状態"),
                        systemImage: "bolt.horizontal.circle"
                    )
                }
                .frame(width: 260)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downloadStateHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Download command center", "ダウンロード操作センター"))
                        .font(.system(size: 14, weight: .medium))
                    Text(viewModel.huggingFaceDownloadStatus.phase.localizedTitle(language: viewModel.settings.uiLanguage))
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Text(downloadProgressText)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            if let progress = viewModel.huggingFaceDownloadStatus.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: viewModel.huggingFaceDownloadStatus.phase == .completed ? 1 : 0)
                    .progressViewStyle(.linear)
            }

            Text(viewModel.huggingFaceDownloadStatus.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Button(t("Preview files", "ファイルをプレビュー")) { viewModel.previewHuggingFaceFilesRequested() }
                    .disabled(viewModel.huggingFaceFilePreview.isLoading || viewModel.isHuggingFaceDownloadRunning)
                Button(strings.text(.download)) { viewModel.startHuggingFaceDownloadRequested() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartHuggingFaceDownload)
                Button(strings.text(.cancel)) { viewModel.cancelHuggingFaceDownloadRequested() }
                    .disabled(!viewModel.isHuggingFaceDownloadRunning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func downloadMetricCard(title: String, value: String, detail: String, systemImage: String) -> some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var recoveryCard: some View {
        if let failed = viewModel.latestFailedHuggingFaceDownloadQueueEntry {
            VStack(alignment: .leading, spacing: 10) {
                Label(t("Latest failed download", "直近の失敗したダウンロード"), systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.orange)
                detailRows([
                    (t("Repository", "リポジトリ"), failed.repositoryID),
                    (t("Destination", "保存先"), failed.compactDestinationPath),
                    (t("Message", "メッセージ"), failed.message)
                ])
                HStack {
                    Button(t("Restore form", "フォームに復元")) {
                        viewModel.restoreHuggingFaceDownloadForm(from: failed)
                    }
                    Button(t("Copy URL", "URLをコピー")) {
                        viewModel.copyHuggingFaceDownloadURL(from: failed)
                    }
                    Button(strings.text(.retry)) {
                        viewModel.retryHuggingFaceDownloadRequested()
                    }
                    .disabled(!viewModel.canRetryHuggingFaceDownload)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var downloadEnvironmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Download tools", "ダウンロードツール確認"))
                .font(.system(size: 14, weight: .medium))
            Text(t("Checks download prerequisites. Model search is the separate search area below.", "ダウンロードの前提条件を確認します。モデル検索は下の別エリアです。"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            detailRows([
                ("aria2c", viewModel.aria2Availability.displayPath),
                (t("Auto restart", "自動再開"), viewModel.enableDownloadAutoRestart ? t("Enabled below \(viewModel.lowSpeedRestartThresholdText)", "\(viewModel.lowSpeedRestartThresholdText)未満で有効") : t("Disabled", "無効"))
            ])
            HStack {
                Button(t("Check aria2c", "aria2cを確認")) { viewModel.refreshAria2Status() }
            }
            Toggle(t("Enable low-speed auto-restart policy", "低速時の自動再開ポリシーを有効にする"), isOn: $viewModel.enableDownloadAutoRestart)
                .toggleStyle(.checkbox)
            HStack {
                Text(t("Low-speed threshold", "低速判定しきい値"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("50K", text: $viewModel.lowSpeedRestartThresholdText, prompt: Text("50K").foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: controlWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isHuggingFaceSearchActive: Bool {
        !viewModel.huggingFaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var huggingFaceSearchField: some View {
        HStack(spacing: 8) {
            TextField(
                t("Search by repository or model name", "リポジトリ名またはモデル名で検索"),
                text: $viewModel.huggingFaceSearchQuery,
                prompt: Text(t("Search by repository or model name", "リポジトリ名またはモデル名で検索")).foregroundStyle(.tertiary)
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))
            .frame(width: controlWidth, alignment: .leading)
            .onSubmit {
                viewModel.performHuggingFaceSearchRequested()
            }

            if isHuggingFaceSearchActive {
                Button {
                    viewModel.huggingFaceSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .help(t("Clear search", "検索をクリア"))
            }
        }
        .accessibilityIdentifier("downloads-huggingface-search-field")
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Hugging Face search", "Hugging Face検索"))
                .font(.system(size: 14, weight: .medium))

            HStack(spacing: 10) {
                huggingFaceSearchField
                Button {
                    viewModel.performHuggingFaceSearchRequested()
                } label: {
                    if viewModel.isHuggingFaceSearching {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label(strings.text(.search), systemImage: AppSymbol.search)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isHuggingFaceSearching)
            }

            Toggle(t("Show MLX-like results only", "MLXらしい候補だけ表示"), isOn: $viewModel.showOnlyMLXLikelySearchResults)
                .toggleStyle(.checkbox)
                .disabled(viewModel.huggingFaceSearchResults.isEmpty)

            Text(viewModel.huggingFaceSearchMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.visibleHuggingFaceSearchResults.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.visibleHuggingFaceSearchResults.prefix(6)) { result in
                        Button {
                            viewModel.selectHuggingFaceSearchResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(result.id)
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Text(result.isMLXLikely ? t("MLX-like", "MLX系") : t("Review", "要確認"))
                                        .font(.caption2.weight(.semibold))
                                }
                                Text(result.qualitySummary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(result.selectionWarning)
                                    .font(.caption2)
                                    .foregroundStyle(result.isMLXLikely ? Color.secondary : Color.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selected = viewModel.selectedHuggingFaceSearchResult {
                detailRows([
                    (t("Selected", "選択中"), selected.id),
                    (t("Owner", "所有者"), selected.owner),
                    (t("Stats", "統計"), selected.qualitySummary),
                    (t("Tags", "タグ"), selected.tagsSummary),
                    ("URL", selected.webURL)
                ])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downloadFormCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(t("Repository ID or URL", "リポジトリIDまたはURL"), text: $viewModel.huggingFaceDownloadDraft.source, prompt: Text(t("Repository ID or URL", "リポジトリIDまたはURL")).foregroundStyle(.tertiary))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: controlWidth, alignment: .leading)
            HStack {
                TextField(t("Revision", "リビジョン"), text: $viewModel.huggingFaceDownloadDraft.revision, prompt: Text(t("Revision", "リビジョン")).foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: controlWidth, alignment: .leading)
                TextField(t("Display name", "表示名"), text: $viewModel.huggingFaceDownloadDraft.displayName, prompt: Text(t("Display name", "表示名")).foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: controlWidth, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button(t("MLX preset", "MLXプリセット")) { viewModel.applyHuggingFaceMLXPreset() }
                    Button("Safetensors") { viewModel.applyHuggingFaceSafeTensorPreset() }
                    Button(t("No filters", "フィルターなし")) { viewModel.clearHuggingFaceFileFilters() }
                    Spacer()
                }
                TextField(t("Include patterns", "含めるパターン"), text: $viewModel.huggingFaceDownloadDraft.includePatterns, prompt: Text("*.safetensors, *.json, tokenizer*").foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: controlWidth, alignment: .leading)
                TextField(t("Exclude patterns", "除外するパターン"), text: $viewModel.huggingFaceDownloadDraft.excludePatterns, prompt: Text("*.onnx, *.msgpack, *.bin").foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: controlWidth, alignment: .leading)
                Text(t("Patterns are comma-separated. Preview files first, then download selected or filtered files.", "パターンはカンマ区切りです。先にファイルをプレビューし、選択済みまたはフィルター済みのファイルをダウンロードします。"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField(t("Save directory", "保存先フォルダ"), text: $viewModel.huggingFaceDownloadDraft.saveDirectory, prompt: Text("~/Models/mlx").foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: controlWidth, alignment: .leading)
                Button(t("Choose", "選択")) {
                    viewModel.chooseHuggingFaceDownloadDirectoryRequested()
                }
                .disabled(viewModel.isHuggingFaceDownloadRunning)
            }

            detailRows([
                (t("Preview", "プレビュー"), viewModel.huggingFaceDownloadPreview.compactDestinationPath),
                (t("Files", "ファイル"), viewModel.huggingFaceSelectedPreviewSummary),
                (t("Status", "ステータス"), viewModel.huggingFaceDownloadStatus.phase.localizedTitle(language: viewModel.settings.uiLanguage)),
                (t("Message", "メッセージ"), viewModel.huggingFaceDownloadStatus.message)
            ])

            downloadProgressPanel

            filePreviewPanel

            if viewModel.huggingFaceDownloadStatus.phase == .completed {
                HStack {
                    Label(t("Download complete. The profile has been added when possible.", "ダウンロードが完了しました。可能な場合はプロファイルを追加済みです。"), systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button(t("Open Models", "モデルを開く")) { onOpenModels() }
                }
            }

            HStack {
                Button {
                    viewModel.previewHuggingFaceFilesRequested()
                } label: {
                    Label(t("Preview files", "ファイルをプレビュー"), systemImage: "list.bullet.rectangle")
                }
                .disabled(viewModel.huggingFaceFilePreview.isLoading || viewModel.isHuggingFaceDownloadRunning)

                Button {
                    viewModel.startHuggingFaceDownloadRequested()
                } label: {
                    Label(strings.text(.download), systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartHuggingFaceDownload)

                Button(strings.text(.retry)) {
                    viewModel.retryHuggingFaceDownloadRequested()
                }
                .disabled(!viewModel.canRetryHuggingFaceDownload)

                Button(strings.text(.cancel)) {
                    viewModel.cancelHuggingFaceDownloadRequested()
                }
                .disabled(!viewModel.isHuggingFaceDownloadRunning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downloadProgressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Download progress", "ダウンロード進捗"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(downloadProgressText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let progress = viewModel.huggingFaceDownloadStatus.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            } else if viewModel.isHuggingFaceDownloadRunning {
                ProgressView()
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: 0)
                    .progressViewStyle(.linear)
            }
            if let repositoryID = viewModel.huggingFaceDownloadStatus.repositoryID {
                Text(repositoryID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier("hf-download-progress-panel")
    }

    private var filePreviewPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("File preview", "ファイルプレビュー"))
                    .font(.caption.weight(.semibold))
                Spacer()
                if viewModel.huggingFaceFilePreview.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            Toggle(t("Use selected preview files", "選択したプレビューファイルを使用"), isOn: $viewModel.huggingFaceDownloadDraft.useSelectedPreviewFiles)
                .toggleStyle(.checkbox)
                .disabled(viewModel.huggingFaceFilePreview.files.isEmpty)
            HStack {
                Text(viewModel.huggingFaceFilePreview.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(t("Select filtered", "フィルター結果を選択")) { viewModel.selectAllHuggingFacePreviewFiles() }
                    .disabled(viewModel.filteredHuggingFacePreviewFiles.isEmpty)
                Button(t("Clear", "クリア")) { viewModel.clearHuggingFacePreviewSelection() }
                    .disabled(viewModel.selectedHuggingFacePreviewFileIDs.isEmpty)
            }
            previewFileList
        }
    }

    @ViewBuilder
    private var previewFileList: some View {
        if !viewModel.filteredHuggingFacePreviewFiles.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.filteredHuggingFacePreviewFiles.prefix(16)) { file in
                    HStack(spacing: 8) {
                        Button {
                            viewModel.toggleHuggingFacePreviewFile(file)
                        } label: {
                            Image(systemName: viewModel.selectedHuggingFacePreviewFileIDs.contains(file.id) ? "checkmark.square" : "square")
                        }
                        .buttonStyle(.plain)
                        Text(file.path)
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                        Spacer()
                        Text(file.compactSize)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func queueProgressView(for entry: HuggingFaceDownloadQueueEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let fraction = entry.progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
            } else if entry.phase == .downloading || entry.phase == .preparing || entry.phase == .finalizing {
                ProgressView()
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: entry.phase == .completed ? 1 : 0)
                    .progressViewStyle(.linear)
            }
            Text(entry.progressText)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("hf-download-queue-progress-\(entry.id.uuidString)")
    }

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.text(.downloadQueue))
                .font(.system(size: 14, weight: .medium))
            Text(viewModel.huggingFaceDownloadQueueSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.huggingFaceDownloadQueue.isEmpty {
                Text(t("No downloads in this session.", "このセッションのダウンロードはありません。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.huggingFaceDownloadQueue.prefix(8)) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.repositoryID)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(entry.phase.localizedTitle(language: viewModel.settings.uiLanguage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.compactDestinationPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        queueProgressView(for: entry)
                        HStack {
                            Button(t("Restore form", "フォームに復元")) {
                                viewModel.restoreHuggingFaceDownloadForm(from: entry)
                            }
                            Button(t("Copy URL", "URLをコピー")) {
                                viewModel.copyHuggingFaceDownloadURL(from: entry)
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRows(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.0)
                            .font(.system(size: 13, weight: .medium))
                        Text(t("Current value for this item.", "この項目の現在値です。"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 20)
                    Text(row.1)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .frame(width: controlWidth, alignment: .leading)
                }
                .padding(.vertical, 14)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.80))
                        .frame(height: 1.0)
                        .padding(.horizontal, -16)
                }
            }
        }
    }
}
