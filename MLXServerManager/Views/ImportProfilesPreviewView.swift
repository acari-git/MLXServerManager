import SwiftUI

struct ImportProfilesPreviewView: View {
    let result: ImportPreviewResult
    let importMessage: String?
    let onImportSelected: (Set<Int>) -> Void
    let onClose: () -> Void

    @State private var selectedSourceIndexes: Set<Int> = []
    @State private var isImportConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    importScopeNotice
                    documentSummary
                    messageSection(title: "Document Messages", messages: result.documentMessages)
                    profilesSection
                }
                .padding(.trailing, 8)
            }

            HStack {
                Text(importMessage ?? "Only selected valid profiles without conflicts will be imported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Import Selected Profiles") {
                    isImportConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedImportableCount == 0)

                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 760, idealWidth: 880, minHeight: 620, idealHeight: 720)
        .onAppear {
            selectedSourceIndexes = Set(importableProfiles.map(\.sourceIndex))
        }
        .alert("Import selected profile metadata?", isPresented: $isImportConfirmationPresented) {
            Button("Import Selected Profiles") {
                onImportSelected(selectedSourceIndexes)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will add selected profiles only. It will not start servers, call /v1/models, download models, import secrets, or change process ownership.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Profiles Preview")
                    .font(.title2.weight(.semibold))

                Text(result.sourceFileName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(result.canProceedToFutureImport ? "\(selectedImportableCount) selected for import" : "Import blocked")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(result.canProceedToFutureImport ? .green : .red)

                Text("\(result.validProfilesCount) valid, \(result.invalidProfilesCount) invalid, \(result.warningCount) warning(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importScopeNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Only selected valid profiles without conflicts will be imported. Rename and replace are future work.", systemImage: "checklist")
                .font(.callout.weight(.semibold))

            Text("Import does not start, stop, or restart servers. It does not call /v1/models, make external HTTP requests, download models, import secrets, change selected profile, or change process ownership.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var documentSummary: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
            summaryRow("Source File", result.sourceFileName)
            summaryRow("schemaVersion", result.schemaVersion.map(String.init) ?? "Missing")
            summaryRow("app", result.app ?? "Not provided")
            summaryRow("exportedAt", formattedDate(result.exportedAt))
            summaryRow("Total Profiles", String(result.totalProfiles))
            summaryRow("Valid Profiles", String(result.validProfilesCount))
            summaryRow("Invalid Profiles", String(result.invalidProfilesCount))
            summaryRow("Warnings", String(result.warningCount))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profiles")
                .font(.headline)

            if result.profiles.isEmpty {
                Text("No profile rows are available for preview.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.profiles) { profile in
                        profileRow(profile)
                    }
                }
            }
        }
    }

    private func profileRow(_ profile: ValidatedImportProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Toggle("", isOn: selectionBinding(for: profile))
                    .labelsHidden()
                    .disabled(!profile.isImportable || resultHasDocumentError)

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(profile.sourceIndex) \(profile.name)")
                        .font(.callout.weight(.semibold))

                    Text(profile.modelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusPill(profile.status)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                compactRow("Host", profile.host)
                compactRow("Port", profile.port.map(String.init) ?? "Missing")
                compactRow("Advanced Launch Options", profile.hasAdvancedLaunchOptions ? "Included" : "Not included")
                compactRow("Conflict", profile.conflictSummary ?? "None")
                compactRow("Planned Action", profile.plannedActionSummary)
            }

            messageSection(title: "Messages", messages: profile.messages)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var importableProfiles: [ValidatedImportProfile] {
        guard !resultHasDocumentError else {
            return []
        }

        return result.profiles.filter(\.isImportable)
    }

    private var selectedImportableCount: Int {
        importableProfiles.filter { selectedSourceIndexes.contains($0.sourceIndex) }.count
    }

    private var resultHasDocumentError: Bool {
        result.documentMessages.contains { $0.severity == .error }
    }

    private func selectionBinding(for profile: ValidatedImportProfile) -> Binding<Bool> {
        Binding {
            selectedSourceIndexes.contains(profile.sourceIndex)
        } set: { isSelected in
            if isSelected {
                selectedSourceIndexes.insert(profile.sourceIndex)
            } else {
                selectedSourceIndexes.remove(profile.sourceIndex)
            }
        }
    }

    private func messageSection(title: String, messages: [ImportValidationMessage]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.medium))

            ForEach(messages) { message in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: iconName(for: message.severity))
                        .foregroundStyle(color(for: message.severity))
                    Text(message.message)
                        .foregroundStyle(message.severity == .error ? .red : .primary)
                }
                .font(.caption)
            }
        }
    }

    private func statusPill(_ status: ImportProfileValidationStatus) -> some View {
        let color: Color = switch status {
        case .valid:
            .green
        case .warning:
            .orange
        case .invalid:
            .red
        }

        return Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private func compactRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func iconName(for severity: ImportValidationSeverity) -> String {
        switch severity {
        case .error:
            "xmark.octagon.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .info:
            "info.circle.fill"
        }
    }

    private func color(for severity: ImportValidationSeverity) -> Color {
        switch severity {
        case .error:
            .red
        case .warning:
            .orange
        case .info:
            .secondary
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Not provided"
        }

        return date.formatted(date: .abbreviated, time: .standard)
    }
}
