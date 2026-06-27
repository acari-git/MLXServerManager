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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                logCommandDeck
                summaryCards
                troubleshootingCard
                boundaryCard

                LogView(
                    entries: entries,
                    language: language,
                    onCopy: onCopy,
                    onClear: onClear
                )
                .accessibilityIdentifier("logs-surface-log-view")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .liquidGlassLayerOne(cornerRadius: 0)
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
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .padding(16)
        .liquidGlassLayerTwo(cornerRadius: 14)
        .accessibilityIdentifier("logs-surface-command-deck")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard(t("Entries", "件数"), value: String(entries.count), identifier: "logs-surface-summary-entries")
            summaryCard(t("Target", "接続先"), value: targetSummary.targetType, identifier: "logs-surface-summary-target")
            summaryCard(t("Readiness", "準備状態"), value: targetSummary.readinessSummary, identifier: "logs-surface-summary-readiness")
            summaryCard(t("Running", "実行中"), value: runningModelText, identifier: "logs-surface-summary-running")
        }
        .accessibilityIdentifier("logs-surface-summary")
    }

    private func summaryCard(_ title: String, value: String, identifier: String) -> some View {
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
        .liquidGlassLayerTwo(cornerRadius: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
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

            DetailGrid(rows: [
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassLayerTwo(cornerRadius: 10)
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

            DetailGrid(rows: [
                (t("Ownership", "管理範囲"), targetSummary.ownershipNote),
                ("Direct Mode", targetSummary.directModeNote),
                ("Base URL", targetSummary.baseURL),
                ("Model ID", targetSummary.modelID)
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassLayerTwo(cornerRadius: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logs-surface-boundary")
    }
}
