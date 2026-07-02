import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IntegratedWorkspaceView: View {
    static let baseMinimumWidth = Layout.requiredWindowWidth(
        leftVisible: true,
        centerMinimumWidth: Layout.defaultCenterMinimumWidth
    )
    static let baseMinimumHeight = Layout.windowMinimumHeight

    @ObservedObject var viewModel: AppViewModel
    @State var selectedDestination: IntegratedWorkspaceDestination = .models
    @State private var expandedRightPanelID: String? = "model"
    @State private var isBottomPanelVisible = true
    @State private var centerPaneWidth = Layout.defaultCenterMinimumWidth
    @State private var didInitializeCenterPaneWidth = false
    @State private var isUserLiveResizing = false
    @State private var isBottomPanelAutoHidden = false
    @State private var modelTableSortOrder = [KeyPathComparator<ModelTableRow>]()
    @State private var modelTableSortColumn: ModelTableSortColumn?
    @State private var modelTableSortDirection: SortOrder = .forward
    @State private var modelNameColumnMinimumWidth = ModelTableColumnLayout.model.minimum
    @State private var modelNameColumnDragStartWidth: CGFloat?
    @State private var hoveredStatusModelID: ModelConfig.ID?
    @State private var bottomPanelHeight: CGFloat = 280
    @State private var bottomPanelDragStartHeight: CGFloat?
    @State private var isMiniChatInputFocused = false
    @State private var isSettingsSidebarHovered = false
    @State private var navigationSplitVisibility: NavigationSplitViewVisibility = .all
    @State private var modelTableCenterMinimumWidth = Layout.defaultCenterMinimumWidth

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }
    private var isLeftSidebarVisible: Bool { navigationSplitVisibility != .detailOnly }
    private var effectiveCenterPaneWidth: CGFloat {
        max(centerPaneWidth, modelTableCenterMinimumWidth)
    }
    private var requiredWindowWidth: CGFloat {
        Layout.requiredWindowWidth(
            leftVisible: isLeftSidebarVisible,
            centerMinimumWidth: modelTableCenterMinimumWidth
        )
    }
    private var requiredDetailWidth: CGFloat {
        Layout.requiredDetailWidth(
            centerMinimumWidth: modelTableCenterMinimumWidth
        )
    }

    private var modelRows: [ModelTableRow] {
        viewModel.visibleModels.map { model in
            ModelTableRow(
                model: model,
                nameSortValue: model.displayName,
                sizeSortValue: viewModel.modelSizeSortValue(for: model),
                statusSortValue: viewModel.integratedStatusSortValue(for: model),
                endpointSortValue: viewModel.endpointSortValue(for: model),
                memorySortValue: viewModel.integratedMemorySortValue(for: model),
                autoUnloadSortValue: viewModel.autoUnloadTableSortValue(for: model),
                reasoningSortValue: viewModel.reasoningSortValue(for: model)
            )
        }
    }

    private var sortedModelRows: [ModelTableRow] {
        let rows = modelRows
        if modelTableSortOrder.isEmpty {
            return rows
        }
        return rows.sorted(using: modelTableSortOrder)
    }

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var preferredColorScheme: ColorScheme? {
        switch viewModel.settings.uiAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var activeAccentColor: Color {
        .accentColor
    }

    private var overallStatusSymbol: String {
        switch viewModel.runtimeState {
        case .ready, .externalServerDetected, .adoptedExternalServer:
            AppSymbol.ready
        case .starting, .loading, .stopping, .checkingPort, .checkingReady:
            AppSymbol.refresh
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            AppSymbol.error
        case .stopped, .portAvailable:
            "circle"
        }
    }

    private var overallStatusColor: Color {
        switch viewModel.runtimeState {
        case .ready, .externalServerDetected, .adoptedExternalServer:
            .green
        case .starting, .loading, .stopping, .checkingPort, .checkingReady:
            activeAccentColor
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            .orange
        case .stopped, .portAvailable:
            .secondary
        }
    }

    private func toggleBottomPanelRequested() {
        if isBottomPanelVisible {
            isBottomPanelAutoHidden = false
            isBottomPanelVisible = false
            return
        }

        isBottomPanelAutoHidden = false
        withAnimation(.easeInOut(duration: 0.24)) {
            isBottomPanelVisible = true
        }
    }

    private func applyAutomaticPanelCollapse(for size: CGSize) {
        withAnimation(.easeInOut(duration: 0.24)) {
            let canShowBottom = size.height >= Layout.minimumBottomPanelHeight

            if isBottomPanelVisible, !canShowBottom {
                isBottomPanelVisible = false
                isBottomPanelAutoHidden = true
            } else if !isBottomPanelVisible, isBottomPanelAutoHidden, canShowBottom {
                isBottomPanelVisible = true
                isBottomPanelAutoHidden = false
            }
        }
    }

    private func setWindowWidthForCurrentLayout(
        leftVisible: Bool? = nil,
        animate: Bool = true
    ) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let resolvedLeftVisible = leftVisible ?? isLeftSidebarVisible
        let targetWidth = Layout.requiredWindowWidth(
            leftVisible: resolvedLeftVisible,
            centerMinimumWidth: effectiveCenterPaneWidth
        )
        let minimumWidth = Layout.requiredWindowWidth(
            leftVisible: resolvedLeftVisible,
            centerMinimumWidth: modelTableCenterMinimumWidth
        )
        WindowFrameController.setWidth(
            window,
            to: targetWidth,
            minimumWidth: minimumWidth,
            minimumHeight: Layout.windowMinimumHeight,
            animate: animate
        )
    }

    private func setCenterPaneWidth(_ width: CGFloat) {
        let nextWidth = max(width, modelTableCenterMinimumWidth)
        guard abs(centerPaneWidth - nextWidth) > 0.5 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            centerPaneWidth = nextWidth
        }
    }

    private func updateCenterPaneWidthForAvailableWidth(_ availableWidth: CGFloat) {
        let nextWidth = max(availableWidth, modelTableCenterMinimumWidth)
        setCenterPaneWidth(nextWidth)
    }

    private func initializeCenterPaneWidthIfNeeded(availableWidth: CGFloat) {
        guard !didInitializeCenterPaneWidth else { return }
        let nextWidth = max(availableWidth, modelTableCenterMinimumWidth)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            centerPaneWidth = nextWidth
            didInitializeCenterPaneWidth = true
        }
    }

    private func modelTableMinimumWidthChanged(_ tableMinimumWidth: CGFloat) {
        let nextWidth = max(Layout.defaultCenterMinimumWidth, tableMinimumWidth)
        guard abs(modelTableCenterMinimumWidth - nextWidth) > 0.5 else { return }

        let isShrinking = nextWidth < modelTableCenterMinimumWidth
        let targetCenterWidth = isShrinking ? nextWidth : max(centerPaneWidth, nextWidth)
        let targetWidth = Layout.requiredWindowWidth(
            leftVisible: isLeftSidebarVisible,
            centerMinimumWidth: targetCenterWidth
        )
        let minimumWidth = Layout.requiredWindowWidth(
            leftVisible: isLeftSidebarVisible,
            centerMinimumWidth: nextWidth
        )

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            WindowFrameController.setWidth(
                window,
                to: targetWidth,
                minimumWidth: minimumWidth,
                minimumHeight: Layout.windowMinimumHeight,
                animate: false
            )
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            modelTableCenterMinimumWidth = nextWidth
            centerPaneWidth = targetCenterWidth
        }
    }

    private enum Layout {
        static let tableChromeWidth: CGFloat = 0
        static let leftPanelWidth: CGFloat = 280
        static let rightPanelWidth: CGFloat = 360
        static let dividerWidth: CGFloat = 1
        static let rightPanelWidthWithDivider = rightPanelWidth + dividerWidth
        static let defaultCenterMinimumWidth = ModelTableColumnLayout.defaultTableWidth + tableChromeWidth
        static let windowMinimumHeight: CGFloat = 760
        static let minimumBottomPanelHeight: CGFloat = 720

        static func requiredDetailWidth(centerMinimumWidth: CGFloat) -> CGFloat {
            centerMinimumWidth + rightPanelWidthWithDivider
        }

        static func requiredWindowWidth(leftVisible: Bool, centerMinimumWidth: CGFloat) -> CGFloat {
            requiredDetailWidth(centerMinimumWidth: centerMinimumWidth)
                + (leftVisible ? leftPanelWidth : 0)
        }
    }

    private struct TableColumnSizing {
        let minimum: CGFloat
        let defaultWidth: CGFloat
        let maximum: CGFloat
    }

    private enum ModelTableSortColumn {
        case name
        case size
        case status
        case endpoint
        case memory
        case autoUnload
        case reasoning

        func comparator(order: SortOrder) -> KeyPathComparator<ModelTableRow> {
            switch self {
            case .name:
                KeyPathComparator(\.nameSortValue, order: order)
            case .size:
                KeyPathComparator(\.sizeSortValue, order: order)
            case .status:
                KeyPathComparator(\.statusSortValue, order: order)
            case .endpoint:
                KeyPathComparator(\.endpointSortValue, order: order)
            case .memory:
                KeyPathComparator(\.memorySortValue, order: order)
            case .autoUnload:
                KeyPathComparator(\.autoUnloadSortValue, order: order)
            case .reasoning:
                KeyPathComparator(\.reasoningSortValue, order: order)
            }
        }
    }

    private enum ModelTableColumnLayout {
        static let model = TableColumnSizing(minimum: 230, defaultWidth: 230, maximum: 1_200)
        static let size = TableColumnSizing(minimum: 66, defaultWidth: 66, maximum: 66)
        static let status = TableColumnSizing(minimum: 82, defaultWidth: 82, maximum: 82)
        static let endpoint = TableColumnSizing(minimum: 116, defaultWidth: 116, maximum: 116)
        static let memory = TableColumnSizing(minimum: 82, defaultWidth: 82, maximum: 82)
        static let autoUnload = TableColumnSizing(minimum: 112, defaultWidth: 112, maximum: 112)
        static let reasoning = TableColumnSizing(minimum: 58, defaultWidth: 58, maximum: 58)
        static let actions = TableColumnSizing(minimum: 124, defaultWidth: 124, maximum: 124)

        static let all = [
            model,
            size,
            status,
            endpoint,
            memory,
            autoUnload,
            reasoning,
            actions
        ]

        static let maximumTotalWidth = all.reduce(CGFloat.zero) { $0 + $1.maximum }
        static let defaultTotalWidth = all.reduce(CGFloat.zero) { $0 + $1.defaultWidth }
        static let minimumTotalWidth = all.reduce(CGFloat.zero) { $0 + $1.minimum }
        static let fixedColumnsWidth = all.dropFirst().reduce(CGFloat.zero) { $0 + $1.defaultWidth }
        static let defaultTableWidth = defaultTotalWidth
        static let minimumWidths = all.map(\.minimum)

        static func modelWidth(availableWidth: CGFloat, minimumModelWidth: CGFloat) -> CGFloat {
            let widthThatFillsAvailableSpace = availableWidth - fixedColumnsWidth
            return max(widthThatFillsAvailableSpace, minimumModelWidth, model.minimum)
        }

        static func tableWidth(modelWidth: CGFloat) -> CGFloat {
            modelWidth + fixedColumnsWidth
        }

        static func tableWidth(minimumModelWidth: CGFloat) -> CGFloat {
            tableWidth(modelWidth: max(minimumModelWidth, model.minimum))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: $navigationSplitVisibility) {
                leftColumn
                    .navigationSplitViewColumnWidth(
                        min: Layout.leftPanelWidth,
                        ideal: Layout.leftPanelWidth,
                        max: Layout.leftPanelWidth
                    )
            } detail: {
                workspaceDetail
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                panelToolbarItems
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            .animation(.easeInOut(duration: 0.24), value: isBottomPanelVisible)
            .onAppear {
                applyAutomaticPanelCollapse(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, size in
                applyAutomaticPanelCollapse(for: size)
            }
            .onChange(of: navigationSplitVisibility) { oldValue, newValue in
                let oldLeftVisible = oldValue != .detailOnly
                let newLeftVisible = newValue != .detailOnly
                if oldLeftVisible != newLeftVisible {
                    setWindowWidthForCurrentLayout(leftVisible: newLeftVisible)
                }
            }
        }
        .background(
            WindowFrameController(
                minWidth: requiredWindowWidth,
                minHeight: Layout.windowMinimumHeight,
                isUserLiveResizing: $isUserLiveResizing
            )
        )
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .preferredColorScheme(preferredColorScheme)
        .accessibilityIdentifier("integrated-workspace")
    }

    private var workspaceDetail: some View {
        GeometryReader { proxy in
            let slotWidth = Layout.rightPanelWidthWithDivider
            let topInset = max(proxy.safeAreaInsets.top, 0)
            let availableCenterWidth = max(modelTableCenterMinimumWidth, proxy.size.width - slotWidth)
            let contentWidth = availableCenterWidth + slotWidth

            HStack(spacing: 0) {
                centerColumn
                    .frame(width: availableCenterWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .id("center-\(viewModel.settings.uiAppearance)")
                    .background(Color(nsColor: .windowBackgroundColor))

                rightPanelSlot(width: slotWidth)
                    .frame(width: slotWidth, height: proxy.size.height + topInset, alignment: .topLeading)
                    .offset(y: -topInset)
            }
            .frame(width: contentWidth, height: proxy.size.height, alignment: .topLeading)
            .onAppear {
                initializeCenterPaneWidthIfNeeded(availableWidth: availableCenterWidth)
            }
            .onChange(of: proxy.size.width) { _, _ in
                updateCenterPaneWidthForAvailableWidth(availableCenterWidth)
            }
        }
        .frame(minWidth: requiredDetailWidth, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rightPanelSlot(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            SidebarMaterialBackdrop()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.55))
                    .frame(width: Layout.dividerWidth)
                rightColumn
                    .frame(width: Layout.rightPanelWidth)
            }
            .frame(width: Layout.rightPanelWidthWithDivider, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(SidebarMaterialBackdrop().ignoresSafeArea())
        .clipped()
        .ignoresSafeArea(.container, edges: .top)
    }

    @ToolbarContentBuilder
    private var panelToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            panelToggleButton(
                systemImage: AppSymbol.bottomPanel,
                isActive: isBottomPanelVisible,
                help: isBottomPanelVisible
                    ? t("Hide bottom panel", "下段パネルを隠す")
                    : t("Show bottom panel", "下段パネルを表示"),
                action: toggleBottomPanelRequested
            )
        }
    }

    private func panelToggleButton(
        systemImage: String,
        isActive: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Label(help, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .symbolVariant(isActive ? .fill : .none)
        }
        .help(help)
        .accessibilityLabel(help)
    }

    private var leftColumn: some View {
        VStack(spacing: 0) {
            IntegratedSidebarMenuView(
                selectedDestination: $selectedDestination,
                language: viewModel.settings.uiLanguage,
                downloadPhase: viewModel.huggingFaceDownloadStatus.phase,
                downloadProgress: viewModel.huggingFaceDownloadStatus.progress
            )
            Divider()
                .padding(.horizontal, 14)
            systemPanel
            Spacer(minLength: 12)
            Divider()
                .padding(.horizontal, 14)
            sidebarFooterControls
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("MLX Server Manager")
    }

    private var systemPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("SYSTEM", "システム"), systemImage: "desktopcomputer")
                .font(.headline)
                .foregroundStyle(.primary)

            systemInfoCard
            Divider()
            systemHealthCard
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.systemInfoRows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.0)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .frame(width: 100, alignment: .leading)
                    Text(row.1)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("Memory", "メモリ"), systemImage: "memorychip")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.integratedMemoryUsagePercentText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            memoryUsageBar

            VStack(alignment: .leading, spacing: 12) {
                memoryLegendRow(color: .blue, label: "mlx-lm", value: viewModel.memoryMLXProcessText)
                memoryLegendRow(color: .green, label: t("Other", "その他"), value: viewModel.memoryOtherProcessesText)
                memoryLegendRow(color: .secondary.opacity(0.45), label: t("Available", "空き容量"), value: viewModel.memoryAvailableText)
            }

            Divider()

            HStack {
                Label {
                    Text(verbatim: "CPU")
                } icon: {
                    Image(systemName: "cpu")
                }
                .font(.headline)
                .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.integratedCPUUsageText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            Divider()

            HStack {
                Label(t("Uptime", "起動時間"), systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.integratedUptimeText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryUsageBar: some View {
        GeometryReader { proxy in
            let mlxWidth = max(0, proxy.size.width * viewModel.memoryMLXProcessFraction)
            let otherWidth = max(0, proxy.size.width * viewModel.memoryOtherProcessesFraction)
            let availableWidth = max(0, proxy.size.width - mlxWidth - otherWidth)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: mlxWidth)
                Rectangle()
                    .fill(Color.green)
                    .frame(width: otherWidth)
                Rectangle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: availableWidth)
            }
            .clipShape(Capsule())
        }
        .frame(height: 7)
    }

    private func memoryLegendRow(color: Color, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
                .frame(width: 8, alignment: .leading)
            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 82, alignment: .leading)
        }
        .lineLimit(1)
        .padding(.leading, 14)
    }

    private var sidebarFooterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedDestination = .settings
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: IntegratedWorkspaceDestination.settings.systemImageName)
                        .font(.body)
                        .frame(width: 18)
                    Text(t("Settings", "設定"))
                        .font(.body)
                    Spacer(minLength: 6)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                selectedDestination == .settings
                ? Color(nsColor: .controlAccentColor).opacity(0.90)
                : (isSettingsSidebarHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.10) : Color.clear)
            )
            .foregroundStyle(selectedDestination == .settings ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onHover { isHovering in
                isSettingsSidebarHovered = isHovering
            }
            .accessibilityIdentifier("integrated-sidebar-footer-settings")
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var centerColumn: some View {
        switch selectedDestination {
        case .models:
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    modelListPanel
                        .frame(maxHeight: .infinity)

                    if isBottomPanelVisible {
                        VStack(spacing: 0) {
                            Divider()
                            bottomOperationsPanel
                                .frame(height: max(180, proxy.size.height / 3))
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        case .downloads:
            DownloadsSurfaceView(viewModel: viewModel, onOpenModels: { selectedDestination = .models })
        case .settings:
            SettingsSurfaceView(viewModel: viewModel)
        case .logs:
            LogsSurfaceView(
                entries: viewModel.logEntries,
                targetSummary: viewModel.connectionTargetSummary,
                runningModelText: viewModel.runningModelText,
                language: viewModel.settings.uiLanguage,
                onCopy: viewModel.copyLogsRequested,
                onClear: viewModel.clearLogsRequested
            )
        }
    }

    private var bottomPanelResizeHandle: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if bottomPanelDragStartHeight == nil {
                            bottomPanelDragStartHeight = bottomPanelHeight
                        }
                        let startHeight = bottomPanelDragStartHeight ?? bottomPanelHeight
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            bottomPanelHeight = min(max(startHeight - value.translation.height, 180), 520)
                        }
                    }
                    .onEnded { _ in
                        bottomPanelDragStartHeight = nil
                    }
            )
            .transaction { transaction in
                transaction.animation = nil
            }
            .accessibilityIdentifier("integrated-bottom-panel-resize-handle")
    }

    private var modelEmptyState: some View {
        ContentUnavailableView {
            Label(t("No models are visible", "表示できるモデルがありません"), systemImage: "cube.transparent")
        } description: {
            Text(t(
                "Add a local model profile or open Downloads to fetch a Hugging Face MLX model.",
                "ローカルモデルのプロファイルを追加するか、ダウンロード画面でHugging FaceのMLXモデルを取得してください。"
            ))
        } actions: {
            HStack {
                Button {
                    viewModel.addProfileRequested()
                } label: {
                    Label(t("Add local model", "ローカルモデルを追加"), systemImage: AppSymbol.add)
                }

                Button {
                    selectedDestination = .downloads
                } label: {
                    Label(t("Open Downloads", "ダウンロードを開く"), systemImage: AppSymbol.downloads)
                }
            }
        }
        .accessibilityIdentifier("integrated-model-empty-state")
    }

    private var modelListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t("Models", "モデル一覧"))
                    .font(.title3)
                Spacer()
                Button {
                    viewModel.addProfileRequested()
                } label: {
                    Label(t("Add Model", "モデル追加"), systemImage: AppSymbol.add)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isManagedProcessRunning)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if viewModel.visibleModels.isEmpty {
                modelEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    modelTable(availableWidth: proxy.size.width)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func modelTable(availableWidth: CGFloat) -> some View {
        let modelWidth = ModelTableColumnLayout.modelWidth(
            availableWidth: availableWidth,
            minimumModelWidth: modelNameColumnMinimumWidth
        )
        let tableWidth = ModelTableColumnLayout.tableWidth(modelWidth: modelWidth)

        return VStack(alignment: .leading, spacing: 0) {
            modelTableHeader(modelWidth: modelWidth, tableWidth: tableWidth)
            Divider()
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedModelRows) { row in
                        modelTableRow(row, modelWidth: modelWidth, tableWidth: tableWidth)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
            .onDrop(of: [.plainText], isTargeted: nil) { providers in
                moveDroppedModelToEnd(providers)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .background(Color(nsColor: .windowBackgroundColor))
        .font(.callout)
        .accessibilityIdentifier("integrated-model-table")
    }

    private func modelTableHeader(modelWidth: CGFloat, tableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            sortableModelHeaderCell(t("Model / purpose", "モデル名 / 用途"), column: .name)
                .frame(width: modelWidth, height: 30, alignment: .leading)
                .overlay(alignment: .trailing) {
                    modelNameColumnResizeHandle
                }
            sortableHeaderCell(t("Size", "サイズ"), column: .size, alignment: .center)
                .frame(width: ModelTableColumnLayout.size.defaultWidth, height: 30)
            sortableHeaderCell(t("Status", "ステータス"), column: .status, alignment: .center)
                .frame(width: ModelTableColumnLayout.status.defaultWidth, height: 30)
            sortableHeaderCell(t("IP address:port", "IPアドレス:ポート"), column: .endpoint, alignment: .center)
                .frame(width: ModelTableColumnLayout.endpoint.defaultWidth, height: 30)
            sortableHeaderCell(t("Memory", "メモリ使用量"), column: .memory, alignment: .center)
                .frame(width: ModelTableColumnLayout.memory.defaultWidth, height: 30)
            sortableHeaderCell(t("Auto unload", "自動アンロード"), column: .autoUnload, alignment: .center)
                .frame(width: ModelTableColumnLayout.autoUnload.defaultWidth, height: 30)
            sortableHeaderCell(t("Reasoning", "推論"), column: .reasoning, alignment: .center)
                .frame(width: ModelTableColumnLayout.reasoning.defaultWidth, height: 30)
            modelHeaderText(t("Model management", "モデル管理"), alignment: .center)
                .frame(width: ModelTableColumnLayout.actions.defaultWidth, height: 30)
        }
        .frame(width: tableWidth, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func modelTableRow(_ row: ModelTableRow, modelWidth: CGFloat, tableWidth: CGFloat) -> some View {
        let model = row.model
        let isSelected = viewModel.selectedModelID == model.id

        return HStack(spacing: 0) {
            modelNameCell(for: model, isSelected: isSelected)
                .frame(width: modelWidth, alignment: .leading)
                .frame(minHeight: 48)
            modelSizeTableText(viewModel.modelSizeText(for: model))
                .frame(width: ModelTableColumnLayout.size.defaultWidth)
                .frame(minHeight: 48)
            statusButton(for: model)
                .frame(width: ModelTableColumnLayout.status.defaultWidth)
                .frame(minHeight: 48)
            endpointTableText(host: "127.0.0.1", port: model.serverPort)
                .frame(width: ModelTableColumnLayout.endpoint.defaultWidth)
                .frame(minHeight: 48)
            memoryCell(viewModel.integratedMemoryText(for: model))
                .frame(width: ModelTableColumnLayout.memory.defaultWidth)
                .frame(minHeight: 48)
            autoUnloadCell(for: model)
                .frame(width: ModelTableColumnLayout.autoUnload.defaultWidth)
                .frame(minHeight: 48)
            Toggle(
                "",
                isOn: Binding(
                    get: { model.enableThinking },
                    set: { viewModel.toggleReasoning(for: model, isEnabled: $0) }
                )
            )
            .labelsHidden()
            .controlSize(.small)
            .frame(width: ModelTableColumnLayout.reasoning.defaultWidth)
            .frame(minHeight: 48)
            modelActions(for: model)
                .frame(width: ModelTableColumnLayout.actions.defaultWidth)
                .frame(minHeight: 48)
        }
        .frame(width: tableWidth, alignment: .leading)
        .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedModelID = model.id
        }
        .onHover { isHovering in
            hoveredStatusModelID = isHovering ? model.id : (hoveredStatusModelID == model.id ? nil : hoveredStatusModelID)
        }
        .onDrag {
            modelDragProvider(for: model)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            moveDroppedModel(providers, before: model)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func modelNameCell(for model: ModelConfig, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                .onDrag {
                    modelDragProvider(for: model)
                }
                .help(t("Drag to reorder", "ドラッグして並び替え"))
                .accessibilityLabel(t("Drag to reorder model", "モデルをドラッグして並び替え"))

            VStack(alignment: .leading, spacing: 5) {
                Text(model.displayName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(model.notes.isEmpty ? model.family : model.notes)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func sortableModelHeaderCell(_ title: String, column: ModelTableSortColumn) -> some View {
        sortableHeaderCell(title, column: column, alignment: .leading)
    }

    private func sortableHeaderCell(_ title: String, column: ModelTableSortColumn, alignment: Alignment) -> some View {
        Button {
            toggleModelTableSort(column)
        } label: {
            modelHeaderText(title, alignment: alignment, sortColumn: column)
        }
        .buttonStyle(.plain)
    }

    private func modelHeaderText(
        _ title: String,
        alignment: Alignment,
        sortColumn: ModelTableSortColumn? = nil
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            if let sortColumn, modelTableSortColumn == sortColumn {
                Image(systemName: modelTableSortDirection == .forward ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .padding(.horizontal, 8)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                .frame(width: 1, height: 18)
        }
    }

    private var modelNameColumnResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 10)
            .contentShape(Rectangle())
            .overlay {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.65))
                    .frame(width: 1, height: 18)
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if modelNameColumnDragStartWidth == nil {
                            modelNameColumnDragStartWidth = modelNameColumnMinimumWidth
                        }
                        let startWidth = modelNameColumnDragStartWidth ?? modelNameColumnMinimumWidth
                        setModelNameColumnMinimumWidth(startWidth + value.translation.width)
                    }
                    .onEnded { _ in
                        modelNameColumnDragStartWidth = nil
                    }
            )
            .onTapGesture(count: 2) {
                setModelNameColumnMinimumWidth(ModelTableColumnLayout.model.minimum)
            }
            .help(t("Drag to resize. Double-click to fit.", "ドラッグで幅を変更。ダブルクリックで最小幅に戻します。"))
    }

    private func setModelNameColumnMinimumWidth(_ proposedWidth: CGFloat) {
        let nextWidth = min(
            max(proposedWidth, ModelTableColumnLayout.model.minimum),
            ModelTableColumnLayout.model.maximum
        )
        guard abs(nextWidth - modelNameColumnMinimumWidth) > 0.5 else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            modelNameColumnMinimumWidth = nextWidth
        }
        modelTableMinimumWidthChanged(ModelTableColumnLayout.tableWidth(minimumModelWidth: nextWidth))
    }

    private func toggleModelTableSort(_ column: ModelTableSortColumn) {
        let nextDirection: SortOrder = modelTableSortColumn == column && modelTableSortDirection == .forward
            ? .reverse
            : .forward
        modelTableSortColumn = column
        modelTableSortDirection = nextDirection
        modelTableSortOrder = [column.comparator(order: nextDirection)]
        viewModel.beginModelReorderRequested()
    }

    private func centeredTableText(
        _ value: String,
        color: Color = .primary,
        weight: Font.Weight = .regular
    ) -> some View {
        Text(value)
            .font(.callout.weight(weight))
            .foregroundStyle(color)
            .padding(.vertical, 5)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func modelSizeTableText(_ value: String) -> some View {
        let components = value.split(separator: " ", maxSplits: 1).map(String.init)
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(components.first ?? value)
                .font(.callout.monospacedDigit())
            if components.count > 1 {
                Text(components[1])
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 5)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func endpointTableText(host: String, port: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(host):")
                .font(.callout.monospacedDigit())
            Text(String(port))
                .font(.callout.monospacedDigit().weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 5)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var selectedModelBinding: Binding<ModelConfig.ID?> {
        Binding(
            get: { viewModel.selectedModelID },
            set: { viewModel.selectedModelID = $0 }
        )
    }

    private func modelDragProvider(for model: ModelConfig) -> NSItemProvider {
        modelTableSortOrder = []
        modelTableSortColumn = nil
        viewModel.beginModelReorderRequested()
        return NSItemProvider(object: model.id as NSString)
    }

    private func moveDroppedModel(_ providers: [NSItemProvider], before targetModel: ModelConfig) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let draggedModelID = value as? String,
                  draggedModelID != targetModel.id else {
                return
            }

            Task { @MainActor in
                modelTableSortOrder = []
                modelTableSortColumn = nil
                viewModel.beginModelReorderRequested()
                viewModel.moveModel(withID: draggedModelID, before: targetModel.id)
            }
        }
        return true
    }

    private func moveDroppedModelToEnd(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let draggedModelID = value as? String else {
                return
            }

            Task { @MainActor in
                modelTableSortOrder = []
                modelTableSortColumn = nil
                viewModel.beginModelReorderRequested()
                viewModel.moveModelToEnd(withID: draggedModelID)
            }
        }
        return true
    }

    @ViewBuilder
    private func statusButton(for model: ModelConfig) -> some View {
        let isHovered = hoveredStatusModelID == model.id
        let statusText = viewModel.interactiveStatusText(for: model, isHovered: isHovered)
        let isTransitioning = viewModel.isModelTransitioning(model)
        let canUseAction = viewModel.canUseStatusAction(for: model)
        let isInteractive = !isTransitioning && canUseAction
        let button = Button {
            guard isInteractive else { return }
            viewModel.statusActionRequested(for: model)
        } label: {
            Text(statusText)
                .font(.caption.weight(.medium))
                .frame(minWidth: 58)
        }
        .controlSize(.small)
        .disabled(!isInteractive)
        .padding(.vertical, 5)
        .onHover { isHovering in
            guard isInteractive else {
                if hoveredStatusModelID == model.id {
                    hoveredStatusModelID = nil
                }
                return
            }
            hoveredStatusModelID = isHovering ? model.id : nil
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .help(statusText)

        if viewModel.isModelLoaded(model) {
            button
                .buttonStyle(.borderedProminent)
                .tint(.green)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(isTransitioning ? .red : .accentColor)
        }
    }

    private func autoUnloadCell(for model: ModelConfig) -> some View {
        HStack(spacing: 6) {
            TextField(
                t("min", "分"),
                value: Binding(
                    get: { viewModel.autoUnloadMinutes(for: model) },
                    set: { viewModel.setAutoUnloadMinutes($0, for: model) }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .frame(width: 44)
            .disabled(!viewModel.isAutoUnloadEnabled(for: model))

            Text(t("min", "分"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.isAutoUnloadEnabled(for: model) },
                    set: { viewModel.setAutoUnloadEnabled($0, for: model) }
                )
            )
            .labelsHidden()
            .controlSize(.small)
        }
    }

    private func modelActions(for model: ModelConfig) -> some View {
        HStack(spacing: 8) {
            Button(t("Settings", "設定")) {
                viewModel.editProfileRequested(for: model)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isManagedProcessRunning)

            Button(t("Delete", "削除"), role: .destructive) {
                viewModel.deleteProfileRequested(for: model)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .foregroundStyle(.red)
            .disabled(viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)
        }
        .help(viewModel.runtimeEditingSafetyText(for: model))
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
                .font(.callout.monospacedDigit())
                .foregroundColor(text == "-" ? .secondary : .blue)
            ProgressView(value: text == "-" ? 0 : 0.48)
                .tint(.blue)
                .frame(width: 62)
        }
    }

    private var bottomOperationsPanel: some View {
        HStack(spacing: 0) {
            testChatPanel
                .frame(minWidth: 260, maxWidth: .infinity)
            Divider()
            logPanel
                .frame(minWidth: 260, maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("integrated-bottom-operations-panel")
    }

    private var testChatPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t("Test Chat", "テストチャット"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.miniChatHTTPStatusText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(viewModel.miniChatDurationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button(t("Clear", "クリア")) {
                    viewModel.clearMiniChatRequested()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                miniChatTranscript
                miniChatComposer
            }
            .padding(14)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("integrated-test-chat-panel")
    }

    private var miniChatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if viewModel.miniChatMessages.isEmpty {
                        Text(t("No messages yet", "まだメッセージはありません"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(viewModel.miniChatMessages) { message in
                            miniChatBubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .onChange(of: viewModel.miniChatMessages.count) { _, _ in
                guard let lastID = viewModel.miniChatMessages.last?.id else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var miniChatComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if viewModel.miniChatPrompt.isEmpty && !isMiniChatInputFocused {
                    Text(t("Type a test chat", "テストチャットを入力"))
                        .font(.callout)
                        .foregroundStyle(.secondary.opacity(0.45))
                        .padding(.top, 7)
                        .padding(.leading, 8)
                }
                MiniChatInputView(
                    text: $viewModel.miniChatPrompt,
                    placeholder: t("Type a test chat", "テストチャットを入力"),
                    isFocused: $isMiniChatInputFocused,
                    onSubmit: { viewModel.sendMiniChatRequested() }
                )
            }
            .frame(height: 42)

            HStack {
                Spacer()
                Button {
                    viewModel.sendMiniChatRequested()
                } label: {
                    Label(t("Send", "送信"), systemImage: "arrow.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!viewModel.canSendMiniChat)
                .help(t("Send test request", "テストリクエストを送信"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func miniChatBubble(_ message: MiniChatTranscriptMessage) -> some View {
        let isUser = message.sender == .user
        let isSystem = message.sender == .system
        let canCopy = message.sender == .assistant && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .font(.callout)
                .textSelection(.enabled)
                .foregroundStyle(isSystem ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .padding(.trailing, canCopy ? 24 : 0)
                .background(
                    isUser
                    ? Color.accentColor.opacity(0.12)
                    : Color.secondary.opacity(isSystem ? 0.10 : 0.16),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(alignment: .topTrailing) {
                    if canCopy {
                        Button {
                            viewModel.copyMiniChatMessageRequested(message)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 18)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 3)
                        .padding(.trailing, 3)
                        .help(t("Copy response", "返答をコピー"))
                        .accessibilityLabel(t("Copy response", "返答をコピー"))
                    }
                }
                .frame(maxWidth: 420, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(strings.text(.logs))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Picker(t("Category", "カテゴリ"), selection: $viewModel.logCategoryFilter) {
                    ForEach(viewModel.logCategoryFilterOptions, id: \.self) { category in
                        Text(viewModel.logCategoryFilterLabel(category)).tag(category)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                Button(t("Copy", "コピー")) {
                    viewModel.copyLogsRequested()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.visibleLogEntries.isEmpty)
                Button(t("Clear", "クリア")) {
                    viewModel.clearLogsRequested()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)

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
                        Text(t("No logs", "ログはありません"))
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
                Label("\(t("Overall status", "全体ステータス")): \(viewModel.runtimeState.title)", systemImage: overallStatusSymbol)
                    .foregroundStyle(overallStatusColor)
                Spacer()
            }
            .font(.caption)
            .padding(10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var rightColumn: some View {
        ZStack {
            SidebarMaterialBackdrop()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    inspectorSection(title: t("Model inspector", "モデル詳細"), systemImage: AppSymbol.modelInspector) {
                        modelSettingsPanelContent
                    }

                    Divider()
                        .padding(.horizontal, 14)

                    inspectorSection(title: t("Connection", "接続"), systemImage: AppSymbol.connection) {
                        externalServerPanelContent
                    }

                    Divider()
                        .padding(.horizontal, 14)

                    inspectorSection(title: t("Hermes Agent connection", "Hermes Agent接続情報"), systemImage: AppSymbol.hermesAgent) {
                        hermesPanelContent
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(TransparentScrollViewBackground())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var externalServerPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            formRow(t("Target", "接続先"), viewModel.connectionTargetSummary.targetType)
            copyRow("Base URL", value: viewModel.connectionTargetSummary.baseURL, action: { viewModel.copyBaseURL() })
            copyRow("Model", value: viewModel.connectionTargetSummary.modelID, action: { viewModel.copyModelID() })
            copyRow("API Key", value: viewModel.connectionTargetSummary.apiKeyPlaceholder, action: { viewModel.copyAPIKeyPlaceholder() })
        }
        .accessibilityIdentifier("integrated-external-server-panel")
    }

    private var recentRightPanelLogs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Latest logs", "最新ログ"))
                .font(.caption.weight(.semibold))
            ForEach(viewModel.visibleLogEntries.suffix(4)) { entry in
                Text(entry.line)
                    .font(.caption2.monospaced())
                    .foregroundStyle(entry.category == "error" ? Color.red : Color.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if viewModel.visibleLogEntries.isEmpty {
                Text(t("No logs yet", "ログはまだありません"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func inspectorSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.vertical, 2)
            content()
                .padding(.leading, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modelSettingsPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            formRow(t("Save location", "保存場所"), selectedModel.flatMap(modelStorageLocationText) ?? "-")
            let safetySummary = localizedStatusText(viewModel.selectedModelSafetySummary)
            formRow(t("Summary", "概要"), safetySummary, valueColor: isPositiveLocalizedStatus(safetySummary) ? .green : .orange)
            ForEach(viewModel.selectedModelSafetyRows.filter { $0.0 != "Server port" }, id: \.0) { row in
                let value = localizedStatusText(row.1)
                formRow(localizedSafetyLabel(row.0), value, valueColor: isPositiveLocalizedStatus(value) ? .green : .orange)
            }
            formRow(t("IP address:port", "IPアドレス:ポート"), selectedModelEndpointAvailabilityText, valueColor: isPositiveLocalizedStatus(localizedStatusText(viewModel.selectedServerPortSafetyText)) ? .green : .orange)
        }
        .accessibilityIdentifier("integrated-model-settings-panel-content")
    }

    private var modelInspectorOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRows([
                (t("Load state", "ロード状態"), isSelectedRunning ? t("Loaded", "ロード済") : t("Not loaded", "未ロード")),
                (t("Safety", "安全性"), localizedStatusText(viewModel.selectedModelSafetySummary)),
                (t("Port", "ポート"), selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-"),
                (t("Changes", "変更"), viewModel.restartRequired ? t("Restart required", "再起動が必要") : t("Active", "有効"))
            ])
        }
    }

    private func groupedSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.leading, 14)
        }
        .padding(.vertical, 6)
    }

    private func formRow(_ title: String, _ value: String, valueColor: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(.callout)
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func modelStorageLocationText(for model: ModelConfig) -> String {
        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) {
            return ModelAvailabilityPathFormatter.compact(path: localPath)
        }
        return model.modelID
    }

    private var selectedModelEndpointAvailabilityText: String {
        guard let selectedModel else { return "-" }
        let endpoint = "\(selectedModel.host):\(selectedModel.serverPort)"
        let status = localizedStatusText(viewModel.selectedServerPortSafetyText)
        return "\(endpoint)（\(status)）"
    }

    private func localizedSafetyLabel(_ label: String) -> String {
        switch label {
        case "Selected model": return t("Selected model", "選択モデル")
        case "Executable": return t("Executable", "実行ファイル")
        case "Model": return t("Model", "モデル")
        case "Server port": return t("IP address:port", "IPアドレス:ポート")
        case "Duplicate": return t("Duplicate", "重複")
        case "Runtime edit": return t("Runtime edit safety", "編集中の安全性")
        default: return label
        }
    }

    private func localizedStatusText(_ value: String) -> String {
        if viewModel.settings.uiLanguage.resolved == .english {
            switch value {
            case "Safety: OK", "OK": return "OK"
            case "Available": return "Available"
            case "Ready": return "Ready"
            case "OK local path": return "Local path OK"
            case "No failed start recovery needed.": return "No recovery action needed"
            case "No model selected": return "No model selected"
            case "Select a model before Start.": return "Select a model before Start"
            default:
                return value
                    .replacingOccurrences(of: "OK local path", with: "Local path OK")
                    .replacingOccurrences(of: "No duplicate endpoint detected.", with: "No duplicate endpoint detected")
            }
        }

        switch value {
        case "Safety: OK", "OK": return "問題なし"
        case "Available": return "利用可能"
        case "Ready": return "準備完了"
        case "OK local path", "Local path OK": return "ローカルパス確認済み"
        case "No failed start recovery needed.", "No recovery action needed": return "復旧操作は不要です"
        case "No model selected": return "モデル未選択"
        case "Select a model before Start.": return "モデルを選択してください"
        default:
            return value
                .replacingOccurrences(of: "Missing", with: "未検出")
                .replacingOccurrences(of: "Server port", with: "IPアドレス:ポート")
                .replacingOccurrences(of: "Stop the managed server before editing runtime identity.", with: "実行中のサーバーを停止してから編集してください")
                .replacingOccurrences(of: "No duplicate endpoint detected.", with: "重複する接続先はありません")
        }
    }

    private func isPositiveLocalizedStatus(_ value: String) -> Bool {
        value == "OK"
            || value == "問題なし"
            || value == "Available"
            || value == "利用可能"
            || value == "Ready"
            || value == "準備完了"
            || value == "Local path OK"
            || value == "ローカルパス確認済み"
            || value == "No duplicate endpoint detected"
            || value == "重複する接続先はありません"
            || value == "OK: in use by loaded model"
            || value == "OK: ロード済みモデルが使用中"
            || value == "Shared endpoint"
            || value == "共有エンドポイント"
            || value == "No recovery action needed"
            || value == "No recovery action needed."
            || value == "復旧操作は不要です"
            || value == "起動失敗の復旧は不要です。"
    }

    private func availabilityStatus(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hermesPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            copyRow("Base URL", value: viewModel.baseURL, action: { viewModel.copyBaseURL() })
            copyRow("API Key", value: viewModel.apiKeyPlaceholder, action: { viewModel.copyAPIKeyPlaceholder() })
            copyRow("Model", value: viewModel.selectedModelIdentifier, action: { viewModel.copyModelID() })
            formRow(t("Config file", "設定ファイル"), viewModel.hermesAgentConfigPathText)

            HStack(spacing: 8) {
                Button {
                    viewModel.applyHermesAgentConfigRequested()
                } label: {
                    Label(t("Apply to Hermes Agent", "Hermes Agentへ反映"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canApplyHermesAgentConfig)

                Button {
                    viewModel.copyHermesAgentConfig()
                } label: {
                    Label(t("Copy", "コピー"), systemImage: AppSymbol.copy)
                }
                .buttonStyle(.bordered)
            }

            Text(viewModel.hermesAgentConfigMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func copyRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(width: 84, alignment: .leading)
            Button(action: action) {
                Text(value)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .buttonStyle(.plain)
            .help(t("Click to copy", "クリックでコピー"))
        }
    }

    private func detailRows(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.0) { label, value in
                formRow(label, value)
            }
        }
    }
}

private struct SidebarMaterialBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .behindWindow
        nsView.state = .active
        nsView.isEmphasized = false
    }
}

private final class VerticalOnlyClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var constrainedBounds = super.constrainBoundsRect(proposedBounds)
        constrainedBounds.origin.x = 0
        return constrainedBounds
    }

    override func scroll(to newOrigin: NSPoint) {
        super.scroll(to: NSPoint(x: 0, y: newOrigin.y))
    }

    override func setBoundsOrigin(_ newOrigin: NSPoint) {
        super.setBoundsOrigin(NSPoint(x: 0, y: newOrigin.y))
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        if bounds.origin.x != 0 {
            super.setBoundsOrigin(NSPoint(x: 0, y: bounds.origin.y))
        }
    }
}

private struct ModelTableColumnConfigurator: NSViewRepresentable {
    let minimumWidths: [CGFloat]
    let maximumWidths: [CGFloat]
    let availableTableWidth: CGFloat
    let tableChromeWidth: CGFloat
    let onTableMinimumWidthChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        Self.scheduleConfiguration(
            from: view,
            minimumWidths: minimumWidths,
            maximumWidths: maximumWidths,
            availableTableWidth: availableTableWidth,
            tableChromeWidth: tableChromeWidth,
            onTableMinimumWidthChange: onTableMinimumWidthChange,
            coordinator: context.coordinator
        )
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Self.scheduleConfiguration(
            from: nsView,
            minimumWidths: minimumWidths,
            maximumWidths: maximumWidths,
            availableTableWidth: availableTableWidth,
            tableChromeWidth: tableChromeWidth,
            onTableMinimumWidthChange: onTableMinimumWidthChange,
            coordinator: context.coordinator
        )
    }

    final class Coordinator {
        var generation = 0
    }

    private static func scheduleConfiguration(
        from markerView: NSView,
        minimumWidths: [CGFloat],
        maximumWidths: [CGFloat],
        availableTableWidth: CGFloat,
        tableChromeWidth: CGFloat,
        onTableMinimumWidthChange: @escaping (CGFloat) -> Void,
        coordinator: Coordinator
    ) {
        coordinator.generation += 1
        let generation = coordinator.generation
        let delays: [TimeInterval] = [0, 0.02, 0.08, 0.2]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard coordinator.generation == generation else { return }
                Self.configureTable(
                    from: markerView,
                    minimumWidths: minimumWidths,
                    maximumWidths: maximumWidths,
                    availableTableWidth: availableTableWidth,
                    tableChromeWidth: tableChromeWidth,
                    onTableMinimumWidthChange: onTableMinimumWidthChange
                )
            }
        }
    }

    private static func configureTable(
        from markerView: NSView,
        minimumWidths: [CGFloat],
        maximumWidths: [CGFloat],
        availableTableWidth: CGFloat,
        tableChromeWidth: CGFloat,
        onTableMinimumWidthChange: @escaping (CGFloat) -> Void
    ) {
        guard let tableView = findTableView(from: markerView, expectedColumnCount: minimumWidths.count) else { return }
        let state = ModelTableColumnState.state(for: tableView)
        state.ensureModelMinimumWidth(minimumWidths.first ?? 0)

        for (index, column) in tableView.tableColumns.enumerated() {
            guard minimumWidths.indices.contains(index), maximumWidths.indices.contains(index) else { continue }
            let minimumWidth = minimumWidths[index]
            let maximumWidth = maximumWidths[index]
            column.minWidth = minimumWidth
            column.maxWidth = maximumWidth
            column.resizingMask = index == 0 ? .userResizingMask : []
        }

        tableView.columnAutoresizingStyle = .noColumnAutoresizing

        if !state.didApplyInitialWidths {
            state.didApplyInitialWidths = true
        }

        if let scrollView = tableView.enclosingScrollView {
            resetHorizontalScrolling(in: scrollView)
        }

        ModelTableDelegateProxy.install(on: tableView, minimumWidths: minimumWidths)
        state.applyVisualWidths(
            to: tableView,
            availableTableWidth: availableTableWidth,
            minimumWidths: minimumWidths,
            maximumWidths: maximumWidths
        )
        state.attach(
            to: tableView,
            expectedColumnCount: minimumWidths.count,
            tableChromeWidth: tableChromeWidth,
            minimumWidths: minimumWidths,
            maximumWidths: maximumWidths,
            availableTableWidth: availableTableWidth,
            onTableMinimumWidthChange: onTableMinimumWidthChange
        )
    }

    private static func findTableView(from markerView: NSView, expectedColumnCount: Int) -> NSTableView? {
        if let windowTable = markerView.window?.contentView.flatMap({
            firstTableView(in: $0, expectedColumnCount: expectedColumnCount)
        }) {
            return windowTable
        }

        var current: NSView? = markerView
        while let view = current {
            if let tableView = view as? NSTableView, tableView.tableColumns.count >= expectedColumnCount {
                return tableView
            }
            if let tableView = firstTableView(in: view, expectedColumnCount: expectedColumnCount) {
                return tableView
            }
            current = view.superview
        }
        return nil
    }

    private static func firstTableView(in view: NSView, expectedColumnCount: Int) -> NSTableView? {
        if let tableView = view as? NSTableView, tableView.tableColumns.count >= expectedColumnCount {
            return tableView
        }
        for subview in view.subviews {
            if let tableView = firstTableView(in: subview, expectedColumnCount: expectedColumnCount) {
                return tableView
            }
        }
        return nil
    }

    static func resetHorizontalScrolling(in scrollView: NSScrollView) {
        installVerticalOnlyClipView(in: scrollView)
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScroller = nil
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        var bounds = scrollView.contentView.bounds
        guard bounds.origin.x != 0 else { return }
        bounds.origin.x = 0
        scrollView.contentView.scroll(to: bounds.origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static func installVerticalOnlyClipView(in scrollView: NSScrollView) {
        guard !(scrollView.contentView is VerticalOnlyClipView) else { return }

        let previousClipView = scrollView.contentView
        let documentView = previousClipView.documentView
        previousClipView.documentView = nil

        let clipView = VerticalOnlyClipView(frame: previousClipView.frame)
        clipView.autoresizingMask = previousClipView.autoresizingMask
        clipView.drawsBackground = previousClipView.drawsBackground
        clipView.backgroundColor = previousClipView.backgroundColor
        clipView.postsBoundsChangedNotifications = previousClipView.postsBoundsChangedNotifications
        scrollView.contentView = clipView
        clipView.documentView = documentView
    }
}

private final class ModelTableColumnState: NSObject {
    var didApplyInitialWidths = false
    private weak var tableView: NSTableView?
    private var expectedColumnCount = 0
    private var tableChromeWidth: CGFloat = 0
    private var minimumWidths: [CGFloat] = []
    private var maximumWidths: [CGFloat] = []
    private var availableTableWidth: CGFloat = 0
    private var modelMinimumWidth: CGFloat?
    private var isApplyingVisualWidths = false
    private var onTableMinimumWidthChange: ((CGFloat) -> Void)?
    private var columnResizeObserver: NSObjectProtocol?

    private static var associationKey: UInt8 = 0

    deinit {
        if let columnResizeObserver {
            NotificationCenter.default.removeObserver(columnResizeObserver)
        }
    }

    static func state(for tableView: NSTableView) -> ModelTableColumnState {
        if let state = objc_getAssociatedObject(tableView, &associationKey) as? ModelTableColumnState {
            return state
        }

        let state = ModelTableColumnState()
        objc_setAssociatedObject(tableView, &associationKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }

    func ensureModelMinimumWidth(_ fallback: CGFloat) {
        if modelMinimumWidth == nil {
            modelMinimumWidth = fallback
        }
    }

    func attach(
        to tableView: NSTableView,
        expectedColumnCount: Int,
        tableChromeWidth: CGFloat,
        minimumWidths: [CGFloat],
        maximumWidths: [CGFloat],
        availableTableWidth: CGFloat,
        onTableMinimumWidthChange: @escaping (CGFloat) -> Void
    ) {
        self.expectedColumnCount = expectedColumnCount
        self.tableChromeWidth = tableChromeWidth
        self.minimumWidths = minimumWidths
        self.maximumWidths = maximumWidths
        self.availableTableWidth = availableTableWidth
        self.onTableMinimumWidthChange = onTableMinimumWidthChange
        ensureModelMinimumWidth(minimumWidths.first ?? 0)

        if self.tableView !== tableView {
            if let columnResizeObserver {
                NotificationCenter.default.removeObserver(columnResizeObserver)
            }
            self.tableView = tableView
            columnResizeObserver = NotificationCenter.default.addObserver(
                forName: NSTableView.columnDidResizeNotification,
                object: tableView,
                queue: .main
            ) { [weak self] _ in
                self?.tableColumnDidResize()
            }
        }

        applyVisualWidths(
            to: tableView,
            availableTableWidth: availableTableWidth,
            minimumWidths: minimumWidths,
            maximumWidths: maximumWidths
        )
        publishCurrentMinimumWidth()
    }

    func applyVisualWidths(
        to tableView: NSTableView,
        availableTableWidth: CGFloat,
        minimumWidths: [CGFloat],
        maximumWidths: [CGFloat]
    ) {
        guard minimumWidths.count == expectedColumnCount || expectedColumnCount == 0 else { return }
        guard !minimumWidths.isEmpty else { return }
        let columnCount = min(tableView.tableColumns.count, minimumWidths.count, maximumWidths.count)
        guard columnCount > 0 else { return }

        ensureModelMinimumWidth(minimumWidths[0])
        let intercellWidth = tableView.intercellSpacing.width * CGFloat(max(0, columnCount - 1))
        let fixedColumnsWidth = minimumWidths
            .prefix(columnCount)
            .dropFirst()
            .reduce(CGFloat.zero, +)
        let requestedModelWidth = availableTableWidth - fixedColumnsWidth - intercellWidth - tableChromeWidth
        let modelWidth = min(
            max(requestedModelWidth, modelMinimumWidth ?? minimumWidths[0], minimumWidths[0]),
            maximumWidths[0]
        )

        isApplyingVisualWidths = true
        defer { isApplyingVisualWidths = false }

        for index in 0..<columnCount {
            let targetWidth = index == 0 ? modelWidth : minimumWidths[index]
            let column = tableView.tableColumns[index]
            if abs(column.width - targetWidth) > 0.5 {
                column.width = targetWidth
            }
        }

        if let scrollView = tableView.enclosingScrollView {
            ModelTableColumnConfigurator.resetHorizontalScrolling(in: scrollView)
        }
    }

    private func tableColumnDidResize() {
        guard !isApplyingVisualWidths, let tableView else { return }
        guard !minimumWidths.isEmpty, !maximumWidths.isEmpty, tableView.tableColumns.indices.contains(0) else { return }

        let currentModelWidth = tableView.tableColumns[0].width
        let clampedModelWidth = min(max(currentModelWidth, minimumWidths[0]), maximumWidths[0])
        if abs((modelMinimumWidth ?? minimumWidths[0]) - clampedModelWidth) > 0.5 {
            modelMinimumWidth = clampedModelWidth
            publishCurrentMinimumWidth()
        }

        applyVisualWidths(
            to: tableView,
            availableTableWidth: availableTableWidth,
            minimumWidths: minimumWidths,
            maximumWidths: maximumWidths
        )
    }

    private func publishCurrentMinimumWidth() {
        guard let tableView else { return }
        if let scrollView = tableView.enclosingScrollView {
            ModelTableColumnConfigurator.resetHorizontalScrolling(in: scrollView)
        }
        let columnCount = min(expectedColumnCount, minimumWidths.count)
        let modelWidth = modelMinimumWidth ?? minimumWidths.first ?? 0
        let fixedColumnsWidth = minimumWidths
            .prefix(columnCount)
            .dropFirst()
            .reduce(CGFloat.zero, +)
        let intercellWidth = tableView.intercellSpacing.width * CGFloat(max(0, expectedColumnCount - 1))
        onTableMinimumWidthChange?(modelWidth + fixedColumnsWidth + intercellWidth + tableChromeWidth)
    }
}

private final class ModelTableDelegateProxy: NSObject, NSTableViewDelegate {
    private static let sizeToFitSelector = NSSelectorFromString("tableView:sizeToFitWidthOfColumn:")
    private static var associationKey: UInt8 = 0

    private weak var originalDelegate: NSTableViewDelegate?
    private var minimumWidths: [CGFloat]

    private init(originalDelegate: NSTableViewDelegate?, minimumWidths: [CGFloat]) {
        self.originalDelegate = originalDelegate
        self.minimumWidths = minimumWidths
        super.init()
    }

    static func install(on tableView: NSTableView, minimumWidths: [CGFloat]) {
        if let proxy = objc_getAssociatedObject(tableView, &associationKey) as? ModelTableDelegateProxy {
            proxy.minimumWidths = minimumWidths
            if tableView.delegate !== proxy {
                proxy.originalDelegate = tableView.delegate
                tableView.delegate = proxy
            }
            return
        }

        let proxy = ModelTableDelegateProxy(originalDelegate: tableView.delegate, minimumWidths: minimumWidths)
        objc_setAssociatedObject(tableView, &associationKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        tableView.delegate = proxy
    }

    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        guard minimumWidths.indices.contains(column) else {
            return tableView.tableColumns.indices.contains(column) ? tableView.tableColumns[column].minWidth : 0
        }
        return minimumWidths[column]
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == Self.sizeToFitSelector {
            return true
        }
        if super.responds(to: aSelector) {
            return true
        }
        return originalDelegate?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let originalDelegate, originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }
}

private struct WindowFrameController: NSViewRepresentable {
    let minWidth: CGFloat
    let minHeight: CGFloat
    @Binding var isUserLiveResizing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isUserLiveResizing: $isUserLiveResizing)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                Self.apply(to: window, coordinator: context.coordinator, minWidth: minWidth, minHeight: minHeight)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                Self.apply(to: window, coordinator: context.coordinator, minWidth: minWidth, minHeight: minHeight)
            }
        }
    }

    private static func apply(to window: NSWindow, coordinator: Coordinator, minWidth: CGFloat, minHeight: CGFloat) {
        coordinator.attach(to: window)
        coordinator.minWidth = minWidth
        coordinator.minHeight = minHeight
        let contentMinimumSize = NSSize(width: minWidth, height: minHeight)
        window.contentMinSize = contentMinimumSize
        window.minSize = frameSize(for: contentMinimumSize, in: window)
    }

    static func setWidth(
        _ window: NSWindow,
        to width: CGFloat,
        minimumWidth minWidth: CGFloat,
        minimumHeight minHeight: CGFloat,
        animate: Bool = true
    ) {
        let nextMinimumSize = NSSize(width: minWidth, height: minHeight)
        window.contentMinSize = nextMinimumSize
        window.minSize = frameSize(for: nextMinimumSize, in: window)

        let currentFrame = window.frame
        let currentContentRect = window.contentRect(forFrameRect: currentFrame)
        let targetWidth = max(width, minWidth)
        let targetHeight = max(currentContentRect.height, minHeight)
        var targetContentRect = currentContentRect
        targetContentRect.size.width = targetWidth
        targetContentRect.size.height = targetHeight
        var frame = window.frameRect(forContentRect: targetContentRect)
        guard abs(frame.width - currentFrame.width) > 0.5 || abs(frame.height - currentFrame.height) > 0.5 else { return }

        frame.origin.x = currentFrame.origin.x
        frame.origin.y = currentFrame.maxY - frame.height

        if let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            if frame.maxX > screenFrame.maxX {
                frame.origin.x = screenFrame.maxX - frame.width
            }
            frame.origin.x = max(frame.origin.x, screenFrame.minX)
            frame.origin.y = min(frame.origin.y, screenFrame.maxY - frame.height)
            frame.origin.y = max(frame.origin.y, screenFrame.minY)
        }

        window.setFrame(frame, display: true, animate: animate)
    }

    private static func frameSize(for contentSize: NSSize, in window: NSWindow) -> NSSize {
        let contentRect = NSRect(origin: .zero, size: contentSize)
        return window.frameRect(forContentRect: contentRect).size
    }

    final class Coordinator {
        var minWidth: CGFloat = 0
        var minHeight: CGFloat = 0
        private var isUserLiveResizing: Binding<Bool>
        private weak var window: NSWindow?
        private var resizeObserver: NSObjectProtocol?
        private var liveResizeStartObserver: NSObjectProtocol?
        private var liveResizeEndObserver: NSObjectProtocol?

        init(isUserLiveResizing: Binding<Bool>) {
            self.isUserLiveResizing = isUserLiveResizing
        }

        deinit {
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
            }
            if let liveResizeStartObserver {
                NotificationCenter.default.removeObserver(liveResizeStartObserver)
            }
            if let liveResizeEndObserver {
                NotificationCenter.default.removeObserver(liveResizeEndObserver)
            }
        }

        func attach(to window: NSWindow) {
            guard self.window !== window else { return }
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
            }
            if let liveResizeStartObserver {
                NotificationCenter.default.removeObserver(liveResizeStartObserver)
            }
            if let liveResizeEndObserver {
                NotificationCenter.default.removeObserver(liveResizeEndObserver)
            }
            self.window = window
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.enforceMinimumSize()
            }
            liveResizeStartObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willStartLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.isUserLiveResizing.wrappedValue = true
            }
            liveResizeEndObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isUserLiveResizing.wrappedValue = false
                }
            }
        }

        private func enforceMinimumSize() {
            guard let window else { return }
            let currentFrame = window.frame
            let currentContentRect = window.contentRect(forFrameRect: currentFrame)
            let targetWidth = max(currentContentRect.width, minWidth)
            let targetHeight = max(currentContentRect.height, minHeight)
            guard targetWidth > currentContentRect.width + 0.5 || targetHeight > currentContentRect.height + 0.5 else { return }

            var targetContentRect = currentContentRect
            targetContentRect.size.width = targetWidth
            targetContentRect.size.height = targetHeight
            var frame = window.frameRect(forContentRect: targetContentRect)
            frame.origin.x = currentFrame.origin.x
            frame.origin.y = currentFrame.maxY - frame.height

            if let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
                if frame.maxX > screenFrame.maxX {
                    frame.origin.x = screenFrame.maxX - frame.width
                }
                frame.origin.x = max(frame.origin.x, screenFrame.minX)
                frame.origin.y = min(frame.origin.y, screenFrame.maxY - frame.height)
                frame.origin.y = max(frame.origin.y, screenFrame.minY)
            }

            window.setFrame(frame, display: true, animate: false)
        }
    }
}

private struct TransparentScrollViewBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            Self.clearScrollViewBackground(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.clearScrollViewBackground(from: nsView)
        }
    }

    private static func clearScrollViewBackground(from view: NSView) {
        var current: NSView? = view
        while let parent = current?.superview {
            if let scrollView = parent as? NSScrollView {
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                scrollView.contentView.drawsBackground = false
                break
            }
            current = parent
        }
    }
}

private struct ModelTableRow: Identifiable {
    let model: ModelConfig
    let nameSortValue: String
    let sizeSortValue: Double
    let statusSortValue: Int
    let endpointSortValue: String
    let memorySortValue: Double
    let autoUnloadSortValue: Int
    let reasoningSortValue: Int

    var id: ModelConfig.ID {
        model.id
    }
}
