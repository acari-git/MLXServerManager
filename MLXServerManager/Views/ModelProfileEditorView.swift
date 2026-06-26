import SwiftUI

struct ModelProfileEditorView: View {
    @Binding var draft: ModelProfileDraft
    @State private var advancedOptionsStatus: String?

    let title: String
    let saveButtonTitle: String
    let noticeMessage: String?
    let message: String?
    let runtimeFieldsLocked: Bool
    let language: AppLanguage = .system
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
        VStack(alignment: .leading, spacing: 14) {
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

            if let noticeMessage, !noticeMessage.isEmpty {
                Label(noticeMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if runtimeFieldsLocked {
                Label(
                    t("Stop the managed server before changing Model ID, host, port, or advanced launch options.", "Model ID、ホスト、ポート、詳細起動オプションを変更する前に、管理中のサーバーを停止してください。"),
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

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                editorRow(t("Display Name", "表示名")) {
                    TextField(t("Uses Model ID if empty", "空欄の場合はModel IDを使用"), text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                }

                editorRow("Model ID") {
                    TextField(t("Required", "必須"), text: $draft.modelID)
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

                editorRow(t("Thinking", "Thinking")) {
                    Toggle(t("Enable thinking", "Thinkingを有効にする"), isOn: $draft.enableThinking)
                        .toggleStyle(.checkbox)
                }

                editorRow(t("Notes", "メモ")) {
                    TextEditor(text: $draft.notes)
                        .font(.callout)
                        .frame(minHeight: 72)
                        .scrollContentBackground(.hidden)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
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

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
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
                            TextEditor(text: advancedBinding(\.chatTemplateArgs))
                                .font(.system(.callout, design: .monospaced))
                                .frame(minHeight: 60)
                                .scrollContentBackground(.hidden)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                }
                        }

                        advancedRow("Raw Extra Args") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextEditor(text: advancedBinding(\.rawExtraArgs))
                                    .font(.system(.callout, design: .monospaced))
                                    .frame(minHeight: 60)
                                    .scrollContentBackground(.hidden)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                    }

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
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

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
        .panelStyle()
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

    private var launchCommandPreview: String {
        guard let request = launchCommandPreviewRequest else {
            return t("Complete Model ID, Host, and Port to preview the launch command.", "起動コマンドをプレビューするには、Model ID、ホスト、ポートを入力してください。")
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
