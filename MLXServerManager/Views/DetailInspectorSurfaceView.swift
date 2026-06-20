import SwiftUI

struct DetailInspectorSurfaceView: View {
    let selectedModel: ModelConfig?
    let runningModelText: String
    let restartRequired: Bool
    let targetSummary: ConnectionTargetSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let selectedModel {
                    selectedProfileCard(selectedModel)
                    connectionTargetCard
                    boundaryNote
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("detail-inspector-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "sidebar.right")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Inspector")
                    .font(.title2.weight(.semibold))
            }

            Text("Read-only selected profile details. Runtime controls remain on Dashboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detail-inspector-header")
    }

    private func selectedProfileCard(_ model: ModelConfig) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.title3.weight(.semibold))
                    Text(model.modelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                if restartRequired {
                    Label("Restart required", systemImage: "arrow.clockwise.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            DetailGrid(rows: [
                ("Model ID", model.modelID),
                ("Display Name", model.displayName),
                ("Family", model.family),
                ("Quantization", model.quantization),
                ("Context", model.contextWindow),
                ("Local Name", model.localName),
                ("Endpoint", "\(model.host):\(model.serverPort)"),
                ("Thinking", model.enableThinking ? "Enabled" : "Disabled"),
                ("Running", runningModelText),
                ("Notes", model.notes)
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail-inspector-selected-profile")
    }

    private var connectionTargetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connection Target")
                .font(.headline)

            DetailGrid(rows: [
                ("Target Type", targetSummary.targetType),
                ("Base URL", targetSummary.baseURL),
                ("Model ID", targetSummary.modelID),
                ("Readiness", targetSummary.readinessSummary),
                ("Ownership", targetSummary.ownershipNote),
                ("Direct Mode", targetSummary.directModeNote)
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail-inspector-connection-target")
    }

    private var boundaryNote: some View {
        Label("Inspector is read-only. Edit, delete, import, export, and runtime controls remain on Dashboard.", systemImage: "lock")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("detail-inspector-boundary-note")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Selected Profile",
            systemImage: "sidebar.right",
            description: Text("Select a profile from Dashboard or Profiles. The inspector does not change runtime lifecycle behavior.")
        )
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityIdentifier("detail-inspector-empty-state")
    }
}

#Preview {
    DetailInspectorSurfaceView(
        selectedModel: ModelConfig.defaults.first,
        runningModelText: "No managed server running",
        restartRequired: false,
        targetSummary: ConnectionTargetSummary(
            targetType: "Managed server",
            baseURL: "http://127.0.0.1:8080",
            modelID: ModelConfig.defaults.first?.modelID ?? "",
            apiKeyPlaceholder: "not required",
            readinessSummary: "Not checked",
            ownershipNote: "Managed by MLX Server Manager",
            directModeNote: "Direct Mode remains direct",
            isActiveTarget: true
        )
    )
}
