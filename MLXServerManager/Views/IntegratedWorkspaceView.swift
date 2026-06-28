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
                    .overlay(alignment: .top) {
                        topGlassOverlay
                    }
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

            ProgressView(value: viewModel.memoryMLXProcessFraction + viewModel.memoryOtherProcessesFraction)

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

    private func memoryLegendRow(color: Color, label: String, value: String) -> some View {
        Label {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .frame(width: 70, alignment: .trailing)
        } icon: {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(color)
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
        Menu {
            Section {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        languageBinding.wrappedValue = option
                    } label: {
                        if option == viewModel.settings.uiLanguage {
                            Label(languageDisplayName(option), systemImage: "checkmark")
                        } else {
                            Text(languageDisplayName(option))
                        }
                    }
                }
            } header: {
                Text(t("Language", "言語"))
            }

            Section {
                themeMenuButton(title: t("System", "システム"), value: "system")
                themeMenuButton(title: t("Light", "ライト"), value: "light")
                themeMenuButton(title: t("Dark", "ダーク"), value: "dark")
            } header: {
                Text(t("Theme", "テーマ"))
            }

            Divider()

            Button {
                selectedDestination = .settings
            } label: {
                Label(t("Advanced settings", "詳細設定"), systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(t("Display", "表示"), systemImage: "paintpalette")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("integrated-sidebar-quick-settings-menu")
    }

    private func themeMenuButton(title: String, value: String) -> some View {
        Button {
            appearanceBinding.wrappedValue = value
        } label: {
            if viewModel.settings.uiAppearance == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
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
            .background(Color(nsColor: .windowBackgroundColor))
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
                    .font(.title3.weight(.semibold))
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        Text(model.notes.isEmpty ? model.family : model.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
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
                Text(viewModel.modelSizeText(for: model))
                    .foregroundStyle(.secondary)
            }
            .width(min: 72, ideal: 90, max: 120)

            TableColumn(t("Status", "ステータス"), value: \ModelTableRow.statusSortValue) { row in
                let model = row.model
                statusButton(for: model)
            }
            .width(min: 86, ideal: 112, max: 140)

            TableColumn(t("Port / IP address", "ポート/IPアドレス"), value: \ModelTableRow.endpointSortValue) { row in
                let model = row.model
                portValue("\(model.host):\(model.serverPort)")
            }
            .width(min: 120, ideal: 150, max: 200)

            TableColumn(t("Memory", "メモリ使用量"), value: \ModelTableRow.memorySortValue) { row in
                let model = row.model
                memoryCell(viewModel.integratedMemoryText(for: model))
            }
            .width(min: 90, ideal: 120, max: 150)

            TableColumn(t("Auto unload", "自動アンロード"), value: \ModelTableRow.autoUnloadSortValue) { row in
                let model = row.model
                autoUnloadCell(for: model)
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
            }
            .width(min: 70, ideal: 90, max: 110)

            TableColumn(t("Model management", "モデル管理")) { row in
                let model = row.model
                modelActions(for: model)
            }
            .width(min: 150, ideal: 170, max: 210)
        }
        .accessibilityIdentifier("integrated-model-table")
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            moveDroppedModelToEnd(providers)
        }
        .onChange(of: modelTableSortOrder) { _, _ in
            viewModel.beginModelReorderRequested()
        }
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

    private func statusButton(for model: ModelConfig) -> some View {
        let isHovered = hoveredStatusModelID == model.id
        let statusText = viewModel.interactiveStatusText(for: model, isHovered: isHovered)
        let isTransitioning = viewModel.isModelTransitioning(model)
        let canUseAction = viewModel.canUseStatusAction(for: model)

        return Button {
            guard !isTransitioning, canUseAction else {
                return
            }
            viewModel.statusActionRequested(for: model)
        } label: {
            Text(statusText)
                .frame(minWidth: 76, maxWidth: .infinity)
                .foregroundStyle(statusForegroundColor(for: model))
        }
        .buttonStyle(.bordered)
        .tint(statusTintColor(for: model))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovering in
            hoveredStatusModelID = isHovering ? model.id : nil
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hoveredStatusModelID = model.id
            case .ended:
                if hoveredStatusModelID == model.id {
                    hoveredStatusModelID = nil
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .disabled(!isTransitioning && !canUseAction)
        .allowsHitTesting(!isTransitioning && canUseAction)
    }

    private func statusForegroundColor(for model: ModelConfig) -> Color {
        if viewModel.isModelTransitioning(model) {
            return .red
        }
        if viewModel.isModelLoaded(model) {
            return .green
        }
        return .primary
    }

    private func statusTintColor(for model: ModelConfig) -> Color? {
        if viewModel.isModelLoaded(model) {
            return .green
        }
        return nil
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
                .font(.callout.weight(.semibold))
                .foregroundColor(text == "-" ? .secondary : .green)
            ProgressView(value: text == "-" ? 0 : 0.48)
                .frame(width: 62)
        }
    }

    private var bottomOperationsPanel: some View {
        HStack(spacing: 0) {
            testChatPanel
                .frame(minWidth: 360, maxWidth: .infinity)
            Divider()
            logPanel
                .frame(minWidth: 360, maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            .padding(.horizontal, 14)
            .frame(height: 52)

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
                .background(Color(nsColor: .textBackgroundColor))

                MiniChatInputView(
                    text: $viewModel.miniChatPrompt,
                    placeholder: t("Type a test message. Enter sends. Shift+Enter inserts a new line.", "テストメッセージを入力。Enterで送信、Shift+Enterで改行。"),
                    onSubmit: { viewModel.sendMiniChatRequested() }
                )
                .frame(height: 58)

                HStack {
                    Button(t("Send", "送信")) {
                        viewModel.sendMiniChatRequested()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSendMiniChat)

                    Button(t("Cancel", "キャンセル")) {
                        viewModel.cancelMiniChatRequested()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isMiniChatRunning)

                    Button(t("Clear", "クリア")) {
                        viewModel.clearMiniChatRequested()
                    }
                    .buttonStyle(.bordered)

                    Button(t("Copy latest", "最新をコピー")) {
                        viewModel.copyMiniChatResponseRequested()
                    }
                    .buttonStyle(.bordered)
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
        .background(Color(nsColor: .windowBackgroundColor))
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
                    .buttonStyle(.bordered)
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
        Form {
            inspectorSection(id: "model", title: t("Model inspector", "モデル詳細"), systemImage: AppSymbol.modelInspector) {
                modelSettingsPanelContent
            }

            inspectorSection(id: "external", title: t("Connection", "接続"), systemImage: AppSymbol.connection) {
                externalServerPanelContent
            }

            inspectorSection(id: "recovery", title: t("Recovery", "復旧"), systemImage: AppSymbol.recovery) {
                IntegratedRecoveryPanelView(
                    issue: viewModel.currentRecoveryIssue,
                    language: viewModel.settings.uiLanguage,
                    onAction: handleRecoveryAction,
                    onCopyTroubleshooting: viewModel.copyTroubleshootingSummary,
                    onRefreshSafety: viewModel.refreshIntegratedSafetyRequested
                )
                recentRightPanelLogs
            }

            inspectorSection(id: "hermes", title: t("Hermes Agent connection", "Hermes Agent接続情報"), systemImage: AppSymbol.hermesAgent) {
                hermesPanelContent
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            topGlassOverlay
        }
    }

    private var topGlassOverlay: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.42),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 96)
            .ignoresSafeArea(.container, edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var externalServerPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("OpenAI-compatible servers such as vLLM, Rapid-MLX, LM Studio, and Ollama are adopted as external servers by storing connection values only.", "vLLM / Rapid-MLX / LM Studio / OllamaなどのOpenAI互換サーバーは、外部サーバーとして接続情報だけを採用します。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            detailRows([
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
                    .buttonStyle(.bordered)
                Button(t("Adopt", "採用")) { viewModel.adoptExternalServerRequested() }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canAdoptExternalServer)
                Button(t("Forget", "解除")) { viewModel.forgetExternalServerRequested() }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canForgetExternalServer)
            }
            Text(t("Adopt stores only the connection context. The app does not stop, restart, capture logs from, or monitor memory for external processes.", "採用は接続コンテキストの保存のみです。外部プロセスの停止・再起動・ログ取得・メモリ監視は行いません。"))
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedRightPanelID == id },
                    set: { expandedRightPanelID = $0 ? id : nil }
                )
            ) {
                content()
                    .padding(.top, 8)
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
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
                availabilityStatus("\(selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-"): \(localizedStatusText(viewModel.selectedServerPortSafetyText))")
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
            detailRows([
                (t("Load state", "ロード状態"), isSelectedRunning ? t("Loaded", "ロード済") : t("Not loaded", "未ロード")),
                (t("Safety", "安全性"), localizedStatusText(viewModel.selectedModelSafetySummary)),
                (t("Port", "ポート"), selectedModel.map { "\($0.host):\($0.serverPort)" } ?? "-"),
                (t("Changes", "変更"), viewModel.restartRequired ? t("Restart required", "再起動が必要") : t("Active", "有効"))
            ])
            Text(t(
                "Use this panel to inspect the selected model. Edit profile data from Basic information; start/stop actions stay in the model list.",
                "このペインでは選択モデルを確認します。プロファイル情報は基本情報から編集し、起動/停止操作はモデル一覧で行います。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
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

            Text(t("Direct Mode: Hermes Agent connects directly to mlx_lm.server. Direct Mode only.", "Direct Mode: Hermes Agentはmlx_lm.serverへ直接接続します。Direct Modeのみです。"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                viewModel.copyHermesAgentConfig()
            } label: {
                Text(t("Copy Hermes settings", "Hermes設定をまとめてコピー"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Text("\(t("Manager", "マネージャー")): \(viewModel.runtimeState.title)")
                Spacer()
                Text("Direct Mode")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func copyRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                Button(t("Copy", "コピー"), action: action)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func detailRows(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.0) { label, value in
                LabeledContent(label) {
                    Text(value)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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
