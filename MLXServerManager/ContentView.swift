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
                }
            }
            .animation(.spring(response: 0.30, dampingFraction: 0.88), value: viewModel.profileDeletionUndoState?.id)
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
        .sheet(isPresented: Binding(
            get: { viewModel.isProfileEditorPresented },
            set: { if !$0 { viewModel.cancelProfileEditing() } }
        )) {
            ModelProfileEditorView(
                draft: $viewModel.profileEditorDraft,
                title: t("Edit Model Profile", "モデルプロファイルを編集"),
                saveButtonTitle: t("Save Profile", "プロファイルを保存"),
                noticeMessage: viewModel.isProfileEditorRuntimeLocked
                    ? t("Runtime fields are locked while the managed server is running.", "管理中サーバーの実行中はランタイム項目を編集できません。")
                    : nil,
                message: viewModel.profileEditorMessage,
                runtimeFieldsLocked: viewModel.isProfileEditorRuntimeLocked,
                kvCacheEnvironment: viewModel.profileEditorKVCacheEnvironment,
                language: viewModel.settings.uiLanguage,
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
                kvCacheEnvironment: viewModel.addProfileKVCacheEnvironment,
                language: viewModel.settings.uiLanguage,
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

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .help(t("Dismiss", "閉じる"))
            }

            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let remaining = max(state.expiresAt.timeIntervalSince(context.date), 0)
                ProgressView(value: min(max(remaining / 4, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
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
