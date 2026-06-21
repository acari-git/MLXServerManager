import Foundation

struct HuggingFaceModelReference: Equatable {
    let repositoryID: String
    let owner: String
    let name: String

    static func parse(_ input: String) -> Result<HuggingFaceModelReference, HuggingFaceModelReferenceError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyInput)
        }

        if trimmed.localizedCaseInsensitiveContains("huggingface.co") {
            return parseURL(trimmed)
        }

        return parseRepositoryID(trimmed)
    }

    private static func parseURL(_ input: String) -> Result<HuggingFaceModelReference, HuggingFaceModelReferenceError> {
        guard let components = URLComponents(string: input),
              let host = components.host?.lowercased(),
              host == "huggingface.co" || host.hasSuffix(".huggingface.co") else {
            return .failure(.invalidURL)
        }

        let pathSegments = components.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !pathSegments.isEmpty else {
            return .failure(.missingRepository)
        }

        if ["datasets", "spaces", "docs"].contains(pathSegments[0].lowercased()) {
            return .failure(.unsupportedRepositoryType)
        }

        guard pathSegments.count >= 2 else {
            return .failure(.missingRepository)
        }

        return parseRepositoryID("\(pathSegments[0])/\(pathSegments[1])")
    }

    private static func parseRepositoryID(_ input: String) -> Result<HuggingFaceModelReference, HuggingFaceModelReferenceError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" ") else {
            return .failure(.invalidRepositoryID)
        }

        let parts = trimmed
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard parts.count == 2 else {
            return .failure(.invalidRepositoryID)
        }

        guard parts.allSatisfy(isValidRepositoryPart) else {
            return .failure(.invalidRepositoryID)
        }

        return .success(
            HuggingFaceModelReference(
                repositoryID: "\(parts[0])/\(parts[1])",
                owner: parts[0],
                name: parts[1]
            )
        )
    }

    nonisolated private static func isValidRepositoryPart(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

enum HuggingFaceModelReferenceError: LocalizedError, Equatable {
    case emptyInput
    case invalidURL
    case missingRepository
    case invalidRepositoryID
    case unsupportedRepositoryType

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Enter a Hugging Face model ID or model URL."
        case .invalidURL:
            "Enter a valid huggingface.co model URL."
        case .missingRepository:
            "The URL does not include an owner and model name."
        case .invalidRepositoryID:
            "Use a model ID such as owner/model-name."
        case .unsupportedRepositoryType:
            "Only Hugging Face model repositories are supported in this release."
        }
    }
}

struct HuggingFaceDownloadDraft: Equatable {
    var source: String
    var saveDirectory: String
    var displayName: String
    var host: String
    var serverPortText: String
    var enableThinking: Bool
    var autoAddToModelList: Bool
    var autoSelectAfterAdd: Bool

    static func defaults(defaultHost: String, defaultPort: Int) -> HuggingFaceDownloadDraft {
        HuggingFaceDownloadDraft(
            source: "",
            saveDirectory: "~/Models/mlx",
            displayName: "",
            host: defaultHost,
            serverPortText: String(defaultPort),
            enableThinking: false,
            autoAddToModelList: true,
            autoSelectAfterAdd: true
        )
    }
}

struct HuggingFaceDownloadPreview: Equatable {
    let reference: HuggingFaceModelReference?
    let destinationPath: String?
    let compactDestinationPath: String
    let destinationNote: String
    let displayName: String
    let message: String
    let canDownload: Bool

