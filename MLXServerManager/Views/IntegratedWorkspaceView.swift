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
    @State private var hoveredModelID: ModelConfig.ID?
    @State private var hoveredStatusModelID: ModelConfig.ID?
    @State private var isQuickSettingsPopoverPresented = false
    @State private var expandedRightPanelID: String? = "model"
    @State private var isBottomPanelVisible = true
    @State private var isRightPanelVisible = true
    @State private var isBottomPanelAutoHidden = false
    @State private var isRightPanelAutoHidden = false
    @State private var hostingWindow: NSWindow?
    @FocusState private var focusedAutoUnloadModelID: ModelConfig.ID?

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }

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

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { viewModel.settings.uiLanguage },
            set: { newValue in
                viewModel.settings.uiLanguage = newValue
                viewModel.saveSettingsRequested()
            }
        )
    }

    private var appearanceBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.uiAppearance },
            set: { newValue in
                viewModel.settings.uiAppearance = newValue
                viewModel.saveSettingsRequested()
            }
        )
    }

    private func toggleNavigationSidebarRequested() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }

    private func toggleRightPanelRequested() {
        if isRightPanelVisible {
            isRightPanelAutoHidden = false
            isRightPanelVisible = false
            return
        }

        isRightPanelAutoHidden = false
        expandWindowIfNeeded(rightVisible: true)
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
            let canShowBothSides = size.width >= comfortableWindowWidth(rightVisible: true)
            let canShowBottom = size.height >= Layout.minimumBottomPanelHeight

            if isRightPanelVisible, !canShowBothSides {
                isRightPanelVisible = false
                isRightPanelAutoHidden = true
                return
            }

            if !isRightPanelVisible, isRightPanelAutoHidden, canShowBothSides {
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

    private func expandWindowIfNeeded(rightVisible: Bool) {
        guard let hostingWindow else { return }
        let requiredWidth = requiredWindowWidth(rightVisible: rightVisible)
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

    private func requiredWindowWidth(rightVisible: Bool) -> CGFloat {
        Layout.leftPanelWidthWithDivider
            + compactRequiredModelListWidth
            + (rightVisible ? Layout.rightPanelWidthWithDivider : 0)
    }

    private func comfortableWindowWidth(rightVisible: Bool) -> CGFloat {
        Layout.leftPanelWidthWithDivider
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
        static let leftPanelWidth: CGFloat = 320
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
            NavigationSplitView {
                leftColumn
                    .navigationSplitViewColumnWidth(
                        min: 260,
                        ideal: Layout.leftPanelWidth,
                        max: 360
                    )
            } detail: {
                HStack(spacing: 0) {
                    centerColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .id("center-\(viewModel.settings.uiAppearance)")

                    if isRightPanelVisible {
                        Divider()
                        rightColumn
                            .frame(width: Layout.rightPanelWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .backgroundExtensionEffect()
            }
            .navigationSplitViewStyle(.balanced)
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
        .liquidGlassWindowBackground()
        .containerBackground(Color(nsColor: .windowBackgroundColor), for: .window)
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .preferredColorScheme(preferredColorScheme)
        .accessibilityIdentifier("integrated-workspace")
        .background(WindowReader { window in
            hostingWindow = window
        })
        .toolbar { workspaceToolbar }
        .toolbarBackground(.hidden, for: .windowToolbar)
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                toggleNavigationSidebarRequested()
            } label: {
                Label(t("Toggle sidebar", "サイドバーを切り替え"), systemImage: AppSymbol.leftSidebar)
            }
            .help(t("Toggle sidebar", "サイドバーを切り替え"))
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                toggleBottomPanelRequested()
            } label: {
                Label(t("Toggle bottom panel", "下段パネルを切り替え"), systemImage: AppSymbol.bottomPanel)
            }
            .help(isBottomPanelVisible
                ? t("Hide bottom panel", "下段パネルを隠す")
                : t("Show bottom panel", "下段パネルを表示"))

            Button {
                toggleRightPanelRequested()
            } label: {
                Label(t("Toggle inspector", "インスペクターを切り替え"), systemImage: AppSymbol.rightInspector)
            }
            .help(isRightPanelVisible
                ? t("Hide inspector", "インスペクターを隠す")
                : t("Show inspector", "インスペクターを表示"))

            if selectedDestination == .models {
                Button {
                    viewModel.addProfileRequested()
                } label: {
                    Label(t("Add model", "モデル追加"), systemImage: AppSymbol.add)
                }
                .help(t("Add model", "モデル追加"))
            }
        }
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
            Divider()
                .padding(.horizontal, 14)
            sidebarFooterControls
        }
        .navigationTitle("MLX Server Manager")
    }

    private var systemPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYSTEM")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            systemInfoCard
            systemHealthCard
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(viewModel.systemInfoRows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .leading)
                    Text(row.1)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(t("Memory", "メモリ"), systemImage: "memorychip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.integratedMemoryUsagePercentText)
                    .font(.callout.weight(.semibold))
            }

            memoryBreakdownBar

            VStack(alignment: .leading, spacing: 5) {
                memoryLegendRow(color: .blue, label: "mlx-lm", value: viewModel.memoryMLXProcessText)
                memoryLegendRow(color: .orange, label: t("Other", "その他"), value: viewModel.memoryOtherProcessesText)
                memoryLegendRow(color: .green, label: t("Available", "空き容量"), value: viewModel.memoryAvailableText)
            }

            Divider()

            HStack {
                Label {
                    Text(verbatim: "CPU")
                } icon: {
                    Image(systemName: "cpu")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.integratedCPUUsageText)
                    .font(.callout.weight(.semibold))
            }

            HStack {
                Label(t("Uptime", "起動時間"), systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.integratedUptimeText)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }

        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var sidebarFooterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickSettingsMenu

            VStack(alignment: .leading, spacing: 3) {
                Text("MLX Server Manager")
                    .font(.caption.weight(.semibold))
                Text("Version 24.0.0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickSettingsMenu: some View {
        Button {
            isQuickSettingsPopoverPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(activeAccentColor.opacity(0.10))
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(activeAccentColor)
                }
                .frame(width: 28, height: 28)

                Text(t("Display", "表示"))
                    .font(.callout.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isQuickSettingsPopoverPresented, arrowEdge: .bottom) {
            quickSettingsPopoverContent
                .padding(14)
                .frame(width: 280)
        }
        .accessibilityIdentifier("integrated-sidebar-quick-settings-menu")
    }

    private var quickSettingsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(t("Display options", "表示オプション"), systemImage: "paintpalette")
                .font(.headline)

            Picker(t("Language", "言語"), selection: languageBinding) {
                ForEach(AppLanguage.allCases) { option in
                    Text(languageDisplayName(option)).tag(option)
                }
            }
            .pickerStyle(.menu)

            Picker(t("Theme", "テーマ"), selection: appearanceBinding) {
                Text(t("System", "システム")).tag("system")
                Text(t("Light", "ライト")).tag("light")
                Text(t("Dark", "ダーク")).tag("dark")
            }
            .pickerStyle(.menu)

            Divider()

            Button {
                selectedDestination = .settings
                isQuickSettingsPopoverPresented = false
            } label: {
                Label(t("Advanced settings", "詳細設定"), systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func languageDisplayName(_ option: AppLanguage) -> String {
        switch option {
        case .system:
            return t("System", "システム")
        case .japanese:
            return t("Japanese", "日本語")
        case .english:
            return t("English", "英語")
        }
    }

    private func appearanceDisplayName(_ option: String) -> String {
        switch option {
        case "light": return t("Light", "ライト")
        case "dark": return t("Dark", "ダーク")
        default: return t("System", "システム")
        }
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
                    bottomOperationsPanel
                        .frame(height: 280)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .liquidGlassLayerOne(cornerRadius: 0)
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

    private var workspaceOverviewStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            workspaceRouteCard(
                title: t("Models", "モデル一覧"),
                value: String(viewModel.visibleModels.count),
                detail: viewModel.runningModelText,
                systemImage: AppSymbol.models,
                destination: .models
            )
            workspaceRouteCard(
                title: strings.text(.download),
                value: viewModel.huggingFaceDownloadStatus.phase.localizedTitle(language: viewModel.settings.uiLanguage),
                detail: viewModel.huggingFaceDownloadQueueSummary,
                systemImage: AppSymbol.downloads,
                destination: .downloads
            )
            workspaceRouteCard(
                title: strings.text(.logs),
                value: String(viewModel.logEntries.count),
                detail: t("Lifecycle and diagnostics", "ライフサイクルと診断"),
                systemImage: AppSymbol.logs,
                destination: .logs
            )
            workspaceRouteCard(
                title: strings.text(.settings),
                value: appearanceDisplayName(viewModel.settings.uiAppearance),
                detail: t("Language and theme", "言語とテーマ"),
                systemImage: AppSymbol.settings,
                destination: .settings
            )
        }
        .accessibilityIdentifier("integrated-workspace-overview-strip")
    }

    private func workspaceRouteCard(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        destination: IntegratedWorkspaceDestination
    ) -> some View {
        Button {
            selectedDestination = destination
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                selectedDestination == destination ? activeAccentColor.opacity(0.06) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedDestination == destination ? activeAccentColor.opacity(0.22) : Color.primary.opacity(0.08))
            )
            .liquidGlassLayerTwo(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }

    private var modelEmptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                t("No models are visible", "表示できるモデルがありません"),
                systemImage: "cube.transparent"
            )
                .font(.title3.weight(.semibold))
            Text(
                t(
                    "Add a local model profile or open Downloads to fetch a Hugging Face MLX model.",
                    "ローカルモデルのプロファイルを追加するか、ダウンロード画面でHugging FaceのMLXモデルを取得してください。"
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    viewModel.addProfileRequested()
                } label: {
                    Label(t("Add local model", "ローカルモデルを追加"), systemImage: AppSymbol.add)
                }
                .buttonStyle(.glassProminent)

                Button {
                    selectedDestination = .downloads
                } label: {
                    Label(t("Open Downloads", "ダウンロードを開く"), systemImage: AppSymbol.downloads)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassLayerTwo(cornerRadius: 14)
        .accessibilityIdentifier("integrated-model-empty-state")
    }

    private var modelListPanel: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Text(t("Models", "モデル一覧"))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                modelHeaderRow
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .liquidGlassLayerOne(cornerRadius: 0)

            ScrollView {
                if viewModel.visibleModels.isEmpty {
                    modelEmptyState
                        .padding(18)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.visibleModels) { model in
                            modelRow(model)
                                .onDrop(
                                    of: [.text],
                                    delegate: ModelRowDropDelegate(
                                        targetModel: model,
                                        draggedModelID: $draggedModelID,
                                        viewModel: viewModel
                                    )
                                )
                        }

                        modelListEndDropTarget
                            .onDrop(
                                of: [.text],
                                delegate: ModelRowDropDelegate(
                                    targetModel: nil,
                                    draggedModelID: $draggedModelID,
                                    viewModel: viewModel
                                )
                            )
                    }
                    .padding(14)
                }
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
            columnHeader("\(t("Model / purpose", "モデル名 / 用途"))\(viewModel.sortIndicator(for: "name"))", width: $modelNameColumnWidth, defaultWidth: ModelListColumn.name, sortKey: "name")
            columnHeader("\(t("Size", "サイズ"))\(viewModel.sortIndicator(for: "size"))", width: $sizeColumnWidth, defaultWidth: ModelListColumn.size, sortKey: "size")
            columnHeader("\(t("Status", "ステータス"))\(viewModel.sortIndicator(for: "status"))", width: $statusColumnWidth, defaultWidth: ModelListColumn.status, sortKey: "status")
            columnHeader("\(t("Port / IP address", "ポート/IPアドレス"))\(viewModel.sortIndicator(for: "port"))", width: $portColumnWidth, defaultWidth: ModelListColumn.port, sortKey: "port")
            columnHeader("\(t("Memory", "メモリ使用量"))\(viewModel.sortIndicator(for: "memory"))", width: $memoryColumnWidth, defaultWidth: ModelListColumn.memory, sortKey: "memory")
            columnHeader("\(t("Auto unload", "自動アンロード"))\(viewModel.sortIndicator(for: "autoUnload"))", width: $unloadColumnWidth, defaultWidth: ModelListColumn.unload, showsHandle: false, sortKey: "autoUnload", alignment: .center)
            columnHeader("\(t("Reasoning", "推論"))\(viewModel.sortIndicator(for: "reasoning"))", width: $reasoningColumnWidth, defaultWidth: ModelListColumn.reasoning, showsHandle: false, sortKey: "reasoning", alignment: .center)
            headerText(t("Model management", "モデル管理"))
                .frame(width: rowActionsColumnWidth, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("integrated-model-list-header")
    }

    private func modelRow(_ model: ModelConfig) -> some View {
        let isSelected = model.id == viewModel.selectedModelID
        let isHovered = hoveredModelID == model.id

        return HStack(alignment: .center, spacing: ModelListColumn.spacing) {
            HStack(spacing: 8) {
                modelDragHandle(for: model)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(model.notes.isEmpty ? model.family : model.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
                    t("min", "分"),
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
                Text(t("min", "分"))
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
                modelActionButton(t("Settings", "設定"), color: .secondary) {
                    viewModel.editProfileRequested(for: model)
                }
                .help(viewModel.runtimeEditingSafetyText(for: model))

                modelActionButton(t("Delete", "削除"), color: .red) {
                    viewModel.deleteProfileRequested(for: model)
                }
                .disabled(viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)
            }
            .frame(width: rowActionsColumnWidth, alignment: .center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(modelRowBackground(isSelected: isSelected, isHovered: isHovered))
        .liquidGlassLayerTwo(cornerRadius: 10)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { isHovered in
            hoveredModelID = isHovered ? model.id : nil
        }
        .onDrag {
            viewModel.beginModelReorderRequested()
            draggedModelID = model.id
            return NSItemProvider(object: model.id as NSString)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.12))
        }
        .onTapGesture {
            viewModel.selectedModelID = model.id
        }
    }

    private func modelRowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.08)
        }
        return isHovered ? Color.primary.opacity(0.045) : .clear
    }

    private func modelDragHandle(for model: ModelConfig) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary.opacity(0.72))
            .frame(width: 22, height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help(t("Drag to reorder", "ドラッグして並べ替え"))
            .onDrag {
                viewModel.beginModelReorderRequested()
                draggedModelID = model.id
                return NSItemProvider(object: model.id as NSString)
            }
    }

    private var modelListEndDropTarget: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.clear)
            .frame(height: 14)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
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
        let foregroundColor: Color = if ["Unload", "アンロード"].contains(statusText) {
            .red
        } else if ["Load", "Loaded", "ロード", "ロード済"].contains(statusText) {
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
                Label(strings.text(.start), systemImage: "play.fill")
                    .frame(width: 110)
            }
            .buttonStyle(.glassProminent)
            .disabled(!viewModel.canStartSelectedModel)

            Button {
                viewModel.stopRequested()
            } label: {
                Label(strings.text(.stop), systemImage: "stop.fill")
                    .frame(width: 110)
            }
            .buttonStyle(.glass)
            .disabled(!viewModel.canStopManagedServer)

            Button {
                viewModel.restartRequested()
            } label: {
                Label(strings.text(.restart), systemImage: "arrow.clockwise")
                    .frame(width: 120)
            }
            .buttonStyle(.glass)
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
        .liquidGlassBar()
    }

    private var bottomOperationsPanel: some View {
        HStack(spacing: 0) {
            testChatPanel
                .frame(minWidth: 360, maxWidth: .infinity)
            Divider()
            logPanel
                .frame(minWidth: 360, maxWidth: .infinity)
        }
        .liquidGlassLayerOne(cornerRadius: 0)
        .accessibilityIdentifier("integrated-bottom-operations-panel")
    }

    private var testChatPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t("Test Chat", "テストチャット"))
                    .font(.headline)
                Spacer()
                Text(viewModel.miniChatHTTPStatusText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(viewModel.miniChatDurationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(t(
                    "Direct test only. Sends one user message directly to the selected OpenAI-compatible endpoint.",
                    "Directテスト専用です。選択中のOpenAI互換エンドポイントへ1件のユーザーメッセージを直接送信します。"
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: .infinity)
                .liquidGlassLayerOne(cornerRadius: 8)

                MiniChatInputView(
                    text: $viewModel.miniChatPrompt,
                    placeholder: t("Type a test message. Enter sends. Shift+Enter inserts a new line.", "テストメッセージを入力。Enterで送信、Shift+Enterで改行。"),
                    onSubmit: { viewModel.sendMiniChatRequested() }
                )
                .frame(height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08))
                )

                HStack {
                    Button(t("Send", "送信")) {
                        viewModel.sendMiniChatRequested()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!viewModel.canSendMiniChat)

                    Button(t("Cancel", "キャンセル")) {
                        viewModel.cancelMiniChatRequested()
                    }
                    .buttonStyle(.glass)
                    .disabled(!viewModel.isMiniChatRunning)

                    Button(t("Clear", "クリア")) {
                        viewModel.clearMiniChatRequested()
                    }
                    .buttonStyle(.glass)

                    Button(t("Copy latest", "最新をコピー")) {
                        viewModel.copyMiniChatResponseRequested()
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.miniChatResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                    Text(viewModel.miniChatStatus)
                        .font(.caption)
                        .foregroundStyle(viewModel.isMiniChatRunning ? .orange : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
        }
        .liquidGlassLayerOne(cornerRadius: 0)
        .accessibilityIdentifier("integrated-test-chat-panel")
    }

    private func miniChatBubble(_ message: MiniChatTranscriptMessage) -> some View {
        let isUser = message.sender == .user
        let isSystem = message.sender == .system
        let canCopy = message.sender == .assistant && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.caption)
                    .textSelection(.enabled)
                    .foregroundStyle(isSystem ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

                if canCopy {
                    Button {
                        viewModel.copyMiniChatMessageRequested(message)
                    } label: {
                        Image(systemName: AppSymbol.copy)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 20)
                            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help(t("Copy response", "返答をコピー"))
                    .accessibilityLabel(t("Copy response", "返答をコピー"))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                isUser
                ? Color.accentColor.opacity(0.12)
                : (isSystem ? Color.orange.opacity(0.10) : Color.white.opacity(0.14)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(strings.text(.logs))
                    .font(.headline)
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
                .buttonStyle(.glass)
                .disabled(viewModel.visibleLogEntries.isEmpty)
                Button(t("Clear", "クリア")) {
                    viewModel.clearLogsRequested()
                }
                .buttonStyle(.glass)
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
        .liquidGlassLayerOne(cornerRadius: 0)
    }

    private var rightColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                compactInspectorHeader
                collapsibleRightPanel(id: "model", title: t("Model inspector", "モデル詳細"), systemImage: AppSymbol.modelInspector) {
                    modelSettingsPanelContent
                }
                collapsibleRightPanel(id: "external", title: t("Connection", "接続"), systemImage: AppSymbol.connection) {
                    externalServerPanelContent
                }
                collapsibleRightPanel(id: "recovery", title: t("Recovery", "復旧"), systemImage: AppSymbol.recovery) {
                    IntegratedRecoveryPanelView(
                        issue: viewModel.currentRecoveryIssue,
                        language: viewModel.settings.uiLanguage,
                        onAction: handleRecoveryAction,
                        onCopyTroubleshooting: viewModel.copyTroubleshootingSummary,
                        onRefreshSafety: viewModel.refreshIntegratedSafetyRequested
                    )
                    recentRightPanelLogs
                }
                collapsibleRightPanel(id: "hermes", title: t("Hermes Agent connection", "Hermes Agent接続情報"), systemImage: AppSymbol.hermesAgent) {
                    hermesPanelContent
                }
            }
            .padding(12)
        }
        .liquidGlassSidebar()
    }

    private var compactInspectorHeader: some View {
        HStack(spacing: 10) {
            Label(t("Inspector", "インスペクター"), systemImage: AppSymbol.rightInspector)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .accessibilityIdentifier("integrated-inspector-header")
    }

    private var rightPanelHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(activeAccentColor.opacity(0.16))
                    Image(systemName: AppSymbol.rightInspector)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(activeAccentColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Operations inspector", "操作インスペクター"))
                        .font(.headline)
                    Text(t(
                        "Review the selected model, connection target, recovery state, and Hermes copy values without leaving this workspace.",
                        "このワークスペース内で、選択モデル、接続先、復旧状態、Hermesコピー値を確認します。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                rightPanelStatusCard(
                    title: t("Selected", "選択中"),
                    value: selectedModel?.displayName ?? "-",
                    systemImage: AppSymbol.models
                )
                rightPanelStatusCard(
                    title: t("Runtime", "実行状態"),
                    value: viewModel.runtimeState.title,
                    systemImage: "bolt.horizontal"
                )
            }

            Text(t("Panel order: model details, connection target, recovery, and agent copy values.", "ペイン順序: モデル詳細、接続先、復旧、エージェントコピー値。"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .liquidGlassLayerTwo(cornerRadius: 12)
    }

    private func rightPanelStatusCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .liquidGlassLayerTwo(cornerRadius: 9)
    }

    private var externalServerPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("OpenAI-compatible servers such as vLLM, Rapid-MLX, LM Studio, and Ollama are adopted as external servers by storing connection values only.", "vLLM / Rapid-MLX / LM Studio / OllamaなどのOpenAI互換サーバーは、外部サーバーとして接続情報だけを採用します。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            DetailGrid(rows: [
                (t("Target", "接続先"), viewModel.connectionTargetSummary.targetType),
                ("Base URL", viewModel.connectionTargetSummary.baseURL),
                ("Model", viewModel.connectionTargetSummary.modelID),
                (t("Ownership", "管理範囲"), viewModel.connectionTargetSummary.ownershipNote),
                (t("Lifecycle", "ライフサイクル"), viewModel.runtimeState.isExternalServerContext ? t("External management. Start / Stop / Restart are unavailable.", "外部管理。起動 / 停止 / 再起動の対象外です。") : t("Not adopted. It can be adopted after Ready Check detection.", "未採用。Ready確認で検出後に採用可能です。"))
            ])
            copyRow("Base URL", value: viewModel.connectionTargetSummary.baseURL, action: { viewModel.copyBaseURL() })
            copyRow("Model", value: viewModel.connectionTargetSummary.modelID, action: { viewModel.copyModelID() })
            copyRow("API Key", value: viewModel.connectionTargetSummary.apiKeyPlaceholder, action: { viewModel.copyAPIKeyPlaceholder() })
            HStack {
                Button(t("Ready Check", "Ready確認")) { viewModel.checkReadyRequested() }
                    .buttonStyle(.glass)
                Button(t("Adopt", "採用")) { viewModel.adoptExternalServerRequested() }
                    .buttonStyle(.glass)
                    .disabled(!viewModel.canAdoptExternalServer)
                Button(t("Forget", "解除")) { viewModel.forgetExternalServerRequested() }
                    .buttonStyle(.glass)
                    .disabled(!viewModel.canForgetExternalServer)
            }
            Text(t("Adopt stores only the connection context. The app does not stop, restart, capture logs from, or monitor memory for external processes.", "採用は接続コンテキストの保存のみです。外部プロセスの停止・再起動・ログ取得・メモリ監視は行いません。"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
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
        .padding(10)
        .liquidGlassLayerTwo(cornerRadius: 8)
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
                    Image(systemName: expandedRightPanelID == id ? AppSymbol.expanded : AppSymbol.collapsed)
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
        .background(Color.clear)
    }

    private var modelSettingsPanelContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            modelInspectorOverview

            groupedSection(t("Basic information", "基本情報")) {
                HStack {
                    Button {
                        viewModel.editProfileRequested()
                    } label: {
                        Label(t("Configure selected model", "選択モデルを設定"), systemImage: AppSymbol.modelInspector)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isManagedProcessRunning)
                }
                if viewModel.isManagedProcessRunning {
                    Text(t("Model ID, host, port, and advanced options are locked while running. Stop the server before editing them.", "実行中はModel ID、ホスト、ポート、詳細オプションの変更を止めています。停止後に設定してください。"))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                formRow(t("Model name", "モデル名"), selectedModel?.displayName ?? "-")
                formRow("Model ID (Hugging Face)", selectedModel?.modelID ?? "-")
                formRow(t("Model validation", "モデル検証"), viewModel.selectedModelIdentityDetailText, valueColor: viewModel.selectedModelIdentityDetailText.localizedCaseInsensitiveContains("Missing") || viewModel.selectedModelIdentityDetailText.localizedCaseInsensitiveContains("review") ? .orange : .green)
                formRow(t("Purpose / notes", "用途・メモ"), selectedModel?.notes.isEmpty == false ? selectedModel?.notes ?? "-" : "-")
            }
            .accessibilityIdentifier("integrated-model-basic-info-section")

            groupedSection(t("Safety", "安全性")) {
                let safetySummary = localizedStatusText(viewModel.selectedModelSafetySummary)
                formRow(t("Summary", "概要"), safetySummary, valueColor: isPositiveLocalizedStatus(safetySummary) ? .green : .orange)
                ForEach(viewModel.selectedModelSafetyRows, id: \.0) { row in
                    let value = localizedStatusText(row.1)
                    formRow(localizedSafetyLabel(row.0), value, valueColor: isPositiveLocalizedStatus(value) ? .green : .orange)
                }
                let recoverySummary = localizedStatusText(viewModel.failedStartRecoverySummary)
                formRow(t("Recovery guide", "復旧ガイド"), recoverySummary, valueColor: isPositiveLocalizedStatus(recoverySummary) ? .secondary : .orange)
            }
            .accessibilityIdentifier("integrated-model-safety-section")

            groupedSection(t("Direct Mode port", "Direct Modeポート")) {
                formRow(t("Port / IP address", "ポート/IPアドレス"), selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-")
                availabilityPill("\(selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-"): \(localizedStatusText(viewModel.selectedServerPortSafetyText))")
            }
            .accessibilityIdentifier("integrated-model-port-section")

            groupedSection(t("Operation settings", "動作設定")) {
                formRow(t("Applied changes", "変更反映"), viewModel.restartRequired ? t("Restart required", "再起動が必要") : t("Current settings are active", "現在の設定が有効"), valueColor: viewModel.restartRequired ? .orange : .green)
                HStack {
                    Text(t("Reasoning mode for Qwen models", "推論モード（Qwen系）"))
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
                formRow(t("Stop method", "停止方式"), t("Manual stop", "手動で停止"))
            }

            groupedSection(t("State information", "状態情報")) {
                formRow(t("Operation safety", "操作安全性"), viewModel.integratedActionStateSummary, valueColor: viewModel.canStartSelectedModel ? .green : .orange)
                formRow(t("Status", "ステータス"), isSelectedRunning ? t("Loaded", "ロード済") : t("Not loaded", "未ロード"), valueColor: isSelectedRunning ? .green : .secondary)
                formRow(t("Latest check", "最終確認"), selectedModel.map { viewModel.integratedLatestUseText(for: $0) } ?? "-")
                formRow(t("Start time", "起動時刻"), viewModel.runtimeEvents.first?.timestamp.formatted(date: .numeric, time: .standard) ?? "-")
                formRow(t("Process", "プロセス"), isSelectedRunning ? t("App managed", "アプリ管理") : "-")
                formRow(t("Memory usage", "メモリ使用量"), isSelectedRunning ? viewModel.memoryUsageText : "-")
                formRow(t("Speed Test", "スピードテスト"), viewModel.latestBenchmarkResult?.summary ?? t("Not run", "未実行"))
            }
        }
    }

    private var modelInspectorOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                inspectorMetricCard(
                    title: t("Load state", "ロード状態"),
                    value: isSelectedRunning ? t("Loaded", "ロード済") : t("Not loaded", "未ロード"),
                    systemImage: isSelectedRunning ? "checkmark.circle.fill" : "circle",
                    valueColor: isSelectedRunning ? .green : .secondary
                )
                inspectorMetricCard(
                    title: t("Safety", "安全性"),
                    value: localizedStatusText(viewModel.selectedModelSafetySummary),
                    systemImage: "shield.lefthalf.filled",
                    valueColor: isPositiveLocalizedStatus(localizedStatusText(viewModel.selectedModelSafetySummary)) ? .green : .orange
                )
            }
            HStack(alignment: .top, spacing: 10) {
                inspectorMetricCard(
                    title: t("Port", "ポート"),
                    value: selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-",
                    systemImage: "network",
                    valueColor: .secondary
                )
                inspectorMetricCard(
                    title: t("Changes", "変更"),
                    value: viewModel.restartRequired ? t("Restart required", "再起動が必要") : t("Active", "有効"),
                    systemImage: viewModel.restartRequired ? "arrow.clockwise.circle" : "checkmark.seal",
                    valueColor: viewModel.restartRequired ? .orange : .green
                )
            }
            Text(t(
                "Use this panel to inspect the selected model. Edit profile data from Basic information; start/stop actions stay in the model list.",
                "このペインでは選択モデルを確認します。プロファイル情報は基本情報から編集し、起動/停止操作はモデル一覧で行います。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .liquidGlassLayerTwo(cornerRadius: 12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        )
    }

    private func inspectorMetricCard(title: String, value: String, systemImage: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .liquidGlassLayerTwo(cornerRadius: 10)
    }

    private func groupedSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(.vertical, 6)
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
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func localizedSafetyLabel(_ label: String) -> String {
        switch label {
        case "Selected model": return t("Selected model", "選択モデル")
        case "Executable": return t("Executable", "実行ファイル")
        case "Model": return t("Model", "モデル")
        case "Server port": return t("Port / IP address", "ポート/IPアドレス")
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
                .replacingOccurrences(of: "Server port", with: "ポート/IPアドレス")
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

            Text(t("Direct Mode: Hermes Agent connects directly to mlx_lm.server. Direct Mode only.", "Direct Mode: Hermes Agentはmlx_lm.serverへ直接接続します。Direct Modeのみです。"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                viewModel.copyHermesAgentConfig()
            } label: {
                Text(t("Copy Hermes settings", "Hermes設定をまとめてコピー"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)

            HStack {
                Text("\(t("Manager", "マネージャー")): \(viewModel.runtimeState.title)")
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
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button(t("Copy", "コピー"), action: action)
                .buttonStyle(.glass)
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
    let targetModel: ModelConfig?
    @Binding var draggedModelID: ModelConfig.ID?
    let viewModel: AppViewModel

    func dropEntered(info: DropInfo) {
        reorder()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedModelID != nil else {
            return false
        }

        reorder()
        self.draggedModelID = nil
        return true
    }

    private func reorder() {
        guard let draggedModelID else { return }
        if let targetModel {
            viewModel.moveModel(withID: draggedModelID, before: targetModel.id)
        } else {
            viewModel.moveModelToEnd(withID: draggedModelID)
        }
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
