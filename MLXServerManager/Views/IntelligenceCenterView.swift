import SwiftUI

struct IntelligenceCenterView: View {
    @ObservedObject var viewModel: AppViewModel
    let onNavigate: (IntelligenceDestination) -> Void
    @State private var severityFilter: IntelligenceSeverity?
    @State private var assignments = AgentAssignmentStore.load()

    private var strings: AppLocalization { AppLocalization(language: viewModel.settings.uiLanguage) }
    private func t(_ english: String, _ japanese: String) -> String { strings.text(english: english, japanese: japanese) }

    private var overview: IntelligenceOverview {
        IntelligenceOverview(
            rows: viewModel.modelListRowStates(from: viewModel.models),
            diagnostics: viewModel.diagnosticsResults,
            diagnosticsHistory: viewModel.diagnosticsHistory,
            sessions: viewModel.hermesAgentSessions,
            assignments: assignments,
            hermesInspected: viewModel.hermesAgentConfigInspection != nil,
            hermesMatchesSelectedModel: viewModel.hermesAgentPendingChangeKeys.isEmpty
        )
    }

    private var visibleInsights: [IntelligenceInsight] {
        guard let severityFilter else { return overview.insights }
        return overview.insights.filter { $0.severity == severityFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                scoreCard
                metricGrid
                filters
                insightList
                boundaryCard
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { assignments = AgentAssignmentStore.load() }
        .accessibilityIdentifier("intelligence-center")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(t("Intelligence Center", "インテリジェンスセンター"))
                    .font(.title2.weight(.semibold))
                Text(t("Prioritized, evidence-based recommendations across runtime, diagnostics, agents, and workspace activity.", "ランタイム、診断、エージェント、ワークスペース活動を横断し、根拠付きの提案を優先度順に表示します。"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.runDiagnosticsRequested()
                viewModel.refreshHermesAgentSessions()
                _ = viewModel.inspectHermesAgentConfigRequested()
                assignments = AgentAssignmentStore.load()
            } label: {
                Label(t("Refresh evidence", "根拠を更新"), systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isDiagnosticsRunning)
        }
    }

    private var scoreCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(overview.score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(overview.score)").font(.title.weight(.bold))
                    Text("/ 100").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 8) {
                Text(scoreTitle).font(.title3.weight(.semibold))
                Text(t("The score is calculated from explicit diagnostics, runtime state, Hermes configuration, and available activity evidence.", "スコアは診断、ランタイム状態、Hermes設定、取得済み活動データから明示的な規則で計算されます。"))
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Label("\(overview.criticalCount) " + t("critical", "重大"), systemImage: "xmark.octagon.fill")
                    Label("\(overview.attentionCount) " + t("attention", "要確認"), systemImage: "exclamationmark.triangle.fill")
                    Label("\(overview.opportunityCount) " + t("opportunities", "改善候補"), systemImage: "sparkles")
                }
                .font(.caption)
            }
            Spacer()
        }
        .padding(18)
        .background(cardBackground)
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            metric(t("Profiles", "プロファイル"), overview.profileCount, "square.stack.3d.up")
            metric(t("Sessions", "セッション"), overview.sessionCount, "clock.arrow.circlepath")
            metric(t("Enabled agents", "有効エージェント"), overview.enabledAgentCount, "person.3")
            metric(t("Diagnostic samples", "診断サンプル"), overview.diagnosticsSampleCount, "waveform.path.ecg")
        }
    }

    private func metric(_ title: String, _ value: Int, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text("\(value)").font(.title3.weight(.semibold))
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(cardBackground)
    }

    private var filters: some View {
        HStack {
            Text(t("Recommendations", "提案"))
                .font(.headline)
            Spacer()
            Picker(t("Severity", "重要度"), selection: $severityFilter) {
                Text(t("All", "すべて")).tag(IntelligenceSeverity?.none)
                ForEach(IntelligenceSeverity.allCases) { severity in
                    Text(severityTitle(severity)).tag(Optional(severity))
                }
            }
            .frame(width: 170)
        }
    }

    private var insightList: some View {
        VStack(spacing: 10) {
            ForEach(visibleInsights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: severityIcon(insight.severity))
                        .foregroundStyle(severityColor(insight.severity))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(title(for: insight)).font(.headline)
                            Text(severityTitle(insight.severity))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(severityColor(insight.severity).opacity(0.14), in: Capsule())
                        }
                        Text(detail(for: insight)).foregroundStyle(.secondary)
                        Text(t("Evidence: ", "根拠: ") + insight.evidence)
                            .font(.caption).foregroundStyle(.secondary)
                        Text(t("Confidence: ", "信頼度: ") + "\(insight.confidence)%")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button(t("Open", "開く")) { onNavigate(insight.destination) }
                }
                .padding(14)
                .background(cardBackground)
            }
        }
    }

    private var boundaryCard: some View {
        Label(t("Recommendations are advisory. Intelligence Center does not start models, modify Hermes configuration, route inference, or run agent tasks automatically.", "提案は助言のみです。モデル起動、Hermes設定変更、推論ルーティング、エージェントタスクの自動実行は行いません。"), systemImage: "hand.raised")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(14)
            .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.4)))
    }

    private var scoreColor: Color { overview.score >= 80 ? .green : overview.score >= 55 ? .orange : .red }
    private var scoreTitle: String {
        overview.score >= 80 ? t("System evidence is healthy", "システム根拠は良好です") : overview.score >= 55 ? t("Review recommended actions", "推奨対応を確認してください") : t("Immediate review recommended", "早急な確認を推奨します")
    }
    private func severityTitle(_ value: IntelligenceSeverity) -> String {
        switch value { case .critical: t("Critical", "重大"); case .attention: t("Attention", "要確認"); case .opportunity: t("Opportunity", "改善候補"); case .healthy: t("Healthy", "良好") }
    }
    private func severityIcon(_ value: IntelligenceSeverity) -> String {
        switch value { case .critical: "xmark.octagon.fill"; case .attention: "exclamationmark.triangle.fill"; case .opportunity: "sparkles"; case .healthy: "checkmark.circle.fill" }
    }
    private func severityColor(_ value: IntelligenceSeverity) -> Color {
        switch value { case .critical: .red; case .attention: .orange; case .opportunity: .blue; case .healthy: .green }
    }
    private func title(for insight: IntelligenceInsight) -> String {
        switch insight.titleKey {
        case "diagnosticFailuresTitle": t("Resolve failed diagnostics", "失敗した診断を解消")
        case "runtimeInstabilityTitle": t("Review runtime instability", "ランタイム不安定状態を確認")
        case "hermesMismatchTitle": t("Align Hermes Agent configuration", "Hermes Agent設定を整合")
        case "diagnosticWarningsTitle": t("Review diagnostic warnings", "診断警告を確認")
        case "noProfilesTitle": t("Register a model profile", "モデルプロファイルを登録")
        case "insufficientTrendTitle": t("Build diagnostic trend evidence", "診断トレンドの根拠を蓄積")
        case "agentAssignmentsTitle": t("Complete agent assignments", "エージェント割り当てを完成")
        case "noSessionEvidenceTitle": t("Load Hermes Agent activity", "Hermes Agent活動を読み込み")
        case "staleActivityTitle": t("Review stale workspace activity", "古いワークスペース活動を確認")
        case "readyToLaunchTitle": t("Profiles appear ready for manual launch", "プロファイルは手動起動可能な状態です")
        default: t("No actionable issue detected", "対応が必要な問題は検出されていません")
        }
    }
    private func detail(for insight: IntelligenceInsight) -> String {
        switch insight.detailKey {
        case "diagnosticFailuresDetail": t("Open Diagnostics and address failed checks before relying on the endpoint.", "診断を開き、接続先を利用する前に失敗項目へ対応してください。")
        case "runtimeInstabilityDetail": t("Inspect runtime logs and port ownership before restarting manually.", "手動再起動の前にランタイムログとポート所有状況を確認してください。")
        case "hermesMismatchDetail": t("Inspect the pending Hermes changes and apply them only after review.", "Hermesの変更予定を確認し、レビュー後にのみ反映してください。")
        case "diagnosticWarningsDetail": t("Warnings may not block operation but should be reviewed.", "警告は動作を妨げない場合がありますが、確認を推奨します。")
        case "noProfilesDetail": t("A registered profile is required before managed local operation.", "管理対象のローカル運用には登録済みプロファイルが必要です。")
        case "insufficientTrendDetail": t("Run the readiness audit more than once to detect improvement or regression.", "改善や悪化を検出するため、準備状態監査を複数回実行してください。")
        case "agentAssignmentsDetail": t("Assign enabled agents to explicit profiles to clarify responsibility.", "有効なエージェントへ明示的なプロファイルを割り当て、担当を明確にしてください。")
        case "noSessionEvidenceDetail": t("Refresh local Hermes sessions to improve workspace and usage evidence.", "ローカルHermesセッションを更新し、ワークスペースと利用状況の根拠を増やしてください。")
        case "staleActivityDetail": t("Review whether the current assignments and workspaces are still relevant.", "現在の割り当てとワークスペースが引き続き有効か確認してください。")
        case "readyToLaunchDetail": t("No critical issue was detected, but launch remains an explicit user action.", "重大な問題は検出されていませんが、起動は明示的なユーザー操作です。")
        default: t("Continue periodic explicit diagnostics to maintain evidence.", "根拠を維持するため、明示的な診断を定期的に実行してください。")
        }
    }
}
