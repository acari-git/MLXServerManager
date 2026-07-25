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
    let runtimeReadinessState: RuntimeReadinessViewState
    let runtimeSetupAssistantState: RuntimeSetupAssistantViewState
    let runtimeCompatibilityState: RuntimeCompatibilityViewState
    let registeredModelHealthState: RegisteredModelHealthViewState
    let hasUnsavedChanges: Bool
    let onRefreshRuntimeReadiness: () -> Void
    let onCancelRuntimeReadiness: () -> Void
    let onDiscoverRuntimeCandidates: () -> Void
    let onCancelRuntimeCandidateDiscovery: () -> Void
    let onApplyRuntimeCandidate: (RuntimeSetupCandidate) -> Void
    let onRefreshRuntimeCompatibility: () -> Void
    let onCancelRuntimeCompatibility: () -> Void
    let onRefreshRegisteredModelHealth: () -> Void
    let onCancelRegisteredModelHealth: () -> Void
    let onOpenOperationalReadiness: () -> Void
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

                runtimeReadinessSection

                runtimeSetupAssistantSection

                runtimeCompatibilitySection

                registeredModelHealthSection

                operationalReadinessSection

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

    private var runtimeReadinessSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(runtimeReadinessState.reports) { report in
                    runtimeReadinessRow(report)

                    if report.id != runtimeReadinessState.reports.last?.id {
                        Divider()
                    }
                }

                HStack(spacing: 10) {
                    if runtimeReadinessState.isChecking {
                        Button(t("Cancel check", "確認を中止")) {
                            onCancelRuntimeReadiness()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        onRefreshRuntimeReadiness()
                    } label: {
                        Label(
                            runtimeReadinessState.isChecking
                                ? t("Checking runtimes", "ランタイムを確認中")
                                : t("Check runtimes", "ランタイムを確認"),
                            systemImage: runtimeReadinessState.isChecking ? "hourglass" : "checkmark.shield"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeReadinessState.isChecking)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Runtime readiness", "ランタイム準備状態"))
                    .font(.headline)
                Text(t(
                    "Checks configured executables without starting a model server.",
                    "モデルサーバーを起動せず、設定済みの実行ファイルを確認します。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .groupBoxStyle(.automatic)
        .accessibilityIdentifier("settings-runtime-readiness")
    }

    private func runtimeReadinessRow(_ report: RuntimeReadinessReport) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: runtimeReadinessSymbol(report.status))
                .foregroundStyle(runtimeReadinessColor(report.status))
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(report.backend.localizedTitle(language: language))
                        .font(.callout.weight(.semibold))
                    Text(report.status.localizedTitle(language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(runtimeReadinessColor(report.status))
                }

                Text(report.issue.localizedDetail(
                    backend: report.backend,
                    executablePath: report.executablePath,
                    language: language
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if !report.executablePath.isEmpty {
                    Text(report.executablePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func runtimeReadinessSymbol(_ status: RuntimeReadinessStatus) -> String {
        switch status {
        case .notChecked: "questionmark.circle"
        case .checking: "hourglass"
        case .ready: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }

    private func runtimeReadinessColor(_ status: RuntimeReadinessStatus) -> Color {
        switch status {
        case .notChecked: .secondary
        case .checking: .accentColor
        case .ready: .green
        case .warning: .orange
        case .unavailable: .red
        }
    }

    private var runtimeSetupAssistantSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if runtimeSetupAssistantState.didSearch && runtimeSetupAssistantState.candidates.isEmpty {
                    Text(t(
                        "No executable candidates were found in the configured path, PATH, Homebrew locations, or the limited user-environment locations.",
                        "設定済みパス、PATH、Homebrewの場所、限定したユーザー環境の場所に実行ファイル候補は見つかりませんでした。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                ForEach(runtimeSetupAssistantState.candidates) { candidate in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "terminal")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.backend.localizedTitle(language: language))
                                .font(.callout.weight(.semibold))
                            Text(candidate.executablePath)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Text([
                                candidate.localizedSource(language: language),
                                candidate.version ?? t("Version unavailable", "バージョン不明")
                            ].joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Button(t("Use path", "このパスを使用")) {
                            onApplyRuntimeCandidate(candidate)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    if runtimeSetupAssistantState.isSearching {
                        Button(t("Cancel search", "検索を中止")) {
                            onCancelRuntimeCandidateDiscovery()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        onDiscoverRuntimeCandidates()
                    } label: {
                        Label(
                            runtimeSetupAssistantState.isSearching
                                ? t("Searching runtimes", "ランタイムを検索中")
                                : t("Find runtime candidates", "ランタイム候補を検索"),
                            systemImage: "magnifyingglass"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeSetupAssistantState.isSearching)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Runtime setup assistant", "ランタイム設定アシスタント"))
                    .font(.headline)
                Text(t(
                    "Finds executable candidates without installing software or changing Settings automatically.",
                    "ソフトウェアをインストールせず、設定を自動変更せずに実行ファイル候補を探します。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings-runtime-setup-assistant")
    }

    private var runtimeCompatibilitySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if runtimeCompatibilityState.didCheck {
                    ForEach(runtimeCompatibilityState.reports) { report in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(report.backend.localizedTitle(language: language))
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                Text(report.version ?? t("Version unavailable", "バージョン不明"))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            if report.executablePath.isEmpty {
                                Text(t(
                                    "Configure an executable path before checking compatibility.",
                                    "互換性を確認する前に実行ファイルパスを設定してください。"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(report.features) { result in
                                        HStack(spacing: 6) {
                                            Image(systemName: compatibilitySymbol(result.support))
                                                .foregroundStyle(compatibilityColor(result.support))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(result.feature.localizedTitle(language: language))
                                                    .font(.caption)
                                                Text(result.support.localizedTitle(language: language))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if report.id != runtimeCompatibilityState.reports.last?.id {
                            Divider()
                        }
                    }
                }

                HStack(spacing: 10) {
                    if runtimeCompatibilityState.isChecking {
                        Button(t("Cancel inspection", "確認を中止")) {
                            onCancelRuntimeCompatibility()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        onRefreshRuntimeCompatibility()
                    } label: {
                        Label(
                            runtimeCompatibilityState.isChecking
                                ? t("Inspecting compatibility", "互換性を確認中")
                                : t("Inspect compatibility", "互換性を確認"),
                            systemImage: "tablecells"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeCompatibilityState.isChecking)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Runtime compatibility matrix", "ランタイム互換性マトリクス"))
                    .font(.headline)
                Text(t(
                    "Reports only flags detected from the configured executable. Unknown support remains unknown.",
                    "設定済み実行ファイルから検出したフラグだけを表示します。不明な対応状況は不明のまま扱います。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings-runtime-compatibility")
    }

    private func compatibilitySymbol(_ support: RuntimeCompatibilitySupport) -> String {
        switch support {
        case .supported: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .unsupported: "xmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    private func compatibilityColor(_ support: RuntimeCompatibilitySupport) -> Color {
        switch support {
        case .supported: .green
        case .partial: .orange
        case .unsupported: .secondary
        case .unknown: .secondary
        }
    }

    private var registeredModelHealthSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if registeredModelHealthState.didCheck {
                    ForEach(registeredModelHealthState.reports) { report in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: modelHealthSymbol(report.status))
                                .foregroundStyle(modelHealthColor(report.status))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(report.displayName)
                                        .font(.callout.weight(.semibold))
                                    Text(report.status.localizedTitle(language: language))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(modelHealthColor(report.status))
                                }
                                Text(report.localizedDetail(language: language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        if report.id != registeredModelHealthState.reports.last?.id {
                            Divider()
                        }
                    }
                }

                HStack(spacing: 10) {
                    if registeredModelHealthState.isChecking {
                        Button(t("Cancel inspection", "確認を中止"), action: onCancelRegisteredModelHealth)
                            .buttonStyle(.bordered)
                    }
                    Button {
                        onRefreshRegisteredModelHealth()
                    } label: {
                        Label(
                            registeredModelHealthState.isChecking
                                ? t("Checking model health", "モデル健全性を確認中")
                                : t("Check registered models", "登録済みモデルを確認"),
                            systemImage: "externaldrive.badge.checkmark"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(registeredModelHealthState.isChecking)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Registered model health", "登録済みモデルの健全性"))
                    .font(.headline)
                Text(t(
                    "Checks only registered local paths. It does not scan unrelated folders, delete models, or browse the full Hugging Face cache.",
                    "登録済みローカルパスだけを確認します。無関係なフォルダの走査、モデル削除、Hugging Faceキャッシュ全体の閲覧は行いません。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings-registered-model-health")
    }

    private var operationalReadinessSection: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t(
                        "Review runtime, compatibility, selected model health, endpoint, resource forecast, benchmark evidence, Session Recovery, and Hermes Agent in one report.",
                        "ランタイム、互換性、選択モデルの健全性、接続先、リソース予測、ベンチマーク根拠、セッション復旧、Hermes Agentを一つのレポートで確認します。"
                    ))
                    .font(.callout)
                    Text(t(
                        "The inspection does not generate text, start a server, download a model, or change settings.",
                        "この確認では文章生成、サーバー起動、モデルダウンロード、設定変更を行いません。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button {
                    onOpenOperationalReadiness()
                } label: {
                    Label(t("Open Readiness", "運用準備状態を開く"), systemImage: "checklist.checked")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        } label: {
            Text(t("Unified operational readiness", "統合運用準備状態"))
                .font(.headline)
        }
        .accessibilityIdentifier("settings-operational-readiness")
    }

    private func modelHealthSymbol(_ status: RegisteredModelHealthStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .incomplete, .missing: "xmark.circle.fill"
        case .externalIdentifier: "link.circle"
        case .duplicatePath: "square.on.square"
        case .uninspectable: "questionmark.circle"
        }
    }

    private func modelHealthColor(_ status: RegisteredModelHealthStatus) -> Color {
        switch status {
        case .ready, .externalIdentifier: .green
        case .duplicatePath, .uninspectable: .orange
        case .incomplete, .missing: .red
        }
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
