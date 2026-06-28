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
        Form {
            Section {
                LabeledContent(t("mlx_lm.server executable path", "mlx_lm.server実行ファイルのパス")) {
                    TextField(t("Unset", "未設定"), text: $executablePath)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent(t("Default host", "デフォルトホスト")) {
                    TextField("127.0.0.1", text: $defaultHost)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent(t("Default port", "デフォルトポート")) {
                    TextField("8080", text: portTextBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                }

                LabeledContent(t("API key placeholder", "APIキーのプレースホルダー")) {
                    TextField("not-required-local", text: $apiKeyPlaceholder)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text(strings.text(.settings))
            } footer: {
                Text(t(
                    "Language and theme are changed from the bottom-left Display menu.",
                    "言語とテーマは左下の表示メニューから変更します。"
                ))
            }

            Section {
                LabeledContent(t("Settings folder", "設定フォルダ")) {
                    Text(settingsDirectoryPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

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
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
