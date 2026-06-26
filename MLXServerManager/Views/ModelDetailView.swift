import SwiftUI

struct ModelDetailView: View {
    let model: ModelConfig?
    let runningModelText: String
    let restartRequired: Bool
    let deletionMessage: String?
    var language: AppLanguage = .system
    let onEditProfile: () -> Void
    let onDeleteProfile: () -> Void

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(l10n.text(english: "Selected Model", japanese: "選択モデル"))
                    .font(.headline)

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        onEditProfile()
                    } label: {
                        Label(l10n.text(english: "Edit Profile", japanese: "プロファイルを編集"), systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDeleteProfile()
                    } label: {
                        Label(l10n.text(english: "Delete Profile", japanese: "プロファイルを削除"), systemImage: "trash")
                    }
                }
                .disabled(model == nil)
            }

            if let deletionMessage, !deletionMessage.isEmpty {
                Label(deletionMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let model {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(l10n.text(english: "Selected Model", japanese: "選択モデル")): \(model.modelID)", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Label(runningModelText, systemImage: "server.rack")
                        .foregroundStyle(.secondary)

                    if restartRequired {
                        Label(l10n.text(english: "Restart required to apply selected model.", japanese: "選択モデルを反映するには再起動が必要です。"), systemImage: "arrow.clockwise.circle")
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)

                DetailGrid(rows: [
                    ("Model ID", model.modelID),
                    (l10n.text(english: "Display Name", japanese: "表示名"), model.displayName),
                    (l10n.text(english: "Family", japanese: "ファミリー"), model.family),
                    (l10n.text(english: "Quantization", japanese: "量子化"), model.quantization),
                    (l10n.text(english: "Context", japanese: "コンテキスト"), model.contextWindow),
                    (l10n.text(english: "Local Name", japanese: "ローカル名"), model.localName),
                    (l10n.text(english: "Endpoint", japanese: "エンドポイント"), "\(model.host):\(model.serverPort)"),
                    ("Thinking", model.enableThinking ? l10n.text(english: "Enabled", japanese: "有効") : l10n.text(english: "Disabled", japanese: "無効")),
                    (l10n.text(english: "Notes", japanese: "メモ"), model.notes)
                ])
            } else {
                Text(l10n.text(english: "No model selected", japanese: "モデルが選択されていません"))
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }
}

struct DetailGrid: View {
    let rows: [(String, String)]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach(rows, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)

                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
