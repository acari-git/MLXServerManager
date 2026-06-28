import SwiftUI

struct SettingsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
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
        .accessibilityIdentifier("settings-surface")
    }

}
