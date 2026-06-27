import SwiftUI

struct SettingsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

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
        .liquidGlassLayerOne(cornerRadius: 0)
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
                "Use this page for connection defaults and diagnostics. Language and theme are in the bottom-left Settings menu.",
                "この画面では接続の既定値と診断を扱います。言語とテーマは左下の設定メニューに移動しました。"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var appBoundaries: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(t("What Settings does not do", "設定画面で行わないこと"), systemImage: "hand.raised")
                .font(.headline)
            Label(t("Direct Mode remains client to mlx_lm.server.", "Direct Modeでは、クライアントがmlx_lm.serverへ直接接続します。"), systemImage: "arrow.right.circle")
            Label(t("Language and theme changes affect app chrome only; model IDs, paths, commands, and raw logs stay unchanged.", "言語とテーマの変更対象はアプリ表示のみです。Model ID、パス、コマンド、生ログは変わりません。"), systemImage: "character.book.closed")
            Label(t("Use Models for profile work, Downloads for Hugging Face, Runtime for server actions, and Logs for troubleshooting.", "プロファイル作業はモデル、Hugging Faceはダウンロード、サーバー操作はランタイム、調査はログで行います。"), systemImage: "square.grid.2x2")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .panelStyle()
    }
}
