import SwiftUI

struct SettingsPanelView: View {
    @Binding var executablePath: String
    @Binding var defaultHost: String
    @Binding var defaultPort: Int
    @Binding var apiKeyPlaceholder: String
    @Binding var language: AppLanguage
    @Binding var appearance: String
    let settingsDirectoryPath: String
    let hasUnsavedChanges: Bool
    let onDiscard: () -> Void
    let onSave: () -> Void

    private let contentWidth: CGFloat = 660
    private let controlWidth: CGFloat = 248
    private let rowHorizontalPadding: CGFloat = 12
    private let rowVerticalPadding: CGFloat = 14
    private let cardCornerRadius: CGFloat = 8

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private var themeOptions: [(value: String, title: String)] {
        [
            ("system", t("System", "システム")),
            ("light", t("Light", "ライト")),
            ("dark", t("Dark", "ダーク"))
        ]
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(strings.text(.settings))
                    .font(.system(size: 20, weight: .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                settingsSection(
                    title: t("Connection", "接続"),
                    rows: [
                        AnyView(editableSettingRow(
                            title: t("mlx_lm.server location", "mlx_lm.serverの場所"),
                            detail: t(
                                "Executable used when MLX Server Manager starts a managed local server.",
                                "MLX Server Managerが管理対象のローカルサーバーを起動するときに使う実行ファイルです。"
                            ),
                            placeholder: "/opt/homebrew/bin/mlx_lm.server",
                            text: $executablePath
                        )),
                        AnyView(editableSettingRow(
                            title: t("Default IP address", "デフォルトIPアドレス"),
                            detail: t(
                                "The local address used when a model profile has no custom host setting.",
                                "モデルプロファイルに個別のホスト指定がない場合に使うローカルアドレスです。"
                            ),
                            placeholder: "127.0.0.1",
                            text: $defaultHost
                        )),
                        AnyView(editableSettingRow(
                            title: t("Default port", "デフォルトポート"),
                            detail: t(
                                "Fallback port for new local mlx_lm.server profiles.",
                                "新しいローカルmlx_lm.serverプロファイルに使う既定ポートです。"
                            ),
                            placeholder: "8080",
                            text: portTextBinding
                        ))
                    ]
                )

                settingsSection(
                    title: t("General", "一般"),
                    rows: [
                        AnyView(languageSettingRow),
                        AnyView(themeSettingRow),
                        AnyView(editableSettingRow(
                            title: t("API key placeholder", "APIキーのプレースホルダー"),
                            detail: t(
                                "Value shown in OpenAI-compatible examples when local authentication is not required.",
                                "ローカル認証が不要な場合に、OpenAI互換の設定例へ表示する値です。"
                            ),
                            placeholder: "not-required-local",
                            text: $apiKeyPlaceholder
                        )),
                        AnyView(readOnlySettingRow(
                            title: t("Settings folder", "設定フォルダ"),
                            detail: t(
                                "Location where app settings and model profile metadata are stored.",
                                "アプリ設定とモデルプロファイル情報を保存する場所です。"
                            ),
                            value: settingsDirectoryPath
                        ))
                    ]
                )

                settingsSaveFooter
            }
            .padding(.top, 12)
            .padding(.bottom, 56)
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var settingsSaveFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Unsaved settings", "未保存の設定"))
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.primary)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("Save changes made on this settings screen.", "この設定画面で変更した内容を保存します。"))
                        .font(.system(size: 15, weight: .light))
                    Text(t(
                        "Leaving this screen without saving discards the changes.",
                        "保存せずにこの画面を離れると、変更内容は破棄されます。"
                    ))
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Button(t("Discard changes", "変更を破棄")) {
                    onDiscard()
                }
                .buttonStyle(.bordered)
                .disabled(!hasUnsavedChanges)

                Button {
                    onSave()
                } label: {
                    Label(t("Save", "保存"), systemImage: "square.and.arrow.down")
                        .frame(width: 92, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasUnsavedChanges)
            }
            .padding(.horizontal, rowHorizontalPadding + 4)
            .padding(.vertical, rowVerticalPadding + 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
            )
        }
    }

    private func settingsSection(title: String, rows: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]

                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor).opacity(0.80))
                            .frame(height: 1.0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableSettingRow(
        title: String,
        detail: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            rowText(title: title, detail: detail)

            Spacer(minLength: 16)

            TextField(placeholder, text: text, prompt: Text(placeholder).foregroundStyle(.tertiary))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15, weight: .light))
                .lineLimit(1)
                .frame(width: controlWidth, height: 28, alignment: .leading)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, rowHorizontalPadding + 4)
        .padding(.vertical, rowVerticalPadding + 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readOnlySettingRow(title: String, detail: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 18) {
            rowText(title: title, detail: detail)

            Spacer(minLength: 16)

            Text(value)
                .font(.system(size: 15, weight: .light))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .frame(width: controlWidth, height: 28, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
                )
        }
        .padding(.horizontal, rowHorizontalPadding + 4)
        .padding(.vertical, rowVerticalPadding + 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var languageSettingRow: some View {
        HStack(alignment: .center, spacing: 18) {
            rowText(
                title: t("Language", "言語"),
                detail: t(
                    "Choose the display language used in MLX Server Manager.",
                    "MLX Server Managerで使用する表示言語を選択します。"
                )
            )

            Spacer(minLength: 16)

            Picker("", selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(languageDisplayName(option))
                        .tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: controlWidth, height: 28, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding + 4)
        .padding(.vertical, rowVerticalPadding + 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var themeSettingRow: some View {
        HStack(alignment: .center, spacing: 18) {
            rowText(
                title: t("Theme", "テーマ"),
                detail: t(
                    "Follow the system appearance or choose a fixed light or dark theme.",
                    "システム外観に合わせるか、ライトまたはダークテーマを固定します。"
                )
            )

            Spacer(minLength: 16)

            Picker("", selection: $appearance) {
                ForEach(themeOptions, id: \.value) { option in
                    Text(option.title)
                        .tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: controlWidth, height: 28, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding + 4)
        .padding(.vertical, rowVerticalPadding + 3)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func rowText(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 14, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2.5)
        }
    }
}
