import SwiftUI

struct ModelProfileEditorView: View {
    @Binding var draft: ModelProfileDraft
    @State private var advancedOptionsStatus: String?

    let title: String
    let saveButtonTitle: String
    let noticeMessage: String?
    let message: String?
    let runtimeFieldsLocked: Bool
    let language: AppLanguage
    let onSave: () -> Void
    let onCancel: () -> Void
    let onCopyPreview: (String) -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                editorContent
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Label(t("Cancel", "キャンセル"), systemImage: "xmark")
                }

                Button {
                    onSave()
                } label: {
                    Label(saveButtonTitle, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let noticeMessage, !noticeMessage.isEmpty {
                Label(noticeMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if runtimeFieldsLocked {
                Label(
                    t("Stop the managed server before changing model path, host, port, or advanced launch options.", "モデルパス、ホスト、ポート、詳細起動オプションを変更する前に、管理中のサーバーを停止してください。"),
                    systemImage: "lock.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let message, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 14) {
                editorRow(t("Display Name", "表示名")) {
                    TextField(t("Uses model path if empty", "空欄の場合はモデルパスを使用"), text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                }

                editorRow(t("Model Path", "モデルパス")) {
                    TextField(t("Local path or Hugging Face model ID", "ローカルパスまたはHugging FaceモデルID"), text: $draft.modelID)
                        .textFieldStyle(.roundedBorder)
                        .disabled(runtimeFieldsLocked)
                }

                editorRow("Host") {
                    TextField("127.0.0.1", text: $draft.host)
                        .textFieldStyle(.roundedBorder)
                        .disabled(runtimeFieldsLocked)
                }

                editorRow("Port") {
                    TextField("8080", text: $draft.serverPortText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(runtimeFieldsLocked)
                }

                editorRow(t("Reasoning Mode", "推論モード")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(t("Enable reasoning mode", "推論モードを有効にする"), isOn: $draft.enableThinking)
                            .toggleStyle(.checkbox)
                        Text(t("For complex tasks. Responses may be slower.", "複雑なタスク向け。応答は遅くなる場合があります。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                editorRow(t("Notes", "メモ")) {
                    borderedTextEditor(text: $draft.notes, minHeight: 112)
                }
            }

            DisclosureGroup(t("Advanced Launch Options", "詳細起動オプション")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("Leave empty to use mlx_lm.server defaults.", "空欄の場合はmlx_lm.serverの既定値を使用します。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(t("Advanced options are workload-dependent and may not improve performance.", "詳細オプションの効果はワークロードに依存し、性能改善を保証するものではありません。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 14) {
                        advancedRow("Temperature") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultTemperature))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Top P") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultTopP))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Top K") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.defaultTopK))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Min P") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultMinP))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Max Tokens") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.defaultMaxTokens))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Allowed Origins") {
                            TextField(t("Optional origin list", "任意のオリジン一覧"), text: advancedBinding(\.allowedOrigins))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Log Level") {
                            TextField(t("Optional log level", "任意のログレベル"), text: advancedBinding(\.logLevel))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Decode Concurrency") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.decodeConcurrency))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Concurrency") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.promptConcurrency))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prefill Step Size") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.prefillStepSize))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Cache Size") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.promptCacheSize))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Cache Bytes") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.promptCacheBytes))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Chat Template Args") {
                            borderedTextEditor(
                                text: advancedBinding(\.chatTemplateArgs),
                                minHeight: 112,
                                font: .system(.callout, design: .monospaced)
                            )
                        }

                        advancedRow("Raw Extra Args") {
                            VStack(alignment: .leading, spacing: 6) {
                                borderedTextEditor(
                                    text: advancedBinding(\.rawExtraArgs),
                                    minHeight: 112,
                                    font: .system(.callout, design: .monospaced)
                                )

                                Text(t("Expert only. Raw arguments are appended last and used only when explicitly set.", "上級者向けです。Raw引数は最後に追加され、明示した場合のみ使われます。"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t("Launch Command Preview", "起動コマンドプレビュー"))
                                .font(.callout.weight(.medium))

                            Spacer()

                            Button {
                                onCopyPreview(launchCommandPreview)
                                advancedOptionsStatus = t("Preview copied.", "プレビューをコピーしました。")
                            } label: {
                                Label(t("Copy Preview", "プレビューをコピー"), systemImage: "doc.on.doc")
                            }
                            .disabled(!canCopyLaunchCommandPreview)

                            Button {
                                draft.advancedLaunchOptions = .empty
                                advancedOptionsStatus = t("Advanced options cleared.", "詳細オプションをクリアしました。")
                            } label: {
                                Label(t("Clear Advanced Options", "詳細オプションをクリア"), systemImage: "clear")
                            }
                        }

                        Text(launchCommandPreview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let advancedOptionsStatus {
                            Text(advancedOptionsStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .disabled(runtimeFieldsLocked)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editorRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func advancedRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func advancedBinding(_ keyPath: WritableKeyPath<AdvancedLaunchOptions, String?>) -> Binding<String> {
        Binding {
            draft.advancedLaunchOptions[keyPath: keyPath] ?? ""
        } set: { newValue in
            draft.advancedLaunchOptions[keyPath: keyPath] = newValue
        }
    }

    private func borderedTextEditor(
        text: Binding<String>,
        minHeight: CGFloat,
        font: Font = .callout
    ) -> some View {
        TextEditor(text: text)
            .font(font)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.72), lineWidth: 1)
            )
    }

    private var launchCommandPreview: String {
        guard let request = launchCommandPreviewRequest else {
            return t("Complete Model Path, Host, and Port to preview the launch command.", "起動コマンドをプレビューするには、モデルパス、ホスト、ポートを入力してください。")
        }

        return ModelProcessManager.commandPreview(for: request, executablePath: "mlx_lm.server")
    }

    private var canCopyLaunchCommandPreview: Bool {
        launchCommandPreviewRequest != nil
    }

    private var launchCommandPreviewRequest: ModelLaunchRequest? {
        let modelID = draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !modelID.isEmpty, !host.isEmpty, let port = Int(portText) else {
            return nil
        }

        return ModelLaunchRequest(
            executablePath: "mlx_lm.server",
            modelID: modelID,
            host: host,
            port: port,
            enableThinking: draft.enableThinking,
            advancedLaunchOptions: draft.advancedLaunchOptions.normalized()
        )
    }
}
