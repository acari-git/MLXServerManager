import SwiftUI

struct ProfilesSurfaceView: View {
    let models: [ModelConfig]
    let selectedModelID: ModelConfig.ID?
    let runningModelID: ModelConfig.ID?
    let restartRequired: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards

                if models.isEmpty {
                    emptyState
                } else {
                    Text("Model Profiles")
                        .font(.headline)
                        .accessibilityIdentifier("profiles-surface-list-heading")

                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(models) { model in
                            profileCard(model)
                        }
                    }
                    .accessibilityIdentifier("profiles-surface-profile-list")

                    selectedModelInspector
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("profiles-surface")
    }

    private var selectedModel: ModelConfig? {
        models.first { model in
            model.id == selectedModelID
        }
    }

    private var runningModel: ModelConfig? {
        models.first { model in
            model.id == runningModelID
        }
    }

    private var restartRequiredText: String {
        restartRequired ? "Yes" : "No"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Models")
                    .font(.title2.weight(.semibold))
            }

            Text("Model management surface with profile list, selected/running badges, and selected model inspector.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-header")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Profiles", value: String(models.count))
            summaryCard("Selected", value: selectedModel?.displayName ?? "None")
            summaryCard("Running", value: runningModel?.displayName ?? "None")
            summaryCard("Restart required", value: restartRequiredText)
        }
        .accessibilityIdentifier("profiles-surface-summary")
    }

    private var selectedModelInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected model inspector")
                .font(.headline)
            if let selectedModel {
                DetailGrid(rows: [
                    ("Model ID", selectedModel.modelID),
                    ("Display Name", selectedModel.displayName),
                    ("Source", sourceLabel(for: selectedModel)),
                    ("Endpoint", "\(selectedModel.host):\(selectedModel.serverPort)"),
                    ("Thinking", selectedModel.enableThinking ? "Enabled" : "Disabled"),
                    ("Notes", selectedModel.notes.isEmpty ? "None" : selectedModel.notes)
                ])
                Label("Deleting a profile removes metadata only. Model files and Hugging Face cache are not deleted.", systemImage: "shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Select a model profile to inspect its details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityIdentifier("models-surface-selected-inspector")
    }

    private func sourceLabel(for model: ModelConfig) -> String {
        if ModelAvailabilityPathFormatter.localPathCandidate(for: model) != nil {
            return model.notes.localizedCaseInsensitiveContains("downloaded") ? "Downloaded" : "Local"
        }
        return model.modelID.contains("/") ? "HF ID" : "Advanced"
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
            description: Text("Add models from Downloads or Dashboard. This surface does not start, stop, or mutate runtime behavior.")
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
                    if model.id == selectedModelID {
                        statusPill("Selected")
                    }

                    if model.id == runningModelID {
                        statusPill("Running")
                    }

                    if restartRequired, model.id == selectedModelID {
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
                    metadataLabel("Quantization")
                    metadataValue(model.quantization)
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

            if !model.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(model.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-profile-\(sanitizedIdentifier(model.id))")
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

#Preview {
    ProfilesSurfaceView(
        models: ModelConfig.defaults,
        selectedModelID: ModelConfig.defaults.first?.id,
        runningModelID: nil,
        restartRequired: false
    )
}
