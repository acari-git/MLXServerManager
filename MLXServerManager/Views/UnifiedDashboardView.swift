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
            dashboardWorkflowBanner

            Divider()

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
                    firstLaunchSetupPanel
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

    private var dashboardWorkflowBanner: some View {
        HStack(spacing: 12) {
            Text("MLX Server Manager")
                .font(.headline)
            Spacer()
            workflowStep("Search")
            workflowStep("Download")
            workflowStep("Register")
            workflowStep("Start")
            workflowStep("Copy")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .accessibilityIdentifier("unified-dashboard-workflow-banner")
    }

    private func workflowStep(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
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

    private var firstLaunchSetupPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("初回セットアップ")
                .font(.headline)

            Text("まずここを順番に確認します。Direct Mode なので、クライアントは mlx_lm.server に直接接続します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            setupCheckRow(
                title: "mlx_lm.server executable path",
                isComplete: !viewModel.settings.mlxServerExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                detail: viewModel.settings.mlxServerExecutablePath.isEmpty ? "Settings で設定" : ModelAvailabilityPathFormatter.compact(path: viewModel.settings.mlxServerExecutablePath)
            )
            setupCheckRow(
                title: "Hugging Face CLI",
                isComplete: viewModel.isHuggingFaceCLIAvailable,
                detail: viewModel.huggingFaceCLIPath
            )
            setupCheckRow(
                title: "Model profile",
                isComplete: !viewModel.models.isEmpty,
                detail: viewModel.models.isEmpty ? "検索・ダウンロード・ローカル登録のいずれかで追加" : "\(viewModel.models.count) profiles"
            )
            setupCheckRow(
                title: "Default endpoint",
                isComplete: true,
                detail: "\(viewModel.settings.defaultHost):\(viewModel.settings.defaultPort)"
            )
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-first-launch-setup")
    }

    private func setupCheckRow(title: String, isComplete: Bool, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isComplete ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            HStack {
                Text("Hugging Face 検索")
                    .font(.headline)
                Spacer()
                if viewModel.isHuggingFaceSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Text("検索して候補を選ぶと、Download form に Model ID を反映します。検索は明示ボタンのみで実行します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("例: qwen mlx 4bit", text: $viewModel.huggingFaceSearchQuery)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("hf-search-query")

            Text(viewModel.huggingFaceSearchMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("MLX-like の候補だけ表示", isOn: $viewModel.showOnlyMLXLikelySearchResults)
                .toggleStyle(.checkbox)
                .disabled(viewModel.huggingFaceSearchResults.isEmpty)

            Button {
                viewModel.performHuggingFaceSearchRequested()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isHuggingFaceSearching)
            .accessibilityIdentifier("hf-search-run")

            if !viewModel.visibleHuggingFaceSearchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(viewModel.visibleHuggingFaceSearchResults.enumerated()), id: \.element.id) { _, result in
                            Button {
                                viewModel.selectHuggingFaceSearchResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(result.id)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        if result.isMLXLikely {
                                            Text("MLX")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.18))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(result.qualitySummary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(result.selectionWarning)
                                        .font(.caption2)
                                        .foregroundStyle(result.isMLXLikely ? Color.secondary : Color.orange)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            if let selected = viewModel.selectedHuggingFaceSearchResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model detail preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    DetailGrid(rows: [
                        ("Repo", selected.id),
                        ("Owner", selected.owner),
                        ("Name", selected.name),
                        ("Stats", selected.qualitySummary),
                        ("Tags", selected.tagsSummary),
                        ("URL", selected.webURL)
                    ])
                    Button {
                        viewModel.copySelectedHuggingFaceModelURL()
                    } label: {
                        Label("Hugging Face URL をコピー", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
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

            if !viewModel.huggingFaceDownloadQueue.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Download queue")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.huggingFaceDownloadQueueSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.huggingFaceDownloadQueue.prefix(5)) { entry in
                        HStack {
                            Text(entry.repositoryID)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(entry.phase.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.compactDestinationPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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

            if status.phase == .completed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Download completed. The model is in the list. Next: Start it or copy connection values after it is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            viewModel.startRequested()
                        } label: {
                            Label("このモデルを起動", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            viewModel.copyAllConnectionSettings()
                        } label: {
                            Label("接続情報をコピー", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(8)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    viewModel.retryHuggingFaceDownloadRequested()
                } label: {
                    Text("Retry")
                }
                .disabled(!viewModel.canRetryHuggingFaceDownload)

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

            if let hint = startRecoveryHint {
                Label(hint, systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .panelStyle()
        .accessibilityIdentifier("unified-dashboard-runtime-status")
    }

    private var hermesConnectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hermes Agent 接続情報")
                .font(.headline)

            Text(viewModel.connectionTargetSummary.isActiveTarget ? "起動中です。以下を OpenAI互換クライアントへ貼り付けます。" : "未起動です。起動後にこの値をクライアントへ貼り付けます。")
                .font(.caption)
                .foregroundStyle(viewModel.connectionTargetSummary.isActiveTarget ? .green : .secondary)

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

            Button {
                viewModel.copyModelsCurl()
            } label: {
                Text("/v1/models 確認 curl をコピー")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
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

    private var startRecoveryHint: String? {
        switch viewModel.runtimeState {
        case let .error(message):
            if message.localizedCaseInsensitiveContains("executable") {
                return "Settings で mlx_lm.server executable path を確認してください。"
            }
            if message.localizedCaseInsensitiveContains("model path") {
                return "モデル一覧で別モデルを選ぶか、ローカルモデルフォルダを登録し直してください。"
            }
            return "ログの直前の preflight / process メッセージを確認してください。"
        case .portBusy:
            return "別のポートへ変更するか、既存サーバーを停止してください。"
        case .readyCheckFailed:
            return "サーバー起動直後の読み込みに時間がかかっている可能性があります。ログを確認してください。"
        default:
            return nil
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
                        HStack(spacing: 6) {
                            Text(sourceBadgeText)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(sourceBadgeColor.opacity(0.15))
                                .foregroundStyle(sourceBadgeColor)
                                .clipShape(Capsule())
                            Text(model.notes.isEmpty ? model.modelID : model.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
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

    private var sourceBadgeText: String {
        if ModelAvailabilityPathFormatter.localPathCandidate(for: model) != nil {
            return model.notes.localizedCaseInsensitiveContains("downloaded") ? "Downloaded" : "Local"
        }
        return model.modelID.contains("/") ? "HF ID" : "Advanced"
    }

    private var sourceBadgeColor: Color {
        switch sourceBadgeText {
        case "Downloaded":
            return .green
        case "Local":
            return .blue
        case "HF ID":
            return .orange
        default:
            return .secondary
        }
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
