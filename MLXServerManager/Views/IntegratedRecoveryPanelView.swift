import SwiftUI

struct IntegratedRecoveryPanelView: View {
    let issue: RecoveryIssue
    let language: AppLanguage
    let onAction: (RecoveryAction) -> Void
    let onCopyTroubleshooting: () -> Void
    let onRefreshSafety: () -> Void

    init(
        issue: RecoveryIssue,
        language: AppLanguage = .system,
        onAction: @escaping (RecoveryAction) -> Void,
        onCopyTroubleshooting: @escaping () -> Void,
        onRefreshSafety: @escaping () -> Void
    ) {
        self.issue = issue
        self.language = language
        self.onAction = onAction
        self.onCopyTroubleshooting = onCopyTroubleshooting
        self.onRefreshSafety = onRefreshSafety
    }

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(t("Recovery", "復旧"), systemImage: iconName)
                    .font(.headline)
                Spacer()
                Text(issue.severity.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(severityColor)
            }

            Text(issue.title)
                .font(.callout.weight(.semibold))
            Text(issue.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let relatedLogLine = issue.relatedLogLine {
                Label(relatedLogLine, systemImage: "exclamationmark.triangle")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                Button(t("Refresh Safety", "安全性を更新")) { onRefreshSafety() }
                Button(t("Copy Troubleshooting", "トラブルシューティングをコピー")) { onCopyTroubleshooting() }
            }
            .font(.caption)
        }
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
