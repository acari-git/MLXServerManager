import SwiftUI

struct DetailInspectorSurfaceView: View {
    let selectedModel: ModelConfig?
    let runningModelText: String
    let restartRequired: Bool
    let targetSummary: ConnectionTargetSummary
    let modelAvailability: ModelAvailabilitySummary
    let onCheckModelAvailability: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards

                if let selectedModel {
                    selectedProfileCard(selectedModel)
                    modelAvailabilityCard
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

    private var selectedProfileText: String {
        selectedModel?.displayName ?? "None"
    }

    private var targetStatusText: String {
        targetSummary.isActiveTarget ? "Active" : "Inactive"
    }

    private var restartRequiredText: String {
        restartRequired ? "Yes" : "No"
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

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Selected", value: selectedProfileText, identifier: "detail-inspector-summary-selected")
            summaryCard("Target", value: targetStatusText, identifier: "detail-inspector-summary-target")
            summaryCard("Running", value: runningModelText, identifier: "detail-inspector-summary-running")
            summaryCard("Restart required", value: restartRequiredText, identifier: "detail-inspector-summary-restart-required")
        }
        .accessibilityIdentifier("detail-inspector-summary")
    }

    private func summaryCard(_ title: String, value: String, identifier: String) -> some View {
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
        .accessibilityIdentifier(identifier)
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

    private var modelAvailabilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Model Availability")
                    .font(.headline)

                Spacer()

                Text(modelAvailability.state.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(modelAvailability.state == .present ? Color.accentColor : Color.secondary)
            }

            DetailGrid(rows: [
                ("Status", modelAvailability.state.title),
                ("Profile", modelAvailability.profileDisplayName),
                ("Target", modelAvailability.configuredTarget),
                ("Checked Path", modelAvailability.checkedPathSummary),
                ("Scope", modelAvailability.scopeText),
                ("Next Step", modelAvailability.nextStep)
            ])

            Button {
                onCheckModelAvailability()
            } label: {
                Label("Check Model Availability", systemImage: "magnifyingglass")
            }
            .disabled(!modelAvailability.canCheck)
            .accessibilityIdentifier("detail-inspector-model-availability-check")

            Text("Checks only the selected profile's configured local path. It does not scan, download, delete, or verify launch compatibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        .accessibilityIdentifier("detail-inspector-model-availability")
    }

    private var connectionTargetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Connection Target")
                    .font(.headline)

                Spacer()

                Text(targetStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(targetSummary.isActiveTarget ? Color.accentColor : Color.secondary)
            }

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
        Label("Inspector is read-only for profile and runtime changes. Availability checks do not mutate profiles or start servers.", systemImage: "lock")
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
        ),
        modelAvailability: ModelAvailabilitySummary.initial(
            for: ModelConfig.defaults.first,
            isExternalTarget: false
        ),
        onCheckModelAvailability: {}
    )
}
