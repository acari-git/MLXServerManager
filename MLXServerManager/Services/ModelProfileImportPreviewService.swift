import Foundation

enum ImportValidationSeverity: String, Hashable {
    case error
    case warning
    case info
}

struct ImportValidationMessage: Identifiable, Hashable {
    let id = UUID()
    let severity: ImportValidationSeverity
    let message: String
}

enum ImportProfileValidationStatus: String, Hashable {
    case valid = "Valid"
    case warning = "Warning"
    case invalid = "Invalid"
}

enum ImportProfileConflictKind: String, Hashable {
    case existingName
    case importedNameDuplicate
    case existingModelID
    case importedModelIDDuplicate
    case existingEndpoint
    case importedEndpointDuplicate

    var isNameConflict: Bool {
        switch self {
        case .existingName, .importedNameDuplicate:
            true
        case .existingModelID, .importedModelIDDuplicate, .existingEndpoint, .importedEndpointDuplicate:
            false
        }
    }
}

enum ImportProfileImportAction: String, Hashable {
    case importProfile
    case rename
}

struct ImportSelectedProfileRequest: Hashable {
    let sourceIndex: Int
    let action: ImportProfileImportAction
    let renamedName: String?

    init(sourceIndex: Int, action: ImportProfileImportAction, renamedName: String? = nil) {
        self.sourceIndex = sourceIndex
        self.action = action
        self.renamedName = renamedName
    }
}

struct ImportPreviewResult {
    let sourceFileName: String
    let schemaVersion: Int?
    let app: String?
    let exportedAt: Date?
    let totalProfiles: Int
    let validProfilesCount: Int
    let invalidProfilesCount: Int
    let warningCount: Int
    let documentMessages: [ImportValidationMessage]
    let profiles: [ValidatedImportProfile]
    let existingProfileNames: Set<String>
    let canProceedToFutureImport: Bool
}

struct ValidatedImportProfile: Identifiable {
    let id = UUID()
    let sourceIndex: Int
    let name: String
    let modelID: String
    let host: String
    let port: Int?
    let advancedLaunchOptions: AdvancedLaunchOptions?
    let hasAdvancedLaunchOptions: Bool
    let status: ImportProfileValidationStatus
    let messages: [ImportValidationMessage]
    let conflictKinds: Set<ImportProfileConflictKind>
    let conflictSummary: String?
    let suggestedRename: String?
    let plannedActionSummary: String

    var isImportable: Bool {
        status != .invalid && conflictSummary == nil && port != nil
    }

    var canImportWithRename: Bool {
        status != .invalid
            && port != nil
            && !conflictKinds.isEmpty
            && conflictKinds.allSatisfy(\.isNameConflict)
    }
}

struct ImportSelectedProfilesResult {
    let importedModels: [ModelConfig]
    let importedCount: Int
    let renamedCount: Int
    let skippedCount: Int
    let messages: [String]
}

