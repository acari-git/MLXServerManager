import SwiftUI

struct ModelProfileEditorView: View {
    @Binding var draft: ModelProfileDraft
    let title: String
    let saveButtonTitle: String
    let noticeMessage: String?
    let message: String?
    let runtimeFieldsLocked: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

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
                    "Stop the managed server before changing modelID, host, or port.",
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
}
