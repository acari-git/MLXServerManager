import Foundation

nonisolated struct HuggingFaceModelReference: Codable, Equatable {
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

nonisolated enum HuggingFaceModelReferenceError: LocalizedError, Equatable {
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

nonisolated struct HuggingFaceDownloadDraft: Codable, Equatable {
    var source: String
    var revision: String
    var includePatterns: String
    var excludePatterns: String
    var useSelectedPreviewFiles: Bool
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
            revision: "main",
            includePatterns: "*.safetensors, *.json, tokenizer.*, *.model, *.txt",
            excludePatterns: "*.h5, *.onnx, *.msgpack, *.bin",
            useSelectedPreviewFiles: false,
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

nonisolated struct HuggingFaceDownloadPreview: Equatable {
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
                reference: reference
            )
            let compactPath = destinationPath.map { ModelAvailabilityPathFormatter.compact(path: $0) } ?? "Invalid save directory"
            let revision = draft.revision.trimmingCharacters(in: .whitespacesAndNewlines)
            let destinationState = HuggingFaceDownloadPlanner.destinationState(
                path: destinationPath,
                repositoryID: reference.repositoryID,
                revision: revision.isEmpty ? "main" : revision
            )
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

nonisolated enum HuggingFaceDownloadPhase: String, Codable, Equatable {
    case waiting
    case preparing
    case downloading
    case finalizing
    case completed
    case failed
    case cancelled

    @MainActor var title: String {
        localizedTitle(language: .english)
    }

    @MainActor func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .waiting:
            return strings.text(english: "Waiting", japanese: "待機中")
        case .preparing:
            return strings.text(english: "Preparing", japanese: "準備中")
        case .downloading:
            return strings.text(english: "Downloading", japanese: "ダウンロード中")
        case .finalizing:
            return strings.text(english: "Finalizing", japanese: "最終処理中")
        case .completed:
            return strings.text(english: "Completed", japanese: "完了")
        case .failed:
            return strings.text(english: "Failed", japanese: "失敗")
        case .cancelled:
            return strings.text(english: "Cancelled", japanese: "キャンセル")
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

nonisolated struct HuggingFaceDownloadQueueEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let repositoryID: String
    let destinationPath: String
    var phase: HuggingFaceDownloadPhase
    var message: String
    var fileCount: Int?
    var downloadedFileCount: Int?
    var downloadedBytes: Int64?
    var totalBytes: Int64?
    var speedBytesPerSecond: Int64?

    var compactDestinationPath: String {
        ModelAvailabilityPathFormatter.compact(path: destinationPath)
    }

    var progressFraction: Double? {
        guard let totalBytes, totalBytes > 0 else {
            return nil
        }
        let downloaded = downloadedBytes ?? 0
        return min(max(Double(downloaded) / Double(totalBytes), 0), 1)
    }

    var fileProgressText: String {
        guard let fileCount, fileCount > 0 else {
            return "-"
        }
        let completed = phase == .completed ? fileCount : min(max(downloadedFileCount ?? 0, 0), fileCount)
        return "\(completed) / \(fileCount)"
    }

    var capacityProgressText: String {
        guard let progressFraction else {
            if let downloadedBytes {
                return "\(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)) downloaded"
            }
            return "-"
        }
        let downloaded = downloadedBytes ?? 0
        let total = totalBytes ?? 0
        return "\(Int(progressFraction * 100))% • \(ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
    }

    var progressText: String {
        let files = fileCount.map { "\(downloadedFileCount ?? 0) / \($0) files" } ?? "files unknown"
        return "\(files) • \(capacityProgressText)"
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

nonisolated struct HuggingFaceDownloadPlanner {
    static func destinationIdentity(path: String) -> String {
        var existingAncestor = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL
        var missingPathComponents: [String] = []

        while !FileManager.default.fileExists(atPath: existingAncestor.path) {
            let parent = existingAncestor.deletingLastPathComponent()
            guard parent.path != existingAncestor.path else {
                break
            }
            missingPathComponents.append(existingAncestor.lastPathComponent)
            existingAncestor = parent
        }

        var resolvedURL = existingAncestor.resolvingSymlinksInPath()
        for component in missingPathComponents.reversed() {
            resolvedURL.appendPathComponent(component, isDirectory: true)
        }
        return resolvedURL.standardizedFileURL.path
    }

    static func destinationsMatch(_ lhs: String, _ rhs: String) -> Bool {
        destinationIdentity(path: lhs) == destinationIdentity(path: rhs)
    }

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

    static func destinationState(
        path: String?,
        repositoryID: String,
        revision: String
    ) -> (note: String, message: String, canUse: Bool) {
        guard let path else {
            return ("No local destination.", "Save directory is not a local path.", false)
        }

        let destinationURL = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let inspection = HuggingFaceDownloadProvenanceStore().inspect(
            destinationURL: destinationURL,
            repositoryID: repositoryID,
            revision: revision
        )
        switch inspection {
        case .newDestination:
            return ("Destination will be created.", "Ready to download.", true)
        case .emptyDirectory:
            return ("Destination is empty and will be assigned to this model.", "Ready to download.", true)
        case .matchingSource:
            return (
                "Destination source matches. Download will update or resume this folder.",
                "Ready to resume or update existing destination.",
                true
            )
        case let .blocked(error):
            let message = error.localizedDescription
            return (message, message, false)
        }
    }

    static func destinationPath(
        baseDirectory: String,
        reference: HuggingFaceModelReference
    ) -> String? {
        guard let basePath = expandedLocalPath(from: baseDirectory) else {
            return nil
        }

        return URL(fileURLWithPath: basePath, isDirectory: true)
            .appendingPathComponent(reference.owner, isDirectory: true)
            .appendingPathComponent(reference.name, isDirectory: true)
            .standardizedFileURL
            .path
    }

    static func baseDirectory(
        forDestinationPath destinationPath: String,
        repositoryID: String
    ) -> String {
        let destinationURL = URL(fileURLWithPath: destinationPath, isDirectory: true).standardizedFileURL
        guard case let .success(reference) = HuggingFaceModelReference.parse(repositoryID),
              destinationURL.lastPathComponent == reference.name,
              destinationURL.deletingLastPathComponent().lastPathComponent == reference.owner else {
            return destinationURL.deletingLastPathComponent().path
        }
        return destinationURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

    nonisolated static func sanitizedOutputLine(
        _ line: String,
        sensitiveValues: [String] = []
    ) -> String {
        let scalarView = line.unicodeScalars.filter { scalar in
            scalar.value >= 32 || scalar == "\n" || scalar == "\t"
        }
        var sanitized = String(String.UnicodeScalarView(scalarView))

        for value in sensitiveValues {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            sanitized = sanitized.replacingOccurrences(of: trimmed, with: "[REDACTED]")
        }

        sanitized = sanitized.replacingOccurrences(
            of: #"(?i)\bBearer[ \t]+[^\s,;]+"#,
            with: "Bearer [REDACTED]",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"\bhf_[A-Za-z0-9][A-Za-z0-9_-]{9,}\b"#,
            with: "[REDACTED]",
            options: .regularExpression
        )

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
