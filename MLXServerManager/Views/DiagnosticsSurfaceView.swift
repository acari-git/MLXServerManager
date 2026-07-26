import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenSettings: () -> Void = {}
    var onOpenDashboard: () -> Void = {}
    @State private var searchText = ""
    @State private var statusFilter: DiagnosticsStatusFilter = .all
    @State private var isHistoryPresented = false
    @State private var comparisonCurrentID: UUID?
    @State private var comparisonPreviousID: UUID?

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var overview: DiagnosticsOverview {
        DiagnosticsOverview(results: viewModel.diagnosticsResults)
    }

    private var visibleResults: [DiagnosticsResult] {
        overview.filtered(status: statusFilter, searchText: searchText)
    }

    private var targetKey: String {
        viewModel.selectedModel?.id ?? "default:\(viewModel.settings.defaultHost):\(viewModel.settings.defaultPort)"
    }

    private var targetHistory: [DiagnosticsSnapshot] {
        DiagnosticsHistoryStore.snapshots(for: targetKey, in: viewModel.diagnosticsHistory)
    }

    private var latestComparison: DiagnosticsComparison? {
        guard let current = targetHistory.first else { return nil }
        return DiagnosticsComparison.compare(current: current, previous: targetHistory.dropFirst().first)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.isDiagnosticsRunning {
                ProgressView(t("Running diagnostics…", "診断を実行中…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.diagnosticsDidRun {
                ContentUnavailableView {
                    Label(t("Diagnostics have not run", "診断はまだ実行されていません"), systemImage: "stethoscope")
                } description: {
                    Text(t("Run diagnostics for the currently selected profile and endpoint.", "現在選択中のプロファイルとエンドポイントを診断します。"))
                } actions: {
                    Button(t("Run Diagnostics", "診断を実行")) {
                        viewModel.runDiagnosticsRequested()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    summaryBar
                    historyBar
                    Divider()
                    if visibleResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(visibleResults) { result in
                                    resultCard(result)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isHistoryPresented) {
            historySheet
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Diagnostics", "診断"))
                    .font(.title3)
                Text(t("Review setup, endpoint, and readiness checks for the selected profile.", "選択中プロファイルの設定、エンドポイント、準備状態を確認します。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField(t("Search diagnostics", "診断を検索"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            Picker(t("Status", "状態"), selection: $statusFilter) {
                Text(t("All", "すべて")).tag(DiagnosticsStatusFilter.all)
                Text(t("Failures", "失敗")).tag(DiagnosticsStatusFilter.fail)
                Text(t("Warnings", "警告")).tag(DiagnosticsStatusFilter.warning)
                Text(t("Passed", "成功")).tag(DiagnosticsStatusFilter.pass)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            Button {
                prepareHistorySelection()
                isHistoryPresented = true
            } label: {
                Label(t("History", "履歴"), systemImage: "clock.arrow.circlepath")
            }
            .disabled(targetHistory.isEmpty)
            Button {
                viewModel.runDiagnosticsRequested()
            } label: {
                Label(t("Run Again", "再実行"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isDiagnosticsRunning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            summaryMetric(title: t("Passed", "成功"), value: overview.passCount, systemImage: "checkmark.circle.fill")
            summaryMetric(title: t("Warnings", "警告"), value: overview.warningCount, systemImage: "exclamationmark.triangle.fill")
            summaryMetric(title: t("Failures", "失敗"), value: overview.failureCount, systemImage: "xmark.octagon.fill")
            Spacer()
            Text(viewModel.selectedModel?.displayName ?? t("Default endpoint", "既定エンドポイント"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private func summaryMetric(title: String, value: Int, systemImage: String) -> some View {
        Label {
            Text(verbatim: "\(title): \(value)")
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
    }

    private var historyBar: some View {
        HStack(spacing: 12) {
            Label(t("History", "履歴") + ": \(targetHistory.count)", systemImage: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
            if let comparison = latestComparison {
                Label(trendTitle(comparison), systemImage: trendImage(comparison.trend))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(trendColor(comparison.trend))
                Text(t("Improved", "改善") + ": \(comparison.improvedCount)  " + t("Worsened", "悪化") + ": \(comparison.worsenedCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let latest = targetHistory.first {
                Text(latest.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
    }

    private func trendTitle(_ comparison: DiagnosticsComparison) -> String {
        switch comparison.trend {
        case .initial: t("Initial result", "初回結果")
        case .improved: t("Improved", "改善")
        case .worsened: t("Worsened", "悪化")
        case .unchanged: t("Unchanged", "変化なし")
        }
    }

    private func trendImage(_ trend: DiagnosticsTrend) -> String {
        switch trend {
        case .initial: "circle"
        case .improved: "arrow.up.circle.fill"
        case .worsened: "arrow.down.circle.fill"
        case .unchanged: "equal.circle.fill"
        }
    }

    private func trendColor(_ trend: DiagnosticsTrend) -> Color {
        switch trend {
        case .initial, .unchanged: .secondary
        case .improved: .green
        case .worsened: .red
        }
    }

    private func resultCard(_ result: DiagnosticsResult) -> some View {
        let guidance = overview.guidance(for: result)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusImage(result.status))
                .font(.title3)
                .foregroundStyle(statusColor(result.status))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(localizedCheckTitle(result.check))
                    .font(.headline)
                Text(result.message)
                    .font(.subheadline)
                    .textSelection(.enabled)
                if let detail = result.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if result.status != .pass {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t("Recommended action", "推奨対処"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(recommendationText(guidance.recommendationKey))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        if guidance.destination != .none {
                            Button(destinationTitle(guidance.destination)) {
                                openDestination(guidance.destination)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(priorityTitle(guidance.priority))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor(result.status))
                Text(statusTitle(result.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(result.status))
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.2))
        }
    }

    private func localizedCheckTitle(_ check: DiagnosticsCheck) -> String {
        switch check {
        case .executablePathConfigured: t("Executable path configured", "実行ファイルパス設定")
        case .executablePathExists: t("Executable path exists", "実行ファイルパス存在確認")
        case .executablePathExecutable: t("Executable path executable", "実行権限確認")
        case .hostConfigured: t("Host configured", "ホスト設定")
        case .portInRange: t("Port in range", "ポート範囲")
        case .settingsStorageLocation: t("Settings storage location", "設定保存先")
        case .portAvailability: t("Port availability", "ポート利用可否")
        case .readyCheck: t("Ready check", "Ready確認")
        }
    }

    private func recommendationText(_ key: String) -> String {
        switch key {
        case "configureExecutable": t("Configure the runtime executable path, then run diagnostics again.", "ランタイム実行ファイルのパスを設定し、診断を再実行してください。")
        case "verifyExecutablePath": t("Verify that the configured executable path exists and points to the intended runtime.", "設定した実行ファイルパスが存在し、対象ランタイムを指しているか確認してください。")
        case "verifyExecutablePermission": t("Verify execute permission for the configured runtime executable.", "設定したランタイム実行ファイルに実行権限があるか確認してください。")
        case "reviewHost": t("Review the host value and use a valid local or network address.", "ホスト値を確認し、有効なローカルまたはネットワークアドレスを使用してください。")
        case "reviewPort": t("Choose a port between 1 and 65535 for the selected profile.", "選択中プロファイルには1から65535のポートを指定してください。")
        case "reviewStorage": t("Review the settings storage location and confirm that it is writable.", "設定保存先を確認し、書き込み可能であることを確認してください。")
        case "resolvePortConflict": t("Stop the process using this port or assign a different unused port to the profile.", "このポートを使用中のプロセスを停止するか、プロファイルへ別の未使用ポートを割り当ててください。")
        case "reviewRuntimeState": t("Confirm that the selected runtime is running and that its endpoint matches the profile.", "選択したランタイムが起動中で、エンドポイントがプロファイル設定と一致しているか確認してください。")
        default: t("Review this result before running diagnostics again.", "この結果を確認してから診断を再実行してください。")
        }
    }

    private func priorityTitle(_ priority: DiagnosticsPriority) -> String {
        switch priority {
        case .critical: t("Critical", "最優先")
        case .high: t("High priority", "優先")
        case .normal: t("Normal", "通常")
        case .informational: t("Information", "情報")
        }
    }

    private func destinationTitle(_ destination: DiagnosticsGuidanceDestination) -> String {
        switch destination {
        case .settings: t("Open Settings", "設定を開く")
        case .dashboard: t("Open Dashboard", "ダッシュボードを開く")
        case .none: ""
        }
    }

    private func openDestination(_ destination: DiagnosticsGuidanceDestination) {
        switch destination {
        case .settings: onOpenSettings()
        case .dashboard: onOpenDashboard()
        case .none: break
        }
    }

    private func statusTitle(_ status: DiagnosticsStatus) -> String {
        switch status {
        case .pass: t("Passed", "成功")
        case .warning: t("Warning", "警告")
        case .fail: t("Failed", "失敗")
        }
    }

    private func statusImage(_ status: DiagnosticsStatus) -> String {
        switch status {
        case .pass: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .fail: "xmark.octagon.fill"
        }
    }

    private var historySheet: some View {
        let current = targetHistory.first(where: { $0.id == comparisonCurrentID })
        let previous = targetHistory.first(where: { $0.id == comparisonPreviousID })
        let rows = current.flatMap { current in previous.map { DiagnosticsComparison.rows(current: current, previous: $0) } } ?? []
        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Diagnostics History", "診断履歴")).font(.title3)
                    Text(viewModel.selectedModel?.displayName ?? t("Default endpoint", "既定エンドポイント"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Export Markdown", "Markdownを書き出す")) { exportMarkdown(current: current, previous: previous) }
                    .disabled(current == nil)
                Button(t("Clear History", "履歴を削除"), role: .destructive) {
                    viewModel.diagnosticsHistory = DiagnosticsHistoryStore.removeSnapshots(
                        for: targetKey,
                        history: viewModel.diagnosticsHistory
                    )
                    isHistoryPresented = false
                }
                Button(t("Close", "閉じる")) { isHistoryPresented = false }
            }
            .padding(16)
            Divider()
            HStack(spacing: 12) {
                snapshotPicker(title: t("Current", "比較後"), selection: $comparisonCurrentID)
                snapshotPicker(title: t("Previous", "比較前"), selection: $comparisonPreviousID)
            }
            .padding(16)
            Divider()
            if let current {
                let comparison = DiagnosticsComparison.compare(current: current, previous: previous)
                HStack(spacing: 16) {
                    Label("\(t("Improved", "改善")): \(comparison.improvedCount)", systemImage: "arrow.up.circle")
                    Label("\(t("Worsened", "悪化")): \(comparison.worsenedCount)", systemImage: "arrow.down.circle")
                    Label("\(t("Unchanged", "変化なし")): \(comparison.unchangedCount)", systemImage: "equal.circle")
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .padding(12)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Text(localizedCheckTitle(DiagnosticsCheck(rawValue: row.checkRawValue) ?? .readyCheck))
                                .font(.caption.weight(.semibold))
                                .frame(width: 180, alignment: .leading)
                            Text(row.previousStatusRawValue ?? "-").font(.caption.monospaced()).frame(width: 70)
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(row.currentStatusRawValue ?? "-").font(.caption.monospaced()).frame(width: 70)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.currentMessage ?? "-").font(.caption)
                                if row.previousMessage != row.currentMessage {
                                    Text(row.previousMessage ?? "-").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private func snapshotPicker(title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            ForEach(targetHistory) { snapshot in
                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .standard)).tag(Optional(snapshot.id))
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
    }

    private func prepareHistorySelection() {
        comparisonCurrentID = targetHistory.first?.id
        comparisonPreviousID = targetHistory.dropFirst().first?.id ?? targetHistory.first?.id
    }

    private func exportMarkdown(current: DiagnosticsSnapshot?, previous: DiagnosticsSnapshot?) {
        guard let current else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "diagnostics-\(current.targetName.replacingOccurrences(of: " ", with: "-"))-report.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? DiagnosticsReportBuilder.markdown(current: current, previous: previous).write(to: url, atomically: true, encoding: .utf8)
    }

    private func statusColor(_ status: DiagnosticsStatus) -> Color {
        switch status {
        case .pass: .green
        case .warning: .orange
        case .fail: .red
        }
    }
}
