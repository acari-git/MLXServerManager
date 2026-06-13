import SwiftUI

struct ModelListView: View {
    let models: [ModelConfig]
    @Binding var selectedModelID: ModelConfig.ID?
    let runningModelID: ModelConfig.ID?
    let restartRequired: Bool
    let onAddProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Models")
                    .font(.headline)

                Spacer()

                Button {
                    onAddProfile()
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .help("Add Profile")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            List(models, selection: $selectedModelID) { model in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.body.weight(.medium))
                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if model.id == selectedModelID {
                            statusPill("Selected", color: .accentColor)
                        }

                        if model.id == runningModelID {
                            statusPill("Running", color: .green)
                        }

                        if restartRequired, model.id == selectedModelID {
                            statusPill("Restart required", color: .orange)
                        }
                    }
                }
                .padding(.vertical, 4)
                .tag(model.id)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
