import AppKit
import SwiftUI

struct PlatformIntegrationView: View {
    @ObservedObject var viewModel: AppViewModel
    let onNavigate: (IntegratedWorkspaceDestination) -> Void

    @State private var assignments = AgentAssignmentStore.load()
    @State private var runbooks = AutomationStore.loadRunbooks()
    @State private var message = ""

    private var profileIDs: Set<String> { Set(viewModel.models.map(\.id)) }
    private var snapshot: PlatformIntegrationSnapshot {
        PlatformIntegrationSnapshot(
            profileIDs: profileIDs,
            diagnosticsHistoryCount: viewModel.diagnosticsHistory.count,
            sessionCount: viewModel.hermesAgentSessions.count,
            runbooks: runbooks,
            assignments: assignments,
            hermesConfigPath: viewModel.settings.hermesConfigPath
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCard
                integrationGrid
                reconciliationCard
                safetyCard
            }
            .padding(20)
        }
        .onAppear { reload() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(t("Platform Integration", "プラットフォーム統合"))
                    .font(.title2.bold())
                Text(t(
                    "Final integration status across profiles, diagnostics, sessions, automation, agents, and Hermes Agent.",
                    "プロファイル、診断、セッション、自動化、エージェント、Hermes Agentを横断した最終統合状態です。"
                ))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { reload() } label: {
                Label(t("Refresh", "更新"), systemImage: "arrow.clockwise")
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stateTitle(snapshot.state)).font(.headline)
                Text(t("Integration completion", "統合完了度")).foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: "\(snapshot.completionPercent)%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snapshot.markdownReport(), forType: .string)
                message = t("Platform report copied.", "プラットフォームレポートをコピーしました。")
            } label: {
                Label(t("Copy Report", "レポートをコピー"), systemImage: "doc.on.doc")
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }

    private var integrationGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
            ForEach(snapshot.items) { item in
                Button { navigate(for: item.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: symbol(for: item.id))
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(itemTitle(item.titleKey)).font(.headline)
                            Text(itemDetail(item.detailKey)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(stateTitle(item.state)).font(.caption.bold())
                            Text(verbatim: "\(item.evidenceCount)").font(.title3.monospacedDigit())
                        }
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var reconciliationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("State Reconciliation", "状態リコンシリエーション")).font(.headline)
            Text(t(
                "Remove references to profiles that no longer exist while preserving agent roles, notes, and enabled states.",
                "存在しないプロファイルへの参照だけを解除し、エージェントの役割、メモ、有効状態は維持します。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text(t("Orphan assignments", "孤立した割り当て"))
                Spacer()
                Text(verbatim: "\(snapshot.orphanAssignmentCount)").monospacedDigit()
                Button(t("Reconcile", "整合する")) {
                    assignments = PlatformIntegrationReconciler.reconcile(assignments: assignments, validProfileIDs: profileIDs)
                    AgentAssignmentStore.save(assignments)
                    message = t("Integration state reconciled.", "統合状態を整合しました。")
                }
                .disabled(snapshot.orphanAssignmentCount == 0)
            }
            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var safetyCard: some View {
        Label(t(
            "Platform integration is status and metadata reconciliation only. It does not start models, route inference, run agents, or modify Hermes configuration.",
            "プラットフォーム統合は状態確認とメタデータ整合のみです。モデル起動、推論ルーティング、エージェント実行、Hermes設定変更は行いません。"
        ), systemImage: "lock.shield")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(14)
    }

    private func reload() {
        assignments = AgentAssignmentStore.load()
        runbooks = AutomationStore.loadRunbooks()
    }

    private func navigate(for id: String) {
        switch id {
        case "profiles": onNavigate(.profiles)
        case "diagnostics": onNavigate(.diagnostics)
        case "sessions": onNavigate(.workspace)
        case "automation": onNavigate(.automation)
        case "agents": onNavigate(.agents)
        case "hermes": onNavigate(.settings)
        default: break
        }
    }

    private func stateTitle(_ state: PlatformIntegrationState) -> String {
        switch state {
        case .ready: t("Ready", "準備完了")
        case .attention: t("Attention", "要確認")
        case .incomplete: t("Incomplete", "未完了")
        }
    }

    private func itemTitle(_ key: String) -> String {
        switch key {
        case "profiles": t("Profile Library", "プロファイルライブラリ")
        case "diagnostics": t("Diagnostics History", "診断履歴")
        case "sessions": t("Hermes Sessions", "Hermesセッション")
        case "automation": t("Automation Runbooks", "自動化Runbook")
        case "agents": t("Agent Assignments", "エージェント割り当て")
        default: t("Hermes Configuration", "Hermes設定")
        }
    }

    private func itemDetail(_ key: String) -> String {
        switch key {
        case "profilesDetail": t("Registered execution profiles.", "登録済み実行プロファイルです。")
        case "diagnosticsDetail": t("Persisted evidence for trend analysis.", "トレンド分析に使用する保存済み根拠です。")
        case "sessionsDetail": t("Local Hermes Agent activity evidence.", "ローカルHermes Agentの活動根拠です。")
        case "automationDetail": t("Enabled explicit-run operational workflows.", "有効な明示実行型運用ワークフローです。")
        case "agentsDetail": t("Enabled roles and profile ownership.", "有効な役割と担当プロファイルです。")
        default: t("Configured local Hermes Agent YAML path.", "設定済みのローカルHermes Agent YAMLパスです。")
        }
    }

    private func symbol(for id: String) -> String {
        switch id {
        case "profiles": "square.grid.2x2"
        case "diagnostics": "stethoscope"
        case "sessions": "bubble.left.and.bubble.right"
        case "automation": "checklist"
        case "agents": "person.3.sequence"
        default: "point.3.connected.trianglepath.dotted"
        }
    }

    private func t(_ english: String, _ japanese: String) -> String {
        AppLocalization(language: viewModel.settings.uiLanguage).text(english: english, japanese: japanese)
    }
}
