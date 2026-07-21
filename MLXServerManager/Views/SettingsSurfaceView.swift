import SwiftUI

struct SettingsSurfaceView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var draftSettings: AppSettings = .defaults
    @State private var savedSettingsSnapshot: AppSettings = .defaults

    private var hasUnsavedChanges: Bool {
        draftSettings != savedSettingsSnapshot
    }

    var body: some View {
        SettingsPanelView(
            mlxExecutablePath: $draftSettings.mlxServerExecutablePath,
            rapidMLXExecutablePath: $draftSettings.rapidMLXExecutablePath,
            defaultHost: $draftSettings.defaultHost,
            defaultPort: $draftSettings.defaultPort,
            apiKeyPlaceholder: $draftSettings.apiKeyPlaceholder,
            hermesConfigPath: $draftSettings.hermesConfigPath,
            downloadSaveDirectory: $draftSettings.downloadSaveDirectory,
            maxConcurrentModelDownloads: $draftSettings.maxConcurrentModelDownloads,
            language: $draftSettings.uiLanguage,
            appearance: $draftSettings.uiAppearance,
            settingsDirectoryPath: viewModel.settingsDirectoryPath,
            hasUnsavedChanges: hasUnsavedChanges,
            onDiscard: discardDraftSettings,
            onSave: saveDraftSettings
        )
        .accessibilityIdentifier("settings-surface")
        .onAppear(perform: resetDraftFromSavedSettings)
        .onDisappear(perform: discardDraftSettings)
        .onChange(of: draftSettings.uiLanguage) { _, _ in
            applyLanguagePreview()
        }
    }

    private func resetDraftFromSavedSettings() {
        savedSettingsSnapshot = viewModel.settings
        draftSettings = viewModel.settings
    }

    private func discardDraftSettings() {
        draftSettings = savedSettingsSnapshot
        viewModel.settings = savedSettingsSnapshot
    }

    private func applyLanguagePreview() {
        viewModel.settings.uiLanguage = draftSettings.uiLanguage
    }

    private func saveDraftSettings() {
        if viewModel.saveSettingsRequested(draftSettings) {
            savedSettingsSnapshot = draftSettings
        } else {
            viewModel.settings = savedSettingsSnapshot
        }
    }
}
