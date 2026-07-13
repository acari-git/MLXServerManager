import AppKit
import SwiftUI

struct SettingsPanelView: View {
    @Binding var mlxExecutablePath: String
    @Binding var rapidMLXExecutablePath: String
    @Binding var defaultHost: String
    @Binding var defaultPort: Int
    @Binding var apiKeyPlaceholder: String
    @Binding var hermesConfigPath: String
    @Binding var downloadSaveDirectory: String
    @Binding var maxConcurrentModelDownloads: Int
    @Binding var language: AppLanguage
    @Binding var appearance: String
    let settingsDirectoryPath: String
    let hasUnsavedChanges: Bool
    let onDiscard: () -> Void
    let onSave: () -> Void

    private let contentWidth: CGFloat = 760
    private let controlWidth: CGFloat = 300
    private let rowHorizontalPadding: CGFloat = 12
    private let rowVerticalPadding: CGFloat = 14

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

    private var concurrentDownloadOptions: [Int] {
        Array(1...5)
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
            VStack(alignment: .leading, spacing: 24) {
                header

                settingsSection(
                    title: t("Connection", "接続"),
                    subtitle: t("Defaults used for managed local endpoints and Hermes Agent integration.", "管理対象のローカルエンドポイントとHermes Agent連携で使う既定値です。"),
                    rows: [
                        AnyView(editableSettingRow(
                            title: t("mlx_lm.server location", "mlx_lm.serverの場所"),
                            detail: t(
                                "Executable used when MLX Server Manager starts a managed local server.",
                                "MLX Server Managerが管理対象のローカルサーバーを起動するときに使う実行ファイルです。"
                            ),
                            placeholder: "/opt/homebrew/bin/mlx_lm.server",
                            text: $mlxExecutablePath
                        )),
                        AnyView(editableSettingRow(
                            title: t("Rapid-MLX location", "Rapid-MLXの場所"),
                            detail: t(
                                "Executable used for profiles that select the Rapid-MLX backend.",
                                "Rapid-MLXバックエンドを選択したプロファイルの起動に使う実行ファイルです。"
                            ),
                            placeholder: "/path/to/rapid-mlx",
                            text: $rapidMLXExecutablePath
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
                                "Fallback port for new local managed-server profiles.",
                                "新しいローカル管理サーバープロファイルに使う既定ポートです。"
                            ),
                            placeholder: "8080",
                            text: portTextBinding
                        )),
                        AnyView(editableSettingRow(
                            title: t("Hermes Agent config file", "Hermes Agent設定ファイル"),
                            detail: t(
                                "YAML file updated by the Hermes Agent apply action. A backup is created before changes.",
                                "Hermes Agentへ反映するときに更新するYAMLファイルです。変更前にバックアップを作成します。"
                            ),
                            placeholder: "~/.hermes/config.yaml",
                            text: $hermesConfigPath
                        ))
                    ]
                )

                settingsSection(
                    title: t("Downloads", "ダウンロード"),
                    subtitle: t("Defaults for Hugging Face model downloads. The download screen uses these values automatically.", "Hugging Faceモデルダウンロードの既定値です。ダウンロード画面ではこの値を自動的に使います。"),
                    rows: [
                        AnyView(downloadDirectoryRow),
                        AnyView(concurrentModelDownloadsRow)
                    ]
                )

                settingsSection(
                    title: t("General", "一般"),
                    subtitle: t("Language, appearance, and copy-safe local client values.", "言語、外観、コピー用のローカルクライアント値です。"),
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.text(.settings))
                .font(.title3)
            Text(t(
                "Review local server defaults, download behavior, Hermes Agent config path, language, and appearance.",
                "ローカルサーバーの既定値、ダウンロード動作、Hermes Agent設定ファイル、言語、外観を確認・変更します。"
            ))
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var settingsSaveFooter: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("Save changes made on this settings screen.", "この設定画面で変更した内容を保存します。"))
                        .font(.callout)
                    Text(t(
                        "Leaving this screen without saving discards the changes.",
                        "保存せずにこの画面を離れると、変更内容は破棄されます。"
                    ))
                    .font(.caption)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Unsaved settings", "未保存の設定"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(t("Changes are applied only after saving.", "保存後に変更が反映されます。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .groupBoxStyle(.automatic)
    }

    private func settingsSection(title: String, subtitle: String, rows: [AnyView]) -> some View {
        GroupBox {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]

                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor).opacity(0.45))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .groupBoxStyle(.automatic)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableSettingRow(
        title: String,
        detail: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(alignment: .center, spacing: 22) {
            rowText(title: title, detail: detail)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(placeholder, text: text, prompt: Text(placeholder).foregroundStyle(.tertiary))
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .lineLimit(1)
                .frame(width: controlWidth, height: 30, alignment: .leading)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readOnlySettingRow(title: String, detail: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 22) {
            rowText(title: title, detail: detail)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(value, text: .constant(value))
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .lineLimit(1)
                .frame(width: controlWidth, height: 30, alignment: .leading)
                .disabled(true)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downloadDirectoryRow: some View {
        HStack(alignment: .center, spacing: 22) {
            rowText(
                title: t("Save Location", "保存先"),
                detail: t(
                    "Downloaded model folders are saved here by default.",
                    "ダウンロードしたモデルフォルダを既定で保存する場所です。"
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                TextField("~/Models/mlx", text: $downloadSaveDirectory, prompt: Text("~/Models/mlx").foregroundStyle(.tertiary))
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(width: 212, height: 30, alignment: .leading)
                Button(t("Choose", "選択")) {
                    chooseDownloadDirectory()
                }
                .controlSize(.small)
            }
            .frame(width: controlWidth, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var concurrentModelDownloadsRow: some View {
        HStack(alignment: .center, spacing: 22) {
            rowText(
                title: t("Concurrent model downloads", "同時にダウンロードするモデル数"),
                detail: t(
                    "This is the number of model download jobs processed at the same time. Files inside one model are handled internally.",
                    "同時に処理するモデル単位のダウンロード数です。1つのモデル内の複数ファイルは内部で制御します。"
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker(selection: $maxConcurrentModelDownloads) {
                ForEach(concurrentDownloadOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: controlWidth, height: 30, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var languageSettingRow: some View {
        HStack(alignment: .center, spacing: 22) {
            rowText(
                title: t("Language", "言語"),
                detail: t(
                    "Choose the display language used in MLX Server Manager.",
                    "MLX Server Managerで使用する表示言語を選択します。"
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker(selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(languageDisplayName(option))
                        .tag(option)
                }
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: controlWidth, height: 30, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var themeSettingRow: some View {
        HStack(alignment: .center, spacing: 22) {
            rowText(
                title: t("Theme", "テーマ"),
                detail: t(
                    "Follow the system appearance or choose a fixed light or dark theme.",
                    "システム外観に合わせるか、ライトまたはダークテーマを固定します。"
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker(selection: $appearance) {
                ForEach(themeOptions, id: \.value) { option in
                    Text(option.title)
                        .tag(option.value)
                }
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: controlWidth, height: 30, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.title = t("Choose Hugging Face download save directory", "Hugging Faceダウンロード保存先を選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        downloadSaveDirectory = url.path
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
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2.5)
        }
    }
}
