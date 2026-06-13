import SwiftUI

struct ModelListView: View {
    let models: [ModelConfig]
    @Binding var selectedModelID: ModelConfig.ID?
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
                }
                .padding(.vertical, 4)
                .tag(model.id)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}
