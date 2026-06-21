import Foundation

enum LocalModelAvailabilityCheckResult: Hashable {
    case present(path: String)
    case missing(path: String)
    case notInspectable(message: String)
}

protocol LocalModelAvailabilityChecking {
    func check(path: String) -> LocalModelAvailabilityCheckResult
}

struct FileSystemLocalModelAvailabilityChecker: LocalModelAvailabilityChecking {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func check(path: String) -> LocalModelAvailabilityCheckResult {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return .notInspectable(message: "No local path is configured for this profile.")
        }

        guard trimmedPath.hasPrefix("/") else {
            return .notInspectable(message: "Configured target is not a local file-system path.")
        }

        if fileManager.fileExists(atPath: trimmedPath) {
            return .present(path: trimmedPath)
        }

        return .missing(path: trimmedPath)
    }
}
