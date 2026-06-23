import SwiftUI

struct IntegratedRecoveryPanelView: View {
    let issue: RecoveryIssue
    let onAction: (RecoveryAction) -> Void
    let onCopyTroubleshooting: () -> Void
    let onRefreshSafety: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recovery", systemImage: iconName)
                    .font(.headline)
                Spacer()
                Text(issue.severity.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            Text(issue.title)
                .font(.callout.weight(.semibold))
            Text(issue.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let relatedLogLine = issue.relatedLogLine {
                Text(relatedLogLine)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if !issue.actions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(issue.actions) { action in
                        if action.isPrimary {
                            recoveryButton(action)
                                .buttonStyle(.borderedProminent)
                        } else {
                            recoveryButton(action)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack {
                Button("Refresh Safety") { onRefreshSafety() }
                Button("Copy Troubleshooting") { onCopyTroubleshooting() }
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func recoveryButton(_ action: RecoveryAction) -> some View {
        Button {
            onAction(action)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.caption.weight(.semibold))
                Text(action.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var iconName: String {
        switch issue.severity {
        case .ok:
            "checkmark.circle"
        case .warning, .review:
            "exclamationmark.triangle"
        case .failed:
            "xmark.octagon"
        }
    }

    private var severityColor: Color {
        switch issue.severity {
        case .ok:
            .green
        case .warning, .review:
            .orange
        case .failed:
            .red
        }
    }
}
