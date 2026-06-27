import SwiftUI

struct ModelListView: View {
    let models: [ModelConfig]
    @Binding var selectedModelID: ModelConfig.ID?
    let runningModelID: ModelConfig.ID?
    let restartRequired: Bool
    let exportSummaryText: String
    let exportMessage: String?
    let importMessage: String?
    var language: AppLanguage = .system
    let onAddProfile: () -> Void
    let onExportProfiles: () -> Void
    let onImportProfilesPreview: () -> Void

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l10n.text(.models))
                        .font(.headline)

                    Spacer()

                    Button {
                        onAddProfile()
                    } label: {
                        Label(t("Add Profile", "プロファイルを追加"), systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .help(t("Add Profile", "プロファイルを追加"))
                }

                HStack(spacing: 8) {
                    Button {
                        onExportProfiles()
                    } label: {
                        Label(t("Export Profiles...", "プロファイルを書き出し..."), systemImage: "square.and.arrow.up")
                    }
                    .disabled(models.isEmpty)

                    Button {
                        onImportProfilesPreview()
                    } label: {
                        Label(t("Import Profiles...", "プロファイルを読み込み..."), systemImage: "square.and.arrow.down")
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exportSummaryText)
                    Text(t("Exports profile metadata only. No API keys, tokens, model weights, caches, logs, executable paths, or runtime state.", "プロファイルメタデータのみを書き出します。APIキー、トークン、モデル重み、キャッシュ、ログ、実行ファイルパス、ランタイム状態は含みません。"))
                    Text(t("Import Profiles adds selected valid metadata, can rename profile-name conflicts, and can replace one unambiguous local profile after confirmation.", "プロファイル読み込みは選択した有効なメタデータを追加し、プロファイル名の競合をリネームでき、確認後に曖昧でないローカルプロファイル1件を置換できます。"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let importMessage {
                    Text(importMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            List(models, selection: $selectedModelID) { model in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.body.weight(.medium))
                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if model.id == selectedModelID {
                            statusPill(t("Selected", "選択中"), color: .accentColor)
                        }

                        if model.id == runningModelID {
                            statusPill(t("Running", "実行中"), color: .green)
                        }

                        if restartRequired, model.id == selectedModelID {
                            statusPill(t("Restart required", "再起動が必要"), color: .orange)
                        }
                    }
                }
                .padding(.vertical, 4)
                .tag(model.id)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