struct ModelProfileImportPreviewService {
    func preview(
        data: Data,
        sourceFileName: String,
        existingModels: [ModelConfig]
    ) -> ImportPreviewResult {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let document = object as? [String: Any] else {
                return documentError(
                    sourceFileName: sourceFileName,
                    message: "Import file must be a JSON object."
                )
            }

            return validate(document: document, sourceFileName: sourceFileName, existingModels: existingModels)
        } catch {
            return documentError(
                sourceFileName: sourceFileName,
                message: "Import file is not valid JSON."
            )
        }
    }

    func importSelectedProfiles(
        from preview: ImportPreviewResult,
        requests: [ImportSelectedProfileRequest],
        existingModels: [ModelConfig]
    ) -> ImportSelectedProfilesResult {
        guard !preview.documentMessages.contains(where: { $0.severity == .error }) else {
            return ImportSelectedProfilesResult(
                importedModels: [],
                importedCount: 0,
                renamedCount: 0,
                skippedCount: requests.count,
                messages: ["Import blocked because the document has validation errors."]
            )
        }

        guard !requests.isEmpty else {
            return ImportSelectedProfilesResult(
                importedModels: [],
                importedCount: 0,
                renamedCount: 0,
                skippedCount: 0,
                messages: ["No importable profiles selected."]
            )
        }

        var requestBySourceIndex: [Int: ImportSelectedProfileRequest] = [:]
        for request in requests {
            requestBySourceIndex[request.sourceIndex] = request
        }
        let selectedProfiles = preview.profiles.compactMap { profile -> (ValidatedImportProfile, ImportSelectedProfileRequest)? in
            guard let request = requestBySourceIndex[profile.sourceIndex] else {
                return nil
            }

            return (profile, request)
        }
        let existingNames = Set(existingModels.map { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) })
        let existingModelIDs = Set(existingModels.map { $0.modelID.trimmingCharacters(in: .whitespacesAndNewlines) })
        let existingEndpoints = Set(existingModels.map { endpointKey(modelID: $0.modelID, host: $0.host, port: $0.serverPort) })
        let selectedNames = Dictionary(grouping: selectedProfiles.compactMap { profile, request in
            finalProfileName(for: profile, request: request)
        }, by: { $0 }).mapValues(\.count)
        let selectedModelIDs = Dictionary(grouping: selectedProfiles.map { $0.0.modelID }, by: { $0 }).mapValues(\.count)
        let selectedEndpoints = Dictionary(grouping: selectedProfiles.compactMap { profile, _ -> String? in
            guard let port = profile.port else {
                return nil
            }

            return endpointKey(modelID: profile.modelID, host: profile.host, port: port)
        }, by: { $0 }).mapValues(\.count)

        var importedModels: [ModelConfig] = []
        var messages: [String] = []
        var renamedCount = 0
        var skippedCount = 0

        for (profile, request) in selectedProfiles {
            let finalName: String
            switch request.action {
            case .importProfile:
                guard profile.isImportable else {
                    skippedCount += 1
                    messages.append("Skipped \(profile.name): validation errors or conflicts cannot be imported without Rename.")
                    continue
                }
                finalName = profile.name
            case .rename:
                guard profile.canImportWithRename else {
                    skippedCount += 1
                    messages.append("Skipped \(profile.name): Rename is available only for profile-name conflicts.")
                    continue
                }
                finalName = normalizedProfileName(request.renamedName)
            }

            guard !finalName.isEmpty else {
                skippedCount += 1
                messages.append("Skipped \(profile.name): renamed profile name is invalid.")
                continue
            }

            guard let port = profile.port else {
                skippedCount += 1
                messages.append("Skipped \(profile.name): port is invalid.")
                continue
            }

            let endpoint = endpointKey(modelID: profile.modelID, host: profile.host, port: port)
            guard !existingNames.contains(finalName),
                  !existingModelIDs.contains(profile.modelID),
                  !existingEndpoints.contains(endpoint) else {
                skippedCount += 1
                messages.append("Skipped \(profile.name): conflicts with an existing profile.")
                continue
            }

            guard selectedNames[finalName, default: 0] == 1,
                  selectedModelIDs[profile.modelID, default: 0] == 1,
                  selectedEndpoints[endpoint, default: 0] == 1 else {
                skippedCount += 1
                messages.append("Skipped \(profile.name): conflicts with another selected profile.")
                continue
            }

            if request.action == .rename {
                renamedCount += 1
                messages.append("Renamed \(profile.name) to \(finalName) during import.")
            }

            importedModels.append(modelConfig(from: profile, port: port, displayName: finalName))
        }

        if importedModels.isEmpty {
            messages.append("No profiles were imported.")
        } else {
            messages.append("Imported \(importedModels.count) profile(s). Renamed \(renamedCount) profile(s). Skipped \(skippedCount) profile(s).")
            messages.append("Import completed. Servers were not started or modified.")
        }

        return ImportSelectedProfilesResult(
            importedModels: importedModels,
            importedCount: importedModels.count,
            renamedCount: renamedCount,
            skippedCount: skippedCount,
            messages: messages
        )
    }

    private func validate(
        document: [String: Any],
        sourceFileName: String,
        existingModels: [ModelConfig]
    ) -> ImportPreviewResult {
        var documentMessages: [ImportValidationMessage] = [
            .info("Review selected profile metadata before import."),
            .info("Shared profile JSON is metadata only. Rename is available only for profile-name conflicts.")
        ]

        documentMessages.append(contentsOf: ignoredFieldMessages(in: document.keys, scope: "Document"))

        let schemaVersion = integerValue(document["schemaVersion"])
        let app = stringValue(document["app"])
        let exportedAt = dateValue(document["exportedAt"])

        guard let schemaVersion else {
            documentMessages.append(.error("schemaVersion is required. No profiles were imported."))
            return result(
                sourceFileName: sourceFileName,
                schemaVersion: nil,
                app: app,
                exportedAt: exportedAt,
                totalProfiles: 0,
                documentMessages: documentMessages,
                profiles: []
            )
        }

        guard schemaVersion == 1 else {
            documentMessages.append(.error("This file uses schemaVersion \(schemaVersion), but this version of MLX Server Manager supports schemaVersion 1 only. No profiles were imported."))
            return result(
                sourceFileName: sourceFileName,
                schemaVersion: schemaVersion,
                app: app,
                exportedAt: exportedAt,
                totalProfiles: 0,
                documentMessages: documentMessages,
                profiles: []
            )
        }

        if let app, app != "MLXServerManager" {
            documentMessages.append(.warning("The app field is \(app). Expected MLXServerManager. Review this file before future import."))
        }

        guard let rawProfiles = document["profiles"] as? [Any] else {
            documentMessages.append(.error("The import file must contain a profiles array."))
            return result(
                sourceFileName: sourceFileName,
                schemaVersion: schemaVersion,
                app: app,
                exportedAt: exportedAt,
                totalProfiles: 0,
                documentMessages: documentMessages,
                profiles: []
            )
        }

        let candidates = rawProfiles.enumerated().map { offset, rawProfile in
            ImportProfileCandidate(sourceIndex: offset + 1, rawProfile: rawProfile)
        }

        let importedNameCounts = Dictionary(grouping: candidates.compactMap(\.normalizedName), by: { $0 })
            .mapValues(\.count)
        let importedModelIDCounts = Dictionary(grouping: candidates.compactMap(\.normalizedModelID), by: { $0 })
            .mapValues(\.count)
        let importedEndpointCounts = Dictionary(grouping: candidates.compactMap(\.endpointKey), by: { $0 })
            .mapValues(\.count)

        let existingNames = Set(existingModels.map { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) })
        let existingModelIDs = Set(existingModels.map { $0.modelID.trimmingCharacters(in: .whitespacesAndNewlines) })
        let existingEndpoints = Set(existingModels.map { endpointKey(modelID: $0.modelID, host: $0.host, port: $0.serverPort) })

        var reservedRenameNames = Set<String>()
        var validatedProfiles: [ValidatedImportProfile] = []
        for candidate in candidates {
            validatedProfiles.append(validate(
                candidate: candidate,
                existingNames: existingNames,
                existingModelIDs: existingModelIDs,
                existingEndpoints: existingEndpoints,
                importedNameCounts: importedNameCounts,
                importedModelIDCounts: importedModelIDCounts,
                importedEndpointCounts: importedEndpointCounts,
                reservedRenameNames: &reservedRenameNames
            ))
        }

        return result(
            sourceFileName: sourceFileName,
            schemaVersion: schemaVersion,
            app: app,
            exportedAt: exportedAt,
            totalProfiles: rawProfiles.count,
            documentMessages: documentMessages,
            profiles: validatedProfiles,
            existingProfileNames: existingNames
        )
    }

    private func validate(
        candidate: ImportProfileCandidate,
        existingNames: Set<String>,
        existingModelIDs: Set<String>,
        existingEndpoints: Set<String>,
        importedNameCounts: [String: Int],
        importedModelIDCounts: [String: Int],
        importedEndpointCounts: [String: Int],
        reservedRenameNames: inout Set<String>
    ) -> ValidatedImportProfile {
        guard let profile = candidate.profile else {
            return ValidatedImportProfile(
                sourceIndex: candidate.sourceIndex,
                name: "Profile \(candidate.sourceIndex)",
                modelID: "Missing",
                host: "Missing",
                port: nil,
                advancedLaunchOptions: nil,
                hasAdvancedLaunchOptions: false,
                status: .invalid,
                messages: [.error("Profile entry must be a JSON object.")],
                conflictKinds: [],
                conflictSummary: nil,
                suggestedRename: nil,
                plannedActionSummary: "Invalid - cannot import"
            )
        }

        let name = stringValue(profile["name"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let modelID = stringValue(profile["modelID"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = stringValue(profile["host"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let port = integerValue(profile["port"])
        let advancedOptions = advancedLaunchOptions(from: profile["advancedLaunchOptions"])
        var messages: [ImportValidationMessage] = []
        var conflicts: [String] = []
        var conflictKinds = Set<ImportProfileConflictKind>()

        messages.append(contentsOf: ignoredFieldMessages(in: profile.keys, scope: "Profile"))
        messages.append(contentsOf: advancedLaunchOptionsShapeMessages(from: profile["advancedLaunchOptions"]))

        if name.isEmpty {
            messages.append(.error("Profile name is required."))
        }

        if modelID.isEmpty {
            messages.append(.error("Model ID is required."))
        }

        if host.isEmpty {
            messages.append(.error("Host is required."))
        } else if !isValidHost(host) {
            messages.append(.error("Host is invalid."))
        }

        if let port {
            if !(1...65_535).contains(port) {
                messages.append(.error("Port must be between 1 and 65535."))
            }
        } else {
            messages.append(.error("Port must be between 1 and 65535."))
        }

        if let advancedOptions {
            messages.append(contentsOf: validateAdvancedLaunchOptions(advancedOptions))
        }

        if !name.isEmpty {
            if existingNames.contains(name) {
                conflicts.append("same profile name as an existing profile")
                conflictKinds.insert(.existingName)
            }

            if importedNameCounts[name, default: 0] > 1 {
                conflicts.append("duplicate profile name inside import file")
                conflictKinds.insert(.importedNameDuplicate)
            }
        }

        if !modelID.isEmpty {
            if existingModelIDs.contains(modelID) {
                conflicts.append("same modelID as an existing profile")
                conflictKinds.insert(.existingModelID)
            }

            if importedModelIDCounts[modelID, default: 0] > 1 {
                conflicts.append("duplicate modelID inside import file")
                conflictKinds.insert(.importedModelIDDuplicate)
            }
        }

        if let port, !modelID.isEmpty, !host.isEmpty {
            let endpoint = Self.endpointKey(modelID: modelID, host: host, port: port)

            if existingEndpoints.contains(endpoint) {
                conflicts.append("same modelID + host + port as an existing profile")
                conflictKinds.insert(.existingEndpoint)
            }

            if importedEndpointCounts[endpoint, default: 0] > 1 {
                conflicts.append("duplicate modelID + host + port inside import file")
                conflictKinds.insert(.importedEndpointDuplicate)
            }
        }

        if !conflicts.isEmpty {
            if canSuggestRename(conflictKinds: conflictKinds) {
                messages.append(.warning("Profile name conflict detected. Skip is the default; Rename is available before import."))
            } else {
                messages.append(.warning("Conflict detected. This profile will be skipped unless a future conflict action supports it."))
            }
        }

        let status: ImportProfileValidationStatus
        if messages.contains(where: { $0.severity == .error }) {
            status = .invalid
        } else if messages.contains(where: { $0.severity == .warning }) {
            status = .warning
        } else {
            status = .valid
        }

        let suggestedRename: String?
        if status != .invalid, canSuggestRename(conflictKinds: conflictKinds), !name.isEmpty {
            let reservedNames = existingNames
                .union(Set(importedNameCounts.keys))
                .union(reservedRenameNames)
            suggestedRename = makeSuggestedRename(for: name, reservedNames: reservedNames)
            if let suggestedRename {
                reservedRenameNames.insert(suggestedRename)
            }
        } else {
            suggestedRename = nil
        }

        return ValidatedImportProfile(
            sourceIndex: candidate.sourceIndex,
            name: name.isEmpty ? "Profile \(candidate.sourceIndex)" : name,
            modelID: modelID.isEmpty ? "Missing" : modelID,
            host: host.isEmpty ? "Missing" : host,
            port: port,
            advancedLaunchOptions: advancedOptions?.normalized(),
            hasAdvancedLaunchOptions: advancedOptions?.normalized() != nil,
            status: status,
            messages: messages.isEmpty ? [.info("Profile metadata is valid for preview.")] : messages,
            conflictKinds: conflictKinds,
            conflictSummary: conflicts.isEmpty ? nil : conflicts.joined(separator: "; "),
            suggestedRename: suggestedRename,
            plannedActionSummary: plannedActionSummary(status: status, conflicts: conflicts, suggestedRename: suggestedRename)
        )
    }

    private func validateAdvancedLaunchOptions(_ options: AdvancedLaunchOptions) -> [ImportValidationMessage] {
        guard let normalizedOptions = options.normalized() else {
            return []
        }

        var messages: [ImportValidationMessage] = []
        let boundedDoubleFields: [(String, String?)] = [
            ("Default Temperature", normalizedOptions.defaultTemperature),
            ("Default Top P", normalizedOptions.defaultTopP),
            ("Default Min P", normalizedOptions.defaultMinP)
        ]

        for (label, value) in boundedDoubleFields {
            guard let value else {
                continue
            }

            guard let doubleValue = Double(value), (0...1).contains(doubleValue) else {
                messages.append(.error("\(label) must be between 0 and 1."))
                continue
            }
        }

        let positiveIntegerFields: [(String, String?)] = [
            ("Default Top K", normalizedOptions.defaultTopK),
            ("Default Max Tokens", normalizedOptions.defaultMaxTokens),
            ("Decode Concurrency", normalizedOptions.decodeConcurrency),
            ("Prompt Concurrency", normalizedOptions.promptConcurrency),
            ("Prefill Step Size", normalizedOptions.prefillStepSize),
            ("Prompt Cache Size", normalizedOptions.promptCacheSize),
            ("Prompt Cache Bytes", normalizedOptions.promptCacheBytes)
        ]

        for (label, value) in positiveIntegerFields {
            guard let value else {
                continue
            }

            guard let integerValue = Int(value), integerValue > 0 else {
                messages.append(.error("\(label) must be a positive integer."))
                continue
            }
        }

        if let chatTemplateArgs = normalizedOptions.chatTemplateArgs {
            guard let data = chatTemplateArgs.data(using: .utf8) else {
                messages.append(.error("Chat Template Args must be valid JSON."))
                return messages
            }

            do {
                _ = try JSONSerialization.jsonObject(with: data)
            } catch {
                messages.append(.error("Chat Template Args must be valid JSON."))
            }
        }

        if normalizedOptions.rawExtraArgs != nil {
            messages.append(.warning("This profile includes raw extra server arguments. Review them before starting a managed server."))
        }

        return messages
    }

    private func ignoredFieldMessages(in keys: Dictionary<String, Any>.Keys, scope: String) -> [ImportValidationMessage] {
        var messages: [ImportValidationMessage] = []
        let knownKeys: Set<String> = [
            "schemaVersion",
            "app",
            "exportedAt",
            "notes",
            "profiles",
            "name",
            "modelID",
            "host",
            "port",
            "advancedLaunchOptions"
        ]

        let secretKeys = keys.filter { isSecretLikeKey($0) }
        if !secretKeys.isEmpty {
            messages.append(.warning("\(scope) contains secret-looking field(s). They are ignored by preview and will not be imported."))
        }

        let pathKeys = keys.filter { isLocalPathLikeKey($0) }
        if !pathKeys.isEmpty {
            messages.append(.warning("\(scope) contains local path or executable path field(s). They are ignored by preview and will not be imported."))
        }

        let unknownKeys = keys.filter { !knownKeys.contains($0) && !isSecretLikeKey($0) && !isLocalPathLikeKey($0) }
        if !unknownKeys.isEmpty {
            messages.append(.info("\(scope) contains unknown field(s). They are treated as data only and ignored."))
        }

        return messages
    }

    private func advancedLaunchOptions(from rawValue: Any?) -> AdvancedLaunchOptions? {
        guard let dictionary = rawValue as? [String: Any] else {
            return nil
        }

        let options = AdvancedLaunchOptions(
            rawExtraArgs: stringValue(dictionary["rawExtraArgs"]),
            chatTemplateArgs: stringValue(dictionary["chatTemplateArgs"]),
            defaultTemperature: stringValue(dictionary["defaultTemperature"]),
            defaultTopP: stringValue(dictionary["defaultTopP"]),
            defaultTopK: stringValue(dictionary["defaultTopK"]),
            defaultMinP: stringValue(dictionary["defaultMinP"]),
            defaultMaxTokens: stringValue(dictionary["defaultMaxTokens"]),
            allowedOrigins: stringValue(dictionary["allowedOrigins"]),
            logLevel: stringValue(dictionary["logLevel"]),
            decodeConcurrency: stringValue(dictionary["decodeConcurrency"]),
            promptConcurrency: stringValue(dictionary["promptConcurrency"]),
            prefillStepSize: stringValue(dictionary["prefillStepSize"]),
            promptCacheSize: stringValue(dictionary["promptCacheSize"]),
            promptCacheBytes: stringValue(dictionary["promptCacheBytes"])
        )

        return options.normalized()
    }

    private func advancedLaunchOptionsShapeMessages(from rawValue: Any?) -> [ImportValidationMessage] {
        guard let rawValue else {
            return []
        }

        guard let dictionary = rawValue as? [String: Any] else {
            if rawValue is NSNull {
                return []
            }

            return [.error("Advanced Launch Options must be a JSON object when present.")]
        }

        let knownAdvancedKeys: Set<String> = [
            "rawExtraArgs",
            "chatTemplateArgs",
            "defaultTemperature",
            "defaultTopP",
            "defaultTopK",
            "defaultMinP",
            "defaultMaxTokens",
            "allowedOrigins",
            "logLevel",
            "decodeConcurrency",
            "promptConcurrency",
            "prefillStepSize",
            "promptCacheSize",
            "promptCacheBytes"
        ]

        var messages: [ImportValidationMessage] = []
        let unknownKeys = dictionary.keys.filter { !knownAdvancedKeys.contains($0) }
        if !unknownKeys.isEmpty {
            messages.append(.info("Advanced Launch Options contain unknown field(s). They are treated as data only and ignored."))
        }

        return messages
    }

    private func result(
        sourceFileName: String,
        schemaVersion: Int?,
        app: String?,
        exportedAt: Date?,
        totalProfiles: Int,
        documentMessages: [ImportValidationMessage],
        profiles: [ValidatedImportProfile],
        existingProfileNames: Set<String> = []
    ) -> ImportPreviewResult {
        let invalidCount = profiles.filter { $0.status == .invalid }.count
        let validCount = profiles.count - invalidCount
        let warningCount = documentMessages.filter { $0.severity == .warning }.count
            + profiles.flatMap(\.messages).filter { $0.severity == .warning }.count
        let hasDocumentError = documentMessages.contains { $0.severity == .error }
        let actionableCount = profiles.filter { $0.isImportable || $0.canImportWithRename }.count

        return ImportPreviewResult(
            sourceFileName: sourceFileName,
            schemaVersion: schemaVersion,
            app: app,
            exportedAt: exportedAt,
            totalProfiles: totalProfiles,
            validProfilesCount: validCount,
            invalidProfilesCount: invalidCount,
            warningCount: warningCount,
            documentMessages: documentMessages,
            profiles: profiles,
            existingProfileNames: existingProfileNames,
            canProceedToFutureImport: !hasDocumentError && actionableCount > 0
        )
    }

    private func modelConfig(from profile: ValidatedImportProfile, port: Int, displayName: String) -> ModelConfig {
        let localName = profile.modelID.split(separator: "/").last.map(String.init) ?? profile.modelID
        return ModelConfig(
            modelID: profile.modelID,
            displayName: displayName,
            family: "Imported",
            quantization: "Imported profile metadata",
            localName: localName,
            host: profile.host,
            serverPort: port,
            enableThinking: false,
            notes: "Imported profile metadata. Review before starting a managed server.",
            advancedLaunchOptions: profile.advancedLaunchOptions?.normalized()
        )
    }

    private func plannedActionSummary(
        status: ImportProfileValidationStatus,
        conflicts: [String],
        suggestedRename: String?
    ) -> String {
        if status == .invalid {
            return "Invalid - cannot import"
        }

        if let suggestedRename {
            return "Skip by default - can rename to \(suggestedRename)"
        }

        if !conflicts.isEmpty {
            return "Skipped - conflict cannot be renamed in this version"
        }

        return "Importable - selected by default"
    }

    private func finalProfileName(
        for profile: ValidatedImportProfile,
        request: ImportSelectedProfileRequest
    ) -> String? {
        switch request.action {
        case .importProfile:
            profile.name
        case .rename:
            normalizedProfileName(request.renamedName)
        }
    }

    private func normalizedProfileName(_ name: String?) -> String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func canSuggestRename(conflictKinds: Set<ImportProfileConflictKind>) -> Bool {
        !conflictKinds.isEmpty && conflictKinds.allSatisfy(\.isNameConflict)
    }

    private func makeSuggestedRename(for name: String, reservedNames: Set<String>) -> String? {
        let baseName = "\(name) (Imported)"
        if !reservedNames.contains(baseName) {
            return baseName
        }

        for index in 2...999 {
            let candidate = "\(name) (Imported \(index))"
            if !reservedNames.contains(candidate) {
                return candidate
            }
        }

        return nil
    }

    private func documentError(sourceFileName: String, message: String) -> ImportPreviewResult {
        result(
            sourceFileName: sourceFileName,
            schemaVersion: nil,
            app: nil,
            exportedAt: nil,
            totalProfiles: 0,
            documentMessages: [.error(message)],
            profiles: []
        )
    }

    private func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty else {
            return false
        }

        if host.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return false
        }

        return !host.contains("/") && !host.contains("://")
    }

    private func isSecretLikeKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        return lowercaseKey.contains("apikey")
            || lowercaseKey.contains("api_key")
            || lowercaseKey.contains("token")
            || lowercaseKey.contains("secret")
            || lowercaseKey.contains("authorization")
            || lowercaseKey.contains("bearer")
            || lowercaseKey.contains("password")
    }

    private func isLocalPathLikeKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        return lowercaseKey.contains("executable")
            || lowercaseKey.contains("filepath")
            || lowercaseKey.contains("file_path")
            || lowercaseKey.contains("modelpath")
            || lowercaseKey.contains("model_path")
            || lowercaseKey.contains("cachepath")
            || lowercaseKey.contains("cache_path")
            || lowercaseKey.contains("localpath")
            || lowercaseKey.contains("local_path")
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            string
        case let number as NSNumber:
            number.stringValue
        default:
            nil
        }
    }

    private func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let integer as Int:
            integer
        case let number as NSNumber:
            number.intValue
        case let string as String:
            Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            nil
        }
    }

    private func dateValue(_ value: Any?) -> Date? {
        guard let string = stringValue(value) else {
            return nil
        }

        return ISO8601DateFormatter().date(from: string)
    }

    private static func endpointKey(modelID: String, host: String, port: Int) -> String {
        "\(modelID.trimmingCharacters(in: .whitespacesAndNewlines))|\(host.trimmingCharacters(in: .whitespacesAndNewlines))|\(port)"
    }

    private func endpointKey(modelID: String, host: String, port: Int) -> String {
        Self.endpointKey(modelID: modelID, host: host, port: port)
    }
}

