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

    private let contentWidth: CGFloat = 660
    private let controlWidth: CGFloat = 248
    private let rowHorizontalPadding: CGFloat = 12
    private let rowVerticalPadding: CGFloat = 14
    private let cardCornerRadius: CGFloat = 8

    private var strings: AppLocalization {
        AppLocalization(language: language)
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
                    .font(.system(size: 18, weight: .semibold))
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

                settingsSection(
                    title: t("Actions", "操作"),
                    rows: [
                        AnyView(actionRow(
                            title: strings.text(.saveSettings),
                            detail: t(
                                "Persist the current settings to the app support folder.",
                                "現在の設定をアプリのサポートフォルダへ保存します。"
                            ),
                            buttonTitle: strings.text(.saveSettings),
                            systemImage: "square.and.arrow.down",
                            isPrimary: true,
                            action: onSave
                        )),
                        AnyView(actionRow(
                            title: strings.text(.runDiagnostics),
                            detail: t(
                                "Check whether the configured executable, folders, and connection defaults are usable.",
                                "設定済みの実行ファイル、フォルダ、接続既定値が利用可能か確認します。"
                            ),
                            buttonTitle: strings.text(.runDiagnostics),
                            systemImage: "stethoscope",
                            isPrimary: false,
                            action: onRunDiagnostics
                        ))
                    ]
                )
            }
            .padding(.top, 64)
            .padding(.bottom, 56)
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsSection(title: String, rows: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
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
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.80), lineWidth: 1.0)
            )
        }
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
                .font(.system(size: 14))
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
                .font(.system(size: 14))
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

    private func actionRow(
        title: String,
        detail: String,
        buttonTitle: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            rowText(title: title, detail: detail)

            Spacer(minLength: 16)

            if isPrimary {
                Button(action: action) {
                    Label(buttonTitle, systemImage: systemImage)
                        .frame(width: controlWidth - 20, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(buttonTitle, systemImage: systemImage)
                        .frame(width: controlWidth - 20, alignment: .center)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, rowHorizontalPadding + 4)
        .padding(.vertical, rowVerticalPadding + 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowText(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
        }
    }
}
