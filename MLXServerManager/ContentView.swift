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

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        IntegratedWorkspaceView(viewModel: viewModel)
            .frame(minWidth: 1280, minHeight: 760)
        .confirmationDialog(
            t("Delete Model Profile?", "モデルプロファイルを削除しますか？"),
            isPresented: $viewModel.isDeleteProfileConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(t("Delete Profile", "プロファイルを削除"), role: .destructive) {
                viewModel.confirmDeleteProfile()
            }

            Button(strings.text(.cancel), role: .cancel) {
                viewModel.cancelDeleteProfile()
            }
        } message: {
            Text(t("This removes only the saved profile. Model files and Hugging Face cache are not deleted.", "削除するのは保存済みプロファイルのみです。モデルファイルとHugging Faceキャッシュは削除されません。"))
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isProfileEditorPresented },
            set: { if !$0 { viewModel.cancelProfileEditing() } }
        )) {
            ModelProfileEditorView(
                draft: $viewModel.profileEditorDraft,
                title: t("Edit Model Profile", "モデルプロファイルを編集"),
                saveButtonTitle: t("Save Profile", "プロファイルを保存"),
                noticeMessage: viewModel.isManagedProcessRunning
                    ? t("Runtime fields are locked while the managed server is running.", "管理中サーバーの実行中はランタイム項目を編集できません。")
                    : nil,
                message: viewModel.profileEditorMessage,
                runtimeFieldsLocked: viewModel.isManagedProcessRunning,
                onSave: viewModel.saveProfileEditing,
                onCancel: viewModel.cancelProfileEditing,
                onCopyPreview: viewModel.copyLaunchCommandPreview
            )
            .padding(20)
            .frame(minWidth: 620, minHeight: 520)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isAddProfilePresented },
            set: { if !$0 { viewModel.cancelAddProfile() } }
        )) {
            ModelProfileEditorView(
                draft: $viewModel.addProfileDraft,
                title: t("Add Model Profile", "モデルプロファイルを追加"),
                saveButtonTitle: t("Save New Profile", "新規プロファイルを保存"),
                noticeMessage: viewModel.isManagedProcessRunning
                    ? t("Saving a new profile will not change the running managed server.", "新規プロファイルを保存しても、実行中の管理サーバーは変更されません。")
                    : nil,
                message: viewModel.addProfileMessage,
                runtimeFieldsLocked: false,
                onSave: viewModel.saveNewProfile,
                onCancel: viewModel.cancelAddProfile,
                onCopyPreview: viewModel.copyLaunchCommandPreview
            )
            .padding(20)
            .frame(minWidth: 620, minHeight: 520)
        }
        .sheet(isPresented: $viewModel.isImportPreviewPresented) {
            if let result = viewModel.importPreviewResult {
                ImportProfilesPreviewView(
                    result: result,
                    importMessage: viewModel.modelProfileImportMessage,
                    language: viewModel.settings.uiLanguage,
                    onImportSelected: viewModel.importSelectedProfilesRequested,
                    onClose: viewModel.dismissImportPreview
                )
            } else {
                VStack(spacing: 12) {
                    Text(t("No import preview is available.", "インポートプレビューはありません。"))
                    Button(t("Close", "閉じる")) {
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
                    language: viewModel.settings.uiLanguage,
                    onAddProfile: viewModel.addProfileRequested,
                    onExportProfiles: viewModel.exportProfilesRequested,
                    onImportProfilesPreview: viewModel.importProfilesPreviewRequested
                )
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
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

                        OnboardingGuidanceView(
                            guidance: viewModel.onboardingGuidance,
                            language: viewModel.settings.uiLanguage
                        )

                        DashboardOverviewView(
                            targetSummary: viewModel.connectionTargetSummary,
                            runtimeState: viewModel.runtimeState,
                            selectedModel: viewModel.selectedModel,
                            exportSummaryText: viewModel.modelProfileExportSummaryText,
                            memoryUsageText: viewModel.memoryUsageText,
                            selectedModelText: viewModel.selectedModelText,
                            runningModelText: viewModel.runningModelText,
                            restartRequired: viewModel.restartRequired,
                            language: viewModel.settings.uiLanguage
                        )

                        DiagnosticsPanelView(
                            results: viewModel.diagnosticsResults,
                            didRun: viewModel.diagnosticsDidRun,
                            summaryText: viewModel.diagnosticsSummaryText,
                            language: viewModel.settings.uiLanguage,
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
                            language: viewModel.settings.uiLanguage,
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
                            language: viewModel.settings.uiLanguage,
                            onEditProfile: viewModel.editProfileRequested,
                            onDeleteProfile: viewModel.deleteProfileRequested
                        )

                        if viewModel.isProfileEditorPresented {
                            ModelProfileEditorView(
                                draft: $viewModel.profileEditorDraft,
                                title: t("Edit Model Profile", "モデルプロファイルを編集"),
                                saveButtonTitle: t("Save Profile", "プロファイルを保存"),
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
                                title: t("Add Model Profile", "モデルプロファイルを追加"),
                                saveButtonTitle: t("Save New Profile", "新規プロファイルを保存"),
                                noticeMessage: viewModel.isManagedProcessRunning
                                    ? t("Saving a new profile will not change the running managed server. Stop the managed server before switching runtime profile.", "新規プロファイルを保存しても実行中の管理サーバーは変更されません。ランタイムプロファイルを切り替える前に管理サーバーを停止してください。")
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
                            language: viewModel.settings.uiLanguage,
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
                            language: viewModel.settings.uiLanguage,
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
                Text(t("Direct Mode control surface for mlx_lm.server", "mlx_lm.serverのDirect Mode操作画面"))
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
