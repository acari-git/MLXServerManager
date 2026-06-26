import SwiftUI

struct ImportProfilesPreviewView: View {
    let result: ImportPreviewResult
    let importMessage: String?
    var language: AppLanguage = .system
    let onImportSelected: ([ImportSelectedProfileRequest]) -> Void
    let onClose: () -> Void

    @State private var actionBySourceIndex: [Int: ImportProfileRowAction] = [:]
    @State private var renameBySourceIndex: [Int: String] = [:]
    @State private var isImportConfirmationPresented = false

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    importScopeNotice
                    documentSummary
                    messageSection(title: t("Document Messages", "ドキュメントメッセージ"), messages: result.documentMessages)
                    profilesSection
                }
                .padding(.trailing, 8)
            }

            HStack {
                Text(importMessage ?? "Import valid profiles, explicitly rename name conflicts, or confirm safe Replace targets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(t("Import Selected Profiles", "選択プロファイルをインポート")) {
                    isImportConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedActionCount == 0)

                Button(t("Close", "閉じる")) {
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

            Button(t("Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(importConfirmationMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Import Profiles Preview", "プロファイルインポートプレビュー"))
                    .font(.title2.weight(.semibold))

                Text(result.sourceFileName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(result.canProceedToFutureImport ? t("\(selectedActionCount) selected for import", "\(selectedActionCount)件をインポート対象に選択") : t("Import blocked", "インポート不可"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(result.canProceedToFutureImport ? .green : .red)

                Text(t("\(result.validProfilesCount) valid, \(result.invalidProfilesCount) invalid, \(result.warningCount) warning(s)", "有効\(result.validProfilesCount)件、無効\(result.invalidProfilesCount)件、警告\(result.warningCount)件"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importScopeNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("Valid profiles are selected by default. Profile-name conflicts can be renamed. Unambiguous existing-profile conflicts can be replaced only after confirmation.", "有効なプロファイルは既定で選択されます。プロファイル名の競合はリネームできます。曖昧でない既存プロファイル競合は、確認後にのみ置換できます。"), systemImage: "checklist")
                .font(.callout.weight(.semibold))

            Text(t("Import does not start, stop, or restart servers. It does not call /v1/models, make external HTTP requests, download models, delete files, import secrets, change external ownership, or change process ownership.", "インポートはサーバーの起動・停止・再起動を行いません。/v1/modelsの呼び出し、外部HTTPリクエスト、モデルのダウンロード、ファイル削除、シークレットのインポート、外部所有権やプロセス所有権の変更も行いません。"))
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
            summaryRow(t("Source File", "ソースファイル"), result.sourceFileName)
            summaryRow("schemaVersion", result.schemaVersion.map(String.init) ?? t("Missing", "不足"))
            summaryRow("app", result.app ?? t("Not provided", "未指定"))
            summaryRow("exportedAt", formattedDate(result.exportedAt))
            summaryRow(t("Total Profiles", "プロファイル総数"), String(result.totalProfiles))
            summaryRow(t("Valid Profiles", "有効なプロファイル"), String(result.validProfilesCount))
            summaryRow(t("Invalid Profiles", "無効なプロファイル"), String(result.invalidProfilesCount))
            summaryRow(t("Warnings", "警告"), String(result.warningCount))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Profiles", "プロファイル"))
                .font(.headline)

            if result.profiles.isEmpty {
                Text(t("No profile rows are available for preview.", "プレビューできるプロファイル行はありません。"))
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
                Picker(t("Action", "操作"), selection: actionBinding(for: profile)) {
                    Text(t("Skip", "スキップ")).tag(ImportProfileRowAction.skip)

                    if profile.isImportable {
                        Text(t("Import", "インポート")).tag(ImportProfileRowAction.importProfile)
                    }

                    if profile.canImportWithRename {
                        Text(t("Rename", "リネーム")).tag(ImportProfileRowAction.rename)
                    }

                    if profile.canImportWithReplace {
                        Text(t("Replace", "置換")).tag(ImportProfileRowAction.replace)
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
                compactRow(t("Host", "ホスト"), profile.host)
                compactRow(t("Port", "ポート"), profile.port.map(String.init) ?? t("Missing", "不足"))
                compactRow(t("Advanced Launch Options", "詳細起動オプション"), profile.hasAdvancedLaunchOptions ? t("Included", "含む") : t("Not included", "含まない"))
                compactRow(t("Conflict", "競合"), profile.conflictSummary ?? t("None", "なし"))
                if let suggestedRename = profile.suggestedRename {
                    compactRow(t("Suggested Rename", "推奨リネーム"), suggestedRename)
                }
                if let replaceTarget = profile.replaceTarget {
                    compactRow(t("Replace Target", "置換対象"), "\(replaceTarget.displayName) (\(replaceTarget.modelID), \(replaceTarget.endpointDescription))")
                }
                compactRow(t("Planned Action", "予定操作"), profile.plannedActionSummary)
            }

            if profile.canImportWithRename {
                renameControls(for: profile)
            }

            if profile.canImportWithReplace {
                replaceControls(for: profile)
            }

            messageSection(title: t("Messages", "メッセージ"), messages: profile.messages)
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
                Text(t("Rename To", "リネーム先"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField(t("New profile name", "新しいプロファイル名"), text: renameBinding(for: profile))
                    .textFieldStyle(.roundedBorder)
                    .disabled(actionBySourceIndex[profile.sourceIndex, default: .skip] != .rename)

                if let suggestedRename = profile.suggestedRename {
                    Button(t("Use Suggested", "推奨名を使用")) {
                        renameBySourceIndex[profile.sourceIndex] = suggestedRename
                        actionBySourceIndex[profile.sourceIndex] = .rename
                    }
                    .buttonStyle(.borderless)
                }
            }

            Text(t("Rename imports this row as a new profile. It does not replace or overwrite the existing profile.", "リネームはこの行を新しいプロファイルとしてインポートします。既存プロファイルの置換や上書きは行いません。"))
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
                Label(t("Replace updates one existing local profile's saved metadata. It does not delete model files, caches, logs, or affect server processes.", "置換は既存ローカルプロファイル1件の保存済みメタデータだけを更新します。モデルファイル、キャッシュ、ログは削除せず、サーバープロセスにも影響しません。"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                    compactRow(t("Before", "変更前"), "\(replaceTarget.displayName) | \(replaceTarget.modelID) | \(replaceTarget.endpointDescription)")
                    compactRow(t("After", "変更後"), "\(profile.name) | \(profile.modelID) | \(profile.host):\(profile.port.map(String.init) ?? "Missing")")
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
            return t("Rename name cannot be empty.", "リネーム名は空にできません。")
        }

        if result.existingProfileNames.contains(name) {
            return t("Rename name already exists in local profiles.", "リネーム名はローカルプロファイルにすでに存在します。")
        }

        if selectedFinalNameCounts[name, default: 0] > 1 {
            return t("Rename name conflicts with another selected import.", "リネーム名が別の選択済みインポートと競合しています。")
        }

        return nil
    }

    private func replaceValidationMessage(for profile: ValidatedImportProfile) -> String? {
        guard actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace else {
            return nil
        }

        guard let replaceTarget = profile.replaceTarget else {
            return t("Replace target is ambiguous or unavailable.", "置換対象が曖昧、または利用できません。")
        }

        if selectedReplaceTargetCounts[replaceTarget.modelID, default: 0] > 1 {
            return t("Another selected import already replaces this existing profile.", "別の選択済みインポートがすでにこの既存プロファイルを置換します。")
        }

        if selectedFinalNameCounts[profile.name, default: 0] > 1 {
            return t("Replacement name conflicts with another selected import.", "置換後の名前が別の選択済みインポートと競合しています。")
        }

        if selectedFinalModelIDCounts[profile.modelID, default: 0] > 1 {
            return t("Replacement Model ID conflicts with another selected import.", "置換後のModel IDが別の選択済みインポートと競合しています。")
        }

        if let endpoint = endpointKey(for: profile),
           selectedFinalEndpointCounts[endpoint, default: 0] > 1 {
            return t("Replacement endpoint conflicts with another selected import.", "置換後のエンドポイントが別の選択済みインポートと競合しています。")
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
        hasReplacementActions ? t("Replace existing profile metadata?", "既存プロファイルのメタデータを置換しますか？") : t("Import selected profile metadata?", "選択したプロファイルメタデータをインポートしますか？")
    }

    private var importConfirmationButtonTitle: String {
        hasReplacementActions ? t("Apply Import and Replace", "インポートと置換を適用") : t("Import Selected Profiles", "選択プロファイルをインポート")
    }

    private var importConfirmationMessage: String {
        let safetyNote = t("This will not start servers, stop servers, call /v1/models, make external HTTP requests, download models, delete model files, import secrets, or change process ownership.", "サーバーの起動・停止、/v1/modelsの呼び出し、外部HTTPリクエスト、モデルのダウンロード、モデルファイル削除、シークレットのインポート、プロセス所有権の変更は行いません。")

        guard hasReplacementActions else {
            return t("This will add selected profile metadata and apply explicit Rename actions shown in the preview. \(safetyNote)", "選択したプロファイルメタデータを追加し、プレビューに表示された明示的なリネーム操作を適用します。\(safetyNote)")
        }

        return "\(replacementConfirmationSummary)\n\n\(t("Replace updates existing local profile metadata only.", "置換は既存ローカルプロファイルのメタデータのみを更新します。")) \(safetyNote)"
    }

    private var replacementConfirmationSummary: String {
        let summaries = result.profiles.compactMap { profile -> String? in
            guard actionBySourceIndex[profile.sourceIndex, default: .skip] == .replace,
                  replaceValidationMessage(for: profile) == nil,
                  let target = profile.replaceTarget else {
                return nil
            }

            return t("Replace \(target.displayName) (\(target.modelID), \(target.endpointDescription)) with \(profile.name) (\(profile.modelID), \(profile.host):\(profile.port.map(String.init) ?? "Missing")).", "\(target.displayName)（\(target.modelID), \(target.endpointDescription)）を\(profile.name)（\(profile.modelID), \(profile.host):\(profile.port.map(String.init) ?? t("Missing", "不足"))）で置換します。")
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
            return t("Not provided", "未指定")
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
