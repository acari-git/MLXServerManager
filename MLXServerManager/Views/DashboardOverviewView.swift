import SwiftUI

struct DashboardOverviewView: View {
    @ObservedObject var viewModel: AppViewModel
    let rows: [ModelListRowState]
    let onOpenProfiles: () -> Void
    let onOpenDiagnostics: () -> Void
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var targetKey: String {
        viewModel.selectedModel?.id ?? "default:\(viewModel.settings.defaultHost):\(viewModel.settings.defaultPort)"
    }

    private var latestDiagnosticsComparison: DiagnosticsComparison? {
        let snapshots = DiagnosticsHistoryStore.snapshots(for: targetKey, in: viewModel.diagnosticsHistory)
        guard let current = snapshots.first else { return nil }
        return DiagnosticsComparison.compare(current: current, previous: snapshots.dropFirst().first)
    }

    private var overview: DashboardOverview {
        DashboardOverview(
            rows: rows,
            diagnostics: viewModel.diagnosticsResults,
            diagnosticsHistoryCount: viewModel.diagnosticsHistory.count,
            hermesInspected: viewModel.hermesAgentConfigInspection != nil,
            hermesMatchesSelectedModel: viewModel.hermesAgentPendingChangeKeys.isEmpty
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Label(healthTitle, systemImage: healthImage)
                    .font(.headline)
                    .foregroundStyle(healthColor)
                Spacer()
                Button {
                    viewModel.runDiagnosticsRequested()
                } label: {
                    Label(t("Run Diagnostics", "診断を実行"), systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isDiagnosticsRunning)

                Button {
                    _ = viewModel.inspectHermesAgentConfigRequested()
                } label: {
                    Label(t("Inspect Hermes", "Hermesを検査"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    metricCard(title: t("Profiles", "プロファイル"), value: overview.profileCount, image: "square.grid.2x2")
                    metricCard(title: t("Loaded", "ロード済み"), value: overview.loadedCount, image: "play.circle.fill")
                    metricCard(title: t("Attention", "要確認"), value: overview.issueCount, image: "exclamationmark.triangle.fill")
                    metricCard(title: t("History", "診断履歴"), value: overview.diagnosticsHistoryCount, image: "clock.arrow.circlepath")
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        metricCard(title: t("Profiles", "プロファイル"), value: overview.profileCount, image: "square.grid.2x2")
                        metricCard(title: t("Loaded", "ロード済み"), value: overview.loadedCount, image: "play.circle.fill")
                    }
                    HStack(spacing: 8) {
                        metricCard(title: t("Attention", "要確認"), value: overview.issueCount, image: "exclamationmark.triangle.fill")
                        metricCard(title: t("History", "診断履歴"), value: overview.diagnosticsHistoryCount, image: "clock.arrow.circlepath")
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    priorityActions
                    diagnosticsTrendCard
                    hermesCard
                }
                VStack(alignment: .leading, spacing: 10) {
                    priorityActions
                    HStack(alignment: .top, spacing: 10) {
                        diagnosticsTrendCard
                        hermesCard
                    }
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3))
        }
        .accessibilityIdentifier("dashboard-operational-overview")
    }

    private func metricCard(title: String, value: Int, image: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: image)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }

    private var priorityActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Priority actions", "優先アクション"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(overview.actions.prefix(3)) { action in
                Button {
                    open(action.destination)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: actionImage(action.destination))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(actionTitle(action.titleKey))
                                .font(.caption.weight(.semibold))
                            Text(actionDetail(action.detailKey))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
    }

