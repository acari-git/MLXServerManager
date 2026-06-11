import SwiftUI

struct SettingsPanelView: View {
    @Binding var executablePath: String
    let settingsDirectoryPath: String
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("mlx_lm.server executable path")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Unset", text: $executablePath)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button {
                    onSave()
                } label: {
                    Label("Save Settings", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Text(settingsDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .panelStyle()
    }
}

