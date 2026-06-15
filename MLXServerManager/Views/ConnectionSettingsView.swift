import SwiftUI

struct ConnectionSettingsView: View {
    let targetSummary: ConnectionTargetSummary
    let baseURL: String
    let modelID: String
    let apiKeyPlaceholder: String
    let onCopyBaseURL: () -> Void
    let onCopyModelID: () -> Void
    let onCopyAPIKeyPlaceholder: () -> Void
    let onCopyConfig: () -> Void
    let onCopyAllConnectionSettings: () -> Void
    let onCopyHermesAgentConfig: () -> Void
    let onCopyModelsCurl: () -> Void
    let onCopyChatCompletionsCurl: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OpenAI-Compatible Connection")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Label(targetSummary.targetType, systemImage: targetIconName)
                        .font(.subheadline.weight(.semibold))

                    if !targetSummary.isActiveTarget {
                        Text("Preview")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(targetSummary.ownershipNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(targetSummary.directModeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DetailGrid(rows: [
                ("Target Type", targetSummary.targetType),
                ("Base URL", baseURL),
                ("Model ID", modelID),
                ("API Key", apiKeyPlaceholder),
                ("Readiness", targetSummary.readinessSummary),
                ("Ownership", targetSummary.ownershipNote)
            ])

            VStack(alignment: .leading, spacing: 10) {
                Text("Copy")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 10) {
                    Button {
                        onCopyBaseURL()
                    } label: {
                        Label("Copy Base URL", systemImage: "link")
                    }

                    Button {
                        onCopyModelID()
                    } label: {
                        Label("Copy Model ID", systemImage: "doc.on.doc")
                    }

                    Button {
                        onCopyAPIKeyPlaceholder()
                    } label: {
                        Label("Copy API Key Placeholder", systemImage: "key")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onCopyConfig()
                    } label: {
                        Label("Copy JSON Config", systemImage: "curlybraces")
                    }

                    Button {
                        onCopyHermesAgentConfig()
                    } label: {
                        Label("Copy Hermes Agent Config", systemImage: "person.crop.circle.badge.checkmark")
                    }

                    Button {
                        onCopyAllConnectionSettings()
                    } label: {
                        Label("Copy All Connection Settings", systemImage: "doc.on.clipboard")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onCopyModelsCurl()
                    } label: {
                        Label("Copy curl Readiness Check", systemImage: "terminal")
                    }

                    Button {
                        onCopyChatCompletionsCurl()
                    } label: {
                        Label("Copy OpenAI Chat Example", systemImage: "terminal")
                    }
                }

                Text("Chat examples are client-side helper text. MLX Server Manager does not run inference requests.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private var targetIconName: String {
        switch targetSummary.targetType {
        case "Managed Server":
            "server.rack"
        case "External Server Detected":
            "network"
        case "Adopted External Server":
            "link"
        default:
            "power"
        }
    }
}
