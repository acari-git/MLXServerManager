import SwiftUI

struct ProfilesSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

    private var models: [ModelConfig] { viewModel.visibleModels }
    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var runningModel: ModelConfig? {
        guard let runningModelID = viewModel.runningModelID else { return nil }
        return viewModel.models.first { $0.id == runningModelID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                toolbar
                summaryCards

                if viewModel.models.isEmpty {
                    emptyState
                } else {
                    HSplitView {
                        modelList
                            .frame(minWidth: 320, idealWidth: 420)
                        selectedModelInspector
                            .frame(minWidth: 360)
                    }
                    .frame(minHeight: 480)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("profiles-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Models")
                    .font(.title2.weight(.semibold))
            }

            Text("Manage model profiles from one surface. Runtime lifecycle controls remain on Runtime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-header")
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("Source", selection: $viewModel.modelListSourceFilter) {
                ForEach(viewModel.modelListSourceFilterOptions, id: \.self) { source in
                    Text(source).tag(source)
                }
            }
            .frame(width: 190)

            TextField("Search models", text: $viewModel.modelListSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, idealWidth: 240)

            Spacer()

            Button {
                viewModel.addProfileRequested()
            } label: {
                Label("Add", systemImage: "plus")
            }

            Button {
                viewModel.editProfileRequested()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(selectedModel == nil)

            Button(role: .destructive) {
                viewModel.deleteProfileRequested()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedModel == nil || viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)

            Divider()
                .frame(height: 24)

            Button {
                viewModel.importProfilesPreviewRequested()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Button {
                viewModel.exportProfilesRequested()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.models.isEmpty)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Profiles", value: String(viewModel.models.count))
            summaryCard("Visible", value: String(models.count))
            summaryCard("Selected", value: selectedModel?.displayName ?? "None")
            summaryCard("Running", value: runningModel?.displayName ?? "None")
            summaryCard("Restart required", value: viewModel.restartRequired ? "Yes" : "No")
        }
        .accessibilityIdentifier("profiles-surface-summary")
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Profiles")
                .font(.headline)
                .accessibilityIdentifier("profiles-surface-list-heading")

            if models.isEmpty {
                ContentUnavailableView(
                    "No models for this filter",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Change the source filter to show other profiles.")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(models) { model in
                        Button {
                            viewModel.selectedModelID = model.id
                        } label: {
                            profileCard(model)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityIdentifier("profiles-surface-profile-list")
            }
        }
    }

    private func summaryCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-summary-\(sanitizedIdentifier(title.lowercased()))")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Models",
            systemImage: "square.stack.3d.up",
            description: Text("Add models from Downloads or use Add to create a profile manually.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
        .accessibilityIdentifier("profiles-surface-empty-state")
    }

    private func profileCard(_ model: ModelConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                    Text(model.modelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    statusPill(viewModel.sourceLabel(for: model))
                    if model.id == viewModel.selectedModelID {
                        statusPill("Selected")
                    }
                    if model.id == viewModel.runningModelID {
                        statusPill("Running")
                    }
                    if viewModel.restartRequired, model.id == viewModel.selectedModelID {
                        statusPill("Restart required")
                    }
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    metadataLabel("Family")
                    metadataValue(model.family)
                }
                GridRow {
                    metadataLabel("Endpoint")
                    metadataValue("\(model.host):\(model.serverPort)")
                }
                GridRow {
                    metadataLabel("Thinking")
                    metadataValue(model.enableThinking ? "Enabled" : "Disabled")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-profile-\(sanitizedIdentifier(model.id))")
    }

    private var selectedModelInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected model inspector")
                .font(.headline)

            if let selectedModel {
                DetailGrid(rows: [
                    ("Model ID", selectedModel.modelID),
                    ("Display Name", selectedModel.displayName),
                    ("Source", viewModel.sourceLabel(for: selectedModel)),
                    ("Family", selectedModel.family),
                    ("Quantization", selectedModel.quantization),
                    ("Context", selectedModel.contextWindow),
                    ("Endpoint", "\(selectedModel.host):\(selectedModel.serverPort)"),
                    ("Thinking", selectedModel.enableThinking ? "Enabled" : "Disabled"),
                    ("Latest benchmark", viewModel.latestBenchmarkResult?.latencyText ?? "Not run"),
                    ("Notes", selectedModel.notes.isEmpty ? "None" : selectedModel.notes)
                ])

                Text("Advanced launch options")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedAdvancedLaunchOptionsSummary)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(6)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Launch command")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedLaunchCommandPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Label("Profile actions are metadata-only. Model files and Hugging Face cache are not deleted.", systemImage: "shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Select a model profile to inspect its details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityIdentifier("models-surface-selected-inspector")
    }

    private func metadataLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func metadataValue(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func sanitizedIdentifier(_ value: String) -> String {
        value
            .map { character in
                character.isLetter || character.isNumber ? character : "-"
            }
            .reduce(into: "") { result, character in
                result.append(character)
            }
    }
}