    private var diagnosticsTrendCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(t("Diagnostics trend", "診断トレンド"), systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.semibold))
            if let comparison = latestDiagnosticsComparison {
                Text(trendTitle(comparison.trend))
                    .font(.caption)
                    .foregroundStyle(trendColor(comparison.trend))
                Text(t("Improved", "改善") + ": \(comparison.improvedCount)  " + t("Worsened", "悪化") + ": \(comparison.worsenedCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text(t("No history yet", "履歴はまだありません"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(t("Run diagnostics to establish a baseline.", "診断を実行して基準を作成します。"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button(t("Open Diagnostics", "診断を開く"), action: onOpenDiagnostics)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(10)
        .frame(width: 210, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
    }

    private var hermesCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(t("Hermes Agent", "Hermes Agent"), systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption.weight(.semibold))
            Text(hermesStatusTitle)
                .font(.caption)
                .foregroundStyle(hermesStatusColor)
            Text(t("Selected model configuration alignment", "選択モデルとの設定整合性"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button(t("Open Settings", "設定を開く"), action: onOpenSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(10)
        .frame(width: 210, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
    }

    private var healthTitle: String {
        switch overview.health {
        case .healthy: t("System ready", "システム準備完了")
        case .attention: t("Review recommended", "確認を推奨")
        case .critical: t("Action required", "対処が必要")
        }
    }

    private var healthImage: String {
        switch overview.health {
        case .healthy: "checkmark.seal.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    private var healthColor: Color {
        switch overview.health {
        case .healthy: .green
        case .attention: .orange
        case .critical: .red
        }
    }

    private var hermesStatusTitle: String {
        guard viewModel.hermesAgentConfigInspection != nil else {
            return t("Not inspected", "未確認")
        }
        return viewModel.hermesAgentPendingChangeKeys.isEmpty
            ? t("Matches selected model", "選択モデルと一致")
            : t("Configuration differs", "設定が不一致")
    }

    private var hermesStatusColor: Color {
        guard viewModel.hermesAgentConfigInspection != nil else { return .secondary }
        return viewModel.hermesAgentPendingChangeKeys.isEmpty ? .green : .orange
    }

    private func actionTitle(_ key: String) -> String {
        switch key {
        case "addProfile": t("Add a model profile", "モデルプロファイルを追加")
        case "reviewDiagnostics": t("Review diagnostics", "診断結果を確認")
        case "reviewRuntimeIssues": t("Review runtime issues", "ランタイム問題を確認")
        case "syncHermes": t("Align Hermes Agent", "Hermes Agent設定を整合")
        default: t("Verify readiness", "準備状態を確認")
        }
    }

    private func actionDetail(_ key: String) -> String {
        switch key {
        case "addProfileDetail": t("Create the first local model profile.", "最初のローカルモデルプロファイルを作成します。")
        case "reviewDiagnosticsDetail": t("Failures or warnings need review.", "失敗または警告を確認してください。")
        case "reviewRuntimeIssuesDetail": t("Inspect degraded models, busy ports, and logs.", "劣化状態、ポート競合、ログを確認します。")
        case "syncHermesDetail": t("Update Hermes Agent to match the selected model.", "Hermes Agentを選択モデルに合わせます。")
        default: t("Run diagnostics to confirm the current endpoint.", "診断を実行して現在の接続先を確認します。")
        }
    }

    private func trendTitle(_ trend: DiagnosticsTrend) -> String {
        switch trend {
        case .initial: t("Baseline recorded", "基準を記録")
        case .improved: t("Improved", "改善")
        case .worsened: t("Worsened", "悪化")
        case .unchanged: t("Unchanged", "変化なし")
        }
    }

    private func trendColor(_ trend: DiagnosticsTrend) -> Color {
        switch trend {
        case .initial, .unchanged: .secondary
        case .improved: .green
        case .worsened: .red
        }
    }

    private func actionImage(_ destination: DashboardActionDestination) -> String {
        switch destination {
        case .profiles: "square.grid.2x2"
        case .diagnostics: "stethoscope"
        case .settings: "gearshape"
        case .logs: "doc.text.magnifyingglass"
        }
    }

    private func open(_ destination: DashboardActionDestination) {
        switch destination {
        case .profiles: onOpenProfiles()
        case .diagnostics: onOpenDiagnostics()
        case .settings: onOpenSettings()
        case .logs: onOpenLogs()
        }
    }
}
