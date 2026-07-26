import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IntegratedWorkspaceView: View {
    static let baseMinimumHeight = Layout.windowMinimumHeight

    @ObservedObject var viewModel: AppViewModel
    @State var selectedDestination: IntegratedWorkspaceDestination = .models
    @State private var isBottomPanelVisible = true
    @State private var isBottomPanelAutoHidden = false
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
    @State private var hermesActionPhase: KineticActionPhase = .idle
    @State private var benchmarkCompletionPhase: KineticActionPhase = .idle
    @State private var readinessCompletionPhase: KineticActionPhase = .idle
    @State private var hermesFeedbackGeneration = 0
    @State private var benchmarkFeedbackGeneration = 0
    @State private var readinessFeedbackGeneration = 0
    @State private var isBenchmarkComparisonPresented = false

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel.map(viewModel.isModelRunning) ?? false }
    private func sortedModelRows(from rows: [ModelListRowState]) -> [ModelListRowState] {
        guard let column = modelTableSortColumn else {
            return rows
        }
        return rows.sorted {
            column.isOrderedBefore($0, $1, order: modelTableSortDirection)
        }
    }

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var benchmarkActionPhase: KineticActionPhase {
        viewModel.isSpeedTestRunning ? .working : benchmarkCompletionPhase
    }

    private var readinessActionPhase: KineticActionPhase {
        viewModel.isAgenticBenchmarkRunning ? .working : readinessCompletionPhase
    }

    private func applyHermesAgentConfigWithFeedback() {
        hermesFeedbackGeneration += 1
        let generation = hermesFeedbackGeneration
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            hermesActionPhase = .working
        }

        DispatchQueue.main.async {
            let succeeded = viewModel.applyHermesAgentConfigRequested()
            guard generation == hermesFeedbackGeneration else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                hermesActionPhase = succeeded ? .success : .failure
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                guard generation == hermesFeedbackGeneration else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    hermesActionPhase = .idle
                }
            }
        }
    }

    private func runBenchmarkWithFeedback() {
        benchmarkFeedbackGeneration += 1
        benchmarkCompletionPhase = .idle
        viewModel.runSpeedTestRequested()
    }

    private func runReadinessWithFeedback() {
        readinessFeedbackGeneration += 1
        readinessCompletionPhase = .idle
        viewModel.runAgenticBenchmarkRequested()
    }

    private func handleBenchmarkRunningChange(wasRunning: Bool, isRunning: Bool) {
        guard wasRunning, !isRunning else { return }
        let phase: KineticActionPhase = viewModel.latestBenchmarkResult?.phase == .success ? .success : .failure
        showBenchmarkFeedback(phase)
    }

    private func handleReadinessRunningChange(wasRunning: Bool, isRunning: Bool) {
        guard wasRunning, !isRunning else { return }
        let phase: KineticActionPhase = viewModel.latestAgenticBenchmarkResult?.phase == .success ? .success : .failure
        showReadinessFeedback(phase)
    }

    private func showBenchmarkFeedback(_ phase: KineticActionPhase) {
        benchmarkFeedbackGeneration += 1
        let generation = benchmarkFeedbackGeneration
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            benchmarkCompletionPhase = phase
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard generation == benchmarkFeedbackGeneration else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                benchmarkCompletionPhase = .idle
            }
        }
    }

    private func showReadinessFeedback(_ phase: KineticActionPhase) {
        readinessFeedbackGeneration += 1
        let generation = readinessFeedbackGeneration
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            readinessCompletionPhase = phase
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard generation == readinessFeedbackGeneration else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                readinessCompletionPhase = .idle
            }
        }
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
        case .degraded, .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
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
        case .degraded, .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
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

        func isOrderedBefore(
            _ lhs: ModelListRowState,
            _ rhs: ModelListRowState,
            order: SortOrder
        ) -> Bool {
            switch self {
            case .name:
                ordered(lhs.nameSortValue, before: rhs.nameSortValue, order: order)
            case .size:
                ordered(lhs.sizeSortValue, before: rhs.sizeSortValue, order: order)
            case .status:
                ordered(lhs.statusSortValue, before: rhs.statusSortValue, order: order)
            case .endpoint:
                ordered(lhs.endpointSortValue, before: rhs.endpointSortValue, order: order)
            case .memory:
                ordered(lhs.memorySortValue, before: rhs.memorySortValue, order: order)
            case .autoUnload:
                ordered(lhs.autoUnloadSortValue, before: rhs.autoUnloadSortValue, order: order)
            case .reasoning:
                ordered(lhs.reasoningSortValue, before: rhs.reasoningSortValue, order: order)
            }
        }

        private func ordered<Value: Comparable>(
            _ lhs: Value,
            before rhs: Value,
            order: SortOrder
        ) -> Bool {
            order == .forward ? lhs < rhs : lhs > rhs
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
        .onChange(of: viewModel.isSpeedTestRunning) { wasRunning, isRunning in
            handleBenchmarkRunningChange(wasRunning: wasRunning, isRunning: isRunning)
        }
        .onChange(of: viewModel.isAgenticBenchmarkRunning) { wasRunning, isRunning in
            handleReadinessRunningChange(wasRunning: wasRunning, isRunning: isRunning)
        }
        .sheet(isPresented: $isBenchmarkComparisonPresented) {
            BenchmarkComparisonView(
                viewModel: viewModel,
                isPresented: $isBenchmarkComparisonPresented
            )
        }
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

            if viewModel.shouldShowRuntimeMemoryHeadroomWarning {
                runtimeMemoryHeadroomWarning
            }

            VStack(alignment: .leading, spacing: 12) {
                memoryLegendRow(
                    color: .blue,
                    label: t("Managed", "管理中"),
                    value: viewModel.memoryMLXProcessText
                )
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

    private var runtimeMemoryHeadroomWarning: some View {
        let assessment = viewModel.runtimeMemoryHeadroomAssessment
        return VStack(alignment: .leading, spacing: 4) {
            Label(
                assessment.title(language: viewModel.settings.uiLanguage),
                systemImage: AppSymbol.warning
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(assessment.level == .critical ? .red : .orange)

            Text(assessment.detail(language: viewModel.settings.uiLanguage))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionText = viewModel.runtimeMemoryProtectionActionText {
                Text(actionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 22)
        .accessibilityElement(children: .combine)
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
        case .workspace:
            WorkspaceSurfaceView(viewModel: viewModel) { _ in
                selectedDestination = .models
            }
        case .profiles:
            ProfileLibrarySurfaceView(viewModel: viewModel)
        case .diagnostics:
            DiagnosticsSurfaceView(
                viewModel: viewModel,
                onOpenSettings: { selectedDestination = .settings },
                onOpenDashboard: { selectedDestination = .models }
            )
        case .automation:
            AutomationSurfaceView(
                viewModel: viewModel,
                onOpenDiagnostics: { selectedDestination = .diagnostics },
                onOpenSettings: { selectedDestination = .settings }
            )
        case .agents:
            MultiAgentHubView(
                viewModel: viewModel,
                onOpenWorkspace: { selectedDestination = .workspace },
                onOpenSettings: { selectedDestination = .settings }
            )
        case .intelligence:
            IntelligenceCenterView(viewModel: viewModel) { destination in
                switch destination {
                case .dashboard: selectedDestination = .models
                case .profiles: selectedDestination = .profiles
                case .diagnostics: selectedDestination = .diagnostics
                case .automation: selectedDestination = .automation
                case .agents: selectedDestination = .agents
                case .workspace: selectedDestination = .workspace
                case .settings: selectedDestination = .settings
                case .logs: selectedDestination = .logs
                }
            }
        case .platform:
            PlatformIntegrationView(viewModel: viewModel) { selectedDestination = $0 }
        case .downloads:
            DownloadsSurfaceView(viewModel: viewModel, onOpenModels: { selectedDestination = .models })
        case .settings:
            SettingsSurfaceView(viewModel: viewModel)
        case .logs:
            LogsSurfaceView(
                entries: viewModel.visibleLogEntries,
                operationalEvents: viewModel.visibleOperationalHistoryEvents,
                operationalHistoryCategories: viewModel.operationalHistoryCategories,
                operationalHistoryCategoryFilter: $viewModel.operationalHistoryCategoryFilter,
                operationalHistorySeverityFilter: $viewModel.operationalHistorySeverityFilter,
                targetSummary: viewModel.connectionTargetSummary,
                runningModelText: viewModel.runningModelText,
                language: viewModel.settings.uiLanguage,
                onCopyOperationalHistory: viewModel.copyOperationalHistoryRequested,
                onClearOperationalHistory: viewModel.clearOperationalHistoryRequested,
                onCopy: viewModel.copyLogsRequested,
                onClear: viewModel.clearLogsRequested
            )
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            let rows = sortedModelRows(from: viewModel.modelListRowStates(from: viewModel.visibleModels))
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

    private func modelTable(rows: [ModelListRowState], availableWidth: CGFloat, allowsWidthAnimation: Bool = false) -> some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 10) {
                DashboardOverviewView(
                    viewModel: viewModel,
                    rows: rows,
                    onOpenProfiles: { selectedDestination = .profiles },
                    onOpenDiagnostics: { selectedDestination = .diagnostics },
                    onOpenSettings: { selectedDestination = .settings },
                    onOpenLogs: { selectedDestination = .logs }
                )
                .frame(width: max(0, availableWidth - 28), alignment: .leading)

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

                Color.clear
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .onDrop(of: [.plainText], isTargeted: nil) { providers in
                        moveDroppedModelToEnd(providers)
                    }
                    .accessibilityHidden(true)
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

    private func lightweightModelRow(for row: ModelListRowState, availableWidth: CGFloat) -> some View {
        let model = row.model
        let isSelected = viewModel.selectedModelID == model.id
        let card = singleLineModelCard(for: row, availableWidth: availableWidth)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.58) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
            .kineticBorderBeam(
                isActive: row.isTransitioning,
                palette: row.isDegraded ? .danger : .warning,
                cornerRadius: 12,
                duration: 1.9,
                strength: 0.88
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(row.isTransitioning ? 0.95 : 0.78))
                        .frame(width: 3)
                        .padding(.vertical, 9)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        return Group {
            if modelTableSortColumn == nil {
                card
                    .onDrag {
                        viewModel.selectedModelID = model.id
                        return NSItemProvider(object: model.id as NSString)
                    }
                    .onDrop(of: [.plainText], isTargeted: nil) { providers in
                        moveDroppedModel(providers, before: model)
                    }
            } else {
                card
            }
        }
        .onTapGesture {
            viewModel.selectedModelID = model.id
        }
        .accessibilityValue(isSelected ? t("Selected", "選択中") : t("Not selected", "未選択"))
        .accessibilityAction(named: Text(t("Select model", "モデルを選択"))) {
            viewModel.selectedModelID = model.id
        }
        .accessibilityHint(modelTableSortColumn == nil
            ? t("Drag to reorder this model profile.", "ドラッグしてモデルプロファイルの順番を変更します。")
            : t("Clear sorting before reordering model profiles.", "モデルプロファイルを並べ替えるにはソートを解除します。"))
        .accessibilityIdentifier("integrated-model-row-\(model.id)")
    }

    private func singleLineModelCard(for row: ModelListRowState, availableWidth: CGFloat) -> some View {
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
                endpointValueText(host: row.model.host, port: row.model.serverPort)
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

    private func modelCardTitle(for row: ModelListRowState) -> some View {
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

    private func modelStatusIndicator(for row: ModelListRowState) -> some View {
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

    private func modelStatusIndicatorColor(for row: ModelListRowState) -> Color {
        if row.isTransitioning {
            return .orange
        }
        if row.isDegraded {
            return .red
        }
        if row.isLoaded {
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
        if viewModel.isModelDegraded(model) {
            return .red
        }
        if viewModel.isModelLoaded(model) {
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
            .disabled(!viewModel.canEditProfile(model))

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

            Button {
                modelTableSortColumn = nil
                viewModel.moveModelUp(withID: model.id)
            } label: {
                Label(t("Move Up", "上へ移動"), systemImage: "arrow.up")
            }
            .disabled(!viewModel.canMoveModelUp(withID: model.id))

            Button {
                modelTableSortColumn = nil
                viewModel.moveModelDown(withID: model.id)
            } label: {
                Label(t("Move Down", "下へ移動"), systemImage: "arrow.down")
            }
            .disabled(!viewModel.canMoveModelDown(withID: model.id))

            Divider()

            Button(role: .destructive) {
                viewModel.deleteProfileRequested(for: model)
            } label: {
                Label(t("Delete", "削除"), systemImage: "trash")
            }
            .disabled(!viewModel.canDeleteProfile(model))
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

    private func lightweightStatusActionButton(for row: ModelListRowState) -> some View {
        let model = row.model
        let isInteractive = !row.isTransitioning && row.canUseStatusAction
        let isHovered = hoveredStatusModelID == model.id
        let statusText = isHovered ? row.hoveredStatusText : row.normalStatusText
        let foregroundColor: Color = row.isLoaded || row.isDegraded || row.isPortBusy
            ? .white
            : (row.isTransitioning ? .orange : .accentColor)
        let backgroundColor: Color = row.isDegraded
            ? .red
            : (row.isLoaded
            ? .green
            : (row.isPortBusy
               ? .red
               : (row.isTransitioning ? Color.orange.opacity(0.18) : Color.accentColor.opacity(isHovered ? 0.18 : 0.10))))
        let systemImage = row.isDegraded
            ? "exclamationmark.triangle.fill"
            : (row.isLoaded
            ? (isHovered ? "stop.fill" : "checkmark")
            : (row.isPortBusy ? "exclamationmark" : (isHovered ? "play.fill" : "power")))

        return Button {
            guard isInteractive else { return }
            viewModel.statusActionRequested(for: model)
        } label: {
            KineticStatusPillLabel(
                title: statusText,
                systemImage: systemImage,
                isBusy: row.isTransitioning,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor,
                borderColor: foregroundColor.opacity(row.isLoaded || row.isDegraded || row.isPortBusy ? 0.20 : 0.28)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .help(row.hoveredStatusText)
        .accessibilityLabel(row.hoveredStatusText)
        .onHover { isHovering in
            hoveredStatusModelID = isHovering ? model.id : (hoveredStatusModelID == model.id ? nil : hoveredStatusModelID)
        }
    }

    private func lightweightStatusActionButton(for model: ModelConfig) -> some View {
        let isTransitioning = viewModel.isModelTransitioning(model)
        let canUseAction = viewModel.canUseStatusAction(for: model)
        let isInteractive = !isTransitioning && canUseAction
        let isLoaded = viewModel.isModelLoaded(model)
        let isDegraded = viewModel.isModelDegraded(model)
        let isPortBusy = viewModel.isModelPortBusy(for: model)
        let isHovered = hoveredStatusModelID == model.id
        let statusText = viewModel.interactiveStatusText(for: model, isHovered: isHovered, isPortBusy: isPortBusy)
        let foregroundColor: Color = isLoaded || isDegraded || isPortBusy
            ? .white
            : (isTransitioning ? .orange : .accentColor)
        let backgroundColor: Color = isDegraded
            ? .red
            : (isLoaded
            ? .green
            : (isPortBusy
               ? .red
               : (isTransitioning ? Color.orange.opacity(0.18) : Color.accentColor.opacity(isHovered ? 0.18 : 0.10))))
        let systemImage = isDegraded
            ? "exclamationmark.triangle.fill"
            : (isLoaded
            ? (isHovered ? "stop.fill" : "checkmark")
            : (isPortBusy ? "exclamationmark" : (isHovered ? "play.fill" : "power")))

        return Button {
            guard isInteractive else { return }
            viewModel.statusActionRequested(for: model)
        } label: {
            KineticStatusPillLabel(
                title: statusText,
                systemImage: systemImage,
                isBusy: isTransitioning,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor,
                borderColor: foregroundColor.opacity(isLoaded || isDegraded || isPortBusy ? 0.20 : 0.28)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .help(viewModel.interactiveStatusText(for: model, isHovered: true, isPortBusy: isPortBusy))
        .accessibilityLabel(viewModel.interactiveStatusText(for: model, isHovered: true, isPortBusy: isPortBusy))
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
                            modelInspectorBenchmark(for: model)
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
                .disabled(!viewModel.canEditProfile(model))
                .help(t("Model Settings", "モデル設定"))
            }

            lightweightStatusActionButton(for: model)
                .frame(width: 96, alignment: .leading)
        }
        .padding(12)
        .background(inspectorCardBackground)
        .kineticBorderBeam(
            isActive: viewModel.isModelTransitioning(model),
            palette: viewModel.isModelDegraded(model) ? .danger : .warning,
            cornerRadius: 12,
            duration: 2.1,
            strength: 0.76
        )
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
                    title: t("Backend", "バックエンド"),
                    value: model.resolvedBackend.localizedTitle(language: viewModel.settings.uiLanguage)
                )
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
                if viewModel.isModelRunning(model) {
                    let uptimeText = viewModel.integratedUptimeText(for: model)
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
            hermesAgentValueRow(
                title: t("Configured Model", "設定済みモデル"),
                value: ModelAvailabilityPathFormatter.compact(path: viewModel.hermesAgentConfiguredModelText)
            )
            hermesAgentValueRow(
                title: t("Configured Base URL", "設定済みBase URL"),
                value: viewModel.hermesAgentConfiguredBaseURLText
            )
            hermesAgentValueRow(
                title: t("Backup Count", "バックアップ数"),
                value: viewModel.hermesAgentBackupCountText
            )
            hermesAgentValueRow(
                title: t("Latest Backup", "最新バックアップ"),
                value: viewModel.hermesAgentLatestBackupText
            )
            if !viewModel.hermesAgentConfigBackups.isEmpty {
                Picker(t("Restore Target", "復元対象"), selection: $viewModel.selectedHermesAgentBackupID) {
                    ForEach(viewModel.hermesAgentConfigBackups) { backup in
                        Text(backup.modifiedAt.formatted(date: .abbreviated, time: .standard))
                            .tag(Optional(backup.id))
                    }
                }
                .pickerStyle(.menu)
                hermesAgentValueRow(
                    title: t("Backup Preview", "バックアップ内容"),
                    value: viewModel.selectedHermesAgentBackupSummaryText
                )
            }
            hermesAgentValueRow(
                title: t("Hermes Sync", "Hermes同期状態"),
                value: viewModel.hermesAgentUnifiedStatusText
            )
            hermesAgentValueRow(
                title: t("Model Change", "モデル変更"),
                value: viewModel.hermesAgentModelChangePreviewText
            )
            hermesAgentValueRow(
                title: t("Base URL Change", "Base URL変更"),
                value: viewModel.hermesAgentBaseURLChangePreviewText
            )
            hermesAgentValueRow(
                title: t("API Key Change", "APIキー変更"),
                value: viewModel.hermesAgentAPIKeyChangePreviewText
            )
            hermesAgentValueRow(
                title: t("Pending Keys", "反映予定キー"),
                value: viewModel.hermesAgentPendingChangesText
            )
            hermesAgentValueRow(
                title: t("YAML Diagnostics", "YAML診断"),
                value: viewModel.hermesAgentDiagnosticsText
            )

            Divider()
            hermesAgentValueRow(
                title: t("Recent Sessions", "最近のセッション"),
                value: "\(viewModel.hermesAgentSessionCountText) · \(viewModel.hermesAgentLatestSessionText)"
            )
            if !viewModel.hermesAgentSessions.isEmpty {
                Picker(t("Session", "セッション"), selection: $viewModel.selectedHermesAgentSessionID) {
                    ForEach(viewModel.hermesAgentSessions) { session in
                        Text(session.title?.isEmpty == false ? session.title! : session.id)
                            .tag(Optional(session.id))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedHermesAgentSessionID) {
                    viewModel.refreshSelectedHermesAgentTranscript()
                }

                if let session = viewModel.selectedHermesAgentSession {
                    hermesAgentValueRow(
                        title: t("Session Source / Model", "起動元・モデル"),
                        value: "\(session.source) · \(session.model ?? "-") · \(Date(timeIntervalSince1970: session.startedAt).formatted(date: .abbreviated, time: .standard))"
                    )
                    hermesAgentValueRow(
                        title: t("Session Details", "セッション詳細"),
                        value: viewModel.selectedHermesAgentSessionDetailsText
                    )
                    hermesAgentValueRow(
                        title: t("Transcript", "トランスクリプト"),
                        value: viewModel.hermesAgentTranscriptSummaryText
                    )
                    TextField(t("Search transcript", "トランスクリプトを検索"), text: $viewModel.hermesAgentTranscriptSearchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.hermesAgentTranscriptSearchText) {
                            viewModel.resetHermesAgentTranscriptDisplayLimit()
                        }

                    Picker(t("Role", "役割"), selection: $viewModel.hermesAgentTranscriptRoleFilter) {
                        Text(t("All roles", "すべての役割")).tag("all")
                        ForEach(viewModel.hermesAgentTranscriptAvailableRoles, id: \.self) { role in
                            Text(role.capitalized).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.hermesAgentTranscriptRoleFilter) {
                        viewModel.resetHermesAgentTranscriptDisplayLimit()
                    }

                    Picker(t("Order", "並び順"), selection: $viewModel.hermesAgentTranscriptNewestFirst) {
                        Text(t("Oldest first", "古い順")).tag(false)
                        Text(t("Newest first", "新しい順")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.hermesAgentTranscriptNewestFirst) {
                        viewModel.resetHermesAgentTranscriptDisplayLimit()
                    }

                    Toggle(t("Show inactive messages", "無効化されたメッセージを表示"), isOn: $viewModel.hermesAgentTranscriptIncludesInactive)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.hermesAgentTranscriptIncludesInactive) {
                            viewModel.resetHermesAgentTranscriptDisplayLimit()
                        }
                    Toggle(t("Show compacted messages", "圧縮済みメッセージを表示"), isOn: $viewModel.hermesAgentTranscriptIncludesCompacted)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.hermesAgentTranscriptIncludesCompacted) {
                            viewModel.resetHermesAgentTranscriptDisplayLimit()
                        }

                    HStack(spacing: 8) {
                        Picker(t("Export format", "書き出し形式"), selection: $viewModel.hermesAgentTranscriptExportFormat) {
                            Text("Markdown").tag(HermesAgentTranscriptExportFormat.markdown)
                            Text(t("Plain text", "プレーンテキスト")).tag(HermesAgentTranscriptExportFormat.plainText)
                        }
                        .pickerStyle(.menu)

                        Button {
                            viewModel.exportHermesAgentTranscriptRequested()
                        } label: {
                            Label(t("Export transcript", "トランスクリプトを書き出し"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.sortedHermesAgentSessionMessages.isEmpty)
                    }

                    if !viewModel.hermesAgentTranscriptExportMessage.isEmpty {
                        Text(viewModel.hermesAgentTranscriptExportMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(viewModel.visibleHermesAgentSessionMessages) { message in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(message.role.uppercased())
                                    .font(.caption2.weight(.bold))
                                Spacer()
                                Text(Date(timeIntervalSince1970: message.timestamp).formatted(date: .omitted, time: .standard))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(viewModel.hermesAgentTranscriptContent(message))
                                .font(.caption)
                                .lineLimit(5)
                                .textSelection(.enabled)
                            HStack(spacing: 8) {
                                if let tokenCount = message.tokenCount {
                                    Text("\(tokenCount) tokens")
                                }
                                if message.active == 0 {
                                    Text(t("Inactive", "無効"))
                                }
                                if message.compacted != 0 {
                                    Text(t("Compacted", "圧縮済み"))
                                }
                                Spacer()
                                Button(t("Details", "詳細")) {
                                    viewModel.selectHermesAgentMessage(message)
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    viewModel.copyHermesAgentMessageContent(message)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help(t("Copy message content", "メッセージ本文をコピー"))
                            }
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            viewModel.selectedHermesAgentMessageID == message.id
                                ? Color.accentColor.opacity(0.10)
                                : Color(nsColor: .textBackgroundColor).opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }

                    if let message = viewModel.selectedHermesAgentMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(t("Message Details", "メッセージ詳細"))
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Button(t("Copy content", "本文をコピー")) {
                                    viewModel.copyHermesAgentMessageContent(message)
                                }
                                .buttonStyle(.bordered)
                                Button(t("Copy all", "全体をコピー")) {
                                    viewModel.copyHermesAgentMessageDetails(message)
                                }
                                .buttonStyle(.bordered)
                            }
                            Text(viewModel.hermesAgentTranscriptMetadata(message))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            ScrollView {
                                Text(viewModel.hermesAgentTranscriptContent(message))
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 240)
                            if let toolCalls = message.toolCalls, !toolCalls.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(t("Tool calls", "ツール呼び出し"))
                                    .font(.caption2.weight(.semibold))
                                Text(toolCalls)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(9)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                        )
                    }

                    if viewModel.canShowMoreHermesAgentTranscript {
                        Button {
                            viewModel.showMoreHermesAgentTranscript()
                        } label: {
                            Label(t("Show 20 more", "さらに20件表示"), systemImage: "chevron.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            Text(viewModel.hermesAgentSessionMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
                applyHermesAgentConfigWithFeedback()
            } label: {
                KineticActionLabel(
                    title: t("Update Hermes Config", "Hermes設定を更新"),
                    workingTitle: t("Updating", "更新中"),
                    successTitle: t("Updated", "更新済み"),
                    failureTitle: t("Failed", "失敗"),
                    systemImage: "arrow.down.doc",
                    phase: hermesActionPhase
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!viewModel.canApplyHermesAgentConfig || hermesActionPhase == .working)

            Button {
                viewModel.refreshHermesAgentSessions()
            } label: {
                Label(t("Load Sessions", "セッションを読込"), systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                viewModel.selectHermesAgentMatchingModelRequested()
            } label: {
                Label(t("Select Profile from Hermes Config", "Hermes設定のプロファイルを選択"), systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!viewModel.canSelectHermesAgentMatchingModel)

            HStack(spacing: 8) {
                Button {
                    viewModel.inspectHermesAgentConfigRequested()
                } label: {
                    Label(t("Check", "確認"), systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

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
                .disabled(viewModel.selectedHermesAgentBackup == nil)
            }
        }
    }

    private func modelInspectorBenchmark(for model: ModelConfig) -> some View {
        inspectorSection(title: t("Benchmark", "ベンチマーク")) {
            VStack(alignment: .leading, spacing: 10) {
                Picker(
                    t("Measurement", "測定モード"),
                    selection: Binding(
                        get: { viewModel.settings.benchmarkPreset },
                        set: { viewModel.setBenchmarkPreset($0) }
                    )
                ) {
                    ForEach(BenchmarkPreset.allCases) { preset in
                        Text(preset.localizedTitle(language: viewModel.settings.uiLanguage))
                            .tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isSpeedTestRunning)
                .help(viewModel.settings.benchmarkPreset.localizedDescription(language: viewModel.settings.uiLanguage))

                Text(viewModel.settings.benchmarkPreset.localizedDescription(language: viewModel.settings.uiLanguage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        runBenchmarkWithFeedback()
                    } label: {
                        KineticActionLabel(
                            title: t("Run Benchmark", "ベンチマーク実行"),
                            workingTitle: t("Running", "実行中"),
                            successTitle: t("Completed", "完了"),
                            failureTitle: t("Failed", "失敗"),
                            systemImage: "speedometer",
                            phase: benchmarkActionPhase
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!viewModel.canRunSpeedTest)
                    .help(viewModel.speedTestDisabledReason)

                    KineticCopyButton(
                        action: {
                            viewModel.copyBenchmark(for: model)
                        }
                    ) {
                        Label(t("Copy", "コピー"), systemImage: AppSymbol.copy)
                            .labelStyle(.iconOnly)
                            .frame(width: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.benchmarkResult(for: model) == nil)
                    .help(t("Copy benchmark for this model", "このモデルのベンチマークをコピー"))

                    Button {
                        isBenchmarkComparisonPresented = true
                    } label: {
                        Label(t("Compare", "比較"), systemImage: "chart.bar.xaxis")
                            .labelStyle(.iconOnly)
                            .frame(width: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.comparableBenchmarkRowCount < 2)
                    .help(t("Compare measured models by use case", "測定済みモデルを用途別に比較"))
                }

                HStack(spacing: 8) {
                    Button {
                        runReadinessWithFeedback()
                    } label: {
                        KineticActionLabel(
                            title: t("Run Readiness", "Readiness実行"),
                            workingTitle: t("Running", "実行中"),
                            successTitle: t("Completed", "完了"),
                            failureTitle: t("Failed", "失敗"),
                            systemImage: "checklist",
                            phase: readinessActionPhase
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!viewModel.canRunAgenticBenchmark)
                    .help(viewModel.agenticBenchmarkDisabledReason)

                    KineticCopyButton(
                        action: {
                            viewModel.copyAgenticBenchmark(for: model)
                        }
                    ) {
                        Label(t("Copy", "コピー"), systemImage: AppSymbol.copy)
                            .labelStyle(.iconOnly)
                            .frame(width: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.agenticBenchmarkResult(for: model) == nil)
                    .help(t("Copy Agent Readiness for this model", "このモデルのAgent Readinessをコピー"))
                }

                if viewModel.isSpeedTestRunning || viewModel.isAgenticBenchmarkRunning {
                    KineticIndeterminateBar()
                        .transition(.opacity)
                }

                if viewModel.isSpeedTestRunning, !viewModel.benchmarkProgressText.isEmpty {
                    Text(viewModel.benchmarkProgressText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.benchmarkSummary(for: model))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let comparisonRow = viewModel.benchmarkComparisonRow(for: model),
                   let exclusionSummary = comparisonRow.localizedExclusionSummary(
                       language: viewModel.settings.uiLanguage
                   ) {
                    Label(
                        t("Re-run needed: \(exclusionSummary)", "再測定が必要: \(exclusionSummary)"),
                        systemImage: "arrow.clockwise.circle"
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let result = viewModel.benchmarkResult(for: model) {
                    if let session = viewModel.benchmarkSession(for: model) {
                        benchmarkAggregateSummary(session)
                    }
                    benchmarkScoreGrid(result)
                    benchmarkMetricSummary(result)
                } else {
                    Text(t("Run Benchmark v1 to score this model for this Mac.", "Benchmark v1を実行すると、このMacでの用途別スコアを表示します。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .opacity(0.45)

                Text(viewModel.agenticBenchmarkSummary(for: model))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let result = viewModel.agenticBenchmarkResult(for: model) {
                    agenticBenchmarkSummary(result)
                } else {
                    Text(t("Agent Readiness is optional. It uses virtual tool tasks and does not require external dependencies.", "Agent Readinessは任意です。仮想ツールタスクを使うため、外部依存は不要です。"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func benchmarkAggregateSummary(_ session: BenchmarkSessionResult) -> some View {
        let aggregate = session.aggregate
        return LazyVGrid(columns: inspectorOverviewColumns, alignment: .leading, spacing: 8) {
            inspectorInfoRow(
                title: t("Successful samples", "成功回数"),
                value: "\(aggregate.successfulSampleCount)/\(aggregate.sampleCount)",
                helpText: t(
                    "Completed samples used to calculate the medians.",
                    "中央値の算出に使えた完了測定の回数です。"
                )
            )
            inspectorInfoRow(
                title: t("Stability", "安定度"),
                value: aggregate.stabilityPercent.map { "\($0)%" }
                    ?? aggregate.stabilityLevel.localizedTitle(language: viewModel.settings.uiLanguage),
                helpText: t(
                    "Consistency of TTFT and output speed across repeated samples. Higher is more stable.",
                    "複数回測定したTTFTと出力速度の一貫性です。高いほど安定しています。"
                )
            )
            inspectorInfoRow(
                title: t("Median TTFT", "TTFT中央値"),
                value: aggregate.medianTTFTMS.map { String(format: "%.0f ms", $0) } ?? "-"
            )
            inspectorInfoRow(
                title: t("Median output", "出力速度中央値"),
                value: aggregate.medianOutputTokensPerSecond.map { String(format: "%.1f tok/s", $0) } ?? "-"
            )
        }
    }

    private func benchmarkScoreGrid(_ result: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.useCaseScores.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("Not scored", "スコア未算出"), systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(result.localizedMessage(language: viewModel.settings.uiLanguage))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(result.useCaseScores, id: \.useCase) { score in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(score.useCase.localizedTitle(language: viewModel.settings.uiLanguage))
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(score.score)/10")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(benchmarkScoreColor(score.score))
                        }
                        if let reason = score.reasons.first {
                            Text(score.localizedReason(reason, language: viewModel.settings.uiLanguage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func benchmarkMetricSummary(_ result: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let speed = result.speedMetrics {
                LazyVGrid(columns: inspectorOverviewColumns, alignment: .leading, spacing: 8) {
                    inspectorInfoRow(
                        title: "TTFT",
                        value: speed.ttftText,
                        helpText: t(
                            "Time To First Token: time until the first generated token arrives. Lower feels more responsive.",
                            "Time To First Token（最初のトークンまでの時間）です。短いほど応答が速く感じます。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Output", "出力速度"),
                        value: speed.outputSpeedText,
                        helpText: t(
                            "Generated tokens per second after output starts. Higher means faster generation.",
                            "出力開始後に1秒あたり生成できたトークン数です。大きいほど生成が速いことを示します。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Latency", "合計時間"),
                        value: speed.totalLatencyText,
                        helpText: t(
                            "Total time from sending the request until the benchmark response completed.",
                            "リクエスト送信からベンチマーク応答が完了するまでの合計時間です。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Tokens", "トークン"),
                        value: speed.outputTokenText,
                        helpText: t(
                            "Number of output tokens generated during the benchmark response.",
                            "ベンチマーク応答で生成された出力トークン数です。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Finish", "終了理由"),
                        value: speed.localizedFinishReasonText(language: viewModel.settings.uiLanguage),
                        helpText: t(
                            "Reason reported by the endpoint when generation stopped, such as stop or length.",
                            "生成停止時にエンドポイントが返した理由です。例: stop、length。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Memory", "メモリ"),
                        value: speed.localizedMemoryText(language: viewModel.settings.uiLanguage),
                        helpText: t(
                            "Managed server memory and available system memory observed during the benchmark.",
                            "ベンチマーク時に観測した管理サーバーのメモリ使用量とシステム空きメモリです。"
                        )
                    )
                }
            }

            if let agent = result.agentReadiness {
                LazyVGrid(columns: inspectorOverviewColumns, alignment: .leading, spacing: 8) {
                    inspectorInfoRow(
                        title: t("Agent JSON", "Agent JSON"),
                        value: agent.jsonValidityText,
                        helpText: t(
                            "How many agent probe responses were valid JSON.",
                            "Agentテストの応答のうち、有効なJSONとして解釈できた件数です。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Instructions", "指示追従"),
                        value: agent.instructionFollowingText,
                        helpText: t(
                            "How often the model followed the benchmark instructions.",
                            "ベンチマーク指示にどれだけ正しく従えたかを示します。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Tool choice", "ツール判断"),
                        value: agent.toolSelectionText,
                        helpText: t(
                            "How often the model selected the expected virtual tool action.",
                            "期待された仮想ツール操作を選べた割合です。"
                        )
                    )
                    inspectorInfoRow(
                        title: t("Timeouts", "タイムアウト"),
                        value: "\(agent.timeoutCount)",
                        helpText: t(
                            "Number of repeated agent probes that timed out.",
                            "繰り返しAgentテスト中にタイムアウトした回数です。"
                        )
                    )
                }
            }

            if let host = result.hostSnapshot {
                let thermalText = host.thermalState.map {
                    " • \(t("Thermal", "熱状態")): \($0.localizedTitle(language: viewModel.settings.uiLanguage))"
                } ?? ""
                Text("\(result.suiteVersion) • \(host.chipName) • \(host.memoryText) • \(host.localizedServerText(language: viewModel.settings.uiLanguage))\(thermalText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
        }
    }

    private func agenticBenchmarkSummary(_ result: AgenticBenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Readiness Score", "Readinessスコア"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(result.scoreText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(result.passedTaskCount == result.taskCount && result.taskCount > 0 ? .green : .orange)
            }
            .contentShape(Rectangle())
            .optionalInspectorHelp(agenticReadinessScoreHelpText)

            ForEach(result.tasks) { task in
                VStack(alignment: .leading, spacing: 3) {
                    let helpText = agenticBenchmarkTaskHelpText(task)
                    HStack {
                        Text(task.localizedTitle(language: viewModel.settings.uiLanguage))
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(task.localizedScoreText(language: viewModel.settings.uiLanguage))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(task.passed ? .green : .red)
                    }
                    .contentShape(Rectangle())
                    .optionalInspectorHelp(helpText)
                    Text(task.localizedNotes(language: viewModel.settings.uiLanguage))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if !task.diagnostics.isEmpty {
                        KineticDisclosureSection(
                            contentTopPadding: 0,
                            label: {
                                Text(t("Diagnostics", "診断"))
                                    .font(.caption2.weight(.semibold))
                            },
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(task.localizedDiagnostics(language: viewModel.settings.uiLanguage)) { diagnostic in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(diagnostic.title)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            Text(diagnostic.text)
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        )
                        .controlSize(.small)
                    }
                }
            }

            Text("\(result.suiteVersion) • \(t("Virtual tools", "仮想ツール"))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var agenticReadinessScoreHelpText: String {
        t(
            "Overall pass count for Docker-free virtual tool tasks. It estimates whether the model can produce stable JSON, follow instructions, handle paths, and plan simple edits for agent workflows.",
            "Docker不要の仮想ツールタスク全体の合格数です。モデルがAgent用途で安定したJSONを返し、指示追従、パス処理、簡単な編集計画を行えるかを見ます。"
        )
    }

    private func agenticBenchmarkTaskHelpText(_ task: AgenticBenchmarkTaskResult) -> String {
        switch task.id {
        case "virtual_file_lookup":
            t(
                "Checks whether the model can plan a small virtual filesystem lookup and return the discovered value as JSON.",
                "仮想ファイルシステムをたどる手順を組み立て、見つけた値をJSONで返せるかを確認します。"
            )
        case "missing_field_honesty":
            t(
                "Checks whether the model admits that a requested field is missing instead of inventing a value.",
                "要求された項目が存在しない時に、値を捏造せず「存在しない」と正直に返せるかを確認します。"
            )
        case "patch_planning":
            t(
                "Checks whether the model can read a virtual config file and propose a targeted patch without changing unrelated settings.",
                "仮想設定ファイルを読み、関係ない設定を変えずに目的の箇所だけを変更するパッチを計画できるかを確認します。"
            )
        case "path_handling":
            t(
                "Checks whether the model can preserve an exact path, including spaces, and extract the requested connection value.",
                "スペースを含むパスを正確に扱い、必要な接続情報を取り出せるかを確認します。"
            )
        case "skill_discovery":
            t(
                "Checks whether the model can discover a virtual instruction file, apply the instruction, and return the decoded result.",
                "仮想の手順ファイルを見つけ、その指示を適用し、変換した結果を返せるかを確認します。"
            )
        default:
            t(
                "Checks one part of agent readiness using a Docker-free virtual tool task.",
                "Docker不要の仮想ツールタスクで、Agent適性の一部を確認します。"
            )
        }
    }

    private func benchmarkScoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10:
            .green
        case 5...7:
            .orange
        default:
            .red
        }
    }

    private func modelInspectorCommandPreview(for model: ModelConfig) -> some View {
        let command = viewModel.launchCommandPreview(for: model)
        return inspectorSection(title: t("Launch Command", "起動コマンド")) {
            KineticCopyButton(
                feedbackStyle: .trailingOverlay,
                action: {
                    viewModel.copyLaunchCommandPreview(for: model)
                }
            ) {
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .padding(.trailing, 18)
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
        valueWeight: Font.Weight = .regular,
        helpText: String? = nil
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
        .contentShape(Rectangle())
        .optionalInspectorHelp(helpText)
    }

    private func inspectorCopyRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        KineticCopyButton(
            feedbackStyle: .trailingOverlay,
            action: action
        ) {
            inspectorInfoRow(title: title, value: value)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .padding(.trailing, 18)
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

    private func moveDroppedModel(_ providers: [NSItemProvider], before targetModel: ModelConfig) -> Bool {
        guard modelTableSortColumn == nil else {
            return false
        }
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }
        let targetModelID = targetModel.id

        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let draggedModelID = value as? String,
                  draggedModelID != targetModelID else {
                return
            }

            Task { @MainActor in
                viewModel.moveModel(withID: draggedModelID, before: targetModelID)
            }
        }
        return true
    }

    private func moveDroppedModelToEnd(_ providers: [NSItemProvider]) -> Bool {
        guard modelTableSortColumn == nil else {
            return false
        }
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let draggedModelID = value as? String else {
                return
            }

            Task { @MainActor in
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
                .stroke(
                    isMiniChatInputFocused ? Color.accentColor.opacity(0.62) : Color.secondary.opacity(0.18),
                    lineWidth: isMiniChatInputFocused ? 1.2 : 1
                )
        )
        .kineticBorderBeam(
            isActive: viewModel.isMiniChatRunning,
            palette: .accent,
            cornerRadius: 18,
            duration: 2.4,
            strength: 0.82
        )
        .animation(.easeInOut(duration: 0.18), value: isMiniChatInputFocused)
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
                        ForEach(viewModel.visibleLogEntries.suffix(16)) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                }
                .padding(14)
            }

            Divider()

            HStack {
                Label(
                    "\(t("Overall status", "全体ステータス")): \(viewModel.runtimeState.localizedTitle(language: viewModel.settings.uiLanguage))",
                    systemImage: overallStatusSymbol
                )
                    .foregroundStyle(overallStatusColor)
                Spacer()
            }
            .font(.caption)
            .padding(10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

}
