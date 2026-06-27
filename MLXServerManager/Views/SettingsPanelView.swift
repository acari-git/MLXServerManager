import SwiftUI

struct SettingsPanelView: View {
    @Binding var executablePath: String
    @Binding var defaultHost: String
    @Binding var defaultPort: Int
    @Binding var apiKeyPlaceholder: String
    @Binding var language: AppLanguage
    let settingsDirectoryPath: String
    let onSave: () -> Void
    let onRunDiagnostics: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private func languageDisplayName(_ option: AppLanguage) -> String {
        switch option {
        case .system:
            return t("System", "システム")
        case .japanese:
            return t("Japanese", "日本語")
        case .english:
            return t("English", "英語")
        }
    }

    private var portTextBinding: Binding<String> {
        Binding(
            get: { String(defaultPort) },
            set: { newValue in
                if let value = Int(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    defaultPort = value
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.text(.settings))
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("mlx_lm.server executable path", "mlx_lm.server実行ファイルのパス"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField(t("Unset", "未設定"), text: $executablePath)
                    .textFieldStyle(.roundedBorder)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text(t("Default host", "デフォルトホスト"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("127.0.0.1", text: $defaultHost)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(t("Default port", "デフォルトポート"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("8080", text: portTextBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                }
                GridRow {
                    Text(t("API key placeholder", "APIキーのプレースホルダー"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("not-required-local", text: $apiKeyPlaceholder)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Text(t(
                "Language and color are now changed from the bottom-left Settings menu so app chrome settings stay one click away.",
                "言語とカラーは左下の設定メニューから変更します。アプリ外観の設定を1クリックで開けるようにしています。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    onSave()
                } label: {
                    Label(strings.text(.saveSettings), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onRunDiagnostics()
                } label: {
                    Label(strings.text(.runDiagnostics), systemImage: "stethoscope")
                }

                Text(settingsDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .panelStyle()
    }
}
