import SwiftUI

struct LogsSurfaceView: View {
    let entries: [LogEntry]
    let targetSummary: ConnectionTargetSummary
    let runningModelText: String
    let onCopy: () -> Void
    let onClear: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards
                troubleshootingCard
                boundaryCard

                LogView(
                    entries: entries,
                    onCopy: onCopy,
                    onClear: onClear
                )
                .accessibilityIdentifier("logs-surface-log-view")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("logs-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Logs")
                    .font(.title2.weight(.semibold))
            }

            Text("App-managed lifecycle and log context. External server logs are not captured.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("logs-surface-header")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Entries", value: String(entries.count), identifier: "logs-surface-summary-entries")
            summaryCard("Target", value: targetSummary.targetType, identifier: "logs-surface-summary-target")
            summaryCard("Readiness", value: targetSummary.readinessSummary, identifier: "logs-surface-summary-readiness")
            summaryCard("Running", value: runningModelText, identifier: "logs-surface-summary-running")
        }
        .accessibilityIdentifier("logs-surface-summary")
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

    private var latestImportantLogEntry: LogEntry? {
        entries.reversed().first { entry in
            entry.line.localizedCaseInsensitiveContains("failed")
                || entry.line.localizedCaseInsensitiveContains("warning")
                || entry.line.localizedCaseInsensitiveContains("error")
        }
    }

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Troubleshooting", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            DetailGrid(rows: [
                ("Latest important log", latestImportantLogEntry?.line ?? "None"),
                ("Target", targetSummary.targetType),
                ("Base URL", targetSummary.baseURL),
                ("Running", runningModelText),
                ("Entries", String(entries.count))
            ])

            HStack {
                Button("Copy logs") { onCopy() }
                    .disabled(entries.isEmpty)
                Button("Clear logs") { onClear() }
                    .disabled(entries.isEmpty)
            }
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
        .accessibilityIdentifier("logs-surface-troubleshooting")
    }

    private var boundaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Log Boundary", systemImage: "lock")
                .font(.headline)

            Text("Logs shown here are app-managed lifecycle and captured managed-process context already available to MLX Server Manager. Adopted external server stdout/stderr is not captured, inspected, stopped, restarted, or owned by the app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            DetailGrid(rows: [
                ("Ownership", targetSummary.ownershipNote),
                ("Direct Mode", targetSummary.directModeNote),
                ("Base URL", targetSummary.baseURL),
                ("Model ID", targetSummary.modelID)
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
        .accessibilityIdentifier("logs-surface-boundary")
    }
}

#Preview {
    LogsSurfaceView(
        entries: [
            LogEntry(line: "[start] Launching managed server"),
            LogEntry(line: "[ready] /v1/models returned successfully")
        ],
        targetSummary: ConnectionTargetSummary(
            targetType: "Managed server",
            baseURL: "http://127.0.0.1:8080",
            modelID: "mlx-community/example",
            apiKeyPlaceholder: "not required",
            readinessSummary: "Ready",
            ownershipNote: "Managed by MLX Server Manager",
            directModeNote: "Direct Mode remains direct",
            isActiveTarget: true
        ),
        runningModelText: "mlx-community/example",
        onCopy: {},
        onClear: {}
    )
}
