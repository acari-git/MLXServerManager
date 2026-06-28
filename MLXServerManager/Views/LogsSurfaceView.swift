import SwiftUI

struct LogsSurfaceView: View {
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
        Form {
            Section {
                header
            }
            Section {
                logCommandDeck
            }
            Section {
                summaryCards
            } header: {
                Text(t("Summary", "概要"))
            }
            Section {
                troubleshootingCard
            }
            Section {
                boundaryCard
            }
            Section {
                LogView(
                    entries: entries,
                    language: language,
                    onCopy: onCopy,
                    onClear: onClear
                )
                .accessibilityIdentifier("logs-surface-log-view")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .top)
        }
        .accessibilityIdentifier("logs-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(strings.text(.logs))
                    .font(.title2.weight(.semibold))
            }

            Text(t(
                "App-managed lifecycle and log context. External server logs are not captured.",
                "アプリ管理のライフサイクルとログコンテキストを表示します。外部サーバーのログは取得しません。"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("logs-surface-header")
    }

    private var logCommandDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(t("Log command center", "ログ操作センター"), systemImage: "terminal")
                        .font(.headline)
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
                .font(.headline)

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
                .font(.headline)

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
