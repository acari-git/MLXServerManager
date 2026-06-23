import SwiftUI
import UniformTypeIdentifiers

struct IntegratedWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State var selectedDestination: IntegratedWorkspaceDestination = .models
    @State private var modelNameColumnWidth = ModelListColumn.name
    @State private var sizeColumnWidth = ModelListColumn.size
    @State private var statusColumnWidth = ModelListColumn.status
    @State private var portColumnWidth = ModelListColumn.port
    @State private var memoryColumnWidth = ModelListColumn.memory
    @State private var latestCheckColumnWidth = ModelListColumn.latestCheck
    @State private var unloadColumnWidth = ModelListColumn.unload
    @State private var reasoningColumnWidth = ModelListColumn.reasoning
    @State private var draggedModelID: ModelConfig.ID?
    @State private var hoveredStatusModelID: ModelConfig.ID?

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }

    private enum ModelListColumn {
        static let name: CGFloat = 210
        static let size: CGFloat = 86
        static let status: CGFloat = 112
        static let port: CGFloat = 92
        static let memory: CGFloat = 104
        static let latestCheck: CGFloat = 88
        static let unload: CGFloat = 148
        static let reasoning: CGFloat = 86
        static let minimum: CGFloat = 64
        static let spacing: CGFloat = 10
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
        .onAppear {
            modelNameColumnWidth = viewModel.initialModelNameColumnWidth
        }
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

            systemInfoCard
            memoryGaugeCard
            usageMetricCard(
                title: "CPU",
                value: viewModel.integratedCPUUsageText,
                detail: "",
                samples: viewModel.systemUsageHistory.map(\.cpuFraction)
            )
            systemMetricCard(
                title: "起動時間",
                value: viewModel.integratedUptimeText,
                detail: ""            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(viewModel.systemInfoRows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .leading)
                    Text(row.1)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var memoryGaugeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("メモリ内訳")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.integratedMemoryUsagePercentText)
                    .font(.caption.weight(.bold))
            }

            memoryPressureHistoryGraph

            memoryBreakdownBar

            VStack(alignment: .leading, spacing: 5) {
                memoryLegendRow(color: .blue, label: "mlx-lm", value: viewModel.memoryMLXProcessText)
                memoryLegendRow(color: .orange, label: "その他", value: viewModel.memoryOtherProcessesText)
                memoryLegendRow(color: .green, label: "空き容量", value: viewModel.memoryAvailableText)
            }


        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var memoryPressureHistoryGraph: some View {
        MemoryPressureHistoryGraph(samples: viewModel.memoryHistory)
            .frame(height: 52)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.secondary.opacity(0.18))
            }
            .accessibilityIdentifier("integrated-memory-pressure-history-graph")
    }

    private var memoryBreakdownBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                memoryBarSegment(
                    width: geometry.size.width * viewModel.memoryMLXProcessFraction,
                    color: .blue
                )
                memoryBarSegment(
                    width: geometry.size.width * viewModel.memoryOtherProcessesFraction,
                    color: .orange
                )
                memoryBarSegment(
                    width: geometry.size.width * viewModel.memoryAvailableFraction,
                    color: .green
                )
            }
        }
        .frame(height: 12)
        .background(Color.secondary.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityIdentifier("integrated-memory-breakdown-bar")
    }

    private func memoryBarSegment(width: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.88))
            .frame(width: max(width, 0))
    }

    private func memoryLegendRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.88))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .frame(width: 70, alignment: .trailing)
        }
        .lineLimit(1)
    }

    private func usageMetricCard(title: String, value: String, detail: String, samples: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
            }
            ResourceUsageHistoryGraph(samples: samples)
                .frame(height: 34)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
        }
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
                            .onDrag {
                                draggedModelID = model.id
                                return NSItemProvider(object: model.id as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: ModelRowDropDelegate(
                                    targetModel: model,
                                    draggedModelID: $draggedModelID,
                                    viewModel: viewModel
                                )
                            )
                    }
                }
                .padding(14)
            }
        }
    }

    private var modelHeaderRow: some View {
        HStack(alignment: .top, spacing: ModelListColumn.spacing) {
            columnHeader("モデル名 / 用途\(viewModel.sortIndicator(for: "name"))", width: $modelNameColumnWidth, defaultWidth: ModelListColumn.name, sortKey: "name")
            columnHeader("サイズ\(viewModel.sortIndicator(for: "size"))", width: $sizeColumnWidth, defaultWidth: ModelListColumn.size, sortKey: "size")
            columnHeader("ステータス\(viewModel.sortIndicator(for: "status"))", width: $statusColumnWidth, defaultWidth: ModelListColumn.status, sortKey: "status")
            columnHeader("サーバーポート\(viewModel.sortIndicator(for: "port"))", width: $portColumnWidth, defaultWidth: ModelListColumn.port, sortKey: "port")
            columnHeader("プロセスメモリ\(viewModel.sortIndicator(for: "memory"))", width: $memoryColumnWidth, defaultWidth: ModelListColumn.memory, sortKey: "memory")
            columnHeader("自動アンロード\(viewModel.sortIndicator(for: "autoUnload"))", width: $unloadColumnWidth, defaultWidth: ModelListColumn.unload, showsHandle: false, sortKey: "autoUnload", alignment: .center)
            columnHeader("推論\(viewModel.sortIndicator(for: "reasoning"))", width: $reasoningColumnWidth, defaultWidth: ModelListColumn.reasoning, showsHandle: false, sortKey: "reasoning", alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modelRow(_ model: ModelConfig) -> some View {
        HStack(alignment: .center, spacing: ModelListColumn.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(model.notes.isEmpty ? model.family : model.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: modelNameColumnWidth, alignment: .leading)

                Text(viewModel.modelSizeText(for: model))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: sizeColumnWidth, alignment: .leading)

                statusButton(for: model)
                    .frame(width: statusColumnWidth, alignment: .leading)

                portValue(String(model.serverPort))
                    .frame(width: portColumnWidth, alignment: .leading)
                memoryCell(viewModel.integratedMemoryText(for: model))
                    .frame(width: memoryColumnWidth, alignment: .leading)
                HStack(spacing: 8) {
                    TextField(
                        "分",
                        value: Binding(
                            get: { viewModel.autoUnloadMinutes(for: model) },
                            set: { viewModel.setAutoUnloadMinutes($0, for: model) }
                        ),
                        format: .number
                    )
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 48)
                    .disabled(!viewModel.isAutoUnloadEnabled(for: model))
                    Text("分")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { viewModel.isAutoUnloadEnabled(for: model) },
                            set: { viewModel.setAutoUnloadEnabled($0, for: model) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .frame(width: unloadColumnWidth, alignment: .leading)

                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.enableThinking },
                        set: { viewModel.toggleReasoning(for: model, isEnabled: $0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(width: reasoningColumnWidth, alignment: .center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.12))
        }
        .onTapGesture {
            viewModel.selectedModelID = model.id
        }
    }

    private func columnHeader(
        _ text: String,
        width: Binding<CGFloat>,
        defaultWidth: CGFloat,
        showsHandle: Bool = true,
        sortKey: String? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        HStack(spacing: 0) {
            headerText(text)
                .frame(width: max(width.wrappedValue - 6, ModelListColumn.minimum), alignment: alignment)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let sortKey {
                        viewModel.sortModelsRequested(by: sortKey)
                    }
                }
            if showsHandle {
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(width: 6, height: 18)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onEnded { value in
                                width.wrappedValue = max(ModelListColumn.minimum, width.wrappedValue + value.translation.width)
                            }
                    )
                    .onTapGesture(count: 2) {
                        width.wrappedValue = defaultWidth
                    }
            }
        }
        .frame(width: width.wrappedValue, alignment: .leading)
    }

    private func statusButton(for model: ModelConfig) -> some View {
        let isHovered = hoveredStatusModelID == model.id
        let statusText = viewModel.interactiveStatusText(for: model, isHovered: isHovered)
        let foregroundColor: Color = if statusText == "アンロード" {
            .red
        } else if statusText == "ロード" || statusText == "ロード済" {
            .green
        } else {
            .secondary
        }

        return Button {
            viewModel.statusActionRequested(for: model)
        } label: {
            Text(statusText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 86, height: 28)
                .background(foregroundColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(foregroundColor.opacity(0.28))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isModelTransitioning(model) || !viewModel.canUseStatusAction(for: model))
        .onHover { isHovered in
            hoveredStatusModelID = isHovered ? model.id : nil
        }
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
                .font(.callout.weight(.semibold))
                .foregroundColor(text == "-" ? .secondary : .green)
            ProgressView(value: text == "-" ? 0 : 0.48)
                .frame(width: 62)
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(text == "稼働中" ? .green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((text == "稼働中" ? Color.green : Color.secondary).opacity(0.14))
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

private struct ResourceUsageHistoryGraph: View {
    let samples: [Double]

    var body: some View {
        GeometryReader { geometry in
            if samples.count >= 2 {
                Path { path in
                    for (index, sample) in samples.enumerated() {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
                        let y = geometry.size.height - geometry.size.height * CGFloat(min(max(sample, 0), 1))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.green.opacity(0.95), lineWidth: 1.4)
            } else {
                Text("-")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ModelRowDropDelegate: DropDelegate {
    let targetModel: ModelConfig
    @Binding var draggedModelID: ModelConfig.ID?
    let viewModel: AppViewModel

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedModelID else {
            return false
        }

        viewModel.moveModel(withID: draggedModelID, before: targetModel.id)
        self.draggedModelID = nil
        return true
    }
}

private struct MemoryPressureHistoryGraph: View {
    let samples: [MemoryHistorySample]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                graphGrid(size: geometry.size)

                if samples.count >= 2 {
                    managedProcessArea(size: geometry.size)
                    usedMemoryLine(size: geometry.size)
                } else {
                    Text("メモリプレッシャー")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func graphGrid(size: CGSize) -> some View {
        Path { path in
            let rows = 3
            let columns = 4

            for row in 1..<rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            for column in 1..<columns {
                let x = size.width * CGFloat(column) / CGFloat(columns)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
    }

    private func usedMemoryLine(size: CGSize) -> some View {
        Path { path in
            for (index, sample) in samples.enumerated() {
                let point = point(
                    index: index,
                    count: samples.count,
                    fraction: sample.usedFraction,
                    size: size
                )

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(Color.green.opacity(0.95), lineWidth: 1.6)
    }

    private func managedProcessArea(size: CGSize) -> some View {
        Path { path in
            for (index, sample) in samples.enumerated() {
                let point = point(
                    index: index,
                    count: samples.count,
                    fraction: sample.managedProcessFraction,
                    size: size
                )

                if index == 0 {
                    path.move(to: CGPoint(x: point.x, y: size.height))
                    path.addLine(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            if let lastIndex = samples.indices.last {
                let lastX = xPosition(index: lastIndex, count: samples.count, width: size.width)
                path.addLine(to: CGPoint(x: lastX, y: size.height))
                path.closeSubpath()
            }
        }
        .fill(Color.blue.opacity(0.24))
    }

    private func point(index: Int, count: Int, fraction: Double, size: CGSize) -> CGPoint {
        CGPoint(
            x: xPosition(index: index, count: count, width: size.width),
            y: size.height - (size.height * CGFloat(min(max(fraction, 0), 1)))
        )
    }

    private func xPosition(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width }
        return width * CGFloat(index) / CGFloat(count - 1)
    }
}
