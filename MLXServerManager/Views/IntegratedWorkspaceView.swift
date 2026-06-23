import SwiftUI

struct IntegratedWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State var selectedDestination: IntegratedWorkspaceDestination = .models

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }

    var body: some View {
        HSplitView {
            leftColumn
                .frame(minWidth: 190, idealWidth: 220, maxWidth: 250)
            centerColumn
                .frame(minWidth: 620, idealWidth: 760)
            rightColumn
                .frame(minWidth: 360, idealWidth: 430, maxWidth: 520)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("integrated-workspace")
    }

    private var leftColumn: some View {
        VStack(spacing: 0) {
            IntegratedSidebarMenuView(selectedDestination: $selectedDestination)
            Divider()
            systemPanel
            Divider()
            footerPanel
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var systemPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SYSTEM")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            memoryGaugeCard
            systemMetricCard(
                title: "CPU",
                value: viewModel.integratedCPUUsageText,
                detail: "not sampled"
            )
            systemMetricCard(
                title: "GPU/Metal",
                value: viewModel.integratedGPUUsageText,
                detail: "not sampled"
            )
            systemMetricCard(
                title: "起動時間",
                value: viewModel.integratedUptimeText,
                detail: "session scoped"
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var memoryGaugeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メモリ使用状況")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Gauge(value: viewModel.integratedMemoryUsageFraction) {
                    Text("Memory")
                } currentValueLabel: {
                    Text(viewModel.integratedMemoryUsagePercentText)
                        .font(.caption.weight(.bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.green)
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.memoryUsageText)
                        .font(.caption.weight(.semibold))
                    Text("合計 64.0 GB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("空き 33.4 GB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("メモリプレッシャー")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("正常")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func systemMetricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footerPanel: some View {
        VStack(spacing: 6) {
            Text("MLX Server Manager")
                .font(.callout.weight(.semibold))
            Text("Version 0.16.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centerColumn: some View {
        switch selectedDestination {
        case .models:
            VStack(spacing: 0) {
                modelListPanel
                    .frame(minHeight: 390, idealHeight: 460)
                Divider()
                actionBar
                    .frame(height: 74)
                Divider()
                logPanel
                    .frame(minHeight: 250)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        case .downloads:
            DownloadsSurfaceView(viewModel: viewModel)
        case .settings:
            SettingsSurfaceView(viewModel: viewModel)
        case .logs:
            LogsSurfaceView(
                entries: viewModel.logEntries,
                targetSummary: viewModel.connectionTargetSummary,
                runningModelText: viewModel.runningModelText,
                onCopy: viewModel.copyLogsRequested,
                onClear: viewModel.clearLogsRequested
            )
        case .help:
            integratedHelpPanel
        }
    }

    private var integratedHelpPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("ヘルプ", systemImage: "questionmark.circle")
                    .font(.title2.weight(.semibold))
                Text("MLX Server Manager は Direct Mode で mlx_lm.server を管理します。")
                    .font(.headline)
                DetailGrid(rows: [
                    ("接続", "client → mlx_lm.server"),
                    ("モデル操作", "モデル一覧で選択し、中央の起動/停止/再起動を使います"),
                    ("Hermes Agent", "右下の接続情報をコピーして外部 client に貼り付けます"),
                    ("ログ", "中央下または左メニューのログで状態を確認します"),
                    ("除外", "Chat UI / proxy / telemetry / token storage はありません")
                ])
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var modelListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("モデル一覧")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    viewModel.addProfileRequested()
                } label: {
                    Label("モデル追加", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)

            Divider()

            modelHeaderRow
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.visibleModels) { model in
                        modelRow(model)
                    }
                }
                .padding(14)
            }
        }
    }

    private var modelHeaderRow: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                headerText("モデル名 / 用途").gridCellColumns(2)
                headerText("ステータス")
                headerText("サーバーポート")
                headerText("プロセスメモリ")
                headerText("最終確認")
                headerText("停止方式")
            }
        }
    }

    private func modelRow(_ model: ModelConfig) -> some View {
        Button {
            viewModel.selectedModelID = model.id
        } label: {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(model.notes.isEmpty ? model.family : model.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .gridCellColumns(2)

                    VStack(alignment: .leading, spacing: 3) {
                        statusPill(viewModel.integratedStatusText(for: model))
                        if let warning = viewModel.duplicateProfileWarning(for: model) {
                            statusPill(warning)
                        }
                        Text(viewModel.integratedStatusDetail(for: model))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    portValue(String(model.serverPort))
                    memoryCell(viewModel.integratedMemoryText(for: model))
                    Text(viewModel.integratedLatestUseText(for: model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.integratedStopModeText(for: model))
                        .font(.caption)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
    }

    private func headerText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func portValue(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text("127.0.0.1")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func memoryCell(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundColor(text == "-" ? .secondary : .green)
            ProgressView(value: text == "-" ? 0 : 0.48)
                .frame(width: 62)
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(text == "Ready" ? .green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((text == "Ready" ? Color.green : Color.secondary).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                viewModel.startRequested()
            } label: {
                Label("起動", systemImage: "play.fill")
                    .frame(width: 110)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartSelectedModel)

            Button {
                viewModel.stopRequested()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .frame(width: 110)
            }
            .disabled(!viewModel.canStopManagedServer)

            Button {
                viewModel.restartRequested()
            } label: {
                Label("再起動", systemImage: "arrow.clockwise")
                    .frame(width: 120)
            }
            .disabled(!viewModel.canRestartManagedServer)

            Button {
                viewModel.runSpeedTestRequested()
            } label: {
                Label("スピードテスト", systemImage: "bolt")
                    .frame(width: 150)
            }
            .disabled(!viewModel.canRunSpeedTest)

                Spacer()
            }

            Text(viewModel.integratedActionStateSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36))
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ログ (\(selectedModel?.displayName ?? "全体"))")
                    .font(.headline)
                Spacer()
                Picker("Category", selection: $viewModel.logCategoryFilter) {
                    ForEach(viewModel.logCategoryFilterOptions, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                Button("コピー") {
                    viewModel.copyLogsRequested()
                }
                .disabled(viewModel.visibleLogEntries.isEmpty)
                Button("クリア") {
                    viewModel.clearLogsRequested()
                }
            }
            .padding(14)

            Divider()

            if let latestImportant = viewModel.latestImportantLogEntry {
                Label(latestImportant.line, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if viewModel.visibleLogEntries.isEmpty {
                        Text("No logs")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(viewModel.visibleLogEntries.prefix(16)) { entry in
                            Text(entry.line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(entry.line.localizedCaseInsensitiveContains("error") || entry.line.localizedCaseInsensitiveContains("failed") ? .orange : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(14)
            }

            Divider()

            HStack {
                Label("全体ステータス: \(viewModel.runtimeState.title)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
            }
            .font(.caption)
            .padding(10)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.20))
    }

    private var rightColumn: some View {
        VStack(spacing: 0) {
            modelSettingsPanel
                .frame(minHeight: 510, idealHeight: 590)
            Divider()
            hermesPanel
                .frame(minHeight: 210)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.38))
    }

    private var modelSettingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                            Text("モデル設定")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        viewModel.editProfileRequested()
                    } label: {
                        Text("編集")
                    }
                    .disabled(selectedModel == nil)
                    .help(selectedModel.map { viewModel.runtimeEditingSafetyText(for: $0) } ?? "No model selected")

                    Button(role: .destructive) {
                        viewModel.deleteProfileRequested()
                    } label: {
                        Text("削除")
                    }
                    .disabled(selectedModel == nil || viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)
                }

                groupedSection("Safety") {
                    formRow("Summary", viewModel.selectedModelSafetySummary, valueColor: viewModel.selectedModelSafetySummary == "Safety: OK" ? .green : .orange)
                    ForEach(viewModel.selectedModelSafetyRows, id: \.0) { row in
                        formRow(row.0, row.1, valueColor: row.1 == "OK" || row.1 == "Available" || row.1 == "Ready" || row.1 == "OK local path" ? .green : .orange)
                    }
                    formRow("Recovery", viewModel.failedStartRecoverySummary, valueColor: viewModel.failedStartRecoverySummary == "No failed start recovery needed." ? .secondary : .orange)
                    Button {
                        viewModel.copySafetySummary()
                    } label: {
                        Text("Safety summary をコピー")
                            .frame(maxWidth: .infinity)
                    }
                }

                IntegratedRecoveryPanelView(
                    issue: viewModel.currentRecoveryIssue,
                    onAction: handleRecoveryAction,
                    onCopyTroubleshooting: viewModel.copyTroubleshootingSummary,
                    onRefreshSafety: viewModel.refreshIntegratedSafetyRequested
                )

                groupedSection("基本情報") {
                    formRow("モデル名", selectedModel?.displayName ?? "-")
                    formRow("モデルID (Hugging Face)", selectedModel?.modelID ?? "-")
                    formRow("モデル検証", viewModel.selectedModelIdentityDetailText, valueColor: viewModel.selectedModelIdentityDetailText.localizedCaseInsensitiveContains("Missing") || viewModel.selectedModelIdentityDetailText.localizedCaseInsensitiveContains("review") ? .orange : .green)
                    formRow("用途・メモ", selectedModel?.notes.isEmpty == false ? selectedModel?.notes ?? "-" : "-")
                }

                groupedSection("Direct Mode ポート") {
                    formRow("mlx_lm.server", selectedModel.map { String($0.serverPort) } ?? "-")
                    availabilityPill("\(selectedModel?.serverPort ?? 0): \(viewModel.selectedServerPortSafetyText)")
                }

                groupedSection("動作設定") {
                    HStack {
                        Text("Thinking モード（Qwen系）")
                            .font(.caption)
                        Spacer()
                        Toggle("", isOn: .constant(selectedModel?.enableThinking ?? false))
                            .labelsHidden()
                            .disabled(true)
                        Text((selectedModel?.enableThinking ?? false) ? "ON" : "OFF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    formRow("停止方式", "手動停止のみ")
                }

                groupedSection("状態情報") {
                    formRow("ステータス", isSelectedRunning ? "Ready" : "Stopped", valueColor: isSelectedRunning ? .green : .secondary)
                    formRow("最終確認", selectedModel.map { viewModel.integratedLatestUseText(for: $0) } ?? "-")
                    formRow("起動時刻", viewModel.runtimeEvents.first?.timestamp.formatted(date: .numeric, time: .standard) ?? "-")
                    formRow("プロセスID", isSelectedRunning ? "managed" : "-")
                    formRow("プロセスメモリ", isSelectedRunning ? viewModel.memoryUsageText : "-")
                    formRow("スピードテスト", viewModel.latestBenchmarkResult?.summary ?? "Not run")
                }
            }
            .padding(14)
        }
    }

    private func groupedSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formRow(_ title: String, _ value: String, valueColor: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 132, alignment: .leading)
            Text(value)
                .font(.callout)
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func availabilityPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var hermesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hermes Agent 接続情報")
                .font(.headline)

            copyRow("Base URL", value: viewModel.baseURL, action: { viewModel.copyBaseURL() })
            copyRow("API Key", value: viewModel.apiKeyPlaceholder, action: { viewModel.copyAPIKeyPlaceholder() })
            copyRow("Model", value: viewModel.selectedModelIdentifier, action: { viewModel.copyModelID() })

            Text("Direct Mode: Hermes Agent connects directly to mlx_lm.server. Direct Mode only.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                viewModel.copyHermesAgentConfig()
            } label: {
                Text("Hermes 設定をまとめてコピー")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Text("Manager: \(viewModel.runtimeState.title)")
                Spacer()
                Text("Direct Mode")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private func copyRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button("コピー", action: action)
        }
    }
}