    static func make(draft: HuggingFaceDownloadDraft) -> HuggingFaceDownloadPreview {
        switch HuggingFaceModelReference.parse(draft.source) {
        case let .success(reference):
            let destinationPath = HuggingFaceDownloadPlanner.destinationPath(
                baseDirectory: draft.saveDirectory,
                repositoryName: reference.name
            )
            let compactPath = destinationPath.map { ModelAvailabilityPathFormatter.compact(path: $0) } ?? "Invalid save directory"
            let destinationState = HuggingFaceDownloadPlanner.destinationState(path: destinationPath)
            let displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? reference.name
                : draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            return HuggingFaceDownloadPreview(
                reference: reference,
                destinationPath: destinationPath,
                compactDestinationPath: compactPath,
                destinationNote: destinationState.note,
                displayName: displayName,
                message: destinationPath == nil ? "Save directory is not a local path." : destinationState.message,
                canDownload: destinationPath != nil && destinationState.canUse
            )
        case let .failure(error):
            return HuggingFaceDownloadPreview(
                reference: nil,
                destinationPath: nil,
                compactDestinationPath: "Not available",
                destinationNote: "No destination until a valid model ID or URL is entered.",
                displayName: "Not available",
                message: error.localizedDescription,
                canDownload: false
            )
        }
    }
}

enum HuggingFaceDownloadPhase: Equatable {
    case waiting
    case preparing
    case downloading
    case finalizing
    case completed
    case failed
    case cancelled

    var title: String {
        switch self {
        case .waiting:
            "Waiting"
        case .preparing:
            "Preparing"
        case .downloading:
            "Downloading"
        case .finalizing:
            "Finalizing"
        case .completed:
            "Completed"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            true
        default:
            false
        }
    }
}

struct HuggingFaceDownloadQueueEntry: Identifiable, Equatable {
    let id: UUID
    let repositoryID: String
    let destinationPath: String
    var phase: HuggingFaceDownloadPhase
    var message: String

    var compactDestinationPath: String {
        ModelAvailabilityPathFormatter.compact(path: destinationPath)
    }
}

struct HuggingFaceDownloadStatus: Equatable {
    var phase: HuggingFaceDownloadPhase
    var message: String
    var repositoryID: String?
    var destinationPath: String?
    var progress: Double?
    var outputLines: [String]

    static let waiting = HuggingFaceDownloadStatus(
        phase: .waiting,
        message: "Paste a Hugging Face model ID or URL, then press Download.",
        repositoryID: nil,
        destinationPath: nil,
        progress: nil,
        outputLines: []
    )
}

struct HuggingFaceDownloadPlanner {
    static func destinationState(path: String?) -> (note: String, message: String, canUse: Bool) {
        guard let path else {
            return ("No local destination.", "Save directory is not a local path.", false)
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return ("Destination will be created.", "Ready to download.", true)
        }

        if isDirectory.boolValue {
            return (
                "Destination already exists. Download will update or reuse this folder.",
                "Ready to resume or update existing destination.",
                true
            )
        }

        return (
            "Destination is an existing file. Choose another save folder.",
            "Cannot download because the destination path is a file.",
            false
        )
    }

    static func destinationPath(baseDirectory: String, repositoryName: String) -> String? {
        guard let basePath = expandedLocalPath(from: baseDirectory) else {
            return nil
        }

        return URL(fileURLWithPath: basePath, isDirectory: true)
            .appendingPathComponent(repositoryName, isDirectory: true)
            .standardizedFileURL
            .path
    }

    static func expandedLocalPath(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed == "~" {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }

        if trimmed.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(trimmed.dropFirst(2)), isDirectory: true)
                .standardizedFileURL
                .path
        }

        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed, isDirectory: true)
                .standardizedFileURL
                .path
        }

        if let url = URL(string: trimmed), url.isFileURL {
            return url.standardizedFileURL.path
        }

        return nil
    }

    nonisolated static func progressFraction(from outputLine: String) -> Double? {
        guard let percentRange = outputLine.range(of: #"\b([0-9]{1,3})%"#, options: .regularExpression) else {
            return nil
        }

        let percentText = outputLine[percentRange].dropLast()
        guard let percent = Double(percentText), (0...100).contains(percent) else {
            return nil
        }

        return percent / 100
    }

    nonisolated static func sanitizedOutputLine(_ line: String) -> String {
        let scalarView = line.unicodeScalars.filter { scalar in
            scalar.value >= 32 || scalar == "\n" || scalar == "\t"
        }
        return String(String.UnicodeScalarView(scalarView))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
