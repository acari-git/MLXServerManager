import Foundation

enum ModelAvailabilityState: String, CaseIterable, Hashable {
    case unknown
    case configured
    case present
    case missing
    case external
    case notInspectable
    case stale

    var title: String {
        switch self {
        case .unknown:
            "Unknown"
        case .configured:
            "Configured"
        case .present:
            "Present"
        case .missing:
            "Missing"
        case .external:
            "External"
        case .notInspectable:
            "Not inspectable"
        case .stale:
            "Stale"
        }
    }
}

struct ModelAvailabilitySummary: Hashable {
    let state: ModelAvailabilityState
    let profileDisplayName: String
    let configuredTarget: String
    let checkedPathSummary: String
    let scopeText: String
    let nextStep: String
    let canCheck: Bool

    static let noSelection = ModelAvailabilitySummary(
        state: .unknown,
        profileDisplayName: "No selected profile",
        configuredTarget: "None",
        checkedPathSummary: "Not checked",
        scopeText: "No selected profile",
        nextStep: "Select a profile before checking availability.",
        canCheck: false
    )

    static func initial(for model: ModelConfig?, isExternalTarget: Bool) -> ModelAvailabilitySummary {
        guard let model else {
            return .noSelection
        }

        if isExternalTarget {
            return external(for: model)
        }

        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) {
            return ModelAvailabilitySummary(
                state: .unknown,
                profileDisplayName: model.displayName,
                configuredTarget: model.modelID,
                checkedPathSummary: ModelAvailabilityPathFormatter.compact(path: localPath),
                scopeText: "Selected profile only. Not checked yet.",
                nextStep: "Run an explicit availability check for this configured local path.",
                canCheck: true
            )
        }

        return ModelAvailabilitySummary(
            state: .configured,
            profileDisplayName: model.displayName,
            configuredTarget: model.modelID,
            checkedPathSummary: "No local path configured",
            scopeText: "Model identifier only. No file-system check is available.",
            nextStep: "Use a local path as Model ID to enable path availability checks.",
            canCheck: false
        )
    }

    static func external(for model: ModelConfig?) -> ModelAvailabilitySummary {
        ModelAvailabilitySummary(
            state: .external,
            profileDisplayName: model?.displayName ?? "External target",
            configuredTarget: model?.modelID ?? "External model identifier",
            checkedPathSummary: "Not checked",
            scopeText: "External targets are not managed by MLX Server Manager.",
            nextStep: "Use the external server's own tools to confirm model files.",
            canCheck: false
        )
    }

    static func checked(for model: ModelConfig, result: LocalModelAvailabilityCheckResult) -> ModelAvailabilitySummary {
        switch result {
        case let .present(path):
            return ModelAvailabilitySummary(
                state: .present,
                profileDisplayName: model.displayName,
                configuredTarget: model.modelID,
                checkedPathSummary: ModelAvailabilityPathFormatter.compact(path: path),
                scopeText: "Selected profile only. Checked this session.",
                nextStep: "Presence does not confirm launch compatibility or performance.",
                canCheck: true
            )
        case let .missing(path):
            return ModelAvailabilitySummary(
                state: .missing,
                profileDisplayName: model.displayName,
                configuredTarget: model.modelID,
                checkedPathSummary: ModelAvailabilityPathFormatter.compact(path: path),
                scopeText: "Selected profile only. Checked this session.",
                nextStep: "Update the profile path or place the model at the configured location.",
                canCheck: true
            )
        case let .notInspectable(message):
            return ModelAvailabilitySummary(
                state: .notInspectable,
                profileDisplayName: model.displayName,
                configuredTarget: model.modelID,
                checkedPathSummary: "Not checked",
                scopeText: "Selected profile only. Local path was not safely inspectable.",
                nextStep: message,
                canCheck: false
            )
        }
    }
}

enum ModelAvailabilityPathFormatter {
    static func localPathCandidate(for model: ModelConfig) -> String? {
        if let modelIDPath = expandedLocalPath(from: model.modelID) {
            return modelIDPath
        }

        return expandedLocalPath(from: model.localName)
    }

    static func expandedLocalPath(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("~/") {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            return homePath + String(trimmed.dropFirst())
        }

        if trimmed.hasPrefix("/") {
            return trimmed
        }

        if let url = URL(string: trimmed), url.isFileURL {
            return url.path
        }

        return nil
    }

    static func compact(path: String, homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path) -> String {
        let normalizedHome = homeDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedHome.isEmpty else {
            return path
        }

        let homeWithSlash = "/" + normalizedHome + "/"
        if path == "/" + normalizedHome {
            return "~"
        }

        if path.hasPrefix(homeWithSlash) {
            return "~/" + String(path.dropFirst(homeWithSlash.count))
        }

        return path
    }
}
