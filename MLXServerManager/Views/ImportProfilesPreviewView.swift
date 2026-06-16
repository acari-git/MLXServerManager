import SwiftUI

struct ImportProfilesPreviewView: View {
    let result: ImportPreviewResult
    let importMessage: String?
    let onImportSelected: ([ImportSelectedProfileRequest]) -> Void
    let onClose: () -> Void

    @State private var actionBySourceIndex: [Int: ImportProfileRowAction] = [:]
    @State private var renameBySourceIndex: [Int: String] = [:]
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
                Text(importMessage ?? "Import valid profiles, explicitly rename name conflicts, or confirm safe Replace targets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Import Selected Profiles") {
                    isImportConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedActionCount == 0)

                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 760, idealWidth: 880, minHeight: 620, idealHeight: 720)
        .onAppear {
            actionBySourceIndex = Dictionary(uniqueKeysWithValues: result.profiles.map { profile in
                (profile.sourceIndex, defaultAction(for: profile))
            })
            renameBySourceIndex = Dictionary(uniqueKeysWithValues: result.profiles.compactMap { profile in
                guard let suggestedRename = profile.suggestedRename else {
                    return nil
                }

                return (profile.sourceIndex, suggestedRename)
            })
        }
        .alert(importConfirmationTitle, isPresented: $isImportConfirmationPresented) {
            Button(importConfirmationButtonTitle, role: hasReplacementActions ? .destructive : nil) {
                onImportSelected(importRequests)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(importConfirmationMessage)
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
                Text(result.canProceedToFutureImport ? "\(selectedActionCount) selected for import" : "Import blocked")
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
            Label("Valid profiles are selected by default. Profile-name conflicts can be renamed. Unambiguous existing-profile conflicts can be replaced only after confirmation.", systemImage: "checklist")
                .font(.callout.weight(.semibold))

            Text("Import does not start, stop, or restart servers. It does not call /v1/models, make external HTTP requests, download models, delete files, import secrets, change external ownership, or change process ownership.")
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
                Picker("Action", selection: actionBinding(for: profile)) {
                    Text("Skip").tag(ImportProfileRowAction.skip)

                    if profile.isImportable {
                        Text("Import").tag(ImportProfileRowAction.importProfile)
                    }

                    if profile.canImportWithRename {
                        Text("Rename").tag(ImportProfileRowAction.rename)
                    }

                    if profile.canImportWithReplace {
                        Text("Replace").tag(ImportProfileRowAction.replace)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .disabled(resultHasDocumentError || !profile.isImportable && !profile.canImportWithRename && !profile.canImportWithReplace)

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
                if let suggestedRename = profile.suggestedRename {
                    compactRow("Suggested Rename", suggestedRename)
                }
                if let replaceTarget = profile.replaceTarget {
                    compactRow("Replace Target", "\(replaceTarget.displayName) (\(replaceTarget.modelID), \(replaceTarget.endpointDescription))")
                }
                compactRow("Planned Action", profile.plannedActionSummary)
            }

            if profile.canImportWithRename {
                renameControls(for: profile)
            }

            if profile.canImportWithReplace {
                replaceControls(for: profile)
            }

            messageSection(title: "Messages", messages: profile.messages)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var selectedActionCount: Int {
        importRequests.count
    }

    private var resultHasDocumentError: Bool {
        result.documentMessages.contains { $0.severity == .error }
    }

    private var importRequests: [ImportSelectedProfileRequest] {
        result.profiles.compactMap { profile in
            switch actionBySourceIndex[profile.sourceIndex, default: .skip] {
            case .skip:
                return nil
            case .importProfile:
                return ImportSelectedProfileRequest(sourceIndex: profile.sourceIndex, action: .importProfile)
            case .rename:
                guard renameValidationMessage(for: profile) == nil else {
                    return nil
                }

                return ImportSelectedProfileRequest(
                    sourceIndex: profile.sourceIndex,
                    action: .rename,
                    renamedName: normalizedRenameName(for: profile)
                )
            case .replace:
                guard replaceValidationMessage(for: profile) == nil else {
                    return nil
                }

                return ImportSelectedProfileRequest(sourceIndex: profile.sourceIndex, action: .replace)
            }
        }
    }

    private func actionBinding(for profile: ValidatedImportProfile) -> Binding<ImportProfileRowAction> {
        Binding {
            actionBySourceIndex[profile.sourceIndex, default: defaultAction(for: profile)]
        } set: { action in
            actionBySourceIndex[profile.sourceIndex] = action
        }
    }

    private func defaultAction(for profile: ValidatedImportProfile) -> ImportProfileRowAction {
        profile.isImportable ? .importProfile : .skip
    }

    private func renameControls(for profile: ValidatedImportProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Rename To")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("New profile name", text: renameBinding(for: profile))
                    .textFieldStyle(.roundedBorder)
                    .disabled(actionBySourceIndex[profile.sourceIndex, default: .skip] != .rename)

                if let suggestedRename = profile.suggestedRename {
                    Button("Use Suggested") {
                        renameBySourceIndex[profile.sourceIndex] = suggestedRename
                        actionBySourceIndex[profile.sourceIndex] = .rename
                    }
                    .buttonStyle(.borderless)
                }
            }

            Text("Rename imports this row as a new profile. It does not replace or overwrite the existing profile.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if actionBySourceIndex[profile.sourceIndex, default: .skip] == .rename,
               let validationMessage = renameValidationMessage(for: profile) {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func replaceControls(for profile: ValidatedImportProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replaceTarget = profile.replaceTarget {
                Label("Replace updates one existing local profile's saved metadata. It does not delete model files, caches, logs, or affect server processes.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                    compactRow("Before", "\(replaceTarget.displayName) | \(replaceTarget.modelID) | \(replaceTarget.endpointDescription)")
                    compactRow("After", "\(profile.name) | \(profile.modelID) | \(profile.host):\(profile.port.map(String.init) ?? "Missing")")
                }
            }

            if actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace,
               let validationMessage = replaceValidationMessage(for: profile) {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func renameBinding(for profile: ValidatedImportProfile) -> Binding<String> {
        Binding {
            renameBySourceIndex[profile.sourceIndex] ?? profile.suggestedRename ?? ""
        } set: { value in
            renameBySourceIndex[profile.sourceIndex] = value
        }
    }

    private func renameValidationMessage(for profile: ValidatedImportProfile) -> String? {
        guard actionBySourceIndex[profile.sourceIndex, default: .skip] == .rename else {
            return nil
        }

        let name = normalizedRenameName(for: profile)
        if name.isEmpty {
            return "Rename name cannot be empty."
        }

        if result.existingProfileNames.contains(name) {
            return "Rename name already exists in local profiles."
        }

        if selectedFinalNameCounts[name, default: 0] > 1 {
            return "Rename name conflicts with another selected import."
        }

        return nil
    }

    private func replaceValidationMessage(for profile: ValidatedImportProfile) -> String? {
        guard actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace else {
            return nil
        }

        guard let replaceTarget = profile.replaceTarget else {
            return "Replace target is ambiguous or unavailable."
        }

        if selectedReplaceTargetCounts[replaceTarget.modelID, default: 0] > 1 {
            return "Another selected import already replaces this existing profile."
        }

        if selectedFinalNameCounts[profile.name, default: 0] > 1 {
            return "Replacement name conflicts with another selected import."
        }

        if selectedFinalModelIDCounts[profile.modelID, default: 0] > 1 {
            return "Replacement Model ID conflicts with another selected import."
        }

        if let endpoint = endpointKey(for: profile),
           selectedFinalEndpointCounts[endpoint, default: 0] > 1 {
            return "Replacement endpoint conflicts with another selected import."
        }

        return nil
    }

    private func normalizedRenameName(for profile: ValidatedImportProfile) -> String {
        (renameBySourceIndex[profile.sourceIndex] ?? profile.suggestedRename ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedFinalNameCounts: [String: Int] {
        let names = result.profiles.compactMap { profile -> String? in
            switch actionBySourceIndex[profile.sourceIndex, default: .skip] {
            case .skip:
                return nil
            case .importProfile:
                return profile.name
            case .rename:
                let name = normalizedRenameName(for: profile)
                return name.isEmpty ? nil : name
            case .replace:
                return profile.name
            }
        }

        return Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
    }

    private var selectedFinalModelIDCounts: [String: Int] {
        let modelIDs = result.profiles.compactMap { profile -> String? in
            switch actionBySourceIndex[profile.sourceIndex, default: .skip] {
            case .skip:
                return nil
            case .importProfile, .rename, .replace:
                return profile.modelID
            }
        }

        return Dictionary(grouping: modelIDs, by: { $0 }).mapValues(\.count)
    }

    private var selectedFinalEndpointCounts: [String: Int] {
        let endpoints = result.profiles.compactMap { profile -> String? in
            switch actionBySourceIndex[profile.sourceIndex, default: .skip] {
            case .skip:
                return nil
            case .importProfile, .rename, .replace:
                return endpointKey(for: profile)
            }
        }

        return Dictionary(grouping: endpoints, by: { $0 }).mapValues(\.count)
    }

    private var selectedReplaceTargetCounts: [String: Int] {
        let targets = result.profiles.compactMap { profile -> String? in
            guard actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace else {
                return nil
            }

            return profile.replaceTarget?.modelID
        }

        return Dictionary(grouping: targets, by: { $0 }).mapValues(\.count)
    }

    private var hasReplacementActions: Bool {
        result.profiles.contains { profile in
            actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace
                && replaceValidationMessage(for: profile) == nil
        }
    }

    private var importConfirmationTitle: String {
        hasReplacementActions ? "Replace existing profile metadata?" : "Import selected profile metadata?"
    }

    private var importConfirmationButtonTitle: String {
        hasReplacementActions ? "Apply Import and Replace" : "Import Selected Profiles"
    }

    private var importConfirmationMessage: String {
        let safetyNote = "This will not start servers, stop servers, call /v1/models, make external HTTP requests, download models, delete model files, import secrets, or change process ownership."

        guard hasReplacementActions else {
            return "This will add selected profile metadata and apply explicit Rename actions shown in the preview. \(safetyNote)"
        }

        return "\(replacementConfirmationSummary)\n\nReplace updates existing local profile metadata only. \(safetyNote)"
    }

    private var replacementConfirmationSummary: String {
        let summaries = result.profiles.compactMap { profile -> String? in
            guard actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace,
                  replaceValidationMessage(for: profile) == nil,
                  let target = profile.replaceTarget else {
                return nil
            }

            return "Replace \(target.displayName) (\(target.modelID), \(target.endpointDescription)) with \(profile.name) (\(profile.modelID), \(profile.host):\(profile.port.map(String.init) ?? "Missing"))."
        }

        return summaries.joined(separator: "\n")
    }

    private func endpointKey(for profile: ValidatedImportProfile) -> String? {
        guard let port = profile.port else {
            return nil
        }

        return "\(profile.modelID)|\(profile.host)|\(port)"
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

private enum ImportProfileRowAction: String, Hashable {
    case skip
    case importProfile
    case rename
    case replace
}
