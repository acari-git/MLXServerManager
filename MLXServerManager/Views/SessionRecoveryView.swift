import SwiftUI

struct SessionRecoveryView: View {
    let state: SessionRecoveryViewState
    let models: [ModelConfig]
    let language: AppLanguage
    let onCheck: () -> Void
    let onAdopt: (ModelConfig.ID) -> Void
    let onDismiss: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    state.previousDisposition?.localizedTitle(language: language)
                        ?? t("Session recovery", "セッション復旧"),
                    systemImage: "arrow.clockwise.circle"
                )
                .font(.title3.weight(.semibold))

                Text(t(
                    "These endpoints were managed by the previous app session. They are treated as external candidates now; ownership is never restored automatically.",
                    "これらのエンドポイントは前回のアプリセッションで管理されていました。現在は外部候補として扱い、所有権を自動復元することはありません。"
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(state.candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
            }
            .frame(minHeight: 180, maxHeight: 360)

            HStack(spacing: 10) {
                Button(t("Close", "閉じる"), action: onDismiss)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onCheck()
                } label: {
                    Label(
                        state.isChecking
                            ? t("Checking endpoints", "エンドポイントを確認中")
                            : t("Check endpoints", "エンドポイントを確認"),
                        systemImage: state.isChecking ? "hourglass" : "network"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isChecking || state.candidates.isEmpty)
            }
        }
        .padding(22)
        .frame(minWidth: 620, minHeight: 360)
        .accessibilityIdentifier("session-recovery-sheet")
    }

    private func candidateRow(_ candidate: SessionRecoveryCandidate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol(candidate.status))
                .foregroundStyle(statusColor(candidate.status))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.endpoint.displayName)
                    .font(.callout.weight(.semibold))
                Text(candidate.endpoint.modelID)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(candidate.endpoint.baseURL)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(candidate.status.localizedTitle(language: language))
                    .font(.caption2)
                    .foregroundStyle(statusColor(candidate.status))
            }

            Spacer(minLength: 12)

            if candidate.isAdopted {
                Label(t("Adopted", "採用済み"), systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(t("Adopt as external", "外部サーバーとして採用")) {
                    onAdopt(candidate.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(
                    !candidate.status.isAvailable
                        || !models.contains(where: { $0.id == candidate.id })
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.75)
        )
    }

    private func statusSymbol(_ status: SessionRecoveryCheckStatus) -> String {
        switch status {
        case .notChecked: "questionmark.circle"
        case .checking: "hourglass"
        case .available: "checkmark.circle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: SessionRecoveryCheckStatus) -> Color {
        switch status {
        case .notChecked: .secondary
        case .checking: .accentColor
        case .available: .green
        case .unavailable: .orange
        }
    }
}
