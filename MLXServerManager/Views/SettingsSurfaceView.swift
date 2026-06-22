import SwiftUI

struct SettingsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
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
            Text("Configure app settings and language. Runtime, downloads, and model management are separated into their own surfaces.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var appBoundaries: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scope boundaries")
                .font(.headline)
            Label("Direct Mode remains client → mlx_lm.server.", systemImage: "arrow.right.circle")
            Label("Language selection changes app labels, not model IDs, paths, commands, or raw logs.", systemImage: "character.book.closed")
            Label("No proxy, chat UI, telemetry, model-file deletion, or token storage is enabled here.", systemImage: "lock.shield")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .panelStyle()
    }
}
