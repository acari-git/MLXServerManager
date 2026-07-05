import SwiftUI

struct LogsSurfaceView: View {
    private let contentWidth: CGFloat = 760
    private let controlWidth: CGFloat = 360

    let entries: [LogEntry]
    let targetSummary: ConnectionTargetSummary
    let runningModelText: String
    let language: AppLanguage
    let onCopy: () -> Void
    let onClear: () -> Void

    init(
        entries: [LogEntry],
        targetSummary: ConnectionTargetSummary,
        runningModelText: String,
        language: AppLanguage = .system,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self.entries = entries
        self.targetSummary = targetSummary
        self.runningModelText = runningModelText
        self.language = language
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
