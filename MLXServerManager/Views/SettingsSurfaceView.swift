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
            executablePath: $draftSettings.mlxServerExecutablePath,
            defaultHost: $draftSettings.defaultHost,
            defaultPort: $draftSettings.defaultPort,
            apiKeyPlaceholder: $draftSettings.apiKeyPlaceholder,
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
        viewModel.settings = draftSettings
        viewModel.saveSettingsRequested()
        savedSettingsSnapshot = draftSettings
    }
}
