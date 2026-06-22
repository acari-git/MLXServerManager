//
//  ContentView.swift
//  MLXServerManager
//
//  Created by yoinkun on 2026/06/11.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSection = AppSection.dashboard

    var body: some View {
        AppShellView(selectedSection: $selectedSection, language: viewModel.settings.uiLanguage) { section in
            switch section {
            case .dashboard:
                DashboardHomeView(viewModel: viewModel)
            case .profiles:
                ProfilesSurfaceView(
                    models: viewModel.models,
                    selectedModelID: viewModel.selectedModelID,
                    runningModelID: viewModel.runningModelID,
                    restartRequired: viewModel.restartRequired
                )
            case .inspector:
                RuntimeSurfaceView(viewModel: viewModel)
            case .logs:
                LogsSurfaceView(
                    entries: viewModel.logEntries,
                    targetSummary: viewModel.connectionTargetSummary,
                    runningModelText: viewModel.runningModelText,
                    onCopy: viewModel.copyLogsRequested,
                    onClear: viewModel.clearLogsRequested
                )
            case .clientSetup:
                DownloadsSurfaceView(viewModel: viewModel)
            case .metrics:
                SettingsSurfaceView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .confirmationDialog(
            "Delete Model Profile?",
            isPresented: $viewModel.isDeleteProfileConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                viewModel.confirmDeleteProfile()
            }

            Button("Cancel", role: .cancel) {
                viewModel.cancelDeleteProfile()
            }
        } message: {
            Text("This removes only the saved profile. Model files and Hugging Face cache are not deleted.")
        }
        .sheet(isPresented: $viewModel.isImportPreviewPresented) {
            if let result = viewModel.importPreviewResult {
                ImportProfilesPreviewView(
                    result: result,
                    importMessage: viewModel.modelProfileImportMessage,
                    onImportSelected: viewModel.importSelectedProfilesRequested,
                    onClose: viewModel.dismissImportPreview
                )
            } else {
                VStack(spacing: 12) {
                    Text("No import preview is available.")
                    Button("Close") {
                        viewModel.dismissImportPreview()
                    }
                }
                .padding(20)
            }
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            statusHeader

            Divider()

            HSplitView {
                ModelListView(
                    models: viewModel.models,
                    selectedModelID: $viewModel.selectedModelID,
                    runningModelID: viewModel.runningModelID,
                    restartRequired: viewModel.restartRequired,
                    exportSummaryText: viewModel.modelProfileExportSummaryText,
                    exportMessage: viewModel.modelProfileExportMessage,
                    importMessage: viewModel.modelProfileImportMessage,
                    onAddProfile: viewModel.addProfileRequested,
                    onExportProfiles: viewModel.exportProfilesRequested,
                    onImportProfilesPreview: viewModel.importProfilesPreviewRequested
                )
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsPanelView(
                            executablePath: $viewModel.settings.mlxServerExecutablePath,
                            language: $viewModel.settings.uiLanguage,
                            settingsDirectoryPath: viewModel.settingsDirectoryPath,
                            onSave: viewModel.saveSettingsRequested,
                            onRunDiagnostics: viewModel.runDiagnosticsRequested
                        )

                        OnboardingGuidanceView(guidance: viewModel.onboardingGuidance)

                        DashboardOverviewView(
                            targetSummary: viewModel.connectionTargetSummary,
                            runtimeState: viewModel.runtimeState,
                            selectedModel: viewModel.selectedModel,
                            exportSummaryText: viewModel.modelProfileExportSummaryText,
                            memoryUsageText: viewModel.memoryUsageText,
                            selectedModelText: viewModel.selectedModelText,
                            runningModelText: viewModel.runningModelText,
                            restartRequired: viewModel.restartRequired
                        )

                        DiagnosticsPanelView(
                            results: viewModel.diagnosticsResults,
                            didRun: viewModel.diagnosticsDidRun,
                            summaryText: viewModel.diagnosticsSummaryText,
                            onCopySummary: viewModel.copyDiagnosticsSummaryRequested
                        )

                        StatusPanelView(
                            runtimeState: viewModel.runtimeState,
                            memoryUsageText: viewModel.memoryUsageText,
                            selectedModelText: viewModel.selectedModelText,
                            runningModelText: viewModel.runningModelText,
                            restartRequired: viewModel.restartRequired,
                            isExternalServerDetected: viewModel.isExternalServerDetected,
                            isAdoptedExternalServer: viewModel.isAdoptedExternalServer,
                            canStopManagedServer: viewModel.canStopManagedServer,
                            canRestartManagedServer: viewModel.canRestartManagedServer,
                            canAdoptExternalServer: viewModel.canAdoptExternalServer,
                            canForgetExternalServer: viewModel.canForgetExternalServer,
                            onCheckPort: viewModel.checkPortRequested,
                            onCheckReady: viewModel.checkReadyRequested,
                            onStart: viewModel.startRequested,
                            onStop: viewModel.stopRequested,
                            onRestart: viewModel.restartRequested,
                            onAdoptExternalServer: viewModel.adoptExternalServerRequested,
                            onForgetExternalServer: viewModel.forgetExternalServerRequested
                        )

                        ModelDetailView(
                            model: viewModel.selectedModel,
                            runningModelText: viewModel.runningModelText,
                            restartRequired: viewModel.restartRequired,
                            deletionMessage: viewModel.profileDeletionMessage,
                            onEditProfile: viewModel.editProfileRequested,
                            onDeleteProfile: viewModel.deleteProfileRequested
                        )

                        if viewModel.isProfileEditorPresented {
                            ModelProfileEditorView(
                                draft: $viewModel.profileEditorDraft,
                                title: "Edit Model Profile",
                                saveButtonTitle: "Save Profile",
                                noticeMessage: nil,
                                message: viewModel.profileEditorMessage,
                                runtimeFieldsLocked: viewModel.isManagedProcessRunning,
                                onSave: viewModel.saveProfileEditing,
                                onCancel: viewModel.cancelProfileEditing,
                                onCopyPreview: viewModel.copyLaunchCommandPreview
                            )
                        }

                        if viewModel.isAddProfilePresented {
                            ModelProfileEditorView(
                                draft: $viewModel.addProfileDraft,
                                title: "Add Model Profile",
                                saveButtonTitle: "Save New Profile",
                                noticeMessage: viewModel.isManagedProcessRunning
                                    ? "Saving a new profile will not change the running managed server. Stop the managed server before switching runtime profile."
                                    : nil,
                                message: viewModel.addProfileMessage,
                                runtimeFieldsLocked: false,
                                onSave: viewModel.saveNewProfile,
                                onCancel: viewModel.cancelAddProfile,
                                onCopyPreview: viewModel.copyLaunchCommandPreview
                            )
                        }

                        ConnectionSettingsView(
                            targetSummary: viewModel.connectionTargetSummary,
                            baseURL: viewModel.baseURL,
                            modelID: viewModel.selectedModelIdentifier,
                            apiKeyPlaceholder: viewModel.apiKeyPlaceholder,
                            onCopyBaseURL: viewModel.copyBaseURL,
                            onCopyModelID: viewModel.copyModelID,
                            onCopyAPIKeyPlaceholder: viewModel.copyAPIKeyPlaceholder,
                            onCopyConfig: viewModel.copyConfig,
                            onCopyAllConnectionSettings: viewModel.copyAllConnectionSettings,
                            onCopyHermesAgentConfig: viewModel.copyHermesAgentConfig,
                            onCopyModelsCurl: viewModel.copyModelsCurl,
                            onCopyChatCompletionsCurl: viewModel.copyChatCompletionsCurl
                        )

                        LogView(
                            entries: viewModel.logEntries,
                            onCopy: viewModel.copyLogsRequested,
                            onClear: viewModel.clearLogsRequested
                        )
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("MLX Server Manager")
                    .font(.title2.weight(.semibold))
                Text("Direct Mode control surface for mlx_lm.server")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(viewModel.runtimeState.title)
                    .font(.headline)
                Text(viewModel.runtimeState.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 430, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView(viewModel: AppViewModel())
}
