import SwiftUI

struct DownloadsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchCard
                downloadFormCard
                queueCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("downloads-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Downloads")
                    .font(.title2.weight(.semibold))
            }
            Text("Search Hugging Face, review the selected result, download explicitly, and recover failed queue entries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hugging Face search")
                .font(.headline)

            HStack {
                TextField("mlx-community/Qwen...", text: $viewModel.huggingFaceSearchQuery)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.performHuggingFaceSearchRequested()
                } label: {
                    if viewModel.isHuggingFaceSearching {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                .disabled(viewModel.isHuggingFaceSearching)
            }

            Toggle("Show MLX-like results only", isOn: $viewModel.showOnlyMLXLikelySearchResults)
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
                                    Text(result.isMLXLikely ? "MLX-like" : "Review")
                                        .font(.caption2.weight(.semibold))
                                }
                                Text(result.qualitySummary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(result.selectionWarning)
                                    .font(.caption2)
                                    .foregroundStyle(result.isMLXLikely ? Color.secondary : Color.orange)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selected = viewModel.selectedHuggingFaceSearchResult {
                DetailGrid(rows: [
                    ("Selected", selected.id),
                    ("Owner", selected.owner),
                    ("Stats", selected.qualitySummary),
                    ("Tags", selected.tagsSummary),
                    ("URL", selected.webURL)
                ])
            }
        }
        .panelStyle()
    }

    private var downloadFormCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download form")
                .font(.headline)

            TextField("Repository ID or URL", text: $viewModel.huggingFaceDownloadDraft.source)
                .textFieldStyle(.roundedBorder)
            TextField("Display name", text: $viewModel.huggingFaceDownloadDraft.displayName)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Save directory", text: $viewModel.huggingFaceDownloadDraft.saveDirectory)
                    .textFieldStyle(.roundedBorder)
                Button("Choose") {
                    viewModel.chooseHuggingFaceDownloadDirectoryRequested()
                }
                .disabled(viewModel.isHuggingFaceDownloadRunning)
            }

            DetailGrid(rows: [
                ("Preview", viewModel.huggingFaceDownloadPreview.compactDestinationPath),
                ("Status", viewModel.huggingFaceDownloadStatus.phase.title),
                ("Message", viewModel.huggingFaceDownloadStatus.message)
            ])

            HStack {
                Button {
                    viewModel.startHuggingFaceDownloadRequested()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartHuggingFaceDownload)

                Button("Retry") {
                    viewModel.retryHuggingFaceDownloadRequested()
                }
                .disabled(!viewModel.canRetryHuggingFaceDownload)

                Button("Cancel") {
                    viewModel.cancelHuggingFaceDownloadRequested()
                }
                .disabled(!viewModel.isHuggingFaceDownloadRunning)
            }
        }
        .panelStyle()
    }

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download queue")
                .font(.headline)
            Text(viewModel.huggingFaceDownloadQueueSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.huggingFaceDownloadQueue.isEmpty {
                Text("No downloads in this session.")
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
                            Text(entry.phase.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.compactDestinationPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack {
                            Button("Restore form") {
                                viewModel.restoreHuggingFaceDownloadForm(from: entry)
                            }
                            Button("Copy URL") {
                                viewModel.copyHuggingFaceDownloadURL(from: entry)
                            }
                            Spacer()
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .panelStyle()
    }
}
