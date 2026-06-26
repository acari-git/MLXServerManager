import SwiftUI

struct SettingsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedAppearance: String

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                appearanceSettings
                SettingsPanelView(
                    executablePath: $viewModel.settings.mlxServerExecutablePath,
                    defaultHost: $viewModel.settings.defaultHost,
                    defaultPort: $viewModel.settings.defaultPort,
                    apiKeyPlaceholder: $viewModel.settings.apiKeyPlaceholder,
                    language: $viewModel.settings.uiLanguage,
                    settingsDirectoryPath: viewModel.settingsDirectoryPath,
                    onSave: viewModel.saveSettingsRequested,
                    onRunDiagnostics: viewModel.runDiagnosticsRequested
                )
                appBoundaries
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("settings-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(strings.text(.settings))
                    .font(.title2.weight(.semibold))
            }
            Text(t(
                "Configure app settings, appearance, and language. Runtime, downloads, and model management are separated into their own surfaces.",
                "アプリ設定、外観、言語を設定します。ランタイム、ダウンロード、モデル管理はそれぞれ専用画面に分けています。"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(t("Appearance", "外観"), systemImage: "circle.lefthalf.filled")
                .font(.headline)
            Text(t(
                "Switch the app-wide display theme here. The right panel does not duplicate appearance settings.",
                "アプリ全体の表示テーマをここで切り替えます。右ペインには外観設定を置きません。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Picker(t("Appearance", "外観"), selection: $selectedAppearance) {
                Text(t("System", "システム")).tag("system")
                Text(t("Light", "ライト")).tag("light")
                Text(t("Dark", "ダーク")).tag("dark")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .panelStyle()
        .accessibilityIdentifier("settings-appearance-panel")
    }

    private var appBoundaries: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Scope boundaries", "スコープ境界"))
                .font(.headline)
            Label(t("Direct Mode remains client to mlx_lm.server.", "Direct Modeでは、クライアントがmlx_lm.serverへ直接接続します。"), systemImage: "arrow.right.circle")
            Label(t("Language selection changes app labels, not model IDs, paths, commands, or raw logs.", "言語設定で変わるのはアプリの表示ラベルです。モデルID、パス、コマンド、生ログは変更しません。"), systemImage: "character.book.closed")
            Label(t("Proxy, chat UI, telemetry, model-file deletion, and credential storage are not enabled here.", "ここではプロキシ、チャットUI、テレメトリー、モデルファイル削除、認証情報保存を有効にしません。"), systemImage: "lock.shield")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .panelStyle()
    }
}
