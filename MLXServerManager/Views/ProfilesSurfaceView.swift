import SwiftUI

struct ProfilesSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

    private var models: [ModelConfig] { viewModel.visibleModels }
    private var selectedModel: ModelConfig? { viewModel.selectedModel }
    private var runningModel: ModelConfig? {
        guard let runningModelID = viewModel.runningModelID else { return nil }
        return viewModel.models.first { $0.id == runningModelID }
    }

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                toolbar
                summaryCards

                if viewModel.models.isEmpty {
                    emptyState
                } else {
                    HSplitView {
                        modelList
                            .frame(minWidth: 320, idealWidth: 420)
                        selectedModelInspector
                            .frame(minWidth: 360)
                    }
                    .frame(minHeight: 480)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("profiles-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(strings.text(.models))
                    .font(.title2.weight(.semibold))
            }

            Text(t("Manage model profiles from one surface. Runtime lifecycle controls remain on Runtime.", "モデルプロファイルをこの画面で管理します。ランタイムのライフサイクル操作はランタイム画面に分けています。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-header")
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker(t("Source", "ソース"), selection: $viewModel.modelListSourceFilter) {
                ForEach(viewModel.modelListSourceFilterOptions, id: \.self) { source in
                    Text(source).tag(source)
                }
            }
            .frame(width: 190)

            TextField(t("Search models", "モデルを検索"), text: $viewModel.modelListSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, idealWidth: 240)

            Spacer()

            Button {
                viewModel.addProfileRequested()
            } label: {
                Label(t("Add", "追加"), systemImage: "plus")
            }

            Button {
                viewModel.editProfileRequested()
            } label: {
                Label(t("Edit", "編集"), systemImage: "pencil")
            }
            .disabled(selectedModel == nil)

            Button(role: .destructive) {
                viewModel.deleteProfileRequested()
            } label: {
                Label(t("Delete", "削除"), systemImage: "trash")
            }
            .disabled(selectedModel == nil || viewModel.models.count <= 1 || viewModel.isManagedProcessRunning)

            Divider()
                .frame(height: 24)

            Button {
                viewModel.importProfilesPreviewRequested()
            } label: {
                Label(t("Import", "インポート"), systemImage: "square.and.arrow.down")
            }

            Button {
                viewModel.exportProfilesRequested()
            } label: {
                Label(t("Export", "エクスポート"), systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.models.isEmpty)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard(t("Profiles", "プロファイル"), value: String(viewModel.models.count))
            summaryCard(t("Visible", "表示中"), value: String(models.count))
            summaryCard(t("Selected", "選択中"), value: selectedModel?.displayName ?? t("None", "なし"))
            summaryCard(t("Running", "実行中"), value: runningModel?.displayName ?? t("None", "なし"))
            summaryCard(t("Restart required", "再起動必要"), value: viewModel.restartRequired ? t("Yes", "はい") : t("No", "いいえ"))
        }
        .accessibilityIdentifier("profiles-surface-summary")
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Model Profiles", "モデルプロファイル"))
                .font(.headline)
                .accessibilityIdentifier("profiles-surface-list-heading")

            if models.isEmpty {
                ContentUnavailableView(
                    t("No models for this filter", "このフィルターに一致するモデルはありません"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(t("Change the source filter to show other profiles.", "ほかのプロファイルを表示するにはソースフィルターを変更してください。"))
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(models) { model in
                        Button {
                            viewModel.selectedModelID = model.id
                        } label: {
                            profileCard(model)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityIdentifier("profiles-surface-profile-list")
            }
        }
    }

    private func summaryCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-summary-\(sanitizedIdentifier(title.lowercased()))")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            t("No Models", "モデルがありません"),
            systemImage: "square.stack.3d.up",
            description: Text(t("Add models from Downloads or use Add to create a profile manually.", "ダウンロード画面からモデルを追加するか、追加ボタンで手動プロファイルを作成してください。"))
        )
        .frame(maxWidth: .infinity, minHeight: 240)
        .accessibilityIdentifier("profiles-surface-empty-state")
    }

    private func profileCard(_ model: ModelConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                    Text(model.modelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    statusPill(viewModel.sourceLabel(for: model))
                    if model.id == viewModel.selectedModelID {
                        statusPill(t("Selected", "選択中"))
                    }
                    if model.id == viewModel.runningModelID {
                        statusPill(t("Running", "実行中"))
                    }
                    if viewModel.restartRequired, model.id == viewModel.selectedModelID {
                        statusPill(t("Restart required", "再起動必要"))
                    }
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    metadataLabel(t("Family", "ファミリー"))
                    metadataValue(model.family)
                }
                GridRow {
                    metadataLabel(t("Endpoint", "エンドポイント"))
                    metadataValue("\(model.host):\(model.serverPort)")
                }
                GridRow {
                    metadataLabel("Thinking")
                    metadataValue(model.enableThinking ? t("Enabled", "有効") : t("Disabled", "無効"))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(model.id == viewModel.selectedModelID ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profiles-surface-profile-\(sanitizedIdentifier(model.id))")
    }

    private var selectedModelInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Selected model inspector", "選択モデルインスペクター"))
                .font(.headline)

            if let selectedModel {
                DetailGrid(rows: [
                    ("Model ID", selectedModel.modelID),
                    (t("Display Name", "表示名"), selectedModel.displayName),
                    (t("Source", "ソース"), viewModel.sourceLabel(for: selectedModel)),
                    (t("Family", "ファミリー"), selectedModel.family),
                    (t("Quantization", "量子化"), selectedModel.quantization),
                    (t("Context", "コンテキスト"), selectedModel.contextWindow),
                    (t("Endpoint", "エンドポイント"), "\(selectedModel.host):\(selectedModel.serverPort)"),
                    ("Thinking", selectedModel.enableThinking ? t("Enabled", "有効") : t("Disabled", "無効")),
                    (t("Latest benchmark", "最新ベンチマーク"), viewModel.latestBenchmarkResult?.latencyText ?? t("Not run", "未実行")),
                    (t("Notes", "メモ"), selectedModel.notes.isEmpty ? t("None", "なし") : selectedModel.notes)
                ])

                Text(t("Advanced launch options", "詳細起動オプション"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedAdvancedLaunchOptionsSummary)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(6)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(t("Launch command", "起動コマンド"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedLaunchCommandPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Label(t("Profile actions are metadata-only. Model files and Hugging Face cache are not deleted.", "プロファイル操作はメタデータのみを対象にします。モデルファイルとHugging Faceキャッシュは削除されません。"), systemImage: "shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(t("Select a model profile to inspect its details.", "詳細を確認するモデルプロファイルを選択してください。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityIdentifier("models-surface-selected-inspector")
    }

    private func metadataLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func metadataValue(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func sanitizedIdentifier(_ value: String) -> String {
        value
            .map { character in
                character.isLetter || character.isNumber ? character : "-"
            }
            .reduce(into: "") { result, character in
                result.append(character)
            }
    }
}
