import SwiftUI

struct MultiAgentHubView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenWorkspace: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var assignments = AgentAssignmentStore.load()

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var activity: AgentActivitySummary {
        .hermes(sessions: viewModel.hermesAgentSessions)
    }

    private var enabledCount: Int {
        assignments.filter(\.isEnabled).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCards
                hermesActivityCard
                assignmentSection
                safetyCard
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: assignments) {
            AgentAssignmentStore.save(assignments)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Multi-Agent Hub", "マルチエージェントハブ"))
                    .font(.title2.weight(.semibold))
                Text(t(
                    "Review agent activity and explicitly assign roles and model profiles without automatic routing.",
                    "エージェントの活動を確認し、自動ルーティングを行わずに役割とモデルプロファイルを明示的に割り当てます。"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.refreshHermesAgentSessions()
            } label: {
                Label(t("Refresh Activity", "活動を更新"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            metricCard(title: t("Configured agents", "設定済みエージェント"), value: assignments.count, icon: "person.3")
            metricCard(title: t("Enabled assignments", "有効な割り当て"), value: enabledCount, icon: "checkmark.circle")
            metricCard(title: t("Hermes sessions", "Hermesセッション"), value: activity.sessionCount, icon: "bubble.left.and.bubble.right")
            metricCard(title: t("Tool calls", "ツール呼び出し"), value: activity.toolCallCount, icon: "wrench.and.screwdriver")
        }
    }

    private func metricCard(title: String, value: Int, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
    }

    private var hermesActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("Hermes Agent", "Hermes Agent連携"), systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer()
                if activity.activeSessionCount > 0 {
                    Label(t("Recent activity", "最近の活動あり"), systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text(t("No recent activity", "最近の活動なし"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 18) {
                activityValue(t("Messages", "メッセージ"), activity.messageCount)
                activityValue(t("Tokens", "トークン"), activity.totalTokens)
                activityValue(t("Models", "モデル"), activity.models.count)
                activityValue(t("Workspaces", "ワークスペース"), activity.workspaces.count)
                Spacer()
            }

            if activity.models.isEmpty {
                Text(t("Load recent Hermes Agent sessions to populate activity details.", "最近のHermes Agentセッションを読み込むと活動詳細が表示されます。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(activity.models.joined(separator: " · "))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            HStack {
                Button(t("Open Workspace", "ワークスペースを開く"), action: onOpenWorkspace)
                    .buttonStyle(.bordered)
                Button(t("Open Hermes Settings", "Hermes設定を開く"), action: onOpenSettings)
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.68), in: RoundedRectangle(cornerRadius: 14))
    }

    private func activityValue(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Agent Assignments", "エージェント割り当て"))
                        .font(.headline)
                    Text(t("Assignments are metadata only and never switch models or route requests automatically.", "割り当てはメタデータのみで、モデル切替やリクエストの自動ルーティングは行いません。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(AgentProvider.allCases) { provider in
                        Button(providerTitle(provider)) {
                            assignments.append(AgentAssignment(provider: provider, role: .general))
                        }
                    }
                } label: {
                    Label(t("Add Assignment", "割り当てを追加"), systemImage: "plus")
                }
            }

            ForEach($assignments) { $assignment in
                assignmentCard($assignment)
            }
        }
    }

    private func assignmentCard(_ assignment: Binding<AgentAssignment>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(isOn: assignment.isEnabled) {
                EmptyView()
            }
                .labelsHidden()
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(providerTitle(assignment.wrappedValue.provider), systemImage: providerIcon(assignment.wrappedValue.provider))
                        .font(.headline)
                    Spacer()
                    Button(role: .destructive) {
                        assignments.removeAll { $0.id == assignment.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(t("Remove assignment", "割り当てを削除"))
                }

                HStack(spacing: 12) {
                    Picker(t("Role", "役割"), selection: assignment.role) {
                        ForEach(AgentRole.allCases) { role in
                            Text(roleTitle(role)).tag(role)
                        }
                    }
                    .frame(maxWidth: 190)

                    Picker(t("Profile", "プロファイル"), selection: assignment.profileID) {
                        Text(t("Unassigned", "未割り当て")).tag(String?.none)
                        ForEach(viewModel.models) { model in
                            Text(model.displayName).tag(Optional(model.id))
                        }
                    }
                    .frame(maxWidth: 280)
                }

                TextField(t("Notes", "メモ"), text: assignment.notes)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private var safetyCard: some View {
        Label {
            Text(t(
                "The hub does not launch agents, send prompts, modify Hermes configuration, or route inference traffic. All operational actions remain explicit.",
                "このハブはエージェント起動、プロンプト送信、Hermes設定変更、推論通信のルーティングを行いません。運用操作はすべて明示的に実行します。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.shield")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42), in: RoundedRectangle(cornerRadius: 12))
    }

    private func providerTitle(_ provider: AgentProvider) -> String {
        switch provider {
        case .hermes: "Hermes Agent"
        case .codex: "Codex"
        case .local: t("Local Agent", "ローカルエージェント")
        }
    }

    private func providerIcon(_ provider: AgentProvider) -> String {
        switch provider {
        case .hermes: "point.3.connected.trianglepath.dotted"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .local: "desktopcomputer"
        }
    }

    private func roleTitle(_ role: AgentRole) -> String {
        switch role {
        case .coordinator: t("Coordinator", "統括")
        case .coding: t("Coding", "コーディング")
        case .review: t("Review", "レビュー")
        case .research: t("Research", "調査")
        case .general: t("General", "汎用")
        }
    }
}
