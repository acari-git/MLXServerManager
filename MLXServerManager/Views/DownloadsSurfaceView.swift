import AppKit
import SwiftUI

struct DownloadsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenModels: () -> Void = {}

    private let contentWidth: CGFloat = 760
    private let controlWidth: CGFloat = 300

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

    private var shouldShowTransferSection: Bool {
        viewModel.isHuggingFaceDownloadRunning || viewModel.huggingFaceDownloadStatus.phase != .waiting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                searchSection
                if shouldShowTransferSection {
                    transferSection
                }
                if !viewModel.huggingFaceDownloadQueue.isEmpty {
                    recentDownloadsSection
                }
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
            Text(t("Add an MLX model from Hugging Face. Paste a model ID or URL, review the target, then download.", "Hugging FaceからMLXモデルを追加します。モデルIDまたはURLを貼り付け、内容を確認してダウンロードします。"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func section<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
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
        }
        .groupBoxStyle(.automatic)
    }

    private var searchSection: some View {
        section(
            title: strings.text(.search),
            subtitle: t("Use a Hugging Face model ID such as owner/model-name, or paste a model URL.", "owner/model-name 形式のHugging FaceモデルID、またはモデルURLを貼り付けます。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    TextField(
                        t("Hugging Face model ID or URL", "Hugging FaceモデルIDまたはURL"),
                        text: $viewModel.huggingFaceDownloadDraft.source,
                        prompt: Text(t("Hugging Face model ID or URL", "Hugging FaceモデルIDまたはURL")).foregroundStyle(.tertiary)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(minWidth: 360, maxWidth: .infinity, alignment: .leading)
                    .onSubmit {
                        viewModel.huggingFaceSearchQuery = viewModel.huggingFaceDownloadDraft.source
                        viewModel.performHuggingFaceSearchRequested()
                    }

                    Button {
                        viewModel.huggingFaceSearchQuery = viewModel.huggingFaceDownloadDraft.source
                        viewModel.performHuggingFaceSearchRequested()
                    } label: {
                        if viewModel.isHuggingFaceSearching {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label(strings.text(.search), systemImage: AppSymbol.search)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isHuggingFaceSearching || viewModel.huggingFaceDownloadDraft.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                HStack(spacing: 10) {
                    Toggle(t("Show MLX-tagged results only", "MLXタグ付きのみ表示"), isOn: $viewModel.showOnlyMLXLikelySearchResults)
                        .toggleStyle(.checkbox)
                        .disabled(viewModel.huggingFaceSearchResults.isEmpty)
                    Spacer()
                    Text(t("Download requires a verified MLX tag.", "ダウンロードにはMLXタグ確認が必要です。"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.huggingFaceSearchMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !viewModel.visibleHuggingFaceSearchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.visibleHuggingFaceSearchResults.prefix(6)) { result in
                            searchResultRow(result)
                        }
                    }
                }

                Divider()
                    .opacity(0.55)

                downloadReviewContent
            }
        }
    }

    private func searchResultRow(_ result: HuggingFaceSearchResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: viewModel.selectedHuggingFaceSearchResult?.id == result.id ? "checkmark.seal.fill" : "circle")
                .foregroundStyle(viewModel.selectedHuggingFaceSearchResult?.id == result.id ? Color.green : Color.secondary)
                .padding(.top, 2)
                .help(t("Verified download target", "確認済みのダウンロード対象"))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(result.id)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(result.compatibility.badgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(result.isSupportedForDownload ? Color.green : Color.red)
                }
                Text(result.qualitySummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(result.selectionMessage(language: viewModel.settings.uiLanguage))
                    .font(.caption2)
                    .foregroundStyle(result.isSupportedForDownload ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.16), lineWidth: 1)
        )
    }

    private var downloadReviewContent: some View {
        HStack(spacing: 10) {
                Button {
                    viewModel.startHuggingFaceDownloadRequested()
                } label: {
                    Label(strings.text(.download), systemImage: "arrow.down.circle")
                        .frame(width: 128, alignment: .center)
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
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: {
                                            viewModel.selectedHuggingFacePreviewFileIDs.contains(file.id)
                                        },
                                        set: { isSelected in
                                            if isSelected != viewModel.selectedHuggingFacePreviewFileIDs.contains(file.id) {
                                                viewModel.toggleHuggingFacePreviewFile(file)
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(.checkbox)
                                .labelsHidden()
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
            title: t("Download status", "ダウンロード状況"),
            subtitle: t("The current download job is shown here.", "現在のダウンロード処理を表示します。")
        ) {
            progressPanel
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: viewModel.huggingFaceDownloadStatus.phase == .completed ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(viewModel.huggingFaceDownloadStatus.phase == .completed ? Color.green : Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.huggingFaceDownloadStatus.phase.localizedTitle(language: viewModel.settings.uiLanguage))
                        .font(.callout.weight(.semibold))
                    Text(activeProgressHeadline)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(downloadProgressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            progressBar(for: viewModel.latestHuggingFaceDownloadEntry)

            if let entry = viewModel.latestHuggingFaceDownloadEntry {
                HStack(spacing: 8) {
                    progressMetricPill(title: t("Files", "ファイル"), value: entry.fileProgressText)
                    progressMetricPill(title: t("Total", "全体"), value: entry.capacityProgressText)
                    if let speed = entry.speedBytesPerSecond, speed > 0 {
                        progressMetricPill(title: t("Speed", "速度"), value: "\(ByteCountFormatter.string(fromByteCount: speed, countStyle: .file))/s")
                    }
                }
            }

            Text(viewModel.huggingFaceDownloadStatus.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if viewModel.huggingFaceDownloadStatus.phase == .completed {
                Label(t("Download complete. The added model is marked in the model list.", "ダウンロードが完了しました。追加されたモデルはモデル一覧でマーク表示されます。"), systemImage: "sparkle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func progressBar(for entry: HuggingFaceDownloadQueueEntry?) -> some View {
        if let fraction = entry?.progressFraction {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
        } else if viewModel.isHuggingFaceDownloadRunning || viewModel.huggingFaceDownloadStatus.phase == .preparing {
            ProgressView()
                .progressViewStyle(.linear)
        } else {
            ProgressView(value: viewModel.huggingFaceDownloadStatus.phase == .completed ? 1 : 0)
                .progressViewStyle(.linear)
        }
    }

    private var activeProgressHeadline: String {
        guard let entry = viewModel.latestHuggingFaceDownloadEntry else {
            return viewModel.huggingFaceDownloadStatus.message
        }
        guard entry.progressFraction != nil else {
            return t("Preparing total size and file count", "総容量とファイル数を確認中")
        }
        return "\(t("File", "ファイル")) \(entry.fileProgressText) • \(entry.capacityProgressText)"
    }

    private func progressMetricPill(title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36), in: Capsule())
    }

    private var recentDownloadsSection: some View {
        section(
            title: t("Recent downloads", "最近のダウンロード"),
            subtitle: t("Recent and queued model download jobs.", "直近またはキュー内のモデルダウンロードです。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.huggingFaceDownloadQueue.prefix(8)) { entry in
                    queueRow(entry)
                }
            }
        }
    }

    private func queueRow(_ entry: HuggingFaceDownloadQueueEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
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
            HStack(spacing: 8) {
                progressMetricPill(title: t("Files", "ファイル"), value: entry.fileProgressText)
                progressMetricPill(title: t("Total", "全体"), value: entry.capacityProgressText)
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button(t("Restore", "復元")) { viewModel.restoreHuggingFaceDownloadForm(from: entry) }
                Button(t("Copy URL", "URLをコピー")) { viewModel.copyHuggingFaceDownloadURL(from: entry) }
                Spacer()
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.16), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
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
                .padding(.vertical, 9)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.45))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 2)
    }
}
