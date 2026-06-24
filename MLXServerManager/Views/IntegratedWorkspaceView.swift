import AppKit
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
    @State private var rowActionsColumnWidth = ModelListColumn.rowActions
    @State private var draggedModelID: ModelConfig.ID?
    @State private var hoveredStatusModelID: ModelConfig.ID?
    @State private var selectedAppearance = "system"
    @State private var expandedRightPanelID: String? = "model"
    @State private var isLeftPanelVisible = true
    @State private var isBottomPanelVisible = true
    @State private var isRightPanelVisible = true
    @State private var isLeftPanelAutoHidden = false
    @State private var isBottomPanelAutoHidden = false
    @State private var isRightPanelAutoHidden = false
    @State private var hostingWindow: NSWindow?
    @FocusState private var focusedAutoUnloadModelID: ModelConfig.ID?

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }

    private var preferredColorScheme: ColorScheme? {
        switch selectedAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var topLeftChromeControls: some View {
        HStack(spacing: 0) {
            chromeToggleButton(
                systemImage: "sidebar.left",
                isActive: isLeftPanelVisible,
                help: isLeftPanelVisible ? "左サイドパネルを隠す" : "左サイドパネルを表示"
            ) {
                toggleLeftPanelRequested()
            }
        }
        .fixedSize()
        .background(Color.clear)
    }

    private var topRightChromeControls: some View {
        HStack(spacing: 8) {
            chromeToggleButton(
                systemImage: "rectangle.bottomthird.inset.filled",
                isActive: isBottomPanelVisible,
                help: isBottomPanelVisible ? "下段ログパネルを隠す" : "下段ログパネルを表示"
            ) {
                toggleBottomPanelRequested()
            }
            chromeToggleButton(
                systemImage: "sidebar.right",
                isActive: isRightPanelVisible,
                help: isRightPanelVisible ? "右サイドパネルを隠す" : "右サイドパネルを表示"
            ) {
                toggleRightPanelRequested()
            }
        }
        .fixedSize()
        .background(Color.clear)
    }

    private func chromeToggleButton(systemImage: String, isActive: Bool, help: String, action: @escaping () -> Void) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isActive ? .primary : .secondary)
            .frame(width: 24, height: 22)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.24)) {
                    action()
                }
            }
            .help(help)
    }

    private func toggleLeftPanelRequested() {
        if isLeftPanelVisible {
            isLeftPanelAutoHidden = false
            isLeftPanelVisible = false
            return
        }

        isLeftPanelAutoHidden = false
        expandWindowIfNeeded(leftVisible: true, rightVisible: isRightPanelVisible)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.24)) {
                isLeftPanelVisible = true
            }
        }
    }

    private func toggleRightPanelRequested() {
        if isRightPanelVisible {
            isRightPanelAutoHidden = false
            isRightPanelVisible = false
            return
        }

        isRightPanelAutoHidden = false
        expandWindowIfNeeded(leftVisible: isLeftPanelVisible, rightVisible: true)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.24)) {
                isRightPanelVisible = true
            }
        }
    }

    private func toggleBottomPanelRequested() {
        if isBottomPanelVisible {
            isBottomPanelAutoHidden = false
            isBottomPanelVisible = false
            return
        }

        isBottomPanelAutoHidden = false
        expandWindowHeightIfNeeded()
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.24)) {
                isBottomPanelVisible = true
            }
        }
    }

    private func applyAutomaticPanelCollapse(for size: CGSize) {
        withAnimation(.easeInOut(duration: 0.24)) {
            let canShowLeftOnly = size.width >= comfortableWindowWidth(leftVisible: true, rightVisible: false)
            let canShowBothSides = size.width >= comfortableWindowWidth(leftVisible: true, rightVisible: true)
            let canShowBottom = size.height >= Layout.minimumBottomPanelHeight

            if isRightPanelVisible, !canShowBothSides {
                isRightPanelVisible = false
                isRightPanelAutoHidden = true
                return
            }

            if isLeftPanelVisible, !canShowLeftOnly {
                isLeftPanelVisible = false
                isLeftPanelAutoHidden = true
                return
            }

            if !isLeftPanelVisible, isLeftPanelAutoHidden, canShowLeftOnly {
                isLeftPanelVisible = true
                isLeftPanelAutoHidden = false
                return
            }

            if !isRightPanelVisible, isRightPanelAutoHidden, isLeftPanelVisible, canShowBothSides {
                isRightPanelVisible = true
                isRightPanelAutoHidden = false
                return
            }

            if isBottomPanelVisible, !canShowBottom {
                isBottomPanelVisible = false
                isBottomPanelAutoHidden = true
            } else if !isBottomPanelVisible, isBottomPanelAutoHidden, canShowBottom {
                isBottomPanelVisible = true
                isBottomPanelAutoHidden = false
            }
        }
    }

    private func expandWindowIfNeeded(leftVisible: Bool, rightVisible: Bool) {
        guard let hostingWindow else { return }
        let requiredWidth = requiredWindowWidth(leftVisible: leftVisible, rightVisible: rightVisible)
        let widthDelta = requiredWidth - hostingWindow.frame.width
        guard widthDelta > 0 else { return }

        var frame = hostingWindow.frame
        frame.size.width += widthDelta
        frame.origin.x = max(0, frame.origin.x - widthDelta)
        hostingWindow.setFrame(frame, display: true, animate: true)
    }

    private func expandWindowHeightIfNeeded() {
        guard let hostingWindow else { return }
        let heightDelta = Layout.minimumBottomPanelHeight - hostingWindow.frame.height
        guard heightDelta > 0 else { return }

        var frame = hostingWindow.frame
        frame.size.height += heightDelta
        frame.origin.y = max(0, frame.origin.y - heightDelta)
        hostingWindow.setFrame(frame, display: true, animate: true)
    }

    private func requiredWindowWidth(leftVisible: Bool, rightVisible: Bool) -> CGFloat {
        (leftVisible ? Layout.leftPanelWidthWithDivider : 0)
            + compactRequiredModelListWidth
            + (rightVisible ? Layout.rightPanelWidthWithDivider : 0)
    }

    private func comfortableWindowWidth(leftVisible: Bool, rightVisible: Bool) -> CGFloat {
        (leftVisible ? Layout.leftPanelWidthWithDivider : 0)
            + defaultRequiredModelListWidth
            + (rightVisible ? Layout.rightPanelWidthWithDivider : 0)
    }

    private var defaultRequiredModelListWidth: CGFloat {
        ModelListColumn.name
            + ModelListColumn.size
            + ModelListColumn.status
            + ModelListColumn.port
            + ModelListColumn.memory
            + ModelListColumn.unload
            + ModelListColumn.reasoning
            + ModelListColumn.rowActions
            + CGFloat(7) * ModelListColumn.spacing
            + Layout.modelListHorizontalPadding
    }

    private var compactRequiredModelListWidth: CGFloat {
        ModelListColumn.minimumName
            + ModelListColumn.minimumSize
            + ModelListColumn.minimumStatus
            + ModelListColumn.minimumPort
            + ModelListColumn.minimumMemory
            + ModelListColumn.minimumUnload
            + ModelListColumn.minimumReasoning
            + ModelListColumn.minimumRowActions
            + CGFloat(7) * ModelListColumn.spacing
            + Layout.modelListHorizontalPadding
    }

    private var requiredModelListWidth: CGFloat {
        modelNameColumnWidth
            + sizeColumnWidth
            + statusColumnWidth
            + portColumnWidth
            + memoryColumnWidth
            + unloadColumnWidth
            + reasoningColumnWidth
            + rowActionsColumnWidth
            + CGFloat(7) * ModelListColumn.spacing
            + Layout.modelListHorizontalPadding
    }

    private func updateResponsiveModelColumns(for containerWidth: CGFloat) {
        let contentWidth = max(containerWidth - Layout.modelListHorizontalPadding, compactRequiredModelListWidth - Layout.modelListHorizontalPadding)
        let availableColumnWidth = max(contentWidth - CGFloat(7) * ModelListColumn.spacing, compactMinimumColumnTotalWidth)
        let expansionRange = max(defaultColumnTotalWidth - compactMinimumColumnTotalWidth, 1)
        let expansionProgress = min(max((availableColumnWidth - compactMinimumColumnTotalWidth) / expansionRange, 0), 1)
        let expandedExtraWidth = max(availableColumnWidth - defaultColumnTotalWidth, 0)

        let name = responsiveColumnWidth(minimum: ModelListColumn.minimumName, defaultValue: ModelListColumn.name, progress: expansionProgress, extra: expandedExtraWidth * 0.42)
        let size = responsiveColumnWidth(minimum: ModelListColumn.minimumSize, defaultValue: ModelListColumn.size, progress: expansionProgress, extra: expandedExtraWidth * 0.07)
        let status = responsiveColumnWidth(minimum: ModelListColumn.minimumStatus, defaultValue: ModelListColumn.status, progress: expansionProgress, extra: expandedExtraWidth * 0.07)
        let port = responsiveColumnWidth(minimum: ModelListColumn.minimumPort, defaultValue: ModelListColumn.port, progress: expansionProgress, extra: expandedExtraWidth * 0.06)
        let memory = responsiveColumnWidth(minimum: ModelListColumn.minimumMemory, defaultValue: ModelListColumn.memory, progress: expansionProgress, extra: expandedExtraWidth * 0.09)
        let unload = responsiveColumnWidth(minimum: ModelListColumn.minimumUnload, defaultValue: ModelListColumn.unload, progress: expansionProgress, extra: expandedExtraWidth * 0.13)
        let reasoning = responsiveColumnWidth(minimum: ModelListColumn.minimumReasoning, defaultValue: ModelListColumn.reasoning, progress: expansionProgress, extra: expandedExtraWidth * 0.05)
        let actions = responsiveColumnWidth(minimum: ModelListColumn.minimumRowActions, defaultValue: ModelListColumn.rowActions, progress: expansionProgress, extra: expandedExtraWidth * 0.11)

        guard abs(modelNameColumnWidth - name) > 0.5
            || abs(sizeColumnWidth - size) > 0.5
            || abs(statusColumnWidth - status) > 0.5
            || abs(portColumnWidth - port) > 0.5
            || abs(memoryColumnWidth - memory) > 0.5
            || abs(unloadColumnWidth - unload) > 0.5
            || abs(reasoningColumnWidth - reasoning) > 0.5
            || abs(rowActionsColumnWidth - actions) > 0.5 else {
            return
        }

        modelNameColumnWidth = name
        sizeColumnWidth = size
        statusColumnWidth = status
        portColumnWidth = port
        memoryColumnWidth = memory
        unloadColumnWidth = unload
        reasoningColumnWidth = reasoning
        rowActionsColumnWidth = actions
    }

    private func responsiveColumnWidth(minimum: CGFloat, defaultValue: CGFloat, progress: CGFloat, extra: CGFloat) -> CGFloat {
        minimum + (defaultValue - minimum) * progress + extra
    }

    private var compactMinimumColumnTotalWidth: CGFloat {
        ModelListColumn.minimumName
            + ModelListColumn.minimumSize
            + ModelListColumn.minimumStatus
            + ModelListColumn.minimumPort
            + ModelListColumn.minimumMemory
            + ModelListColumn.minimumUnload
            + ModelListColumn.minimumReasoning
            + ModelListColumn.minimumRowActions
    }

    private var defaultColumnTotalWidth: CGFloat {
        ModelListColumn.name
            + ModelListColumn.size
            + ModelListColumn.status
            + ModelListColumn.port
            + ModelListColumn.memory
            + ModelListColumn.unload
            + ModelListColumn.reasoning
            + ModelListColumn.rowActions
    }

    private enum Layout {
        static let leftPanelWidth: CGFloat = 220
        static let rightPanelWidth: CGFloat = 430
        static let dividerWidth: CGFloat = 1
        static let leftPanelWidthWithDivider = leftPanelWidth + dividerWidth
        static let rightPanelWidthWithDivider = rightPanelWidth + dividerWidth
        static let modelListHorizontalPadding: CGFloat = 32
        static let minimumBottomPanelHeight: CGFloat = 720
    }

    private enum ModelListColumn {
        static let name: CGFloat = 210
        static let size: CGFloat = 86
        static let status: CGFloat = 112
        static let port: CGFloat = 128
        static let memory: CGFloat = 104
        static let latestCheck: CGFloat = 88
        static let unload: CGFloat = 148
        static let reasoning: CGFloat = 86
        static let rowActions: CGFloat = 188
        static let minimumName: CGFloat = 150
        static let minimumSize: CGFloat = 70
        static let minimumStatus: CGFloat = 92
        static let minimumPort: CGFloat = 108
        static let minimumMemory: CGFloat = 82
        static let minimumUnload: CGFloat = 116
        static let minimumReasoning: CGFloat = 68
        static let minimumRowActions: CGFloat = 148
        static let minimum: CGFloat = 48
        static let spacing: CGFloat = 10
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if isLeftPanelVisible {
                    leftColumn
                        .frame(width: Layout.leftPanelWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }

                centerColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                if isRightPanelVisible {
                    Divider()
                    rightColumn
                        .frame(width: Layout.rightPanelWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.24), value: isLeftPanelVisible)
            .animation(.easeInOut(duration: 0.24), value: isRightPanelVisible)
            .animation(.easeInOut(duration: 0.24), value: isBottomPanelVisible)
            .onAppear {
                modelNameColumnWidth = viewModel.initialModelNameColumnWidth
                applyAutomaticPanelCollapse(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, size in
                applyAutomaticPanelCollapse(for: size)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(preferredColorScheme)
        .accessibilityIdentifier("integrated-workspace")
        .background(WindowReader { window in
            hostingWindow = window
        })
        .background(
            TitlebarPanelControlsInstaller(
                isLeftPanelVisible: $isLeftPanelVisible,
                isBottomPanelVisible: $isBottomPanelVisible,
                isRightPanelVisible: $isRightPanelVisible,
                onLeftToggle: toggleLeftPanelRequested,
                onBottomToggle: toggleBottomPanelRequested,
                onRightToggle: toggleRightPanelRequested
            )
        )
    }

    private var leftColumn: some View {
        VStack(spacing: 0) {
            IntegratedSidebarMenuView(selectedDestination: $selectedDestination)
            Divider()
            systemPanel
            Divider()
            settingsFooterButton
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
                    .font(.headline)
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

    private var settingsFooterButton: some View {
        Button {
            selectedDestination = .settings
        } label: {
            Label("設定", systemImage: "gearshape")
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(selectedDestination == .settings ? Color.accentColor.opacity(0.85) : Color.clear)
                .foregroundStyle(selectedDestination == .settings ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .accessibilityIdentifier("integrated-sidebar-settings-footer")
    }

    private var footerPanel: some View {
        VStack(spacing: 6) {
            Text("MLX Server Manager")
                .font(.callout.weight(.semibold))
            Text("Version 22.0.0")
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
                    .frame(maxHeight: isBottomPanelVisible ? .infinity : .infinity)
                if isBottomPanelVisible {
                    Divider()
                    logPanel
                        .frame(height: 250)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        case .downloads:
            DownloadsSurfaceView(viewModel: viewModel)
        case .settings:
            SettingsSurfaceView(viewModel: viewModel, selectedAppearance: $selectedAppearance)
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
        GeometryReader { proxy in
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                updateResponsiveModelColumns(for: proxy.size.width)
            }
            .onChange(of: proxy.size.width) { _, width in
                updateResponsiveModelColumns(for: width)
            }
        }
    }

    private var modelHeaderRow: some View {
        HStack(alignment: .top, spacing: ModelListColumn.spacing) {
            columnHeader("モデル名 / 用途\(viewModel.sortIndicator(for: "name"))", width: $modelNameColumnWidth, defaultWidth: ModelListColumn.name, sortKey: "name")
            columnHeader("サイズ\(viewModel.sortIndicator(for: "size"))", width: $sizeColumnWidth, defaultWidth: ModelListColumn.size, sortKey: "size")
            columnHeader("ステータス\(viewModel.sortIndicator(for: "status"))", width: $statusColumnWidth, defaultWidth: ModelListColumn.status, sortKey: "status")
            columnHeader("ポート/IPアドレス\(viewModel.sortIndicator(for: "port"))", width: $portColumnWidth, defaultWidth: ModelListColumn.port, sortKey: "port")
            columnHeader("メモリ使用量\(viewModel.sortIndicator(for: "memory"))", width: $memoryColumnWidth, defaultWidth: ModelListColumn.memory, sortKey: "memory")
            columnHeader("自動アンロード\(viewModel.sortIndicator(for: "autoUnload"))", width: $unloadColumnWidth, defaultWidth: ModelListColumn.unload, showsHandle: false, sortKey: "autoUnload", alignment: .center)
            columnHeader("推論\(viewModel.sortIndicator(for: "reasoning"))", width: $reasoningColumnWidth, defaultWidth: ModelListColumn.reasoning, showsHandle: false, sortKey: "reasoning", alignment: .center)
            headerText("モデル管理")
                .frame(width: rowActionsColumnWidth, alignment: .center)
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

                portValue("\(model.host):\(model.serverPort)")
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
                    .focused($focusedAutoUnloadModelID, equals: model.id)
                    .onSubmit {
                        focusedAutoUnloadModelID = nil
                    }
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
                    .scaleEffect(0.82)
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
                .scaleEffect(0.82)
                .frame(width: reasoningColumnWidth, alignment: .center)

                HStack(spacing: 6) {
                    modelActionButton("設定", color: .secondary) {
                        viewModel.editProfileRequested(for: model)
                    }
                    .help(viewModel.runtimeEditingSafetyText(for: model))

                    modelActionButton("削除", color: .red) {
                        viewModel.deleteProfileRequested(for: model)
                    }
                    .disabled(viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)
                }
                .frame(width: rowActionsColumnWidth, alignment: .center)
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
            statusButtonLabel(statusText, color: foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isModelTransitioning(model) || !viewModel.canUseStatusAction(for: model))
        .onHover { isHovered in
            hoveredStatusModelID = isHovered ? model.id : nil
        }
    }

    private func modelActionButton(_ text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            statusButtonLabel(text, color: color)
        }
        .buttonStyle(.plain)
    }

    private func statusButtonLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 86, height: 28)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.28))
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
                Text("ログ")
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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                collapsibleRightPanel(id: "model", title: "モデル設定", systemImage: "slider.horizontal.3") {
                    modelSettingsPanelContent
                }
                collapsibleRightPanel(id: "recovery", title: "Recovery", systemImage: "wrench.and.screwdriver") {
                    IntegratedRecoveryPanelView(
                        issue: viewModel.currentRecoveryIssue,
                        onAction: handleRecoveryAction,
                        onCopyTroubleshooting: viewModel.copyTroubleshootingSummary,
                        onRefreshSafety: viewModel.refreshIntegratedSafetyRequested
                    )
                    recentRightPanelLogs
                }
                collapsibleRightPanel(id: "hermes", title: "Hermes Agent 接続情報", systemImage: "point.3.connected.trianglepath.dotted") {
                    hermesPanelContent
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.38))
    }

    private var appearancePanel: some View {
        HStack {
            Label("外観", systemImage: "circle.lefthalf.filled")
                .font(.headline)
            Spacer()
            Picker("外観", selection: $selectedAppearance) {
                Text("システム").tag("system")
                Text("ライト").tag("light")
                Text("ダーク").tag("dark")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 190)
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var recentRightPanelLogs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最新ログ")
                .font(.caption.weight(.semibold))
            ForEach(viewModel.visibleLogEntries.suffix(4)) { entry in
                Text(entry.line)
                    .font(.caption2.monospaced())
                    .foregroundStyle(entry.category == "error" ? Color.red : Color.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if viewModel.visibleLogEntries.isEmpty {
                Text("ログはまだありません")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func collapsibleRightPanel<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    expandedRightPanelID = expandedRightPanelID == id ? nil : id
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expandedRightPanelID == id ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 12)
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Spacer()
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedRightPanelID == id {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding([.horizontal, .bottom], 12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var modelSettingsPanelContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            groupedSection("基本情報") {
                HStack {
                    Button {
                        viewModel.editProfileRequested()
                    } label: {
                        Label("選択モデルを設定", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isManagedProcessRunning)
                }
                if viewModel.isManagedProcessRunning {
                    Text("実行中は Model ID / host / port / advanced options の変更を止めています。停止後に設定してください。")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                formRow("モデル名", selectedModel?.displayName ?? "-")
                formRow("モデルID (Hugging Face)", selectedModel?.modelID ?? "-")
                formRow("モデル検証", viewModel.selectedModelIdentityDetailText, valueColor: viewModel.selectedModelIdentityDetailText.localizedCaseInsensitiveContains("Missing") || viewModel.selectedModelIdentityDetailText.localizedCaseInsensitiveContains("review") ? .orange : .green)
                formRow("用途・メモ", selectedModel?.notes.isEmpty == false ? selectedModel?.notes ?? "-" : "-")
            }

            groupedSection("安全性") {
                let safetySummary = localizedStatusText(viewModel.selectedModelSafetySummary)
                formRow("概要", safetySummary, valueColor: safetySummary == "問題なし" ? .green : .orange)
                ForEach(viewModel.selectedModelSafetyRows, id: \.0) { row in
                    let value = localizedStatusText(row.1)
                    formRow(localizedSafetyLabel(row.0), value, valueColor: isPositiveLocalizedStatus(value) ? .green : .orange)
                }
                let recoverySummary = localizedStatusText(viewModel.failedStartRecoverySummary)
                formRow("復旧ガイド", recoverySummary, valueColor: recoverySummary == "復旧操作は不要です" ? .secondary : .orange)
            }

            groupedSection("Direct Mode ポート") {
                formRow("ポート/IPアドレス", selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-")
                availabilityPill("\(selectedModel?.serverPort ?? 0): \(localizedStatusText(viewModel.selectedServerPortSafetyText))")
            }

            groupedSection("動作設定") {
                formRow("変更反映", viewModel.restartRequired ? "再起動が必要" : "現在の設定が有効", valueColor: viewModel.restartRequired ? .orange : .green)
                HStack {
                    Text("推論モード（Qwen系）")
                        .font(.caption)
                    Spacer()
                    Toggle("", isOn: .constant(selectedModel?.enableThinking ?? false))
                        .labelsHidden()
                        .scaleEffect(0.82)
                        .disabled(true)
                    Text((selectedModel?.enableThinking ?? false) ? "ON" : "OFF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                formRow("停止方式", "手動で停止")
            }

            groupedSection("状態情報") {
                formRow("操作安全性", viewModel.integratedActionStateSummary, valueColor: viewModel.canStartSelectedModel ? .green : .orange)
                formRow("ステータス", isSelectedRunning ? "ロード済" : "未ロード", valueColor: isSelectedRunning ? .green : .secondary)
                formRow("最終確認", selectedModel.map { viewModel.integratedLatestUseText(for: $0) } ?? "-")
                formRow("起動時刻", viewModel.runtimeEvents.first?.timestamp.formatted(date: .numeric, time: .standard) ?? "-")
                formRow("プロセス", isSelectedRunning ? "アプリ管理" : "-")
                formRow("メモリ使用量", isSelectedRunning ? viewModel.memoryUsageText : "-")
                formRow("スピードテスト", viewModel.latestBenchmarkResult?.summary ?? "未実行")
            }
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

    private func localizedSafetyLabel(_ label: String) -> String {
        switch label {
        case "Selected model": return "選択モデル"
        case "Executable": return "実行ファイル"
        case "Model": return "モデル"
        case "Server port": return "サーバーポート"
        case "Duplicate": return "重複"
        case "Runtime edit": return "編集中の安全性"
        default: return label
        }
    }

    private func localizedStatusText(_ value: String) -> String {
        switch value {
        case "Safety: OK", "OK": return "問題なし"
        case "Available": return "利用可能"
        case "Ready": return "準備完了"
        case "OK local path": return "ローカルパス確認済み"
        case "No failed start recovery needed.": return "復旧操作は不要です"
        case "No model selected": return "モデル未選択"
        case "Select a model before Start.": return "モデルを選択してください"
        default:
            return value
                .replacingOccurrences(of: "Missing", with: "未検出")
                .replacingOccurrences(of: "Server port", with: "サーバーポート")
                .replacingOccurrences(of: "Stop the managed server before editing runtime identity.", with: "実行中のサーバーを停止してから編集してください")
                .replacingOccurrences(of: "No duplicate endpoint detected.", with: "重複する接続先はありません")
        }
    }

    private func isPositiveLocalizedStatus(_ value: String) -> Bool {
        value == "問題なし" || value == "利用可能" || value == "準備完了" || value == "ローカルパス確認済み" || value == "重複する接続先はありません"
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

    private var hermesPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Text("-")
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
