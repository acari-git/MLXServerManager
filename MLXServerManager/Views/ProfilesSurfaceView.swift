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

                if models.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(models) { model in
                            profileCard(model)
                        }
                    }
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
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Profiles")
                    .font(.title2.weight(.semibold))
            }

            Text("Model profile list surface for staged navigation. Runtime controls remain on Dashboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-header")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Profiles",
            systemImage: "list.bullet.rectangle",
            description: Text("Add profiles from Dashboard. This surface does not change runtime lifecycle behavior.")
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
