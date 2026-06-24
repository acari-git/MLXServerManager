import SwiftUI

struct ClientSetupSurfaceView: View {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards
                directModeCard
                safetyCard
                copyScopeCard

                ConnectionSettingsView(
                    targetSummary: targetSummary,
                    baseURL: baseURL,
                    modelID: modelID,
                    apiKeyPlaceholder: apiKeyPlaceholder,
                    onCopyBaseURL: onCopyBaseURL,
                    onCopyModelID: onCopyModelID,
                    onCopyAPIKeyPlaceholder: onCopyAPIKeyPlaceholder,
                    onCopyConfig: onCopyConfig,
                    onCopyAllConnectionSettings: onCopyAllConnectionSettings,
                    onCopyHermesAgentConfig: onCopyHermesAgentConfig,
                    onCopyModelsCurl: onCopyModelsCurl,
                    onCopyChatCompletionsCurl: onCopyChatCompletionsCurl
                )
                .accessibilityIdentifier("client-setup-connection-settings")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("client-setup-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Client Setup")
                    .font(.title2.weight(.semibold))
            }

            Text("Copy-safe OpenAI-compatible setup values. Clients connect directly to the active endpoint.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("client-setup-header")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 170), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Target", value: targetSummary.targetType, identifier: "client-setup-summary-target")
            summaryCard("Base URL", value: baseURL, identifier: "client-setup-summary-base-url")
            summaryCard("Model ID", value: modelID, identifier: "client-setup-summary-model-id")
            summaryCard("Readiness", value: targetSummary.readinessSummary, identifier: "client-setup-summary-readiness")
        }
        .accessibilityIdentifier("client-setup-summary")
    }

    private func summaryCard(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .textSelection(.enabled)
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

    private var directModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Direct Mode", systemImage: "arrow.right.circle")
                .font(.headline)

            Text("OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("MLX Server Manager displays setup values and copy actions. It does not sit between the client and server, proxy inference traffic, rewrite requests, inspect requests, or provide Chat UI.")
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
        .accessibilityIdentifier("client-setup-direct-mode")
    }

    private var copyScopeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Copy Scope", systemImage: "doc.on.doc")
                .font(.headline)

            DetailGrid(rows: [
                ("Base URL", "Copies the active endpoint base URL."),
                ("Model ID", "Copies the selected model identifier for OpenAI-compatible clients."),
                ("API key placeholder", "Copies the documented placeholder only; no secret is created."),
                ("Config examples", "Copies text examples only; no files are generated or written.")
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
        .accessibilityIdentifier("client-setup-copy-scope")
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Safety Boundary", systemImage: "lock")
                .font(.headline)

            DetailGrid(rows: [
                ("Secrets", "No API keys, tokens, or secrets are generated or stored."),
                ("Config files", "No client config files are generated or persisted."),
                ("Endpoint testing", "No new network behavior is added here."),
                ("Ownership", targetSummary.ownershipNote)
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
        .accessibilityIdentifier("client-setup-safety-boundary")
    }
}