private struct ImportProfileCandidate {
    let sourceIndex: Int
    let profile: [String: Any]?

    init(sourceIndex: Int, rawProfile: Any) {
        self.sourceIndex = sourceIndex
        self.profile = rawProfile as? [String: Any]
    }

    var normalizedName: String? {
        guard let name = stringValue(profile?["name"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        return name
    }

    var normalizedModelID: String? {
        guard let modelID = stringValue(profile?["modelID"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !modelID.isEmpty else {
            return nil
        }

        return modelID
    }

    var endpointKey: String? {
        guard let modelID = stringValue(profile?["modelID"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              let host = stringValue(profile?["host"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              let port = integerValue(profile?["port"]),
              !modelID.isEmpty,
              !host.isEmpty else {
            return nil
        }

        return "\(modelID)|\(host)|\(port)"
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            string
        case let number as NSNumber:
            number.stringValue
        default:
            nil
        }
    }

    private func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let integer as Int:
            integer
        case let number as NSNumber:
            number.intValue
        case let string as String:
            Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            nil
        }
    }
}

private extension ImportValidationMessage {
    static func error(_ message: String) -> ImportValidationMessage {
        ImportValidationMessage(severity: .error, message: message)
    }

    static func warning(_ message: String) -> ImportValidationMessage {
        ImportValidationMessage(severity: .warning, message: message)
    }

    static func info(_ message: String) -> ImportValidationMessage {
        ImportValidationMessage(severity: .info, message: message)
    }
}
