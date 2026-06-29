import AppKit
import SwiftUI

struct DownloadsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenModels: () -> Void = {}

    private enum DownloadSchedulingMode: String, CaseIterable, Identifiable {
        case queue
        case parallel

        var id: String { rawValue }
    }

    @State private var schedulingMode: DownloadSchedulingMode = .queue

    private let contentWidth: CGFloat = 760
    private let controlWidth: CGFloat = 300
    private let cardCornerRadius: CGFloat = 10

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
            return t("Downloading", "ダウンロード中")
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
            VStack(alignment: .leading, spacing: 28) {
                header
                searchSection
                destinationSection
                downloadFormSection
                transferSection
                queueSection
            }
            .padding(.top, 12)
            .padding(.bottom, 56)
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("downloads-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.text(.downloads))
                .font(.title3)
            Text(t("Search Hugging Face, choose a save location, and download MLX model files.", "Hugging Faceから検索し、保存先を選んでMLXモデルファイルをダウンロードします。"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func section<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
                )
        }
    }

    private var searchSection: some View {
        section(
            title: t("Search", "検索"),
            subtitle: t("Find models on Hugging Face. Use the MLX filter to avoid unrelated repositories.", "Hugging Face上のモデルを検索します。MLXフィルタで無関係な候補を減らします。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    TextField(
                        t("Repository, model name, or Hugging Face URL", "リポジトリ名、モデル名、Hugging Face URL"),
                        text: $viewModel.huggingFaceSearchQuery,
                        prompt: Text(t("Repository, model name, or Hugging Face URL", "リポジトリ名、モデル名、Hugging Face URL")).foregroundStyle(.tertiary)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(minWidth: 360, maxWidth: .infinity, alignment: .leading)
                    .onSubmit {
                        viewModel.performHuggingFaceSearchRequested()
                    }

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

                Toggle(t("Show MLX format only", "MLX形式のみ表示"), isOn: $viewModel.showOnlyMLXLikelySearchResults)
                    .toggleStyle(.checkbox)
                    .disabled(viewModel.huggingFaceSearchResults.isEmpty)

                Text(viewModel.huggingFaceSearchMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !viewModel.visibleHuggingFaceSearchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.visibleHuggingFaceSearchResults.prefix(8)) { result in
                            searchResultRow(result)
                        }
                    }
                }
            }
        }
    }

    private func searchResultRow(_ result: HuggingFaceSearchResult) -> some View {
        Button {
            viewModel.selectHuggingFaceSearchResult(result)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.id)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(result.isMLXLikely ? t("MLX", "MLX") : t("Review", "要確認"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(result.isMLXLikely ? Color.green : Color.orange)
                }
                Text(result.qualitySummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(result.selectionWarning)
                    .font(.caption2)
                    .foregroundStyle(result.isMLXLikely ? Color.secondary : Color.orange)
                    .lineLimit(2)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                viewModel.selectedHuggingFaceSearchResult?.id == result.id
                ? Color(nsColor: .controlAccentColor).opacity(0.12)
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var destinationSection: some View {
        section(
            title: t("Save Location", "保存先"),
            subtitle: t("Downloaded models are saved under this folder and can be added to the model list automatically.", "ダウンロードしたモデルはこのフォルダ配下へ保存し、モデル一覧へ自動追加できます。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField(
                        t("Save directory", "保存先フォルダ"),
                        text: $viewModel.huggingFaceDownloadDraft.saveDirectory,
                        prompt: Text("~/Models/mlx").foregroundStyle(.tertiary)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(width: controlWidth, alignment: .leading)

                    Button(t("Choose", "選択")) {
                        viewModel.chooseHuggingFaceDownloadDirectoryRequested()
                    }
                    .disabled(viewModel.isHuggingFaceDownloadRunning)
                }

                HStack(spacing: 18) {
                    Toggle(t("Add to model list after download", "完了後にモデル一覧へ追加"), isOn: $viewModel.huggingFaceDownloadDraft.autoAddToModelList)
                        .toggleStyle(.checkbox)
                    Toggle(t("Select added model", "追加したモデルを選択"), isOn: $viewModel.huggingFaceDownloadDraft.autoSelectAfterAdd)
                        .toggleStyle(.checkbox)
                        .disabled(!viewModel.huggingFaceDownloadDraft.autoAddToModelList)
                }

                compactRows([
                    (t("Destination preview", "保存先プレビュー"), viewModel.huggingFaceDownloadPreview.compactDestinationPath),
                    (t("Status", "状態"), viewModel.huggingFaceDownloadPreview.message)
                ])
            }
        }
    }

    private var downloadFormSection: some View {
        section(
            title: strings.text(.download),
            subtitle: t("Select a repository, preview files if needed, then start the download.", "リポジトリを選択し、必要に応じてファイル確認後にダウンロードします。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    TextField(
                        t("Repository ID or URL", "リポジトリIDまたはURL"),
                        text: $viewModel.huggingFaceDownloadDraft.source,
                        prompt: Text(t("Repository ID or URL", "リポジトリIDまたはURL")).foregroundStyle(.tertiary)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(width: controlWidth, alignment: .leading)

                    TextField(
                        t("Display name", "表示名"),
                        text: $viewModel.huggingFaceDownloadDraft.displayName,
                        prompt: Text(t("Display name", "表示名")).foregroundStyle(.tertiary)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(width: controlWidth, alignment: .leading)
                }

                HStack(spacing: 10) {
                    TextField(
                        t("Revision", "リビジョン"),
                        text: $viewModel.huggingFaceDownloadDraft.revision,
                        prompt: Text("main").foregroundStyle(.tertiary)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(width: 160, alignment: .leading)

                    Button(t("MLX preset", "MLXプリセット")) { viewModel.applyHuggingFaceMLXPreset() }
                    Button(t("Preview files", "ファイルを確認")) { viewModel.previewHuggingFaceFilesRequested() }
                        .disabled(viewModel.huggingFaceFilePreview.isLoading || viewModel.isHuggingFaceDownloadRunning)
                }

                filePreviewSummary

                HStack(spacing: 10) {
                    Button {
                        viewModel.startHuggingFaceDownloadRequested()
                    } label: {
                        Label(strings.text(.download), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartHuggingFaceDownload)

                    Button(strings.text(.retry)) { viewModel.retryHuggingFaceDownloadRequested() }
                        .disabled(!viewModel.canRetryHuggingFaceDownload)

                    Button(strings.text(.cancel)) { viewModel.cancelHuggingFaceDownloadRequested() }
                        .disabled(!viewModel.isHuggingFaceDownloadRunning)

                    if viewModel.huggingFaceDownloadStatus.phase == .completed {
                        Spacer()
                        Button(t("Open Models", "モデル一覧を開く")) { onOpenModels() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var filePreviewSummary: some View {
        if viewModel.huggingFaceFilePreview.isLoading {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text(t("Loading file preview...", "ファイル一覧を確認中..."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(t("Use selected preview files", "選択したファイルだけ使用"), isOn: $viewModel.huggingFaceDownloadDraft.useSelectedPreviewFiles)
                    .toggleStyle(.checkbox)
                    .disabled(viewModel.huggingFaceFilePreview.files.isEmpty)

                HStack {
                    Text(viewModel.huggingFaceSelectedPreviewSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(t("Select filtered", "フィルター結果を選択")) { viewModel.selectAllHuggingFacePreviewFiles() }
                        .disabled(viewModel.filteredHuggingFacePreviewFiles.isEmpty)
                    Button(t("Clear", "クリア")) { viewModel.clearHuggingFacePreviewSelection() }
                        .disabled(viewModel.selectedHuggingFacePreviewFileIDs.isEmpty)
                }

                if !viewModel.filteredHuggingFacePreviewFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.filteredHuggingFacePreviewFiles.prefix(10)) { file in
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
        }
    }

    private var transferSection: some View {
        section(
            title: t("Transfer", "転送"),
            subtitle: t("Track progress and choose how future multi-download jobs should be handled.", "進捗確認と、今後の複数ダウンロード時の扱いを選びます。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Picker(t("Download mode", "ダウンロード方式"), selection: $schedulingMode) {
                    Text(t("Queue", "順番にダウンロード")).tag(DownloadSchedulingMode.queue)
                    Text(t("Parallel", "同時にダウンロード")).tag(DownloadSchedulingMode.parallel)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Text(
                    schedulingMode == .queue
                    ? t("Current backend runs one active download at a time and keeps completed or failed jobs in the queue list.", "現在の内部処理は1件ずつ実行し、完了・失敗したジョブをキュー一覧に残します。")
                    : t("Parallel mode is shown here as the target UX. Backend parallel execution will be enabled after the single-task downloader is replaced.", "同時ダウンロードは目標UXとして表示しています。内部の単一タスク処理を置き換えた後に有効化します。")
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                progressPanel
            }
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.huggingFaceDownloadStatus.phase.localizedTitle(language: viewModel.settings.uiLanguage))
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(downloadProgressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let progress = viewModel.huggingFaceDownloadStatus.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            } else if viewModel.isHuggingFaceDownloadRunning {
                ProgressView()
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: viewModel.huggingFaceDownloadStatus.phase == .completed ? 1 : 0)
                    .progressViewStyle(.linear)
            }

            Text(viewModel.huggingFaceDownloadStatus.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if viewModel.huggingFaceDownloadStatus.phase == .completed {
                Label(t("Download complete. The model has been added when possible.", "ダウンロードが完了しました。可能な場合はモデル一覧へ追加済みです。"), systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var queueSection: some View {
        section(
            title: strings.text(.downloadQueue),
            subtitle: t("Recent downloads and queued jobs are listed here.", "直近のダウンロードとキュー内ジョブを表示します。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.huggingFaceDownloadQueue.isEmpty {
                    Text(t("No downloads in this session.", "このセッションのダウンロードはありません。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.huggingFaceDownloadQueue.prefix(10)) { entry in
                        queueRow(entry)
                    }
                }
            }
        }
    }

    private func queueRow(_ entry: HuggingFaceDownloadQueueEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
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
            HStack(spacing: 10) {
                Button(t("Restore", "復元")) { viewModel.restoreHuggingFaceDownloadForm(from: entry) }
                Button(t("Copy URL", "URLをコピー")) { viewModel.copyHuggingFaceDownloadURL(from: entry) }
                Spacer()
            }
        }
        .padding(.vertical, 6)
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
    }

    private func compactRows(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Text(row.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                    Text(row.1)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
