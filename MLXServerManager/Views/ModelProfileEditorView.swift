import SwiftUI

struct ModelProfileEditorView: View {
    @Binding var draft: ModelProfileDraft
    @State private var advancedOptionsStatus: String?

    let title: String
    let saveButtonTitle: String
    let noticeMessage: String?
    let message: String?
    let runtimeFieldsLocked: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let onCopyPreview: (String) -> Void

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
                        Label("Cancel", systemImage: "xmark")
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
                    "Stop the managed server before changing modelID, host, port, or advanced launch options.",
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
                editorRow("Display Name") {
                    TextField("Uses Model ID if empty", text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                }

                editorRow("Model ID") {
                    TextField("Required", text: $draft.modelID)
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

                editorRow("Thinking") {
                    Toggle("Enable thinking", isOn: $draft.enableThinking)
                        .toggleStyle(.checkbox)
                }

                editorRow("Notes") {
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

            DisclosureGroup("Advanced Launch Options") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Leave empty to use mlx_lm.server defaults.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text("Advanced options are workload-dependent and may not improve performance.")
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
                            TextField("Positive integer", text: advancedBinding(\.defaultTopK))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Min P") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultMinP))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Max Tokens") {
                            TextField("Positive integer", text: advancedBinding(\.defaultMaxTokens))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Allowed Origins") {
                            TextField("Optional origin list", text: advancedBinding(\.allowedOrigins))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Log Level") {
                            TextField("Optional log level", text: advancedBinding(\.logLevel))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Decode Concurrency") {
                            TextField("Positive integer", text: advancedBinding(\.decodeConcurrency))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Concurrency") {
                            TextField("Positive integer", text: advancedBinding(\.promptConcurrency))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prefill Step Size") {
                            TextField("Positive integer", text: advancedBinding(\.prefillStepSize))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Cache Size") {
                            TextField("Positive integer", text: advancedBinding(\.promptCacheSize))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Cache Bytes") {
                            TextField("Positive integer", text: advancedBinding(\.promptCacheBytes))
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

                                Text("Expert only. Raw arguments are appended last and used only when explicitly set.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Launch Command Preview")
                                .font(.callout.weight(.medium))

                            Spacer()

                            Button {
                                onCopyPreview(launchCommandPreview)
                                advancedOptionsStatus = "Preview copied."
                            } label: {
                                Label("Copy Preview", systemImage: "doc.on.doc")
                            }
                            .disabled(!canCopyLaunchCommandPreview)

                            Button {
                                draft.advancedLaunchOptions = .empty
                                advancedOptionsStatus = "Advanced options cleared."
                            } label: {
                                Label("Clear Advanced Options", systemImage: "clear")
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
            return "Complete Model ID, Host, and Port to preview the launch command."
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
