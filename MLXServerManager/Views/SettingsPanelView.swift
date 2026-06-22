import SwiftUI

struct SettingsPanelView: View {
    @Binding var executablePath: String
    @Binding var defaultHost: String
    @Binding var defaultPort: Int
    @Binding var apiKeyPlaceholder: String
    @Binding var language: AppLanguage
    let settingsDirectoryPath: String
    let onSave: () -> Void
    let onRunDiagnostics: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private var portTextBinding: Binding<String> {
        Binding(
            get: { String(defaultPort) },
            set: { newValue in
                if let value = Int(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    defaultPort = value
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.text(.settings))
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("mlx_lm.server executable path")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Unset", text: $executablePath)
                    .textFieldStyle(.roundedBorder)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Default host")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("127.0.0.1", text: $defaultHost)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Default port")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("8080", text: portTextBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                }
                GridRow {
                    Text("API key placeholder")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("not-required-local", text: $apiKeyPlaceholder)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(strings.text(.language))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker(strings.text(.language), selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Button {
                    onSave()
                } label: {
                    Label(strings.text(.saveSettings), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onRunDiagnostics()
                } label: {
                    Label(strings.text(.runDiagnostics), systemImage: "stethoscope")
                }

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
