import SwiftUI

struct RuntimeSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                runtimeControlsCard
                runtimeMetricsCard
                benchmarkCard
                timelineCard
                connectionCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("runtime-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Runtime")
                    .font(.title2.weight(.semibold))
            }
            Text("Start, stop, diagnose, benchmark, and copy Direct Mode connection values.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var runtimeControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runtime controls")
                .font(.headline)

            DetailGrid(rows: [
                ("Status", viewModel.runtimeState.title),
                ("Selected", viewModel.selectedModelIdentifier),
                ("Running", viewModel.runningModelID ?? "Not running"),
                ("Restart required", viewModel.restartRequired ? "Yes" : "No"),
                ("Memory", viewModel.memoryUsageText)
            ])

            HStack {
                Button {
                    viewModel.startRequested()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.stopRequested()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!viewModel.canStopManagedServer)

                Button {
                    viewModel.restartRequested()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .disabled(!viewModel.canRestartManagedServer)

                Button {
                    viewModel.checkReadyRequested()
                } label: {
                    Label("Ready Check", systemImage: "checkmark.seal")
                }

                Button {
                    viewModel.runSpeedTestRequested()
                } label: {
                    if viewModel.isSpeedTestRunning {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label("Speed Test", systemImage: "bolt")
                    }
                }
                .disabled(!viewModel.canRunSpeedTest)
            }

            if let warning = viewModel.runtimeSelectionWarning {
                Label(warning, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .panelStyle()
    }

    private var runtimeMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)
            DetailGrid(rows: [
                ("Target", viewModel.connectionTargetSummary.targetType),
                ("Base URL", viewModel.baseURL),
                ("Readiness", viewModel.connectionTargetSummary.readinessSummary),
                ("Correlation", viewModel.diagnosticsBenchmarkCorrelationSummary),
                ("Launch command", viewModel.selectedLaunchCommandPreview)
            ])
        }
        .panelStyle()
    }

    private var benchmarkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Benchmark")
                    .font(.headline)
                Spacer()
                Button("Copy latest") {
                    viewModel.copyLatestBenchmark()
                }
                .disabled(viewModel.latestBenchmarkResult == nil)
                Button("Copy history") {
                    viewModel.copyBenchmarkSummary()
                }
                .disabled(viewModel.benchmarkHistory.isEmpty)
                Button("Copy debug") {
                    viewModel.copyBenchmarkTroubleshooting()
                }
            }

            Text(viewModel.benchmarkSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let latest = viewModel.latestBenchmarkResult {
                DetailGrid(rows: [
                    ("Latest", latest.summary),
                    ("HTTP", latest.httpStatusText),
                    ("Latency", latest.latencyText),
                    ("Selected", latest.selectedProfileName),
                    ("Running", latest.runningProfileText)
                ])
            } else {
                Text("No benchmark results in this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let guidance = viewModel.benchmarkFailureGuidance {
                Label(guidance, systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .panelStyle()
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runtime timeline")
                .font(.headline)
            if viewModel.runtimeEvents.isEmpty {
                Text("No runtime events in this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.runtimeEvents.prefix(10)) { event in
                    Text(event.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .panelStyle()
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection presets")
                .font(.headline)
            DetailGrid(rows: [
                ("Base URL", viewModel.baseURL),
                ("Model ID", viewModel.selectedModelIdentifier),
                ("API key", viewModel.apiKeyPlaceholder)
            ])
            HStack {
                Button("Hermes") { viewModel.copyHermesAgentConfig() }
                Button("OpenAI-compatible") { viewModel.copyAllConnectionSettings() }
                Button("/v1/models curl") { viewModel.copyModelsCurl() }
                Button("Chat completions curl") { viewModel.copyChatCompletionsCurl() }
            }
        }
        .panelStyle()
    }
}
