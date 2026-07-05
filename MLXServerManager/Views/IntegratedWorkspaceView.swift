import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IntegratedWorkspaceView: View {
    static let baseMinimumHeight = Layout.windowMinimumHeight

    @ObservedObject var viewModel: AppViewModel
    @State var selectedDestination: IntegratedWorkspaceDestination = .models
    @State private var isBottomPanelVisible = true
    @State private var isBottomPanelAutoHidden = false
    @State private var modelTableSortOrder = [KeyPathComparator<ModelTableRow>]()
    @State private var modelTableSortColumn: ModelTableSortColumn?
    @State private var modelTableSortDirection: SortOrder = .forward
    @State private var hoveredStatusModelID: ModelConfig.ID?
    @State private var isMiniChatInputFocused = false
    @State private var isModelInspectorVisible = true
    @State private var isModelInspectorAutoHidden = false
    @State private var modelInspectorProgress: CGFloat = 1
    @State private var isModelInspectorAnimating = false
    @State private var isCenterWidthAnimating = false
    @State private var centerWidthAnimationGeneration = 0
    @State private var currentDetailWidth: CGFloat = 0
    @State private var inspectorCopyToast: String?

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }
    private func modelRows(from models: [ModelConfig]) -> [ModelTableRow] {
        models.map { model in
            let sizeText = viewModel.modelSizeText(for: model)
            let memoryText = viewModel.integratedMemoryText(for: model)
            let isTransitioning = viewModel.isModelTransitioning(model)
            let isLoaded = model.id == viewModel.runningModelID && !isTransitioning
            let isPortBusy = viewModel.isModelPortBusy(for: model)
            let canUseStatusAction = viewModel.canUseStatusAction(for: model)
            let statusSortValue: Int
            if isTransitioning {
                statusSortValue = 0
            } else if model.id == viewModel.runningModelID {
                statusSortValue = 1
            } else if isPortBusy {
                statusSortValue = 2
            } else {
                statusSortValue = 3
            }
            return ModelTableRow(
                model: model,
                sizeText: sizeText,
                memoryText: memoryText,
                normalStatusText: viewModel.interactiveStatusText(for: model, isHovered: false, isPortBusy: isPortBusy),
                hoveredStatusText: viewModel.interactiveStatusText(for: model, isHovered: true, isPortBusy: isPortBusy),
                isTransitioning: isTransitioning,
                isLoaded: isLoaded,
                isPortBusy: isPortBusy,
                canUseStatusAction: canUseStatusAction,
                isRecentlyAdded: viewModel.isLastAddedDownloadedModel(model),
                nameSortValue: model.displayName,
                sizeSortValue: viewModel.modelSizeSortValue(for: model),
                statusSortValue: statusSortValue,
                endpointSortValue: viewModel.endpointSortValue(for: model),
                memorySortValue: viewModel.integratedMemorySortValue(for: model),
                autoUnloadSortValue: viewModel.autoUnloadTableSortValue(for: model),
                reasoningSortValue: viewModel.reasoningSortValue(for: model)
            )
        }
    }

    private func sortedModelRows(from rows: [ModelTableRow]) -> [ModelTableRow] {
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
        isBottomPanelAutoHidden = false
        withAnimation(.easeInOut(duration: 0.24)) {
            isBottomPanelVisible.toggle()
        }
    }

    private func toggleModelInspectorRequested() {
        let nextVisible = !isModelInspectorVisible
        isModelInspectorAutoHidden = false

        guard !nextVisible || canShowModelInspector(forDetailWidth: currentDetailWidth) else {
            setModelInspectorVisible(false)
            return
        }

        setModelInspectorVisible(nextVisible)
    }

    private func setModelInspectorVisible(_ isVisible: Bool) {
        isModelInspectorVisible = isVisible
        isModelInspectorAnimating = true

        withAnimation(.easeInOut(duration: 0.24)) {
            modelInspectorProgress = isVisible ? 1 : 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            isModelInspectorAnimating = false
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

    private func updateDetailWidth(_ detailWidth: CGFloat) {
        let didChangeWidth = abs(currentDetailWidth - detailWidth) > 2
        currentDetailWidth = detailWidth

        if didChangeWidth {
            centerWidthAnimationGeneration += 1
            let generation = centerWidthAnimationGeneration

            if !isCenterWidthAnimating {
                isCenterWidthAnimating = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                if centerWidthAnimationGeneration == generation {
                    isCenterWidthAnimating = false
                }
            }
        }

        applyAutomaticModelInspectorCollapse(forDetailWidth: detailWidth)
    }

    private var canToggleModelInspectorOpen: Bool {
        selectedDestination == .models && canShowModelInspector(forDetailWidth: currentDetailWidth)
    }

    private var isModelInspectorToggleEnabled: Bool {
        isModelInspectorVisible || canToggleModelInspectorOpen
    }

    private func canShowModelInspector(forDetailWidth detailWidth: CGFloat) -> Bool {
        let inspectorReservedWidth = Layout.modelInspectorWidth + Layout.modelInspectorDividerWidth
        let minimumFullMetadataOuterWidth = Layout.modelTableFullMetadataWidth + Layout.modelTableHorizontalChrome
        return detailWidth - inspectorReservedWidth >= minimumFullMetadataOuterWidth
    }

    private func applyAutomaticModelInspectorCollapse(forDetailWidth detailWidth: CGFloat) {
        guard selectedDestination == .models else { return }
        guard isModelInspectorVisible else { return }

        if !canShowModelInspector(forDetailWidth: detailWidth) {
            isModelInspectorAutoHidden = true
            setModelInspectorVisible(false)
        }
    }

    private enum Layout {
        static let tableChromeWidth: CGFloat = 0
        static let leftPanelWidth: CGFloat = 280
        static let defaultCenterMinimumWidth: CGFloat = 620
        static let windowMinimumHeight: CGFloat = 760
        static let minimumBottomPanelHeight: CGFloat = 720
        static let modelSortHeaderHeight: CGFloat = 32
        static let modelTableHorizontalChrome: CGFloat = 28
        static let modelTableFullMetadataWidth: CGFloat = 840
        static let modelInspectorWidth: CGFloat = 320
        static let modelInspectorDividerWidth: CGFloat = 1
        static let modelInspectorDockThreshold: CGFloat = 1189
        static let sidebarAnimationDuration: TimeInterval = 0.24
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

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                if selectedDestination == .models {
                    let inspectorSlotWidth = Layout.modelInspectorWidth + Layout.modelInspectorDividerWidth
                    rootModelInspectorOverlay(availableHeight: geometry.size.height)
                        .frame(width: inspectorSlotWidth)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(x: inspectorSlotWidth * (1 - modelInspectorProgress))
                        .allowsHitTesting(isModelInspectorVisible && modelInspectorProgress > 0.98)
                        .zIndex(3)
                }

                NavigationSplitView {
                    standardSidebar
                } detail: {
                    GeometryReader { detailProxy in
                        workspaceDetail(availableWidth: detailProxy.size.width, availableHeight: detailProxy.size.height)
                            .id("center-\(viewModel.settings.uiAppearance)")
                            .frame(width: detailProxy.size.width, height: detailProxy.size.height, alignment: .topLeading)
                            .clipped()
                            .background(Color(nsColor: .windowBackgroundColor))
                            .onAppear {
                                updateDetailWidth(detailProxy.size.width)
                            }
                            .onChange(of: detailProxy.size.width) { _, width in
                                updateDetailWidth(width)
                            }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .navigationTitle(selectedDestination.title(language: viewModel.settings.uiLanguage))
                }
                .navigationSplitViewStyle(.balanced)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                    panelToggleButton(
                        systemImage: AppSymbol.bottomPanel,
                        isActive: isBottomPanelVisible,
                        help: isBottomPanelVisible
                            ? t("Hide bottom panel", "下段パネルを隠す")
                            : t("Show bottom panel", "下段パネルを表示"),
                        action: toggleBottomPanelRequested
                    )

                    panelToggleButton(
                        systemImage: "sidebar.trailing",
                        isActive: isModelInspectorVisible,
                        isEnabled: isModelInspectorToggleEnabled,
                        help: isModelInspectorToggleHelp,
                        action: toggleModelInspectorRequested
                    )
                    }
                }
                .animation(.easeInOut(duration: 0.24), value: isBottomPanelVisible)
                .onAppear {
                    applyAutomaticPanelCollapse(for: geometry.size)
                }
                .onChange(of: geometry.size) { _, size in
                    applyAutomaticPanelCollapse(for: size)
                }
            }
        }
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .preferredColorScheme(preferredColorScheme)
        .accessibilityIdentifier("integrated-workspace")
    }

    private var isModelInspectorToggleHelp: String {
        if isModelInspectorVisible {
            return t("Hide model inspector", "モデルInspectorを隠す")
        }
        if canToggleModelInspectorOpen {
            return t("Show model inspector", "モデルInspectorを表示")
        }
        return t("Model inspector needs more width", "モデルInspectorを表示するには幅が足りません")
    }

    private func panelToggleButton(
        systemImage: String,
        isActive: Bool,
        isEnabled: Bool = true,
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
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private var standardSidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedDestination) {
                Section {
                    ForEach(IntegratedWorkspaceDestination.primarySidebarDestinations) { destination in
                        NavigationLink(value: destination) {
                            sidebarDestinationLabel(destination)
                        }
                        .accessibilityIdentifier("integrated-sidebar-\(destination.rawValue)")
                    }
                } header: {
                    Text(t("Workspace", "ワークスペース"))
                }

                Section {
                    systemPanel
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 12))
                } header: {
                    Text(t("System", "システム"))
                }
            }
            .listStyle(.sidebar)

            sidebarFooterControls
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: Layout.leftPanelWidth, max: 320)
    }

    private func sidebarDestinationLabel(_ destination: IntegratedWorkspaceDestination) -> some View {
        HStack(spacing: 8) {
            Image(systemName: destination.systemImageName)
                .frame(width: 16, alignment: .center)
            Text(destination.title(language: viewModel.settings.uiLanguage))
                .fontWeight(.regular)
            Spacer(minLength: 6)
            if destination == .downloads {
                downloadSidebarMarker
            }
        }
    }

    @ViewBuilder
    private var downloadSidebarMarker: some View {
        if viewModel.isHuggingFaceDownloadActive {
            ProgressView(value: viewModel.downloadSidebarProgressFraction ?? 0)
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .frame(width: 14, height: 14)
                .help(viewModel.downloadProgressSummaryText)
        } else if viewModel.hasCompletedHuggingFaceDownloadMarker {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .help(t("Download complete", "ダウンロード完了"))
        }
    }

    private var systemPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("SYSTEM", "システム"), systemImage: "desktopcomputer")
                .font(.headline.weight(.regular))
                .foregroundStyle(.primary)

            systemInfoCard
            Divider()
            systemHealthCard
        }
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
        .padding(.leading, 22)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t("Memory", "メモリ"), systemImage: "memorychip")
                    .font(.headline.weight(.regular))
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.integratedMemoryUsagePercentText)
                    .font(.headline.monospacedDigit().weight(.regular))
                    .foregroundStyle(.primary)
            }

            memoryUsageBar

            VStack(alignment: .leading, spacing: 12) {
                memoryLegendRow(color: .blue, label: "mlx-lm", value: viewModel.memoryMLXProcessText)
                memoryLegendRow(color: .green, label: t("Other", "その他"), value: viewModel.memoryOtherProcessesText)
                memoryLegendRow(color: .secondary.opacity(0.45), label: t("Available", "空き容量"), value: viewModel.memoryAvailableText)
            }
            .padding(.leading, 22)

            Divider()

            HStack {
                Label {
                    Text(verbatim: "CPU")
                } icon: {
                    Image(systemName: "cpu")
                }
                .font(.headline.weight(.regular))
                .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.integratedCPUUsageText)
                    .font(.headline.monospacedDigit().weight(.regular))
                    .foregroundStyle(.primary)
            }

            Divider()

            HStack {
                Label(t("Uptime", "起動時間"), systemImage: "timer")
                    .font(.headline.weight(.regular))
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.integratedUptimeText)
                    .font(.headline.monospacedDigit().weight(.regular))
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
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(width: 82, alignment: .leading)
        }
        .lineLimit(1)
    }

    private var sidebarFooterControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.horizontal, 8)

            Button {
                selectedDestination = .settings
            } label: {
                Label {
                    Text(t("Settings", "設定"))
                        .fontWeight(.regular)
                } icon: {
                    Image(systemName: IntegratedWorkspaceDestination.settings.systemImageName)
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedDestination == .settings ? Color.accentColor : Color.primary)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        selectedDestination = .settings
                    }
            )
            .accessibilityIdentifier("integrated-sidebar-footer-settings")
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rootModelInspectorOverlay(availableHeight: CGFloat) -> some View {
        let inspectorWidth = Layout.modelInspectorWidth
        let dividerWidth = Layout.modelInspectorDividerWidth

        return HStack(spacing: 0) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                .frame(width: dividerWidth, height: availableHeight)

            ZStack(alignment: .top) {
                InspectorVisualEffectBackground()
                    .ignoresSafeArea()

                modelInspectorPanel
                    .frame(width: inspectorWidth, height: availableHeight + 36, alignment: .topLeading)
                    .offset(y: -36)
                    .allowsHitTesting(isModelInspectorVisible && modelInspectorProgress > 0.98)
            }
            .frame(width: inspectorWidth, height: availableHeight, alignment: .top)
        }
        .frame(width: inspectorWidth + dividerWidth, height: availableHeight, alignment: .topTrailing)
        .background(InspectorVisualEffectBackground().ignoresSafeArea())
        .animation(.easeInOut(duration: 0.24), value: modelInspectorProgress)
    }

    @ViewBuilder
    private func workspaceDetail(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        if selectedDestination == .models, availableWidth >= Layout.modelInspectorDockThreshold || modelInspectorProgress > 0 {
            let inspectorWidth = Layout.modelInspectorWidth
            let dividerWidth: CGFloat = 1
            let reservedWidth = (inspectorWidth + dividerWidth) * modelInspectorProgress
            let centerWidth = max(0, availableWidth - reservedWidth)

            HStack(spacing: 0) {
                centerColumn(availableWidth: centerWidth)
                    .frame(width: centerWidth, height: availableHeight, alignment: .topLeading)
                    .clipped()

                Color.clear
                    .frame(width: reservedWidth, height: availableHeight, alignment: .trailing)
            }
            .frame(width: availableWidth, height: availableHeight, alignment: .topLeading)
            .clipped()
            .animation(.easeInOut(duration: 0.24), value: modelInspectorProgress)
        } else {
            centerColumn(availableWidth: availableWidth)
                .frame(width: availableWidth, height: availableHeight, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func centerColumn(availableWidth: CGFloat) -> some View {
        switch selectedDestination {
        case .models:
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    modelListPanel(availableWidth: proxy.size.width)
                        .frame(width: proxy.size.width, alignment: .topLeading)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    if isBottomPanelVisible {
                        VStack(spacing: 0) {
                            Divider()
                            bottomOperationsPanel(availableWidth: proxy.size.width)
                                .frame(height: max(180, proxy.size.height / 3))
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
                .background(Color(nsColor: .windowBackgroundColor))
            }
        case .downloads:
            DownloadsSurfaceView(viewModel: viewModel, onOpenModels: { selectedDestination = .models })
        case .settings:
            SettingsSurfaceView(viewModel: viewModel)
        case .logs:
            EmptyView()
        }
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

    private func modelListPanel(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t("Dashboard", "ダッシュボード"))
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

            let rows = sortedModelRows(from: modelRows(from: viewModel.visibleModels))
            if rows.isEmpty {
                modelEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    modelTable(rows: rows, availableWidth: proxy.size.width, allowsWidthAnimation: isModelInspectorAnimating)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .clipped()
                }
            }
        }
        .frame(width: availableWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity)
        .clipped()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func modelTable(rows: [ModelTableRow], availableWidth: CGFloat, allowsWidthAnimation: Bool = false) -> some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 10) {
                if availableWidth >= 850 {
                    modelSortHeader(availableWidth: max(0, availableWidth - 28))
                        .frame(width: max(0, availableWidth - 28), alignment: .leading)
                } else {
                    compactSortBar
                        .frame(width: max(0, availableWidth - 28), alignment: .leading)
                }

                ForEach(rows) { row in
                    lightweightModelRow(for: row, availableWidth: max(0, availableWidth - 28))
                        .frame(width: max(0, availableWidth - 28), alignment: .leading)
                }
            }
            .frame(width: max(0, availableWidth - 28), alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .transaction { transaction in
            if !allowsWidthAnimation {
                transaction.animation = nil
            }
        }
        .accessibilityIdentifier("integrated-model-list")
    }

    private func modelSortHeader(availableWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 14) {
            sortHeaderButton(t("Model", "モデル名"), column: .name, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            sortHeaderButton(t("Size", "サイズ"), column: .size, alignment: .leading)
                .frame(width: 72, alignment: .leading)

            sortHeaderButton(t("Status", "状態"), column: .status, alignment: .center)
                .frame(width: 88)

            sortHeaderButton(t("Endpoint", "接続先"), column: .endpoint, alignment: .leading)
                .frame(width: 132, alignment: .leading)

            sortHeaderButton(t("Memory", "メモリ"), column: .memory, alignment: .leading)
                .frame(width: 78, alignment: .leading)

            Text(t("Actions", "操作"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 42)
        }
        .padding(.horizontal, 14)
        .frame(width: availableWidth, height: Layout.modelSortHeaderHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.32))
        )
        .accessibilityIdentifier("integrated-model-sort-header")
    }

    private var compactSortBar: some View {
        HStack(spacing: 8) {
            Text(sortSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Menu {
                sortMenuButton(t("Model", "モデル名"), column: .name)
                sortMenuButton(t("Size", "サイズ"), column: .size)
                sortMenuButton(t("Status", "状態"), column: .status)
                sortMenuButton(t("Endpoint", "接続先"), column: .endpoint)
                sortMenuButton(t("Memory", "メモリ"), column: .memory)
            } label: {
                Label(t("Sort", "並び替え"), systemImage: "arrow.up.arrow.down")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.button)
            .controlSize(.mini)
        }
        .padding(.horizontal, 14)
        .frame(height: Layout.modelSortHeaderHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.32))
        )
        .accessibilityIdentifier("integrated-model-compact-sort-bar")
    }

    private var sortSummaryText: String {
        guard let column = modelTableSortColumn else {
            return t("Sorted by profile order", "プロファイル順")
        }
        let direction = modelTableSortDirection == .forward ? "↑" : "↓"
        return "\(sortColumnTitle(column)) \(direction)"
    }

    private func sortColumnTitle(_ column: ModelTableSortColumn) -> String {
        switch column {
        case .name:
            t("Model", "モデル名")
        case .size:
            t("Size", "サイズ")
        case .status:
            t("Status", "状態")
        case .endpoint:
            t("Endpoint", "接続先")
        case .memory:
            t("Memory", "メモリ")
        case .autoUnload:
            t("Auto unload", "自動アンロード")
        case .reasoning:
            t("Reasoning", "推論")
        }
    }

    private func sortHeaderButton(_ title: String, column: ModelTableSortColumn, alignment: Alignment) -> some View {
        Button {
            toggleModelTableSort(column)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if modelTableSortColumn == column {
                    Image(systemName: modelTableSortDirection == .forward ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(modelTableSortColumn == column ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
        }
        .buttonStyle(.plain)
        .help(t("Sort by", "並び替え") + " " + title)
    }

    private func sortMenuButton(_ title: String, column: ModelTableSortColumn) -> some View {
        Button {
            toggleModelTableSort(column)
        } label: {
            Label(title, systemImage: modelTableSortColumn == column ? (modelTableSortDirection == .forward ? "chevron.up" : "chevron.down") : "circle")
        }
    }

    private func lightweightModelRow(for row: ModelTableRow, availableWidth: CGFloat) -> some View {
        let model = row.model
        let isSelected = viewModel.selectedModelID == model.id
        return singleLineModelCard(for: row, availableWidth: availableWidth)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.38) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    viewModel.selectedModelID = model.id
                }
        )
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            moveDroppedModel(providers, before: model)
        }
        .accessibilityIdentifier("integrated-model-row-\(model.id)")
    }

    private func singleLineModelCard(for row: ModelTableRow, availableWidth: CGFloat) -> some View {
        let showsFullMetadata = availableWidth >= 840
        let showsMediumMetadata = availableWidth >= 640
        let showsStatusAction = availableWidth >= 380

        return HStack(alignment: .center, spacing: 12) {
            modelCardTitle(for: row)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0.7)

            if showsFullMetadata || showsMediumMetadata {
                compactValueText(row.sizeText)
                    .frame(width: 72, alignment: .leading)
            }

            if showsStatusAction {
                lightweightStatusActionButton(for: row)
                    .frame(width: 88)
            }

            if showsFullMetadata {
                endpointValueText(host: "127.0.0.1", port: row.model.serverPort)
                    .frame(width: 132, alignment: .leading)
            }

            if showsFullMetadata || showsMediumMetadata {
                compactValueText(row.memoryText)
                    .frame(width: 78, alignment: .leading)
            }

            modelActionsMenu(for: row.model)
                .frame(width: 42)
        }
        .frame(minHeight: 40)
    }

    private func modelCardTitle(for row: ModelTableRow) -> some View {
        let model = row.model
        return HStack(alignment: .top, spacing: 8) {
            modelStatusIndicator(for: row)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(model.displayName)
                        .font(.callout.weight(.regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if row.isRecentlyAdded {
                        Image(systemName: "sparkle.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .help(t("Recently added", "最近追加"))
                    }
                }
                Text(model.notes.isEmpty ? model.family : model.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func modelStatusIndicator(for row: ModelTableRow) -> some View {
        Circle()
            .fill(modelStatusIndicatorColor(for: row))
            .frame(width: 8, height: 8)
            .accessibilityLabel(row.normalStatusText)
    }

    private func modelStatusIndicator(for model: ModelConfig) -> some View {
        Circle()
            .fill(modelStatusIndicatorColor(for: model))
            .frame(width: 8, height: 8)
            .accessibilityLabel(viewModel.integratedStatusText(for: model))
    }

    private func modelStatusIndicatorColor(for row: ModelTableRow) -> Color {
        if row.isTransitioning {
            return .orange
        }
        if row.model.id == viewModel.runningModelID {
            return .green
        }
        if row.isPortBusy {
            return .red
        }
        if row.canUseStatusAction {
            return .blue
        }
        return .secondary.opacity(0.55)
    }

    private func modelStatusIndicatorColor(for model: ModelConfig) -> Color {
        let isTransitioning = viewModel.isModelTransitioning(model)
        if isTransitioning {
            return .orange
        }
        if model.id == viewModel.runningModelID {
            return .green
        }
        if viewModel.isModelPortBusy(for: model) {
            return .red
        }
        if viewModel.canUseStatusAction(for: model) {
            return .blue
        }
        return .secondary.opacity(0.55)
    }

    private func modelActionsMenu(for model: ModelConfig) -> some View {
        Menu {
            Button {
                viewModel.editProfileRequested(for: model)
            } label: {
                Label(t("Settings", "設定"), systemImage: "gearshape")
            }
            .disabled(viewModel.isManagedProcessRunning)

            Button {
                viewModel.copyModelID(for: model)
            } label: {
                Label(t("Copy Model Path", "モデルパスをコピー"), systemImage: "doc.on.doc")
            }

            Button {
                viewModel.copyLaunchCommandPreview(for: model)
            } label: {
                Label(t("Copy Launch Command", "起動コマンドをコピー"), systemImage: "terminal")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteProfileRequested(for: model)
            } label: {
                Label(t("Delete", "削除"), systemImage: "trash")
            }
            .disabled(viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help(t("Model actions", "モデル操作"))
        .accessibilityLabel(t("Model actions", "モデル操作"))
    }

    private func compactValueText(_ value: String) -> some View {
        let components = value.split(separator: " ", maxSplits: 1).map(String.init)
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(components.first ?? value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            if components.count > 1 {
                Text(components[1])
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func endpointValueText(host: String, port: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(host):")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(String(port))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lightweightStatusActionButton(for row: ModelTableRow) -> some View {
        let model = row.model
        let isInteractive = !row.isTransitioning && row.canUseStatusAction
        let isHovered = hoveredStatusModelID == model.id
        let statusText = isHovered ? row.hoveredStatusText : row.normalStatusText

        return Button {
            guard isInteractive else { return }
            viewModel.statusActionRequested(for: model)
        } label: {
            Text(statusText)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .foregroundStyle(row.isLoaded || row.isPortBusy ? .white : .accentColor)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            row.isLoaded
                            ? Color.green
                            : (row.isPortBusy
                               ? Color.red
                               : (row.isTransitioning ? Color.orange.opacity(0.18) : Color.accentColor.opacity(isHovered ? 0.18 : 0.10)))
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredStatusModelID = isHovering ? model.id : (hoveredStatusModelID == model.id ? nil : hoveredStatusModelID)
        }
    }

    private func lightweightStatusActionButton(for model: ModelConfig) -> some View {
        let isTransitioning = viewModel.isModelTransitioning(model)
        let canUseAction = viewModel.canUseStatusAction(for: model)
        let isInteractive = !isTransitioning && canUseAction
        let isLoaded = viewModel.isModelLoaded(model)
        let isPortBusy = viewModel.isModelPortBusy(for: model)
        let isHovered = hoveredStatusModelID == model.id
        let statusText = viewModel.interactiveStatusText(for: model, isHovered: isHovered, isPortBusy: isPortBusy)

        return Button {
            guard isInteractive else { return }
            viewModel.statusActionRequested(for: model)
        } label: {
            Text(statusText)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .foregroundStyle(isLoaded || isPortBusy ? .white : .accentColor)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isLoaded
                            ? Color.green
                            : (isPortBusy
                               ? Color.red
                               : (isTransitioning ? Color.orange.opacity(0.18) : Color.accentColor.opacity(isHovered ? 0.18 : 0.10)))
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredStatusModelID = isHovering ? model.id : (hoveredStatusModelID == model.id ? nil : hoveredStatusModelID)
        }
    }

    private func toggleModelTableSort(_ column: ModelTableSortColumn) {
        let nextDirection: SortOrder = modelTableSortColumn == column && modelTableSortDirection == .forward
            ? .reverse
            : .forward
        modelTableSortColumn = column
        modelTableSortDirection = nextDirection
        modelTableSortOrder = [column.comparator(order: nextDirection)]
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

    private var modelInspectorPanel: some View {
        Group {
            if let model = selectedModel {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 12) {
                            modelInspectorHeader(for: model)
                            modelInspectorOverview(for: model)
                            modelInspectorClientSetup(for: model)
                            modelInspectorHermesAgent(for: model)
                            modelInspectorCommandPreview(for: model)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        .padding(.bottom, 12)
                    }
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .contentMargins(.bottom, 0, for: .scrollContent)
                }
            } else {
                ScrollView(.vertical) {
                    ContentUnavailableView {
                        Label(t("No model selected", "モデル未選択"), systemImage: "sidebar.trailing")
                    } description: {
                        Text(t("Select a model to inspect its details.", "詳細を表示するモデルを選択してください。"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .padding(.horizontal, 12)
                }
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.bottom, 0, for: .scrollContent)
            }
        }
        .background(Color.clear)
        .overlay(alignment: .top) {
            inspectorCopyToastView
        }
        .accessibilityIdentifier("integrated-model-inspector")
    }

    private func modelInspectorHeader(for model: ModelConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                modelStatusIndicator(for: model)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Text(modelInspectorHeaderSubtitle(for: model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                Button {
                    viewModel.editProfileRequested(for: model)
                } label: {
                    Label(t("Model Settings", "モデル設定"), systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                        .frame(width: 26, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isManagedProcessRunning)
                .help(t("Model Settings", "モデル設定"))
            }

            lightweightStatusActionButton(for: model)
                .frame(width: 96, alignment: .leading)
        }
        .padding(12)
        .background(inspectorCardBackground)
    }

    private func modelInspectorHeaderSubtitle(for model: ModelConfig) -> String {
        let trimmedNotes = model.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            return trimmedNotes
        }
        return ModelAvailabilityPathFormatter.compact(path: model.modelID)
    }

    private func modelInspectorOverview(for model: ModelConfig) -> some View {
        let isPortBusy = viewModel.isModelPortBusy(for: model)
        let memoryText = viewModel.integratedMemoryText(for: model)

        return inspectorSection(title: t("Overview", "概要")) {
            LazyVGrid(columns: inspectorOverviewColumns, alignment: .leading, spacing: 10) {
                inspectorInfoRow(title: t("Size", "サイズ"), value: viewModel.modelSizeText(for: model))
                inspectorInfoRow(
                    title: t("Port Status", "ポート状態"),
                    value: viewModel.integratedPortStatusText(for: model),
                    valueColor: isPortBusy ? .red : .primary,
                    valueWeight: isPortBusy ? .semibold : .regular
                )
                inspectorInfoRow(title: t("Endpoint", "接続先"), value: "\(model.host):\(model.serverPort)")
                inspectorInfoRow(
                    title: t("Reasoning Mode", "推論モード"),
                    value: model.enableThinking ? t("Enabled", "有効") : t("Disabled", "無効")
                )
                if memoryText != "-" {
                    inspectorInfoRow(title: t("Memory", "メモリ"), value: memoryText)
                }
                if model.id == viewModel.runningModelID {
                    let uptimeText = viewModel.integratedUptimeText
                    if uptimeText != "-" {
                        inspectorInfoRow(title: t("Uptime", "稼働時間"), value: uptimeText)
                    }
                }
            }
        }
    }

    private var inspectorOverviewColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .leading),
            GridItem(.flexible(minimum: 0), spacing: 0, alignment: .leading)
        ]
    }

    private func modelInspectorClientSetup(for model: ModelConfig) -> some View {
        inspectorSection(title: t("Client Setup", "クライアント設定")) {
            inspectorCopyRow(title: t("Base URL", "Base URL"), value: "http://\(model.host):\(model.serverPort)/v1") {
                viewModel.copyBaseURL(for: model)
            }
            inspectorCopyRow(title: t("Model Path", "モデルパス"), value: model.modelID) {
                viewModel.copyModelID(for: model)
            }
            inspectorInfoRow(title: t("API Key", "API Key"), value: t("not required", "不要"))
        }
    }

    private func modelInspectorHermesAgent(for model: ModelConfig) -> some View {
        inspectorSection(title: "Hermes Agent") {
            VStack(alignment: .leading, spacing: 10) {
                hermesAgentConnectionSummary

                Divider()
                    .opacity(0.55)

                hermesAgentActionArea

                Label(
                    t("A backup is created before writing. Restart Hermes Agent if it is already running.", "書き込み前にバックアップを作成します。Hermes Agentが起動中の場合は再起動してください。"),
                    systemImage: "info.circle"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hermesAgentConnectionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            hermesAgentValueRow(
                title: t("Config File", "設定ファイル"),
                value: ModelAvailabilityPathFormatter.compact(path: viewModel.hermesAgentConfigPathText)
            )
            hermesAgentValueRow(
                title: t("Target Model", "反映先モデル"),
                value: ModelAvailabilityPathFormatter.compact(path: viewModel.hermesAgentTargetModelText)
            )
            hermesAgentValueRow(
                title: "Base URL",
                value: viewModel.hermesAgentTargetBaseURLText
            )

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, 1)
                Text(viewModel.hermesAgentConfigMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.16), lineWidth: 1)
        )
    }

    private func hermesAgentValueRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hermesAgentActionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.applyHermesAgentConfigRequested()
            } label: {
                Label(t("Update Hermes Config", "Hermes設定を更新"), systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!viewModel.canApplyHermesAgentConfig)

            HStack(spacing: 8) {
                Button {
                    viewModel.chooseHermesAgentConfigRequested()
                } label: {
                    Label(t("Choose", "選択"), systemImage: "doc.badge.gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    viewModel.openHermesAgentConfigRequested()
                } label: {
                    Label(t("Open", "開く"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    viewModel.restoreHermesAgentConfigBackupRequested()
                } label: {
                    Label(t("Restore", "復元"), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func modelInspectorCommandPreview(for model: ModelConfig) -> some View {
        let command = LaunchCommandBuilder.command(executablePath: viewModel.settings.mlxServerExecutablePath, model: model)
        return inspectorSection(title: t("Launch Command", "起動コマンド")) {
            Button {
                viewModel.copyLaunchCommandPreview(for: model)
                showInspectorCopyToast(title: t("Launch Command", "起動コマンド"))
            } label: {
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
            )
            .help(t("Click to copy", "クリックでコピー"))
        }
    }

    private func inspectorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(12)
        .background(inspectorCardBackground)
    }

    private var inspectorCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            )
    }

    private func inspectorInfoRow(
        title: String,
        value: String,
        valueColor: Color = .primary,
        valueWeight: Font.Weight = .regular
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(valueWeight))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inspectorCopyRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            showInspectorCopyToast(title: title)
        } label: {
            inspectorInfoRow(title: title, value: value)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
        )
        .help(t("Click to copy", "クリックでコピー"))
    }

    @ViewBuilder
    private var inspectorCopyToastView: some View {
        if let inspectorCopyToast {
            Text(inspectorCopyToast)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                        .shadow(radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                )
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
        }
    }

    private func showInspectorCopyToast(title: String) {
        let message = t("Copied \(title)", "\(title)をコピーしました")
        withAnimation(.easeInOut(duration: 0.16)) {
            inspectorCopyToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard inspectorCopyToast == message else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                inspectorCopyToast = nil
            }
        }
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
                viewModel.moveModelToEnd(withID: draggedModelID)
            }
        }
        return true
    }

    private func bottomOperationsPanel(availableWidth: CGFloat) -> some View {
        Group {
            if availableWidth < 980 {
                VStack(spacing: 0) {
                    logPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    testChatPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                HStack(spacing: 0) {
                    testChatPanel
                        .frame(minWidth: 0, maxWidth: .infinity)
                    Divider()
                    logPanel
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
            }
        }
        .frame(width: availableWidth, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .layoutPriority(-1)
        .clipped()
        .accessibilityIdentifier("integrated-bottom-operations-panel")
    }

    private var testChatPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t("Test Chat", "テストチャット"))
                    .font(.title3)
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
            .frame(height: 42)

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
                        .font(.caption)
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
                .font(.caption)
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
                .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(strings.text(.logs))
                    .font(.title3)
                    .foregroundStyle(.primary)
                Spacer()
                Picker(t("Category", "カテゴリ"), selection: $viewModel.logCategoryFilter) {
                    ForEach(viewModel.logCategoryFilterOptions, id: \.self) { category in
                        Text(viewModel.logCategoryFilterLabel(category)).tag(category)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 88, idealWidth: 112, maxWidth: 130)
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
            .controlSize(.small)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .clipped()

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
                            LogEntryRow(entry: entry)
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

}

private struct InspectorVisualEffectBackground: NSViewRepresentable {
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

private struct ModelTableRow: Identifiable {
    let model: ModelConfig
    let sizeText: String
    let memoryText: String
    let normalStatusText: String
    let hoveredStatusText: String
    let isTransitioning: Bool
    let isLoaded: Bool
    let isPortBusy: Bool
    let canUseStatusAction: Bool
    let isRecentlyAdded: Bool
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
