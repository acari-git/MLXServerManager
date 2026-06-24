import SwiftUI

struct DownloadsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenModels: () -> Void = {}
    var onOpenRuntime: () -> Void = {}

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                recoveryCard
                downloadEnvironmentCard
                downloadWorkflowCard
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
                Text(strings.text(.downloads))
                    .font(.title2.weight(.semibold))
            }
            Text("Search Hugging Face, review the selected result, download explicitly, and recover failed queue entries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recoveryCard: some View {
        if let failed = viewModel.latestFailedHuggingFaceDownloadQueueEntry {
            VStack(alignment: .leading, spacing: 10) {
                Label("Latest failed download", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.orange)
                DetailGrid(rows: [
                    ("Repository", failed.repositoryID),
                    ("Destination", failed.compactDestinationPath),
                    ("Message", failed.message)
                ])
                HStack {
                    Button("Restore form") {
                        viewModel.restoreHuggingFaceDownloadForm(from: failed)
                    }
                    Button("Copy URL") {
                        viewModel.copyHuggingFaceDownloadURL(from: failed)
                    }
                    Button(strings.text(.retry)) {
                        viewModel.retryHuggingFaceDownloadRequested()
                    }
                    .disabled(!viewModel.canRetryHuggingFaceDownload)
                }
            }
            .panelStyle()
        }
    }

    private var downloadEnvironmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Download environment")
                .font(.headline)
            DetailGrid(rows: [
                ("HF access", viewModel.huggingFaceAccessMessage),
                ("aria2c", viewModel.aria2Availability.displayPath),
                ("Auto restart", viewModel.enableDownloadAutoRestart ? "Enabled below \(viewModel.lowSpeedRestartThresholdText)" : "Disabled")
            ])
            HStack {
                SecureField("Hugging Face access value", text: $viewModel.huggingFaceAccessInput)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { viewModel.saveHuggingFaceAccessRequested() }
                Button("Delete") { viewModel.deleteHuggingFaceAccessRequested() }
                    .disabled(!viewModel.isHuggingFaceAccessSaved)
                Button("Check aria2c") { viewModel.refreshAria2Status() }
            }
            Toggle("Enable low-speed auto-restart policy", isOn: $viewModel.enableDownloadAutoRestart)
                .toggleStyle(.checkbox)
            HStack {
                Text("Low-speed threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("50K", text: $viewModel.lowSpeedRestartThresholdText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }
        }
        .panelStyle()
    }

    private var downloadWorkflowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Download workflow")
                .font(.headline)
            Label("1. Search or paste a Hugging Face model ID.", systemImage: "magnifyingglass")
            Label("2. Preview files and select MLX-related weights/config files.", systemImage: "list.bullet.rectangle")
            Label("3. Download, auto-add to Models, then start the server.", systemImage: "arrow.down.circle")
            Label("4. Copy client or Hermes connection settings from the right panel.", systemImage: "doc.on.doc")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .panelStyle()
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
                        Label(strings.text(.search), systemImage: "magnifyingglass")
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
            Text(strings.text(.download))
                .font(.headline)

            TextField("Repository ID or URL", text: $viewModel.huggingFaceDownloadDraft.source)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Revision", text: $viewModel.huggingFaceDownloadDraft.revision)
                    .textFieldStyle(.roundedBorder)
                TextField("Display name", text: $viewModel.huggingFaceDownloadDraft.displayName)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button("MLX preset") { viewModel.applyHuggingFaceMLXPreset() }
                    Button("Safetensors") { viewModel.applyHuggingFaceSafeTensorPreset() }
                    Button("No filters") { viewModel.clearHuggingFaceFileFilters() }
                    Spacer()
                }
                TextField("Include patterns", text: $viewModel.huggingFaceDownloadDraft.includePatterns)
                    .textFieldStyle(.roundedBorder)
                TextField("Exclude patterns", text: $viewModel.huggingFaceDownloadDraft.excludePatterns)
                    .textFieldStyle(.roundedBorder)
                Text("Patterns are comma-separated. Preview files first, then download selected or filtered files.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
                ("Files", viewModel.huggingFaceSelectedPreviewSummary),
                ("Status", viewModel.huggingFaceDownloadStatus.phase.title),
                ("Message", viewModel.huggingFaceDownloadStatus.message)
            ])

            filePreviewPanel

            if viewModel.huggingFaceDownloadStatus.phase == .completed {
                HStack {
                    Label("Download complete. The profile has been added when possible.", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Open Models") { onOpenModels() }
                    Button("Open Runtime") { onOpenRuntime() }
                }
                .padding(8)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button {
                    viewModel.previewHuggingFaceFilesRequested()
                } label: {
                    Label("Preview files", systemImage: "list.bullet.rectangle")
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
        .panelStyle()
    }

    private var filePreviewPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("File preview")
                    .font(.caption.weight(.semibold))
                Spacer()
                if viewModel.huggingFaceFilePreview.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            Toggle("Use selected preview files", isOn: $viewModel.huggingFaceDownloadDraft.useSelectedPreviewFiles)
                .toggleStyle(.checkbox)
                .disabled(viewModel.huggingFaceFilePreview.files.isEmpty)
            HStack {
                Text(viewModel.huggingFaceFilePreview.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select filtered") { viewModel.selectAllHuggingFacePreviewFiles() }
                    .disabled(viewModel.filteredHuggingFacePreviewFiles.isEmpty)
                Button("Clear") { viewModel.clearHuggingFacePreviewSelection() }
                    .disabled(viewModel.selectedHuggingFacePreviewFileIDs.isEmpty)
            }
            previewFileList
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.text(.downloadQueue))
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
