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
            runtimeReadinessState: viewModel.runtimeReadinessViewState,
            runtimeSetupAssistantState: viewModel.runtimeSetupAssistantViewState,
            runtimeCompatibilityState: viewModel.runtimeCompatibilityViewState,
            registeredModelHealthState: viewModel.registeredModelHealthViewState,
            hasUnsavedChanges: hasUnsavedChanges,
            onRefreshRuntimeReadiness: {
                viewModel.refreshRuntimeReadinessRequested(settings: draftSettings)
            },
            onCancelRuntimeReadiness: {
                viewModel.cancelRuntimeReadinessRequested(settings: draftSettings)
            },
            onDiscoverRuntimeCandidates: {
                viewModel.discoverRuntimeCandidatesRequested(settings: draftSettings)
            },
            onCancelRuntimeCandidateDiscovery: viewModel.cancelRuntimeCandidateDiscoveryRequested,
            onApplyRuntimeCandidate: applyRuntimeCandidate,
            onRefreshRuntimeCompatibility: {
                viewModel.refreshRuntimeCompatibilityRequested(settings: draftSettings)
            },
            onCancelRuntimeCompatibility: viewModel.cancelRuntimeCompatibilityRequested,
            onRefreshRegisteredModelHealth: viewModel.refreshRegisteredModelHealthRequested,
            onCancelRegisteredModelHealth: viewModel.cancelRegisteredModelHealthRequested,
            onOpenOperationalReadiness: viewModel.openOperationalReadinessRequested,
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

    private func applyRuntimeCandidate(_ candidate: RuntimeSetupCandidate) {
        switch candidate.backend {
        case .mlxLM:
            draftSettings.mlxServerExecutablePath = candidate.executablePath
        case .rapidMLX:
            draftSettings.rapidMLXExecutablePath = candidate.executablePath
        }
    }

    private func saveDraftSettings() {
        if viewModel.saveSettingsRequested(draftSettings) {
            savedSettingsSnapshot = draftSettings
        } else {
            viewModel.settings = savedSettingsSnapshot
        }
    }
}
