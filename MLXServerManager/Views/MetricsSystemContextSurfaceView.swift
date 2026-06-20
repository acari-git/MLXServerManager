import SwiftUI

struct MetricsSystemContextSurfaceView: View {
    let targetSummary: ConnectionTargetSummary
    let runtimeState: ModelRuntimeState
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool
    let logEntryCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards
                readinessContextCard
                memoryContextCard
                processOwnershipCard
                privacyPerformanceCard
                troubleshootingCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("metrics-system-context-surface")
    }

    private var restartRequiredText: String {
        restartRequired ? "Yes" : "No"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Metrics")
                    .font(.title2.weight(.semibold))
            }

            Text("Read-only system and readiness context. No telemetry, background monitoring, or request inspection is added.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("metrics-system-context-header")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 170), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Runtime", value: runtimeState.title, identifier: "metrics-summary-runtime")
            summaryCard("Readiness", value: targetSummary.readinessSummary, identifier: "metrics-summary-readiness")
            summaryCard("Memory", value: memoryUsageText, identifier: "metrics-summary-memory")
            summaryCard("Restart required", value: restartRequiredText, identifier: "metrics-summary-restart-required")
        }
        .accessibilityIdentifier("metrics-system-context-summary")
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

    private var readinessContextCard: some View {
        contextCard(
            title: "Readiness Context",
            systemImage: "checkmark.seal",
            identifier: "metrics-readiness-context",
            rows: [
                ("Target", targetSummary.targetType),
                ("Base URL", targetSummary.baseURL),
                ("Model ID", targetSummary.modelID),
                ("Readiness", targetSummary.readinessSummary),
                ("Runtime", runtimeState.detail)
            ],
            note: "This surface reuses readiness context already available to the app. It does not add new endpoint testing or inference calls."
        )
    }

    private var memoryContextCard: some View {
        contextCard(
            title: "Memory / System Guidance",
            systemImage: "memorychip",
            identifier: "metrics-memory-context",
            rows: [
                ("Memory", memoryUsageText),
                ("Selected", selectedModelText),
                ("Running", runningModelText),
                ("Logs", "\(logEntryCount) entries")
            ],
            note: "Memory guidance is informational. It is not a benchmark, fit guarantee, profiler, or background monitor."
        )
    }

    private var processOwnershipCard: some View {
        contextCard(
            title: "Process Ownership",
            systemImage: "lock",
            identifier: "metrics-process-ownership",
            rows: [
                ("Ownership", targetSummary.ownershipNote),
                ("Direct Mode", targetSummary.directModeNote),
                ("Current target", targetSummary.isActiveTarget ? "Active" : "Inactive"),
                ("Lifecycle", "Start, Stop, and Restart remain explicit Dashboard actions.")
            ],
            note: "Adopted external servers remain connection context only. External process internals, logs, and metrics are not collected."
        )
    }

    private var privacyPerformanceCard: some View {
        contextCard(
            title: "Privacy / Performance Boundary",
            systemImage: "speedometer",
            identifier: "metrics-privacy-performance-boundary",
            rows: [
                ("Telemetry", "None"),
                ("Analytics", "None"),
                ("Request inspection", "None"),
                ("Metrics persistence", "None"),
                ("Background monitoring", "None")
            ],
            note: "Direct Mode remains the performance boundary: OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model."
        )
    }

    private var troubleshootingCard: some View {
        contextCard(
            title: "Troubleshooting Context",
            systemImage: "wrench.and.screwdriver",
            identifier: "metrics-troubleshooting-context",
            rows: [
                ("If readiness fails", "Use Dashboard readiness checks and app-managed logs."),
                ("If using external server", "Check the external terminal or app for process logs."),
                ("If client cannot connect", "Confirm Base URL and model ID in Client Setup."),
                ("If model is large", "Confirm memory headroom before launch.")
            ],
            note: "These are static guidance notes. The app does not run diagnostics automatically from this surface."
        )
    }

    private func contextCard(
        title: String,
        systemImage: String,
        identifier: String,
        rows: [(String, String)],
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            DetailGrid(rows: rows)

            Text(note)
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
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    MetricsSystemContextSurfaceView(
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
        runtimeState: .ready(host: "127.0.0.1", port: 8080, processIdentifier: 1234),
        memoryUsageText: "Memory context available",
        selectedModelText: "mlx-community/example",
        runningModelText: "mlx-community/example",
        restartRequired: false,
        logEntryCount: 2
    )
}
