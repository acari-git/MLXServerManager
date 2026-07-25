import SwiftUI

struct LogsSurfaceView: View {
    private let contentWidth: CGFloat = 760
    private let controlWidth: CGFloat = 360

    let entries: [LogEntry]
    let operationalEvents: [RuntimeEvent]
    let operationalHistoryCategories: [String]
    @Binding var operationalHistoryCategoryFilter: String
    @Binding var operationalHistorySeverityFilter: OperationalHistorySeverityFilter
    let targetSummary: ConnectionTargetSummary
    let runningModelText: String
    let language: AppLanguage
    let onCopyOperationalHistory: () -> Void
    let onClearOperationalHistory: () -> Void
    let onCopy: () -> Void
    let onClear: () -> Void

    init(
        entries: [LogEntry],
        operationalEvents: [RuntimeEvent],
        operationalHistoryCategories: [String],
        operationalHistoryCategoryFilter: Binding<String>,
        operationalHistorySeverityFilter: Binding<OperationalHistorySeverityFilter>,
        targetSummary: ConnectionTargetSummary,
        runningModelText: String,
        language: AppLanguage = .system,
        onCopyOperationalHistory: @escaping () -> Void,
        onClearOperationalHistory: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self.entries = entries
        self.operationalEvents = operationalEvents
        self.operationalHistoryCategories = operationalHistoryCategories
        self._operationalHistoryCategoryFilter = operationalHistoryCategoryFilter
        self._operationalHistorySeverityFilter = operationalHistorySeverityFilter
        self.targetSummary = targetSummary
        self.runningModelText = runningModelText
        self.language = language
        self.onCopyOperationalHistory = onCopyOperationalHistory
        self.onClearOperationalHistory = onClearOperationalHistory
        self.onCopy = onCopy
        self.onClear = onClear
    }

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                controlsSection
                contextSection
                operationalHistorySection
                logSection
            }
            .padding(.top, 12)
            .padding(.bottom, 56)
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("logs-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.text(.logs))
                .font(.title3)
                .accessibilityIdentifier("logs-surface-header")
            Text(t(
                "App lifecycle, managed server events, ready checks, and download activity are shown here.",
                "アプリのライフサイクル、管理サーバー、Ready確認、ダウンロード処理のログを表示します。"
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func section<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .groupBoxStyle(.automatic)
    }

    private var controlsSection: some View {
        section(
            title: t("Controls", "操作"),
            subtitle: t("Copy or clear the current in-app log buffer.", "現在のアプリ内ログバッファをコピーまたはクリアします。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Label(t("Log buffer", "ログバッファ"), systemImage: "terminal")
                        .font(.callout.weight(.medium))

                    Spacer()

                    metricPill(value: String(entries.count), label: t("entries", "件"))
                    statusPill(targetSummary.targetType)
                }

                HStack(spacing: 10) {
                    Button(t("Copy logs", "ログをコピー")) { onCopy() }
                        .disabled(entries.isEmpty)
                    Button(t("Clear logs", "ログをクリア")) { onClear() }
                        .disabled(entries.isEmpty)
                    Spacer(minLength: 0)
                }
            }
            .accessibilityIdentifier("logs-surface-controls")
        }
    }

    private func metricPill(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.40), in: Capsule())
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.40), in: Capsule())
    }

    private var contextSection: some View {
        section(
            title: t("Context", "状態"),
            subtitle: t("The log boundary is limited to MLX Server Manager managed lifecycle and captured managed-process context.", "ログ対象はMLX Server Managerが管理するライフサイクルと取得済みの管理プロセス情報に限定されます。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let latestImportantLogEntry {
                    Label(latestImportantLogEntry.line, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }

                compactRows([
                    (t("Base URL", "Base URL"), targetSummary.baseURL),
                    (t("Model ID", "Model ID"), targetSummary.modelID),
                    (t("Readiness", "準備状態"), targetSummary.readinessSummary),
                    (t("Running", "実行中"), runningModelText),
                    (t("Ownership", "管理範囲"), targetSummary.ownershipNote),
                    ("Direct Mode", targetSummary.directModeNote)
                ])
            }
            .accessibilityIdentifier("logs-surface-context")
        }
    }

    private var latestImportantLogEntry: LogEntry? {
        entries.reversed().first { entry in
            entry.line.localizedCaseInsensitiveContains("failed")
                || entry.line.localizedCaseInsensitiveContains("warning")
                || entry.line.localizedCaseInsensitiveContains("error")
        }
    }

    private var operationalHistorySection: some View {
        section(
            title: t("Operational History", "操作履歴"),
            subtitle: t(
                "A bounded, in-memory record of explicit operations in this app session. It is not written to disk or transmitted.",
                "このアプリセッションで行った明示的な操作を、件数制限付きでメモリ内に保持します。ディスク保存や外部送信は行いません。"
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Picker(t("Category", "カテゴリ"), selection: $operationalHistoryCategoryFilter) {
                        ForEach(operationalHistoryCategories, id: \.self) { category in
                            Text(localizedOperationalCategory(category))
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 190, alignment: .leading)

                    Picker(t("Severity", "重要度"), selection: $operationalHistorySeverityFilter) {
                        ForEach(OperationalHistorySeverityFilter.allCases) { severity in
                            Text(severity.localizedTitle(language: language))
                                .tag(severity)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170, alignment: .leading)

                    Spacer(minLength: 0)

                    metricPill(value: String(operationalEvents.count), label: t("events", "件"))
                }

                HStack(spacing: 10) {
                    Button(t("Copy history", "履歴をコピー")) {
                        onCopyOperationalHistory()
                    }
                    .disabled(operationalEvents.isEmpty)

                    Button(t("Clear history", "履歴をクリア")) {
                        onClearOperationalHistory()
                    }
                    .disabled(operationalEvents.isEmpty)

                    Spacer(minLength: 0)
                }

                if operationalEvents.isEmpty {
                    ContentUnavailableView {
                        Label(t("No matching events", "一致する操作履歴がありません"), systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text(t(
                            "Run an explicit operation or change the filters.",
                            "明示的な操作を実行するか、フィルターを変更してください。"
                        ))
                    }
                    .frame(minHeight: 120)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(operationalEvents.prefix(40)) { event in
                            operationalHistoryRow(event)
                            if event.id != operationalEvents.prefix(40).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("logs-operational-history")
        }
    }

    private func operationalHistoryRow(_ event: RuntimeEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: operationalHistorySymbol(event.severity))
                .foregroundStyle(operationalHistoryColor(event.severity))
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(localizedOperationalCategory(event.category))
                        .font(.caption.weight(.semibold))
                    Text(event.severity.localizedTitle(language: language))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(operationalHistoryColor(event.severity))
                    Spacer(minLength: 8)
                    Text(event.timestamp, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Text(event.localizedMessage(language: language))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)

                let context = [event.modelID, event.endpoint].compactMap { $0 }
                if !context.isEmpty {
                    Text(context.joined(separator: " · "))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func localizedOperationalCategory(_ category: String) -> String {
        switch category {
        case OperationalHistoryProjection.allCategories:
            return t("All categories", "すべてのカテゴリ")
        case "Lifecycle":
            return t("Lifecycle", "ライフサイクル")
        case "Port":
            return t("Port", "ポート")
        case "Ready":
            return t("Ready", "準備確認")
        case "Runtime":
            return t("Runtime", "ランタイム")
        case "Runtime Health":
            return t("Runtime Health", "ランタイム状態")
        case "Runtime Setup":
            return t("Runtime Setup", "ランタイム設定")
        case "Runtime Compatibility":
            return t("Runtime Compatibility", "ランタイム互換性")
        case "Session Recovery":
            return t("Session Recovery", "セッション復旧")
        case "Model Health":
            return t("Model Health", "モデル健全性")
        case "Operational Readiness":
            return t("Operational Readiness", "運用準備状態")
        case "Launch Diagnosis":
            return t("Launch Diagnosis", "起動診断")
        case "Profile":
            return t("Profile", "プロファイル")
        case "Download":
            return t("Download", "ダウンロード")
        case "Benchmark":
            return t("Benchmark", "ベンチマーク")
        case "General":
            return t("General", "一般")
        default:
            return category
        }
    }

    private func operationalHistorySymbol(_ severity: RuntimeEventSeverity) -> String {
        switch severity {
        case .info: "info.circle"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failure: "xmark.octagon.fill"
        }
    }

    private func operationalHistoryColor(_ severity: RuntimeEventSeverity) -> Color {
        switch severity {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }

    private var logSection: some View {
        section(
            title: strings.text(.logs),
            subtitle: t("Newest retained entries in the current session.", "現在のセッションで保持している最新ログです。")
        ) {
            LogView(
                entries: entries,
                language: language,
                showsHeader: false,
                onCopy: onCopy,
                onClear: onClear
            )
            .frame(minHeight: 260)
            .accessibilityIdentifier("logs-surface-log-view")
        }
    }

    private func compactRows(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Text(row.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 110, alignment: .leading)
                    Text(row.1)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .frame(width: controlWidth, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.45))
                        .frame(height: 1.0)
                }
            }
        }
    }
}
