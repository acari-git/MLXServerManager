import SwiftUI

struct IntegratedWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedDestination: IntegratedWorkspaceDestination = .models

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }
    private var proxyPortText: String {
        guard let selectedModel else { return "-" }
        return String(selectedModel.serverPort + 10000)
    }

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
                title: "CPU使用率",
                value: viewModel.integratedCPUUsageText,
                detail: "runtime sampling later"
            )
            systemMetricCard(
                title: "GPU/Metal",
                value: viewModel.integratedGPUUsageText,
                detail: "Metal usage estimate"
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

    private var centerColumn: some View {
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
                headerText("プロキシポート")
                headerText("メモリ使用量")
                headerText("最終使用")
                headerText("自動アンロード")
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
                        Text(viewModel.integratedStatusDetail(for: model))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    portValue(String(model.serverPort))
                    portValue(String(viewModel.integratedProxyPort(for: model)))
                    memoryCell(viewModel.integratedMemoryText(for: model))
                    Text(viewModel.integratedLatestUseText(for: model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(viewModel.integratedAutoUnloadText(for: model))
                            .font(.caption)
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.accentColor)
                    }
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
        HStack(spacing: 12) {
            Button {
                viewModel.startRequested()
            } label: {
                Label("起動", systemImage: "play.fill")
                    .frame(width: 110)
            }
            .buttonStyle(.borderedProminent)

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
        .padding(.horizontal, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36))
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ログ (\(selectedModel?.displayName ?? "全体"))")
                    .font(.headline)
                Spacer()
                Button("クリア") {
                    viewModel.clearLogsRequested()
                }
            }
            .padding(14)

            Divider()

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
                    Button(role: .destructive) {
                        viewModel.deleteProfileRequested()
                    } label: {
                        Text("削除")
                    }
                    .disabled(selectedModel == nil || viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)
                }

                groupedSection("基本情報") {
                    formRow("モデル名", selectedModel?.displayName ?? "-")
                    formRow("モデルID (Hugging Face)", selectedModel?.modelID ?? "-")
                    formRow("用途・メモ", selectedModel?.notes.isEmpty == false ? selectedModel?.notes ?? "-" : "-")
                }

                groupedSection("ポート設定") {
                    formRow("サーバーポート (mlx_lm.server)", selectedModel.map { String($0.serverPort) } ?? "-")
                    formRow("プロキシポート (Hermes接続用)", proxyPortText)
                    HStack {
                        availabilityPill("\(selectedModel?.serverPort ?? 0): 使用可能")
                        availabilityPill("\(proxyPortText): 使用可能")
                    }
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
                    formRow("自動アンロード", "10分")
                }

                groupedSection("状態情報") {
                    formRow("ステータス", isSelectedRunning ? "Ready" : "Stopped", valueColor: isSelectedRunning ? .green : .secondary)
                    formRow("最終使用", isSelectedRunning ? "2分前" : "-")
                    formRow("起動時刻", viewModel.runtimeEvents.first?.timestamp.formatted(date: .numeric, time: .standard) ?? "-")
                    formRow("プロセスID", isSelectedRunning ? "managed" : "-")
                    formRow("メモリ使用量", isSelectedRunning ? viewModel.memoryUsageText : "-")
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

            copyRow("Base URL", value: hermesBaseURL, action: { viewModel.copyBaseURL() })
            copyRow("API Key", value: viewModel.apiKeyPlaceholder, action: { viewModel.copyAPIKeyPlaceholder() })
            copyRow("Model", value: viewModel.selectedModelIdentifier, action: { viewModel.copyModelID() })

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
                Text("プロキシ: \(viewModel.runningModelID == nil ? "0" : "1") / \(viewModel.models.count) 稼働中")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private var hermesBaseURL: String {
        guard let selectedModel else { return viewModel.baseURL }
        return "http://127.0.0.1:\(selectedModel.serverPort + 10000)/v1"
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
