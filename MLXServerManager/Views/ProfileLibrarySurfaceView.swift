import SwiftUI

struct ProfileLibrarySurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var backendFilter: InferenceBackend?
    @State private var thinkingOnly = false
    @State private var favoritesOnly = false
    @State private var categoryFilter: ProfileUsageCategory?
    @State private var sortOrder: ProfileLibrarySortOrder = .favorites
    @State private var metadataByModelID: [String: ProfileLibraryMetadata] = [:]
    @State private var tagDraftByModelID: [String: String] = [:]
    @State private var selectedPreset: ProfileLibraryPreset = .all
    @State private var recentModelIDs: [String] = []
    @State private var comparisonModelIDs: Set<String> = []
    @State private var isComparisonPresented = false
    @State private var isCompositionPresented = false
    @State private var compositionSelection: ProfileCompositionSelection?

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var items: [ProfileLibraryItem] {
        let presetCategory: ProfileUsageCategory?
        let presetTag: String?
        let presetFavorites: Bool
        let presetRecent: Bool
        switch selectedPreset {
        case .all:
            presetCategory = nil
            presetTag = nil
            presetFavorites = false
            presetRecent = false
        case .favorites:
            presetCategory = nil
            presetTag = nil
            presetFavorites = true
            presetRecent = false
        case .recent:
            presetCategory = nil
            presetTag = nil
            presetFavorites = false
            presetRecent = true
        case let .category(category):
            presetCategory = category
            presetTag = nil
            presetFavorites = false
            presetRecent = false
        case let .tag(tag):
            presetCategory = nil
            presetTag = tag
            presetFavorites = false
            presetRecent = false
        }

        return ProfileLibrary.items(
            from: viewModel.models,
            metadataByModelID: metadataByModelID,
            searchText: searchText,
            backend: backendFilter,
            category: presetCategory ?? categoryFilter,
            favoritesOnly: presetFavorites || favoritesOnly,
            recentModelIDs: recentModelIDs,
            recentOnly: presetRecent,
            tag: presetTag,
            thinkingOnly: thinkingOnly,
            sortOrder: sortOrder
        )
    }

    private var availableTags: [String] {
        ProfileLibrary.availableTags(in: metadataByModelID)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            presetBar
            Divider()
            if items.isEmpty {
                ContentUnavailableView {
                    Label(t("No matching profiles", "該当するプロファイルなし"), systemImage: "square.grid.2x2")
                } description: {
                    Text(t("Change the search or filters.", "検索条件またはフィルターを変更してください。"))
                } actions: {
                    Button(t("Clear Filters", "フィルター解除")) {
                        searchText = ""
                        backendFilter = nil
                        thinkingOnly = false
                        favoritesOnly = false
                        categoryFilter = nil
                        selectedPreset = .all
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        ForEach(items) { item in
                            profileCard(item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            let validIDs = Set(viewModel.models.map(\.id))
            metadataByModelID = ProfileLibraryMetadataStore.reconcile(validModelIDs: validIDs)
            recentModelIDs = ProfileLibraryRecentStore.reconcile(validModelIDs: validIDs)
            reconcileLibraryState()
        }
        .onChange(of: viewModel.models.map(\.id)) { _, _ in
            reconcileLibraryState()
        }
        .sheet(isPresented: $isComparisonPresented) {
            comparisonSheet
        }
        .sheet(isPresented: $isCompositionPresented) {
            compositionSheet
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Profile Library", "プロファイルライブラリ"))
                    .font(.title3)
                Text(t("Browse, filter, edit, and duplicate model profiles.", "モデルプロファイルを検索、編集、複製します。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField(t("Search profiles", "プロファイルを検索"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            Picker(t("Backend", "バックエンド"), selection: $backendFilter) {
                Text(t("All backends", "すべてのバックエンド")).tag(Optional<InferenceBackend>.none)
                ForEach(InferenceBackend.allCases) { backend in
                    Text(backend.localizedTitle(language: viewModel.settings.uiLanguage)).tag(Optional(backend))
                }
            }
            .pickerStyle(.menu)
            Picker(t("Category", "用途"), selection: $categoryFilter) {
                Text(t("All categories", "すべての用途")).tag(Optional<ProfileUsageCategory>.none)
                ForEach(ProfileUsageCategory.allCases) { category in
                    Text(categoryTitle(category)).tag(Optional(category))
                }
            }
            .pickerStyle(.menu)
            Picker(t("Sort", "並び順"), selection: $sortOrder) {
                Text(t("Favorites", "お気に入り")).tag(ProfileLibrarySortOrder.favorites)
                Text(t("Name", "名前")).tag(ProfileLibrarySortOrder.name)
                Text(t("Backend", "バックエンド")).tag(ProfileLibrarySortOrder.backend)
                Text(t("Port", "ポート")).tag(ProfileLibrarySortOrder.port)
            }
            .pickerStyle(.menu)
            Toggle(t("Favorites only", "お気に入りのみ"), isOn: $favoritesOnly)
                .toggleStyle(.switch)
            Toggle(t("Thinking only", "推論対応のみ"), isOn: $thinkingOnly)
                .toggleStyle(.switch)
            Button {
                isComparisonPresented = true
            } label: {
                Label(t("Compare (\(comparisonModelIDs.count))", "比較（\(comparisonModelIDs.count)）"), systemImage: "rectangle.split.3x1")
            }
            .buttonStyle(.bordered)
            .disabled(comparisonModelIDs.count < 2)
            Button {
                viewModel.addProfileRequested()
            } label: {
                Label(t("New Profile", "新規プロファイル"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var presetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                presetButton(.all, title: t("All", "すべて"), systemImage: "square.grid.2x2")
                presetButton(.favorites, title: t("Favorites", "お気に入り"), systemImage: "star")
                presetButton(.recent, title: t("Recent", "最近使用"), systemImage: "clock")
                ForEach(ProfileUsageCategory.allCases) { category in
                    presetButton(.category(category), title: categoryTitle(category), systemImage: "folder")
                }
                ForEach(availableTags, id: \.self) { tag in
                    presetButton(.tag(tag), title: tag, systemImage: "tag")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private func presetButton(_ preset: ProfileLibraryPreset, title: String, systemImage: String) -> some View {
        Button {
            selectedPreset = preset
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(selectedPreset == preset ? Color.accentColor : Color.secondary)
        .controlSize(.small)
    }

    private func profileCard(_ item: ProfileLibraryItem) -> some View {
        let model = item.model
        let metadata = item.metadata
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    Text(model.modelID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Toggle(isOn: Binding(
                    get: { comparisonModelIDs.contains(model.id) },
                    set: { enabled in updateComparisonSelection(model.id, enabled: enabled) }
                )) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help(t("Add to comparison", "比較対象に追加"))
                Button {
                    updateMetadata(for: model.id) { $0.isFavorite.toggle() }
                } label: {
                    Image(systemName: metadata.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .help(metadata.isFavorite ? t("Remove from favorites", "お気に入りから解除") : t("Add to favorites", "お気に入りに追加"))
                if viewModel.isModelRunning(model) {
                    Label(t("Running", "実行中"), systemImage: "circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    label(t("Backend", "バックエンド"))
                    Text(model.resolvedBackend.localizedTitle(language: viewModel.settings.uiLanguage))
                }
                GridRow {
                    label(t("Endpoint", "エンドポイント"))
                    Text("\(model.host):\(model.serverPort)").monospaced()
                }
                GridRow {
                    label(t("Family", "ファミリー"))
                    Text(model.family.isEmpty ? "-" : model.family)
                }
                GridRow {
                    label(t("Quantization", "量子化"))
                    Text(model.quantization.isEmpty ? "-" : model.quantization)
                }
                GridRow {
                    label(t("Thinking", "推論"))
                    Text(model.enableThinking ? t("Enabled", "有効") : t("Disabled", "無効"))
                }
            }
            .font(.caption)

            Picker(t("Usage", "用途"), selection: Binding(
                get: { metadata.category },
                set: { category in updateMetadata(for: model.id) { $0.category = category } }
            )) {
                ForEach(ProfileUsageCategory.allCases) { category in
                    Text(categoryTitle(category)).tag(category)
                }
            }
            .pickerStyle(.segmented)

            if !metadata.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(metadata.tags, id: \.self) { tag in
                            Button {
                                updateMetadata(for: model.id) { value in
                                    value.tags.removeAll { $0 == tag }
                                }
                            } label: {
                                Label(tag, systemImage: "xmark")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                TextField(t("Add tag", "タグを追加"), text: Binding(
                    get: { tagDraftByModelID[model.id] ?? "" },
                    set: { tagDraftByModelID[model.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button(t("Add", "追加")) {
                    addTag(for: model.id)
                }
                .disabled((tagDraftByModelID[model.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !model.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(model.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack {
                Button(t("Select", "選択")) {
                    selectProfile(model)
                }
                .buttonStyle(.bordered)
                Button(t("Edit", "編集")) {
                    viewModel.editProfileRequested(for: model)
                }
                .buttonStyle(.bordered)
                Button(t("Duplicate", "複製")) {
                    viewModel.duplicateProfileRequested(for: model)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.76), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(viewModel.selectedModelID == model.id ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.18), lineWidth: viewModel.selectedModelID == model.id ? 2 : 1)
        }
    }

    private var comparisonModels: [ModelConfig] {
        viewModel.models.filter { comparisonModelIDs.contains($0.id) }
    }

    private var comparisonSheet: some View {
        let models = comparisonModels
        let rows = ProfileLibrary.comparisonRows(for: models)
        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Profile Comparison", "プロファイル比較"))
                        .font(.title3)
                    Text(t("Differences are highlighted. Duplicate a profile only after reviewing the settings.", "差分を強調表示します。設定確認後にプロファイルを複製できます。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    compositionSelection = ProfileCompositionSelection.initial(models: models)
                    isCompositionPresented = compositionSelection != nil
                } label: {
                    Label(t("Compose Profile", "プロファイルを合成"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderedProminent)
                Button(t("Close", "閉じる")) { isComparisonPresented = false }
            }
            .padding(16)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text(t("Setting", "設定")).font(.headline)
                        ForEach(models) { model in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(model.displayName).font(.headline).lineLimit(2)
                                Button(t("Duplicate", "複製")) {
                                    isComparisonPresented = false
                                    viewModel.duplicateProfileRequested(for: model)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .frame(minWidth: 190, alignment: .leading)
                        }
                    }
                    Divider()
                    ForEach(rows) { row in
                        GridRow {
                            Text(comparisonRowTitle(row.key))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                                Text(value.isEmpty ? "-" : value)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .padding(6)
                                    .frame(minWidth: 190, maxWidth: 260, alignment: .leading)
                                    .background(row.hasDifference ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var compositionSheet: some View {
        let models = comparisonModels
        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Compose Profile", "プロファイル合成"))
                        .font(.title3)
                    Text(t("Choose the source profile for each setting group. The result opens as an editable draft.", "設定グループごとに採用元を選択します。結果は編集可能な下書きとして開きます。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Close", "閉じる")) { isCompositionPresented = false }
            }
            .padding(16)
            Divider()

            if let selection = compositionSelection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        compositionPicker(
                            title: t("Identity", "識別情報"),
                            detail: t("Display name and model ID", "表示名とモデルID"),
                            selection: binding(for: \ProfileCompositionSelection.identityModelID),
                            models: models
                        )
                        compositionPicker(
                            title: t("Runtime", "ランタイム"),
                            detail: t("Host, backend, thinking mode, and suggested port", "ホスト、バックエンド、推論モード、推奨ポート"),
                            selection: binding(for: \ProfileCompositionSelection.runtimeModelID),
                            models: models
                        )
                        compositionPicker(
                            title: t("Launch Tuning", "起動調整"),
                            detail: t("Advanced launch options and generation defaults", "詳細起動オプションと生成既定値"),
                            selection: binding(for: \ProfileCompositionSelection.tuningModelID),
                            models: models
                        )
                        compositionPicker(
                            title: t("Notes", "メモ"),
                            detail: t("Profile notes", "プロファイルのメモ"),
                            selection: binding(for: \ProfileCompositionSelection.notesModelID),
                            models: models
                        )

                        Divider()

                        if let preview = ProfileLibrary.composedDraft(
                            models: models,
                            selection: selection,
                            suggestedPort: suggestedCompositionPort(models: models, selection: selection)
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t("Draft Preview", "下書きプレビュー"))
                                    .font(.headline)
                                previewRow(t("Name", "名前"), preview.displayName)
                                previewRow(t("Model ID", "モデルID"), preview.modelID)
                                previewRow(t("Backend", "バックエンド"), preview.backend.localizedTitle(language: viewModel.settings.uiLanguage))
                                previewRow(t("Endpoint", "エンドポイント"), "\(preview.host):\(preview.serverPortText)")
                                previewRow(t("Thinking", "推論"), preview.enableThinking ? t("Enabled", "有効") : t("Disabled", "無効"))
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(16)
                }

                Divider()
                HStack {
                    Spacer()
                    Button {
                        isCompositionPresented = false
                        isComparisonPresented = false
                        viewModel.composeProfileRequested(models: models, selection: selection)
                    } label: {
                        Label(t("Create Editable Draft", "編集可能な下書きを作成"), systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
            } else {
                ContentUnavailableView(t("No profiles selected", "プロファイルが選択されていません"), systemImage: "square.stack.3d.up.slash")
            }
        }
        .frame(minWidth: 620, minHeight: 560)
    }

    private func compositionPicker(
        title: String,
        detail: String,
        selection: Binding<String>,
        models: [ModelConfig]
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 220, alignment: .leading)
            Picker(title, selection: selection) {
                ForEach(models) { model in
                    Text(model.displayName).tag(model.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding(for keyPath: WritableKeyPath<ProfileCompositionSelection, String>) -> Binding<String> {
        Binding(
            get: { compositionSelection?[keyPath: keyPath] ?? "" },
            set: { value in
                guard var selection = compositionSelection else { return }
                selection[keyPath: keyPath] = value
                compositionSelection = selection
            }
        )
    }

    private func suggestedCompositionPort(models: [ModelConfig], selection: ProfileCompositionSelection) -> Int {
        guard let runtime = models.first(where: { $0.id == selection.runtimeModelID }) else { return viewModel.settings.defaultPort }
        let usedPorts = Set(viewModel.models.filter { $0.host == runtime.host }.map(\.serverPort))
        var port = min(runtime.serverPort + 1, 65_535)
        while usedPorts.contains(port), port < 65_535 { port += 1 }
        return port
    }

    private func previewRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value.isEmpty ? "-" : value).monospaced().textSelection(.enabled)
            Spacer()
        }
        .font(.caption)
    }

    private func updateComparisonSelection(_ modelID: String, enabled: Bool) {
        if enabled {
            guard comparisonModelIDs.count < 3 else { return }
            comparisonModelIDs.insert(modelID)
        } else {
            comparisonModelIDs.remove(modelID)
        }
    }

    private func comparisonRowTitle(_ key: String) -> String {
        switch key {
        case "Model ID": t("Model ID", "モデルID")
        case "Backend": t("Backend", "バックエンド")
        case "Host": t("Host", "ホスト")
        case "Port": t("Port", "ポート")
        case "Family": t("Family", "ファミリー")
        case "Quantization": t("Quantization", "量子化")
        case "Thinking": t("Thinking", "推論")
        case "Local name": t("Local name", "ローカル名")
        case "Notes": t("Notes", "メモ")
        case "Extra arguments": t("Extra arguments", "追加引数")
        case "Temperature": t("Temperature", "Temperature")
        case "Top P": t("Top P", "Top P")
        case "Max tokens": t("Max tokens", "最大トークン")
        default: key
        }
    }

    private func selectProfile(_ model: ModelConfig) {
        viewModel.selectedModelID = model.id
        recentModelIDs = ProfileLibraryRecentStore.record(model.id)
    }

    private func reconcileLibraryState() {
        let state = ProfileLibrary.reconciledState(
            models: viewModel.models,
            metadataByModelID: metadataByModelID,
            recentModelIDs: recentModelIDs,
            comparisonModelIDs: comparisonModelIDs
        )
        metadataByModelID = state.metadataByModelID
        recentModelIDs = state.recentModelIDs
        comparisonModelIDs = state.comparisonModelIDs
        if comparisonModelIDs.count < 2 {
            isComparisonPresented = false
            isCompositionPresented = false
            compositionSelection = nil
        }
        if case let .tag(tag) = selectedPreset,
           !ProfileLibrary.availableTags(in: metadataByModelID).contains(where: {
               $0.localizedCaseInsensitiveCompare(tag) == .orderedSame
           }) {
            selectedPreset = .all
        }
    }

    private func updateMetadata(for modelID: String, update: (inout ProfileLibraryMetadata) -> Void) {
        var value = metadataByModelID[modelID] ?? ProfileLibraryMetadata()
        update(&value)
        value.normalize()
        metadataByModelID[modelID] = value
        ProfileLibraryMetadataStore.save(metadataByModelID)
    }

    private func addTag(for modelID: String) {
        let tag = (tagDraftByModelID[modelID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        updateMetadata(for: modelID) { value in
            value.tags.append(tag)
        }
        tagDraftByModelID[modelID] = ""
    }

    private func categoryTitle(_ category: ProfileUsageCategory) -> String {
        switch category {
        case .general: t("General", "一般")
        case .coding: t("Coding", "コーディング")
        case .agent: t("Agent", "エージェント")
        case .chat: t("Chat", "チャット")
        case .benchmark: t("Benchmark", "ベンチマーク")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(width: 82, alignment: .leading)
    }
}
