import SwiftUI

struct UnifiedDashboardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HSplitView {
            mainColumn
                .frame(minWidth: 560, idealWidth: 760)

            rightInspectorColumn
                .frame(minWidth: 340, idealWidth: 390, maxWidth: 460)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("unified-dashboard")
    }

    private var mainColumn: some View {
        VStack(spacing: 0) {
            modelListPanel

            Divider()

            primaryActionBar

            Divider()

            unifiedLogPanel

            systemStatusRibbon

            statusFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("unified-dashboard-main-column")
    }

    private var rightInspectorColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.isProfileEditorPresented {
                    ModelProfileEditorView(
                        draft: $viewModel.profileEditorDraft,
                        title: "Edit Model Profile",
                        saveButtonTitle: "Save Profile",
                        noticeMessage: nil,
                        message: viewModel.profileEditorMessage,
                        runtimeFieldsLocked: viewModel.isManagedProcessRunning,
                        onSave: viewModel.saveProfileEditing,
                        onCancel: viewModel.cancelProfileEditing,
                        onCopyPreview: viewModel.copyLaunchCommandPreview
                    )
                } else if viewModel.isAddProfilePresented {
                    ModelProfileEditorView(
                        draft: $viewModel.addProfileDraft,
                        title: "Add Model Profile",
                        saveButtonTitle: "Save New Profile",
                        noticeMessage: viewModel.isManagedProcessRunning
                            ? "Saving a new profile will not change the running managed server. Stop the managed server before switching runtime profile."
                            : nil,
                        message: viewModel.addProfileMessage,
                        runtimeFieldsLocked: false,
                        onSave: viewModel.saveNewProfile,
                        onCancel: viewModel.cancelAddProfile,
                        onCopyPreview: viewModel.copyLaunchCommandPreview
                    )
                } else {
                    modelAddFlowGuidePanel
                    huggingFaceSearchFoundationPanel
                    localModelRegistrationPanel
                    huggingFaceDownloadPanel
                    selectedModelSettingsPanel
                    availabilityPanel
                    runtimeStatusPanel
                    hermesConnectionPanel
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .accessibilityIdentifier("unified-dashboard-right-inspector")
    }

    private var modelListPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("モデル一覧")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    viewModel.importProfilesPreviewRequested()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button {
                    viewModel.exportProfilesRequested()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.models.isEmpty)

                Button {
                    viewModel.addProfileRequested()
                } label: {
                    Label("モデル追加", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if let message = viewModel.modelProfileExportMessage ?? viewModel.modelProfileImportMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(spacing: 0) {
                modelListHeader

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.models) { model in
                            UnifiedModelRow(
                                model: model,
                                isSelected: model.id == viewModel.selectedModelID,
                                isRunning: model.id == viewModel.runningModelID,
                                runtimeState: model.id == viewModel.runningModelID ? viewModel.runtimeState : .stopped,
                                memoryUsageText: model.id == viewModel.runningModelID ? compactMemoryText : "-",
                                restartRequired: viewModel.restartRequired && model.id == viewModel.selectedModelID,
                                onSelect: {
                                    viewModel.selectedModelID = model.id
                                }
                            )

                            Divider()
                        }
                    }
                }
                .frame(minHeight: 210)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .padding(14)
        .accessibilityIdentifier("unified-dashboard-model-list")
    }

    private var modelListHeader: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                tableHeader("モデル名 / 用途", width: 210)
                tableHeader("ステータス", width: 92)
                tableHeader("サーバーポート", width: 96)
                tableHeader("メモリ使用量", width: 92)
                tableHeader("自動アンロード", width: 100)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func tableHeader(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private var primaryActionBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.startRequested()
            } label: {
                Label("起動", systemImage: "play.fill")
                    .frame(minWidth: 92)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("unified-dashboard-start")

            Button {
                viewModel.stopRequested()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .frame(minWidth: 92)
            }
            .disabled(!viewModel.canStopManagedServer)
            .accessibilityIdentifier("unified-dashboard-stop")

            Button {
                viewModel.restartRequested()
            } label: {
                Label("再起動", systemImage: "arrow.clockwise")
                    .frame(minWidth: 92)
            }
            .disabled(!viewModel.canRestartManagedServer)
            .accessibilityIdentifier("unified-dashboard-restart")

            Button {
                viewModel.checkPortRequested()
            } label: {
                Label("ポート確認", systemImage: "network")
            }

            Button {
                viewModel.checkReadyRequested()
            } label: {
                Label("Ready確認", systemImage: "checkmark.seal")
            }

            Spacer()

            Button {
            } label: {
                Label("スピードテスト", systemImage: "bolt")
            }
            .disabled(true)
            .help("v7.1.0 は GUI foundation release です。Speed Test は後続リリースで明示操作として実装します。")
        }
        .padding(14)
        .accessibilityIdentifier("unified-dashboard-action-bar")
    }

    private var unifiedLogPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ログ")
                    .font(.headline)

                Text("\(viewModel.logEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.copyLogsRequested()
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                }

                Button {
                    viewModel.clearLogsRequested()
                } label: {
                    Label("クリア", systemImage: "trash")
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if viewModel.logEntries.isEmpty {
                        Text("No logs")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(viewModel.logEntries) { entry in
                            compactLogRow(entry)
                        }
                    }
                }
                .padding(12)
            }
            .frame(minHeight: 210)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("unified-dashboard-log-panel")
    }

    private func compactLogRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.category)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(logColor(for: entry))
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func logColor(for entry: LogEntry) -> Color {
        let category = entry.category.lowercased()
        if category.contains("error") || entry.message.localizedCaseInsensitiveContains("failed") {
            return .red
        }
        if category.contains("warning") || entry.message.localizedCaseInsensitiveContains("warning") {
            return .orange
        }
        if ["start", "restart", "ready"].contains(category) {
            return .green
        }
        if ["profile", "model", "diagnostics", "availability"].contains(category) {
            return .purple
        }
        return .secondary
    }

    private var systemStatusRibbon: some View {
        HStack(spacing: 10) {
            statusPill("Manager", value: viewModel.runtimeState.title)
            statusPill("Profiles", value: String(viewModel.models.count))
            statusPill("hf CLI", value: viewModel.isHuggingFaceCLIAvailable ? viewModel.huggingFaceCLIPath : "Missing")
            statusPill("Mode", value: "Direct")
            Spacer()
            Text("初心者向け導線: download/register → select → start → copy")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .accessibilityIdentifier("unified-dashboard-system-ribbon")
    }

    private func statusPill(_ label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(Capsule())
    }

    private var statusFooter: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
            Text("全体ステータス: \(viewModel.runtimeState.title)")
                .font(.caption.weight(.semibold))
            Text(viewModel.runtimeState.badgeDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Direct Mode: client -> mlx_lm.server")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityIdentifier("unified-dashboard-status-footer")
    }

    private var modelAddFlowGuidePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("モデル追加フロー")
                .font(.headline)

            Text("CLIに不慣れなユーザー向けに、モデル取得とプロファイル追加を明確に分けています。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                acquisitionRow(
                    title: "1. Hugging Face からダウンロード",
                    detail: "ID / URL を貼り、保存後にモデル一覧へ自動追加します。"
                )
                acquisitionRow(
                    title: "2. ダウンロード済みローカルモデルを追加",
                    detail: "既に保存済みのローカルフォルダをプロファイル化します。v7.5.0 で追加します。"
                )
                acquisitionRow(
                    title: "3. 上級者向けプロファイル追加",
                    detail: "Hugging Face ID や任意の起動引数を直接設定します。"
                )
            }

            Button {
                viewModel.addProfileRequested()
            } label: {
                Label("上級者向けプロファイルを追加", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-model-add-flow")
    }

    private func acquisitionRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var huggingFaceSearchFoundationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hugging Face 検索準備")
                .font(.headline)

            Text("oMLX のような検索は後続実装です。ここでは検索導線だけを独立させ、ID / URL ダウンロードと混同しないようにします。")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("例: qwen mlx 4bit", text: $viewModel.huggingFaceSearchQuery)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("hf-search-query")

            Text(viewModel.huggingFaceSearchMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                viewModel.prepareHuggingFaceSearchRequested()
            } label: {
                Label("検索条件を準備", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("hf-search-prepare")
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-hf-search-foundation")
    }

    private var localModelRegistrationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ローカルモデルを追加")
                .font(.headline)

            Text("既にダウンロード済みのモデルフォルダを、モデル一覧へ local path profile として追加します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("ローカルモデルフォルダ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("~/Models/mlx/model-name", text: $viewModel.localModelPath)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("local-model-path")
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("表示名")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("フォルダ名から自動入力", text: $viewModel.localModelDisplayName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Port")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("8080", text: $viewModel.localModelPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 76)
                }
            }

            Toggle("Thinking を有効にする", isOn: $viewModel.localModelEnableThinking)
                .toggleStyle(.checkbox)

            Text(viewModel.localModelMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                viewModel.registerLocalModelRequested()
            } label: {
                Label("ローカルモデルを一覧に追加", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("local-model-add")
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-local-model-registration")
    }

    private var huggingFaceDownloadPanel: some View {
        let preview = viewModel.huggingFaceDownloadPreview
        let status = viewModel.huggingFaceDownloadStatus
        let isRunning = viewModel.isHuggingFaceDownloadRunning

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hugging Face から追加")
                    .font(.headline)
                Spacer()
                Text(status.phase.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.phase == .completed ? Color.green : Color.secondary)
            }

            Text("Model ID または huggingface.co のURLを貼ると、保存後にモデル一覧へ自動追加します。検索は後続リリースで追加します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Model ID / URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("mlx-community/model-name or https://huggingface.co/...", text: $viewModel.huggingFaceDownloadDraft.source)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isRunning)
                    .accessibilityIdentifier("hf-download-source")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("保存先フォルダ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("~/Models/mlx", text: $viewModel.huggingFaceDownloadDraft.saveDirectory)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isRunning)
                    .accessibilityIdentifier("hf-download-save-directory")
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("表示名")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("モデル名から自動入力", text: $viewModel.huggingFaceDownloadDraft.displayName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isRunning)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Port")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("8080", text: $viewModel.huggingFaceDownloadDraft.serverPortText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 76)
                        .disabled(isRunning)
                }
            }

            Toggle("Thinking を有効にする", isOn: $viewModel.huggingFaceDownloadDraft.enableThinking)
                .toggleStyle(.checkbox)
                .disabled(isRunning)

            Toggle("完了後にモデル一覧へ自動追加", isOn: $viewModel.huggingFaceDownloadDraft.autoAddToModelList)
                .toggleStyle(.checkbox)
                .disabled(isRunning)

            Toggle("追加したモデルを自動選択", isOn: $viewModel.huggingFaceDownloadDraft.autoSelectAfterAdd)
                .toggleStyle(.checkbox)
                .disabled(isRunning || !viewModel.huggingFaceDownloadDraft.autoAddToModelList)

            if !viewModel.isHuggingFaceCLIAvailable {
                Label(viewModel.huggingFaceCLIMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            DetailGrid(rows: [
                ("hf CLI", viewModel.isHuggingFaceCLIAvailable ? "Available" : "Missing"),
                ("hf Path", viewModel.huggingFaceCLIPath),
                ("Repository", preview.reference?.repositoryID ?? "未確定"),
                ("Save to", preview.compactDestinationPath),
                ("Destination", preview.destinationNote),
                ("Display", preview.displayName),
                ("Status", status.message)
            ])

            if isRunning {
                if let progress = status.progress {
                    ProgressView(value: progress)
                        .accessibilityIdentifier("hf-download-progress")
                } else {
                    ProgressView()
                        .accessibilityIdentifier("hf-download-progress")
                }
            } else if status.phase == .completed {
                ProgressView(value: 1)
                    .accessibilityIdentifier("hf-download-progress-completed")
            }

            if !status.outputLines.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(status.outputLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 82, maxHeight: 120)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }

            HStack {
                Button {
                    viewModel.startHuggingFaceDownloadRequested()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartHuggingFaceDownload)
                .accessibilityIdentifier("hf-download-start")

                Button {
                    viewModel.refreshHuggingFaceCLIRequested()
                } label: {
                    Text("Retry CLI")
                }
                .disabled(isRunning)
                .accessibilityIdentifier("hf-cli-retry")

                Button {
                    viewModel.cancelHuggingFaceDownloadRequested()
                } label: {
                    Text("Cancel")
                }
                .disabled(!isRunning)
                .accessibilityIdentifier("hf-download-cancel")
            }
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-hf-download")
    }

    private var selectedModelSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("モデル設定")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    viewModel.deleteProfileRequested()
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .disabled(viewModel.selectedModel == nil)
            }

            if let message = viewModel.profileDeletionMessage, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let model = viewModel.selectedModel {
                DetailGrid(rows: [
                    ("モデル名", model.displayName),
                    ("モデルID", model.modelID),
                    ("用途・メモ", model.notes.isEmpty ? "未設定" : model.notes),
                    ("サーバーポート", String(model.serverPort)),
                    ("ホスト", model.host),
                    ("Thinking", model.enableThinking ? "Enabled" : "Disabled"),
                    ("Family", model.family),
                    ("Quantization", model.quantization)
                ])

                Button {
                    viewModel.editProfileRequested()
                } label: {
                    Label("選択モデルを編集", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("モデルを選択してください。")
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-model-settings")
    }

    private var availabilityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("モデル可用性")
                    .font(.headline)
                Spacer()
                Text(viewModel.modelAvailabilitySummary.state.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.modelAvailabilitySummary.state == .present ? Color.green : Color.secondary)
            }

            DetailGrid(rows: [
                ("Status", viewModel.modelAvailabilitySummary.state.title),
                ("Target", viewModel.modelAvailabilitySummary.configuredTarget),
                ("Path", viewModel.modelAvailabilitySummary.checkedPathSummary),
                ("Scope", viewModel.modelAvailabilitySummary.scopeText)
            ])

            Button {
                viewModel.checkModelAvailabilityRequested()
            } label: {
                Label("Check Model Availability", systemImage: "magnifyingglass")
            }
            .disabled(!viewModel.modelAvailabilitySummary.canCheck)
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-availability")
    }

    private var runtimeStatusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("状態情報")
                .font(.headline)

            DetailGrid(rows: [
                ("ステータス", viewModel.runtimeState.title),
                ("詳細", viewModel.runtimeState.badgeDetail),
                ("選択モデル", viewModel.selectedModelIdentifier),
                ("稼働モデル", viewModel.runningModelID ?? "Not running"),
                ("メモリ使用量", viewModel.memoryUsageText),
                ("再起動必要", viewModel.restartRequired ? "Yes" : "No")
            ])
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-runtime-status")
    }

    private var hermesConnectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hermes Agent 接続情報")
                .font(.headline)

            copyRow("Base URL", value: viewModel.baseURL, action: viewModel.copyBaseURL)
            copyRow("API Key", value: viewModel.apiKeyPlaceholder, action: viewModel.copyAPIKeyPlaceholder)
            copyRow("Model", value: viewModel.selectedModelIdentifier, action: viewModel.copyModelID)

            Button {
                viewModel.copyAllConnectionSettings()
            } label: {
                Text("Hermes 設定をまとめてコピー")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-connection")
    }

    private func copyRow(_ label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                action()
            } label: {
                Text("コピー")
            }
        }
    }

    private var compactMemoryText: String {
        viewModel.memoryUsageText.replacingOccurrences(of: "Memory: ", with: "")
    }

    private var statusColor: Color {
        switch viewModel.runtimeState {
        case .ready, .portAvailable:
            .green
        case .starting, .loading, .stopping, .checkingPort, .checkingReady, .externalServerDetected, .adoptedExternalServer:
            .orange
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error:
            .red
        case .unknown:
            .yellow
        case .stopped:
            .secondary
        }
    }
}

private struct UnifiedModelRow: View {
    let model: ModelConfig
    let isSelected: Bool
    let isRunning: Bool
    let runtimeState: ModelRuntimeState
    let memoryUsageText: String
    let restartRequired: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(model.notes.isEmpty ? model.modelID : model.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 210, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        if restartRequired {
                            Text("再起動必要")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(width: 92, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(model.serverPort))
                            .font(.body.weight(.medium))
                        Text(model.host)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 96, alignment: .leading)

                    Text(memoryUsageText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isRunning ? .green : .secondary)
                        .frame(width: 92, alignment: .leading)

                    Text("手動")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("unified-dashboard-model-row-\(model.id)")
    }

    private var statusText: String {
        if isRunning {
            return runtimeState.title
        }

        return isSelected ? "Selected" : "Stopped"
    }

    private var statusColor: Color {
        if isRunning {
            switch runtimeState {
            case .ready, .portAvailable:
                return .green
            case .starting, .loading, .checkingReady, .checkingPort:
                return .orange
            case .error, .portBusy, .portCheckFailed, .readyCheckFailed:
                return .red
            default:
                return .secondary
            }
        }

        return isSelected ? .accentColor : .secondary
    }
}
