import SwiftUI

struct AutomationSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenDiagnostics: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    @State private var runbooks = AutomationStore.loadRunbooks()
    @State private var history = AutomationStore.loadHistory()
    @State private var runningRunbookID: String?
    @State private var automationTask: Task<Void, Never>?

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    safetyCard
                    runbookSection
                    historySection
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            automationTask?.cancel()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Automation", "自動化"))
                    .font(.title3)
                Text(t("Run explicit operational checklists without hidden background actions.", "隠れたバックグラウンド操作を行わず、明示的な運用チェックリストを実行します。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let runningRunbookID,
               let runbook = runbooks.first(where: { $0.id == runningRunbookID }) {
                ProgressView()
                    .controlSize(.small)
                Text(runbookName(runbook))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(t("Cancel", "中止")) {
                    cancelCurrentRun()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("Explicit execution only", "明示実行のみ"), systemImage: "hand.raised.fill")
                .font(.headline)
            Text(t(
                "Runbooks start only when you press Run. They never start, stop, restart, download, delete, or reconfigure a model automatically.",
                "Runbookは「実行」を押した場合にのみ開始します。モデルの起動、停止、再起動、ダウンロード、削除、設定変更を自動では行いません。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
    }

    private var runbookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Runbooks", "Runbook"))
                .font(.headline)
            ForEach($runbooks) { $runbook in
                runbookCard($runbook)
            }
        }
    }

    private func runbookCard(_ runbook: Binding<AutomationRunbook>) -> some View {
        let value = runbook.wrappedValue
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: runbookImage(value.id))
                .font(.title2)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(runbookName(value))
                        .font(.headline)
                    Text(value.isEnabled ? t("Enabled", "有効") : t("Disabled", "無効"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(value.isEnabled ? .green : .secondary)
                }
                Text(runbookDescription(value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(value.steps) { step in
                        Text(stepTitle(step))
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                    }
                }
            }
            Spacer()
            Toggle(t("Enabled", "有効"), isOn: runbook.isEnabled)
                .labelsHidden()
                .onChange(of: runbook.wrappedValue.isEnabled) { _, _ in
                    AutomationStore.saveRunbooks(runbooks)
                }
            Button(t("Run", "実行")) {
                execute(value)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!value.isEnabled || runningRunbookID != nil)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.25)) }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Execution History", "実行履歴"))
                    .font(.headline)
                Spacer()
                Button(t("Clear History", "履歴を消去")) {
                    history = []
                    AutomationStore.clearHistory()
                }
                .disabled(history.isEmpty || runningRunbookID != nil)
            }
            if history.isEmpty {
                Text(t("No runbooks have been executed.", "実行済みのRunbookはありません。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(history) { record in
                    historyRow(record)
                }
            }
        }
    }

    private func historyRow(_ record: AutomationRunRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusImage(record.status))
                .foregroundStyle(statusColor(record.status))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.runbookName)
                    .font(.subheadline.weight(.semibold))
                Text(record.targetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.summary)
                    .font(.caption)
                Text(record.completedAt.formatted(date: .abbreviated, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(statusTitle(record.status))
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor(record.status))
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func execute(_ runbook: AutomationRunbook) {
        guard runningRunbookID == nil else { return }
        let startedAt = Date()
        runningRunbookID = runbook.id
        automationTask = Task { @MainActor in
            var completed: [AutomationStepKind] = []
            var needsAttention = false

            for step in runbook.steps {
                guard !Task.isCancelled else {
                    finish(runbook, startedAt: startedAt, completed: completed, status: .cancelled)
                    return
                }
                switch step {
                case .diagnostics:
                    viewModel.runDiagnosticsRequested()
                    completed.append(step)
                    for _ in 0..<120 where viewModel.isDiagnosticsRunning {
                        try? await Task.sleep(for: .milliseconds(250))
                        if Task.isCancelled { break }
                    }
                    needsAttention = needsAttention || viewModel.diagnosticsResults.contains { $0.status != .pass }
                case .hermesInspection:
                    let inspected = viewModel.inspectHermesAgentConfigRequested()
                    completed.append(step)
                    needsAttention = needsAttention || !inspected || !viewModel.hermesAgentPendingChangeKeys.isEmpty
                case .openDiagnostics:
                    onOpenDiagnostics()
                    completed.append(step)
                case .openSettings:
                    onOpenSettings()
                    completed.append(step)
                }
            }
            finish(
                runbook,
                startedAt: startedAt,
                completed: completed,
                status: needsAttention ? .completedWithAttention : .succeeded
            )
        }
    }

    private func cancelCurrentRun() {
        automationTask?.cancel()
        viewModel.cancelDiagnostics(reason: "the automation runbook was cancelled")
    }

    private func finish(
        _ runbook: AutomationRunbook,
        startedAt: Date,
        completed: [AutomationStepKind],
        status: AutomationRunStatus
    ) {
        let record = AutomationRunRecord(
            runbookID: runbook.id,
            runbookName: runbookName(runbook),
            targetName: viewModel.selectedModel?.displayName ?? t("Default endpoint", "既定エンドポイント"),
            startedAt: startedAt,
            status: status,
            completedSteps: completed,
            summary: summaryText(status, completedCount: completed.count, totalCount: runbook.steps.count)
        )
        history = AutomationStore.record(record, history: history)
        runningRunbookID = nil
        automationTask = nil
    }

    private func runbookName(_ runbook: AutomationRunbook) -> String {
        switch runbook.nameKey {
        case "readinessAudit": t("Readiness Audit", "準備状態監査")
        case "diagnosticsCheck": t("Diagnostics Check", "診断チェック")
        case "hermesAudit": t("Hermes Agent Audit", "Hermes Agent監査")
        default: runbook.nameKey
        }
    }

    private func runbookDescription(_ runbook: AutomationRunbook) -> String {
        switch runbook.descriptionKey {
        case "readinessAuditDescription": t("Run diagnostics and inspect Hermes Agent configuration for the selected profile.", "選択中プロファイルの診断とHermes Agent設定検査を実行します。")
        case "diagnosticsCheckDescription": t("Run setup diagnostics, then open the detailed results.", "セットアップ診断を実行し、詳細結果を開きます。")
        case "hermesAuditDescription": t("Inspect Hermes Agent configuration, then open Settings for review.", "Hermes Agent設定を検査し、確認用に設定画面を開きます。")
        default: runbook.descriptionKey
        }
    }

    private func stepTitle(_ step: AutomationStepKind) -> String {
        switch step {
        case .diagnostics: t("Diagnostics", "診断")
        case .hermesInspection: t("Hermes inspection", "Hermes検査")
        case .openDiagnostics: t("Open results", "結果を開く")
        case .openSettings: t("Open settings", "設定を開く")
        }
    }

    private func runbookImage(_ id: String) -> String {
        switch id {
        case "readiness-audit": "checklist"
        case "diagnostics-check": "stethoscope"
        default: "point.3.connected.trianglepath.dotted"
        }
    }

    private func summaryText(_ status: AutomationRunStatus, completedCount: Int, totalCount: Int) -> String {
        switch status {
        case .succeeded: t("All \(totalCount) steps completed without detected issues.", "全\(totalCount)ステップが問題なく完了しました。")
        case .completedWithAttention: t("All \(totalCount) steps completed; review the detected items.", "全\(totalCount)ステップが完了しました。検出項目を確認してください。")
        case .cancelled: t("Cancelled after \(completedCount) of \(totalCount) steps.", "全\(totalCount)ステップ中\(completedCount)ステップ後に中止しました。")
        }
    }

    private func statusTitle(_ status: AutomationRunStatus) -> String {
        switch status {
        case .succeeded: t("Succeeded", "成功")
        case .completedWithAttention: t("Needs review", "要確認")
        case .cancelled: t("Cancelled", "中止")
        }
    }

    private func statusImage(_ status: AutomationRunStatus) -> String {
        switch status {
        case .succeeded: "checkmark.circle.fill"
        case .completedWithAttention: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: AutomationRunStatus) -> Color {
        switch status {
        case .succeeded: .green
        case .completedWithAttention: .orange
        case .cancelled: .secondary
        }
    }
}
