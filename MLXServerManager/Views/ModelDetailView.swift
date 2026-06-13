import SwiftUI

struct ModelDetailView: View {
    let model: ModelConfig?
    let deletionMessage: String?
    let onEditProfile: () -> Void
    let onDeleteProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Selected Model")
                    .font(.headline)

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        onEditProfile()
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDeleteProfile()
                    } label: {
                        Label("Delete Profile", systemImage: "trash")
                    }
                }
                .disabled(model == nil)
            }

            if let deletionMessage, !deletionMessage.isEmpty {
                Label(deletionMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let model {
                DetailGrid(rows: [
                    ("Model ID", model.modelID),
                    ("Display Name", model.displayName),
                    ("Family", model.family),
                    ("Quantization", model.quantization),
                    ("Context", model.contextWindow),
                    ("Local Name", model.localName),
                    ("Endpoint", "\(model.host):\(model.serverPort)"),
                    ("Thinking", model.enableThinking ? "Enabled" : "Disabled"),
                    ("Notes", model.notes)
                ])
            } else {
                Text("No model selected")
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }
}

struct DetailGrid: View {
    let rows: [(String, String)]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach(rows, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)

                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
