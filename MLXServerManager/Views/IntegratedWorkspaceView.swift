import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IntegratedWorkspaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State var selectedDestination: IntegratedWorkspaceDestination = .models
    @State private var expandedRightPanelID: String? = "model"
    @State private var isBottomPanelVisible = true
    @State private var isRightPanelVisible = true
    @State private var isBottomPanelAutoHidden = false
    @State private var isRightPanelAutoHidden = false
    @State private var modelTableSortOrder = [KeyPathComparator<ModelTableRow>]()
    @State private var hoveredStatusModelID: ModelConfig.ID?
    @State private var bottomPanelHeight: CGFloat = 280
    @State private var bottomPanelDragStartHeight: CGFloat?
    @State private var isMiniChatInputFocused = false
    @State private var isSettingsSidebarHovered = false

    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var isSelectedRunning: Bool { selectedModel?.id == viewModel.runningModelID }

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
        withAnimation(.easeInOut(duration: 0.24)) {
            isRightPanelVisible = true
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

    private func comfortableWindowWidth(rightVisible: Bool) -> CGFloat {
        Layout.leftPanelWidthWithDivider
            + Layout.modelListIdealWidth
            + (rightVisible ? Layout.rightPanelWidthWithDivider : 0)
    }

    private enum Layout {
        static let leftPanelWidth: CGFloat = 320
        static let rightPanelWidth: CGFloat = 430
        static let dividerWidth: CGFloat = 1
        static let leftPanelWidthWithDivider = leftPanelWidth + dividerWidth
        static let rightPanelWidthWithDivider = rightPanelWidth + dividerWidth
        static let modelListIdealWidth: CGFloat = 960
        static let minimumBottomPanelHeight: CGFloat = 720
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
                centerColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .id("center-\(viewModel.settings.uiAppearance)")
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .navigationSplitViewStyle(.balanced)
            .inspector(isPresented: $isRightPanelVisible) {
                rightColumn
                    .inspectorColumnWidth(
                        min: 360,
                        ideal: Layout.rightPanelWidth,
                        max: 520
                    )
            }
            .toolbar {
                panelToolbarItems
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            .animation(.easeInOut(duration: 0.24), value: isRightPanelVisible)
            .animation(.easeInOut(duration: 0.24), value: isBottomPanelVisible)
            .onAppear {
                applyAutomaticPanelCollapse(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, size in
                applyAutomaticPanelCollapse(for: size)
            }
        }
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .preferredColorScheme(preferredColorScheme)
        .accessibilityIdentifier("integrated-workspace")
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
            panelToggleButton(
                systemImage: AppSymbol.rightInspector,
                isActive: isRightPanelVisible,
                help: isRightPanelVisible
                    ? t("Hide inspector", "インスペクターを隠す")
                    : t("Show inspector", "インスペクターを表示"),
                action: toggleRightPanelRequested
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
                        Divider()
                        bottomOperationsPanel
                            .frame(height: max(180, proxy.size.height / 3))
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
                modelTable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var modelTable: some View {
        Table(sortedModelRows, selection: selectedModelBinding, sortOrder: $modelTableSortOrder) {
            TableColumn(t("Model / purpose", "モデル名 / 用途"), value: \ModelTableRow.nameSortValue) { row in
                let model = row.model
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .onDrag {
                            modelDragProvider(for: model)
                        }
                        .help(t("Drag to reorder", "ドラッグして並び替え"))
                        .accessibilityLabel(t("Drag to reorder model", "モデルをドラッグして並び替え"))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.displayName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(model.notes.isEmpty ? model.family : model.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedModelID = model.id
                }
                .onDrag {
                    modelDragProvider(for: model)
                }
                .onHover { isHovering in
                    hoveredStatusModelID = isHovering ? model.id : (hoveredStatusModelID == model.id ? nil : hoveredStatusModelID)
                }
                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                    moveDroppedModel(providers, before: model)
                }
            }
            .width(min: 220, ideal: 320, max: 520)

            TableColumn(t("Size", "サイズ"), value: \ModelTableRow.sizeSortValue) { row in
                let model = row.model
                modelSizeTableText(viewModel.modelSizeText(for: model))
            }
            .width(min: 72, ideal: 90, max: 120)

            TableColumn(t("Status", "ステータス"), value: \ModelTableRow.statusSortValue) { row in
                let model = row.model
                statusButton(for: model)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 86, ideal: 112, max: 140)

            TableColumn(t("IP address : port", "IPアドレス : ポート"), value: \ModelTableRow.endpointSortValue) { row in
                let model = row.model
                endpointTableText(host: "127.0.0.1", port: model.serverPort)
            }
            .width(min: 120, ideal: 150, max: 200)

            TableColumn(t("Memory", "メモリ使用量"), value: \ModelTableRow.memorySortValue) { row in
                let model = row.model
                memoryCell(viewModel.integratedMemoryText(for: model))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 90, ideal: 120, max: 150)

            TableColumn(t("Auto unload", "自動アンロード"), value: \ModelTableRow.autoUnloadSortValue) { row in
                let model = row.model
                autoUnloadCell(for: model)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 130, ideal: 160, max: 190)

            TableColumn(t("Reasoning", "推論"), value: \ModelTableRow.reasoningSortValue) { row in
                let model = row.model
                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.enableThinking },
                        set: { viewModel.toggleReasoning(for: model, isEnabled: $0) }
                    )
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 70, ideal: 90, max: 110)

            TableColumn(t("Model management", "モデル管理")) { row in
                let model = row.model
                modelActions(for: model)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 150, ideal: 170, max: 210)
        }
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .font(.callout)
        .accessibilityIdentifier("integrated-model-table")
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            moveDroppedModelToEnd(providers)
        }
        .onChange(of: modelTableSortOrder) { _, _ in
            viewModel.beginModelReorderRequested()
        }
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
            Text("\(host) : ")
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
                .frame(minWidth: 76)
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
            .frame(width: 52)
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
        }
    }

    private func modelActions(for model: ModelConfig) -> some View {
        HStack(spacing: 8) {
            Button(t("Settings", "設定")) {
                viewModel.editProfileRequested(for: model)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isManagedProcessRunning)

            Button(t("Delete", "削除"), role: .destructive) {
                viewModel.deleteProfileRequested(for: model)
            }
            .buttonStyle(.bordered)
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
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background {
            SidebarMaterialBackdrop()
                .ignoresSafeArea()
        }
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
                .frame(width: 132, alignment: .leading)
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
