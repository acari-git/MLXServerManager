import SwiftUI

struct DashboardHomeView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenModels: () -> Void = {}
    var onOpenDownloads: () -> Void = {}
    var onOpenRuntime: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onOpenLogs: () -> Void = {}

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
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
            Text(t("Overview for Direct Mode operations. Use Models, Downloads, Runtime, Settings, and Logs for detailed work.", "Direct Mode操作の概要です。詳細な作業はモデル、ダウンロード、ランタイム、設定、ログで行います。"))
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
            summaryCard(strings.text(.runtime), value: viewModel.runtimeState.title)
            summaryCard(t("Selected", "選択中"), value: viewModel.selectedModelIdentifier)
            summaryCard(t("Running", "実行中"), value: viewModel.runningModelID ?? t("Not running", "未実行"))
            summaryCard(t("Latest benchmark", "最新ベンチマーク"), value: viewModel.latestBenchmarkResult?.latencyText ?? t("Not run", "未実行"))
            summaryCard(strings.text(.downloads), value: viewModel.huggingFaceDownloadQueueSummary)
            summaryCard(strings.text(.logs), value: t("\(viewModel.logEntries.count) entries", "\(viewModel.logEntries.count)件"))
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
                Button(t("Manage Models", "モデルを管理")) { onOpenModels() }
                    .buttonStyle(.borderedProminent)
                Button(t("Find / Download", "検索 / ダウンロード")) { onOpenDownloads() }
                Button(t("Open Runtime", "ランタイムを開く")) { onOpenRuntime() }
                Button(t("Open Settings", "設定を開く")) { onOpenSettings() }
                Button(t("Open Logs", "ログを開く")) { onOpenLogs() }
            }

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

            Text(t("Detailed model management moved to Models. Hugging Face acquisition moved to Downloads. Runtime diagnostics and benchmark history moved to Runtime.", "詳細なモデル管理はモデル画面へ、Hugging Faceからの取得はダウンロード画面へ、ランタイム診断とベンチマーク履歴はランタイム画面へ移動しました。"))
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
