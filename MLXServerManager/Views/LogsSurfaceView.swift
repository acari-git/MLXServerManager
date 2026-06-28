import SwiftUI

struct LogsSurfaceView: View {
    private let contentWidth: CGFloat = 660
    private let controlWidth: CGFloat = 248
    private let cardCornerRadius: CGFloat = 8

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
            VStack(alignment: .leading, spacing: 26) {
                header
                settingsSection(title: t("Controls", "操作"), content: logCommandDeck)
                settingsSection(title: t("Summary", "概要"), content: summaryCards)
                settingsSection(title: t("Troubleshooting", "トラブルシューティング"), content: troubleshootingCard)
                settingsSection(title: t("Log Boundary", "ログ境界"), content: boundaryCard)
                settingsSection(title: strings.text(.logs), content:
                    LogView(
                        entries: entries,
                        language: language,
                        onCopy: onCopy,
                        onClear: onClear
                    )
                    .accessibilityIdentifier("logs-surface-log-view")
                )
            }
            .padding(.top, 64)
            .padding(.bottom, 56)
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("logs-surface")
    }

    private var header: some View {
        Text(strings.text(.logs))
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
            .accessibilityIdentifier("logs-surface-header")
    }

    private func settingsSection<Content: View>(title: String, content: Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
                )
        }
    }

    private var logCommandDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(t("Log command center", "ログ操作センター"), systemImage: "terminal")
                        .font(.system(size: 14, weight: .medium))
                    Text(t(
                        "Use logs for app-managed lifecycle, ready checks, and troubleshooting context. External server stdout/stderr remains outside this boundary.",
                        "ログは、アプリ管理のライフサイクル、Ready確認、トラブルシューティング情報の確認に使います。外部サーバーのstdout/stderrは対象外です。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(String(entries.count))
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                    Text(t("entries", "件"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let latestImportantLogEntry {
                Label(latestImportantLogEntry.line, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(t("Copy logs", "ログをコピー")) { onCopy() }
                    .disabled(entries.isEmpty)
                Button(t("Clear logs", "ログをクリア")) { onClear() }
                    .disabled(entries.isEmpty)
                Spacer()
                Text(targetSummary.targetType)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("logs-surface-command-deck")
    }

    private var summaryCards: some View {
        detailRows([
            (t("Entries", "件数"), String(entries.count)),
            (t("Target", "接続先"), targetSummary.targetType),
            (t("Readiness", "準備状態"), targetSummary.readinessSummary),
            (t("Running", "実行中"), runningModelText)
        ])
        .accessibilityIdentifier("logs-surface-summary")
    }

    private var latestImportantLogEntry: LogEntry? {
        entries.reversed().first { entry in
            entry.line.localizedCaseInsensitiveContains("failed")
                || entry.line.localizedCaseInsensitiveContains("warning")
                || entry.line.localizedCaseInsensitiveContains("error")
        }
    }

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Troubleshooting", "トラブルシューティング"), systemImage: "wrench.and.screwdriver")
                .font(.system(size: 14, weight: .medium))

            detailRows([
                (t("Latest important log", "直近の重要ログ"), latestImportantLogEntry?.line ?? t("None", "なし")),
                (t("Target", "接続先"), targetSummary.targetType),
                ("Base URL", targetSummary.baseURL),
                (t("Running", "実行中"), runningModelText),
                (t("Entries", "件数"), String(entries.count))
            ])

            HStack {
                Button(t("Copy logs", "ログをコピー")) { onCopy() }
                    .disabled(entries.isEmpty)
                Button(t("Clear logs", "ログをクリア")) { onClear() }
                    .disabled(entries.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logs-surface-troubleshooting")
    }

    private var boundaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Log Boundary", "ログ境界"), systemImage: "lock")
                .font(.system(size: 14, weight: .medium))

            Text(t(
                "Logs shown here are app-managed lifecycle and captured managed-process context already available to MLX Server Manager. Adopted external server stdout/stderr is not captured, inspected, stopped, restarted, or owned by the app.",
                "ここに表示するログは、MLX Server Managerがすでに保持しているアプリ管理のライフサイクルと管理プロセスのコンテキストです。採用済み外部サーバーのstdout/stderrは取得・検査・停止・再起動・所有しません。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            detailRows([
                (t("Ownership", "管理範囲"), targetSummary.ownershipNote),
                ("Direct Mode", targetSummary.directModeNote),
                ("Base URL", targetSummary.baseURL),
                ("Model ID", targetSummary.modelID)
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logs-surface-boundary")
    }

    private func detailRows(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.0)
                            .font(.system(size: 14, weight: .medium))
                        Text(t("Current log context for this item.", "この項目の現在のログコンテキストです。"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 20)
                    Text(row.1)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .frame(width: controlWidth, alignment: .leading)
                }
                .padding(.vertical, 14)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.80))
                        .frame(height: 1.0)
                        .padding(.horizontal, -16)
                }
            }
        }
    }
}
