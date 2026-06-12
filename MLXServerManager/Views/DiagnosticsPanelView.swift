import SwiftUI

struct DiagnosticsPanelView: View {
    let results: [DiagnosticsResult]
    let didRun: Bool
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagnostics")
                    .font(.headline)

                Spacer()

                Text(summaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if didRun {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(results) { result in
                        resultRow(result)
                    }
                }
            } else {
                Text("Diagnostics not run yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private func resultRow(_ result: DiagnosticsResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(result.status.rawValue)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(statusForegroundColor(result.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: 72)
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
