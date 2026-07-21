//
//  ContentView.swift
//  MLXServerManager
//
//  Created by yoinkun on 2026/06/11.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        IntegratedWorkspaceView(viewModel: viewModel)
            .frame(minWidth: 0, minHeight: IntegratedWorkspaceView.baseMinimumHeight)
            .background(WindowTitlebarSeparatorHider())
            .overlay(alignment: .bottomTrailing) {
                if let undoState = viewModel.profileDeletionUndoState {
                    ProfileDeletionUndoSnackbar(
                        state: undoState,
                        language: viewModel.settings.uiLanguage,
                        onUndo: viewModel.undoProfileDeletionRequested,
                        onDismiss: viewModel.dismissProfileDeletionUndo
                    )
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let message = viewModel.profileDeletionMessage {
                    ProfileDeletionMessageSnackbar(
                        message: message,
                        language: viewModel.settings.uiLanguage,
                        onDismiss: viewModel.dismissProfileDeletionMessage
                    )
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.30, dampingFraction: 0.88), value: viewModel.profileDeletionUndoState?.id)
            .animation(.spring(response: 0.30, dampingFraction: 0.88), value: viewModel.profileDeletionMessage)
        .confirmationDialog(
            t("Delete Model Profile?", "モデルプロファイルを削除しますか？"),
            isPresented: $viewModel.isDeleteProfileConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(t("Delete Profile", "プロファイルを削除"), role: .destructive) {
                viewModel.confirmDeleteProfile()
            }

            Button(t("Delete Profile and Hugging Face Cache", "プロファイルとHugging Faceキャッシュを削除"), role: .destructive) {
                viewModel.confirmDeleteProfile(deleteHuggingFaceCache: true)
            }

            Button(strings.text(.cancel), role: .cancel) {
                viewModel.cancelDeleteProfile()
            }
        } message: {
            Text(t(
                "Choose profile-only deletion, or also remove the matching Hugging Face hub cache. Local model folders are not deleted.",
                "プロファイルのみ削除するか、一致するHugging Face hubキャッシュも削除するかを選択します。ローカルのモデルフォルダは削除されません。"
            ))
        }
        .alert(
            viewModel.networkExposureConfirmationTitle,
            isPresented: $viewModel.isNetworkExposureStartConfirmationPresented
        ) {
            Button(t("Start Anyway", "このまま起動"), role: .destructive) {
                viewModel.confirmNetworkExposureStart()
            }
            Button(strings.text(.cancel), role: .cancel) {
                viewModel.cancelNetworkExposureStart()
            }
        } message: {
            Text(viewModel.networkExposureConfirmationDetail)
        }
        .alert(
            viewModel.memoryRiskConfirmationTitle,
            isPresented: $viewModel.isMemoryRiskStartConfirmationPresented
        ) {
            Button(t("Start Anyway", "このまま起動"), role: .destructive) {
                viewModel.confirmMemoryRiskStart()
            }
            Button(strings.text(.cancel), role: .cancel) {
                viewModel.cancelMemoryRiskStart()
            }
        } message: {
            Text(viewModel.memoryRiskConfirmationDetail)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isProfileEditorPresented },
            set: { if !$0 { viewModel.cancelProfileEditing() } }
        )) {
            ModelProfileEditorView(
                draft: $viewModel.profileEditorDraft,
                title: t("Edit Model Profile", "モデルプロファイルを編集"),
                saveButtonTitle: t("Save Profile", "プロファイルを保存"),
                noticeMessage: viewModel.profileEditorNoticeMessage,
                message: viewModel.profileEditorMessage,
                runtimeFieldsLocked: viewModel.isProfileEditorRuntimeLocked,
                kvCacheEnvironment: viewModel.profileEditorKVCacheEnvironment,
                language: viewModel.settings.uiLanguage,
                portSuggestionMessage: viewModel.profileEditorPortSuggestionMessage,
                onSuggestPort: viewModel.suggestAvailablePortForProfileEditor,
                onEndpointInputChanged: viewModel.profileEditorEndpointInputChanged,
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
                noticeMessage: viewModel.addProfileNoticeMessage,
                message: viewModel.addProfileMessage,
                runtimeFieldsLocked: false,
                kvCacheEnvironment: viewModel.addProfileKVCacheEnvironment,
                language: viewModel.settings.uiLanguage,
                portSuggestionMessage: viewModel.addProfilePortSuggestionMessage,
                onSuggestPort: viewModel.suggestAvailablePortForAddProfile,
                onEndpointInputChanged: viewModel.addProfileEndpointInputChanged,
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
}

private struct ProfileDeletionUndoSnackbar: View {
    let state: ProfileDeletionUndoState
    let language: AppLanguage
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)

                Text(t("Deleted \(state.displayName)", "\(state.displayName)を削除しました"))
                    .font(.callout.weight(.medium))
                    .lineLimit(2)

                Spacer(minLength: 12)

                Button(t("Undo", "元に戻す"), action: onUndo)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint(t(
                        "Restore the deleted model profile.",
                        "削除したモデルプロファイルを復元します。"
                    ))

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .help(t("Dismiss", "閉じる"))
                .accessibilityLabel(t("Dismiss", "閉じる"))
            }

            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let remaining = max(state.expiresAt.timeIntervalSince(context.date), 0)
                ProgressView(value: min(max(remaining / 4, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .accessibilityLabel(t(
                        "Time remaining to undo deletion",
                        "削除を元に戻せる残り時間"
                    ))
                    .accessibilityValue(t(
                        "About \(Int(ceil(remaining))) seconds",
                        "約\(Int(ceil(remaining)))秒"
                    ))
            }
        }
        .padding(12)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }
}

private struct ProfileDeletionMessageSnackbar: View {
    let message: String
    let language: AppLanguage
    let onDismiss: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text(message)
                .font(.callout)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .help(strings.text(english: "Dismiss", japanese: "閉じる"))
            .accessibilityLabel(strings.text(english: "Dismiss", japanese: "閉じる"))
        }
        .padding(12)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-deletion-message")
    }
}

private struct WindowTitlebarSeparatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarSeparatorStyle = .none
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.titlebarSeparatorStyle = .none
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }
}
