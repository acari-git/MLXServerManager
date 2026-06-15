import SwiftUI

struct ModelListView: View {
    let models: [ModelConfig]
    @Binding var selectedModelID: ModelConfig.ID?
    let runningModelID: ModelConfig.ID?
    let restartRequired: Bool
    let exportSummaryText: String
    let exportMessage: String?
    let importMessage: String?
    let onAddProfile: () -> Void
    let onExportProfiles: () -> Void
    let onImportProfilesPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Models")
                        .font(.headline)

                    Spacer()

                    Button {
                        onAddProfile()
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .help("Add Profile")
                }

                HStack(spacing: 8) {
                    Button {
                        onExportProfiles()
                    } label: {
                        Label("Export Profiles...", systemImage: "square.and.arrow.up")
                    }
                    .disabled(models.isEmpty)

                    Button {
                        onImportProfilesPreview()
                    } label: {
                        Label("Import Profiles...", systemImage: "square.and.arrow.down")
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exportSummaryText)
                    Text("Exports profile metadata only. No API keys, tokens, model weights, caches, logs, executable paths, or runtime state.")
                    Text("Import Profiles is preview-only. It validates JSON metadata and does not save profiles or start servers.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let importMessage {
                    Text(importMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            List(models, selection: $selectedModelID) { model in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.body.weight(.medium))
                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if model.id == selectedModelID {
                            statusPill("Selected", color: .accentColor)
                        }

                        if model.id == runningModelID {
                            statusPill("Running", color: .green)
                        }

                        if restartRequired, model.id == selectedModelID {
                            statusPill("Restart required", color: .orange)
                        }
                    }
                }
                .padding(.vertical, 4)
                .tag(model.id)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
