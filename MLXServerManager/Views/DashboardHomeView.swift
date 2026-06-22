import SwiftUI

struct DashboardHomeView: View {
    @ObservedObject var viewModel: AppViewModel

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryGrid
                nextActions
                recentActivity
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("dashboard-home")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.grid.2x2")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(strings.text(.dashboard))
                    .font(.title2.weight(.semibold))
            }
            Text("Overview for Direct Mode operations. Use Models, Downloads, Runtime, Settings, and Logs for detailed work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard("Runtime", value: viewModel.runtimeState.title)
            summaryCard("Selected", value: viewModel.selectedModelIdentifier)
            summaryCard("Running", value: viewModel.runningModelID ?? "Not running")
            summaryCard("Latest benchmark", value: viewModel.latestBenchmarkResult?.latencyText ?? "Not run")
            summaryCard("Downloads", value: viewModel.huggingFaceDownloadQueueSummary)
            summaryCard("Logs", value: "\(viewModel.logEntries.count) entries")
        }
    }

    private func summaryCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
    }

    private var nextActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.text(.nextActions))
                .font(.headline)
            HStack {
                Button {
                    viewModel.startRequested()
                } label: {
                    Label(strings.text(.start), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.runSpeedTestRequested()
                } label: {
                    Label(strings.text(.speedTest), systemImage: "bolt")
                }
                .disabled(!viewModel.canRunSpeedTest)

                Button {
                    viewModel.copyHermesAgentConfig()
                } label: {
                    Label(strings.text(.copyHermes), systemImage: "doc.on.doc")
                }

                Button {
                    viewModel.copyAllConnectionSettings()
                } label: {
                    Label(strings.text(.copyOpenAICompatible), systemImage: "link")
                }
            }

            Text("Detailed model management moved to Models. Hugging Face acquisition moved to Downloads. Runtime diagnostics and benchmark history moved to Runtime.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.text(.recentActivity))
                .font(.headline)

            if let latestImportant = viewModel.latestImportantLogEntry {
                Label(latestImportant.line, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if viewModel.runtimeEvents.isEmpty {
                Text(strings.text(.noRuntimeEvents))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.runtimeEvents.prefix(5)) { event in
                    Text(event.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .panelStyle()
    }
}
