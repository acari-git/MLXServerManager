import SwiftUI

struct SettingsPanelView: View {
    @Binding var executablePath: String
    @Binding var language: AppLanguage
    let settingsDirectoryPath: String
    let onSave: () -> Void
    let onRunDiagnostics: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
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
