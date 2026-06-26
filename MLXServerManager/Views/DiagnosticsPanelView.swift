import SwiftUI

struct DiagnosticsPanelView: View {
    let results: [DiagnosticsResult]
    let didRun: Bool
    let summaryText: String
    var language: AppLanguage = .system
    let onCopySummary: () -> Void

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private var passCount: Int {
        results.filter { $0.status == .pass }.count
    }

    private var warningCount: Int {
        results.filter { $0.status == .warning }.count
    }

    private var failureCount: Int {
        results.filter { $0.status == .fail }.count
    }

    private var hasWarningsOrFailures: Bool {
        warningCount > 0 || failureCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n.text(english: "Diagnostics", japanese: "診断"))
                    .font(.headline)

                Spacer()

                Button {
                    onCopySummary()
                } label: {
                    Label(l10n.text(english: "Copy Diagnostics Summary", japanese: "診断サマリーをコピー"), systemImage: "doc.on.doc")
                }
            }

            if didRun {
                summaryView

                if hasWarningsOrFailures {
                    issueBanner
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(results) { result in
                        resultRow(result)
                    }
                }
            } else {
                Text(l10n.text(english: "No diagnostics run yet.", japanese: "診断はまだ実行されていません。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private var summaryView: some View {
        HStack(spacing: 8) {
            summaryPill(title: l10n.text(english: "Pass", japanese: "成功"), count: passCount, color: .green)
            summaryPill(title: l10n.text(english: "Warning", japanese: "警告"), count: warningCount, color: .orange)
            summaryPill(title: l10n.text(english: "Failure", japanese: "失敗"), count: failureCount, color: .red)

            Spacer(minLength: 0)

            Text(summaryText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var issueBanner: some View {
        let message = failureCount > 0
            ? l10n.text(english: "\(failureCount) failure(s) need attention.", japanese: "\(failureCount)件の失敗に対応が必要です。")
            : l10n.text(english: "\(warningCount) warning(s) need review.", japanese: "\(warningCount)件の警告を確認してください。")

        return Text(message)
            .font(.callout.weight(.semibold))
            .foregroundStyle(failureCount > 0 ? .red : .orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background((failureCount > 0 ? Color.red : Color.orange).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func summaryPill(title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 82, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resultRow(_ result: DiagnosticsResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(result.status.rawValue.uppercased())
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(statusForegroundColor(result.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: 86)
                .background(statusBackgroundColor(result.status))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.check.title)
                    .font(.callout.weight(.semibold))

                Text(result.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let detail = result.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(statusBackgroundColor(result.status).opacity(result.status == .pass ? 0.25 : 0.70))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusForegroundColor(_ status: DiagnosticsStatus) -> Color {
        switch status {
        case .pass:
            .green
        case .warning:
            .orange
        case .fail:
            .red
        }
    }

    private func statusBackgroundColor(_ status: DiagnosticsStatus) -> Color {
        statusForegroundColor(status).opacity(0.12)
    }
}
