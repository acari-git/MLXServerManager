import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var showRunningOnly = false
    @State private var sortOrder: WorkspaceSortOrder = .recent
    let onOpenSession: (String) -> Void
    @State private var selectedWorkspacePath: String?
    @State private var selectedSessionID: String?
    @State private var exportFormat: WorkspaceExportFormat = .markdown
    @State private var exportMessage = ""

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var workspaceGroups: [WorkspaceGroup] {
        WorkspaceAnalytics.groups(
            from: viewModel.hermesAgentSessions,
            unknownWorkspaceName: t("Unknown workspace", "不明なワークスペース"),
            searchText: searchText,
            runningOnly: showRunningOnly,
            sortOrder: sortOrder
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Workspace", "ワークスペース"))
                        .font(.title3)
                    Text(t(
                        "Review Hermes Agent activity grouped by working directory.",
                        "Hermes Agentの作業履歴を作業ディレクトリ別に確認します。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    TextField(t("Search workspaces", "ワークスペースを検索"), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    Picker(t("Sort", "並び順"), selection: $sortOrder) {
                        Text(t("Recent", "最近使用")).tag(WorkspaceSortOrder.recent)
                        Text(t("Name", "名前")).tag(WorkspaceSortOrder.name)
                        Text(t("Session count", "セッション数")).tag(WorkspaceSortOrder.sessionCount)
                    }
                    .pickerStyle(.menu)
                    Toggle(t("Running only", "実行中のみ"), isOn: $showRunningOnly)
                        .toggleStyle(.switch)
                    Button {
                        viewModel.refreshHermesAgentSessions()
                    } label: {
                        Label(t("Refresh", "更新"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if workspaceGroups.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.hermesAgentSessions.isEmpty
                            ? t("No workspace history", "ワークスペース履歴なし")
                            : t("No matching workspaces", "該当するワークスペースなし"),
                        systemImage: "folder"
                    )
                } description: {
                    Text(
                        viewModel.hermesAgentSessions.isEmpty
                            ? t("Load Hermes Agent sessions to build a workspace overview.", "Hermes Agentセッションを読み込むと、ワークスペース概要が表示されます。")
                            : t("Change the search, sort, or running-session filter.", "検索条件、並び順、実行中フィルターを変更してください。")
                    )
                } actions: {
                    if viewModel.hermesAgentSessions.isEmpty {
                        Button {
                            viewModel.refreshHermesAgentSessions()
                        } label: {
                            Label(t("Load Sessions", "セッション読込"), systemImage: "arrow.clockwise")
                        }
                    } else {
                        Button {
                            searchText = ""
                            showRunningOnly = false
                        } label: {
                            Label(t("Clear Filters", "フィルター解除"), systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        summaryStrip
                        ForEach(workspaceGroups) { group in
                            workspaceCard(group)
                        }
                        if let selectedGroup {
                            workspaceDetail(selectedGroup)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if viewModel.hermesAgentSessions.isEmpty {
                viewModel.refreshHermesAgentSessions()
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryMetric(
                title: t("Workspaces", "ワークスペース"),
                value: "\(workspaceGroups.count)",
                systemImage: "folder"
            )
            summaryMetric(
                title: t("Sessions", "セッション"),
                value: "\(viewModel.hermesAgentSessions.count)",
                systemImage: "bubble.left.and.bubble.right"
            )
            summaryMetric(
                title: t("Messages", "メッセージ"),
                value: "\(viewModel.hermesAgentSessions.reduce(0) { $0 + $1.messageCount })",
                systemImage: "text.bubble"
            )
        }
    }

    private func summaryMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private var selectedGroup: WorkspaceGroup? {
        guard let selectedWorkspacePath else { return workspaceGroups.first }
        return workspaceGroups.first { $0.path == selectedWorkspacePath }
    }

    private func workspaceCard(_ group: WorkspaceGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.displayName)
                        .font(.headline)
                    Text(group.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                if group.path != t("Unknown workspace", "不明なワークスペース") {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: group.path, isDirectory: true))
                    } label: {
                        Label(t("Open", "開く"), systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            HStack(spacing: 14) {
                Label("\(group.sessions.count) \(t("sessions", "セッション"))", systemImage: "bubble.left.and.bubble.right")
                Label("\(group.messageCount) \(t("messages", "メッセージ"))", systemImage: "text.bubble")
                Label("\(group.toolCallCount) \(t("tool calls", "ツール呼出"))", systemImage: "wrench.and.screwdriver")
                Spacer()
                Text(Date(timeIntervalSince1970: group.latestStartedAt).formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            ForEach(group.sessions.prefix(3)) { session in
                HStack(spacing: 8) {
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(session.endedAt == nil ? Color.green : Color.secondary)
                    Text(session.title?.isEmpty == false ? session.title! : session.id)
                        .lineLimit(1)
                    Spacer()
                    Text(session.model ?? "-")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(session.messageCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedWorkspacePath == group.path ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.18), lineWidth: selectedWorkspacePath == group.path ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedWorkspacePath = group.path
            selectedSessionID = group.sessions.first?.id
        }
    }

    private func workspaceAnalytics(_ group: WorkspaceGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Usage Overview", "利用概要"))
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                analyticsMetric(
                    title: t("Total tokens", "総トークン"),
                    value: group.totalTokens.formatted(),
                    systemImage: "number"
                )
                analyticsMetric(
                    title: t("Avg. messages", "平均メッセージ"),
                    value: String(format: "%.1f", group.averageMessagesPerSession),
                    systemImage: "text.bubble"
                )
                analyticsMetric(
                    title: t("Active days", "活動日数"),
                    value: "\(group.activityDayCount)",
                    systemImage: "calendar"
                )
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Model usage", "モデル使用傾向"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(group.modelUsage.prefix(5), id: \.model) { usage in
                        HStack {
                            Text(usage.model)
                                .lineLimit(1)
                            Spacer()
                            Text("\(usage.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if group.modelUsage.isEmpty {
                        Text(t("No model data", "モデル情報なし"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Activity period", "活動期間"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(group.activityPeriodText)
                        .font(.caption)
                    Text(t("Average tokens per session", "セッション平均トークン"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(group.averageTokensPerSession.formatted())
                        .font(.headline.monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
    }

    private func exportWorkspace(_ group: WorkspaceGroup) {
        let panel = NSSavePanel()
        let safeName = WorkspaceAnalytics.sanitizedFileName(group.displayName)
        panel.nameFieldStringValue = "\(safeName)-workspace-analysis.\(exportFormat.fileExtension)"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = exportFormat == .markdown
            ? [UTType(filenameExtension: "md") ?? .plainText]
            : [.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else {
            exportMessage = t("Workspace export cancelled.", "ワークスペースの書き出しをキャンセルしました。")
            return
        }

        do {
            let text = exportFormat == .markdown
                ? WorkspaceAnalytics.markdown(for: group)
                : WorkspaceAnalytics.csv(for: group)
            try text.write(to: url, atomically: true, encoding: .utf8)
            exportMessage = t(
                "Exported workspace analysis to \(url.lastPathComponent).",
                "ワークスペース分析を\(url.lastPathComponent)へ書き出しました。"
            )
        } catch {
            exportMessage = t(
                "Workspace export failed: \(error.localizedDescription)",
                "ワークスペースの書き出しに失敗しました: \(error.localizedDescription)"
            )
        }
    }

    private func analyticsMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func workspaceDetail(_ group: WorkspaceGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Workspace Details", "ワークスペース詳細"))
                        .font(.headline)
                    Text(group.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Picker(t("Export format", "書き出し形式"), selection: $exportFormat) {
                    Text("Markdown").tag(WorkspaceExportFormat.markdown)
                    Text("CSV").tag(WorkspaceExportFormat.csv)
                }
                .pickerStyle(.menu)
                Button {
                    exportWorkspace(group)
                } label: {
                    Label(t("Export Analysis", "分析を書き出す"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            if !exportMessage.isEmpty {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            workspaceAnalytics(group)

            Picker(t("Session", "セッション"), selection: $selectedSessionID) {
                ForEach(group.sessions) { session in
                    Text(session.title?.isEmpty == false ? session.title! : session.id)
                        .tag(Optional(session.id))
                }
            }
            .pickerStyle(.menu)

            if let session = group.sessions.first(where: { $0.id == selectedSessionID }) ?? group.sessions.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.title?.isEmpty == false ? session.title! : session.id)
                            .font(.headline)
                        Spacer()
                        Text(session.endedAt == nil ? t("Running", "実行中") : t("Completed", "完了"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(session.endedAt == nil ? Color.green : Color.secondary)
                    }
                    Text("\(session.source) · \(session.model ?? "-")")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        Label { Text(verbatim: "\(session.messageCount)") } icon: { Image(systemName: "text.bubble") }
                        Label { Text(verbatim: "\(session.toolCallCount)") } icon: { Image(systemName: "wrench.and.screwdriver") }
                        Label { Text(verbatim: "\(session.inputTokens + session.outputTokens)") } icon: { Image(systemName: "number") }
                        Spacer()
                        Text(Date(timeIntervalSince1970: session.startedAt).formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    Button {
                        viewModel.selectedHermesAgentSessionID = session.id
                        viewModel.refreshSelectedHermesAgentTranscript()
                        onOpenSession(session.id)
                    } label: {
                        Label(t("Open Session Transcript", "セッショントランスクリプトを開く"), systemImage: "arrow.right.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
    }
}

