import Foundation

nonisolated struct HuggingFaceDownloadFileSelection: Equatable, Sendable {
    let filteredFiles: [HuggingFaceDownloadPreviewFile]
    let selectedFiles: [HuggingFaceDownloadPreviewFile]
    let downloadFiles: [HuggingFaceDownloadPreviewFile]
    let downloadIncludePatterns: [String]
    let downloadExcludePatterns: [String]
    let totalDownloadBytes: Int64?

    var knownDownloadByteCount: Int64 {
        downloadFiles.compactMap(\.size).reduce(0, +)
    }

    var hasUnknownDownloadSize: Bool {
        downloadFiles.contains { $0.size == nil }
    }
}

nonisolated enum HuggingFaceDownloadFileSelectionPlanner {
    static func make(
        files: [HuggingFaceDownloadPreviewFile],
        draft: HuggingFaceDownloadDraft,
        selectedFileIDs: Set<String>
    ) -> HuggingFaceDownloadFileSelection {
        let includePatterns = patternList(from: draft.includePatterns)
        let excludePatterns = patternList(from: draft.excludePatterns)
        let includeMatchers = includePatterns.map(GlobMatcher.init)
        let excludeMatchers = excludePatterns.map(GlobMatcher.init)

        let filteredFiles = files.filter { file in
            let included = includeMatchers.isEmpty || includeMatchers.contains { $0.matches(file.path) }
            let excluded = excludeMatchers.contains { $0.matches(file.path) }
            return included && !excluded
        }
        let selectedFiles = filteredFiles.filter { selectedFileIDs.contains($0.id) }
        let downloadFiles = draft.useSelectedPreviewFiles ? selectedFiles : filteredFiles

        return HuggingFaceDownloadFileSelection(
            filteredFiles: filteredFiles,
            selectedFiles: selectedFiles,
            downloadFiles: downloadFiles,
            downloadIncludePatterns: draft.useSelectedPreviewFiles && !selectedFiles.isEmpty
                ? selectedFiles.map(\.path)
                : includePatterns,
            downloadExcludePatterns: excludePatterns,
            totalDownloadBytes: totalBytes(for: downloadFiles)
        )
    }

    static func patternList(from text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func totalBytes(for files: [HuggingFaceDownloadPreviewFile]) -> Int64? {
        guard !files.isEmpty else {
            return nil
        }

        var total: Int64 = 0
        for file in files {
            guard let size = file.size else {
                return nil
            }
            total += size
        }
        return total > 0 ? total : nil
    }

    private struct GlobMatcher {
        private let expression: NSRegularExpression?

        init(pattern: String) {
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\*\\*", with: ".*")
                .replacingOccurrences(of: "\\*", with: "[^/]*")
                .replacingOccurrences(of: "\\?", with: "[^/]")
            expression = try? NSRegularExpression(pattern: "^\(escaped)$")
        }

        func matches(_ path: String) -> Bool {
            matchesCompleteValue(path)
                || matchesCompleteValue(URL(fileURLWithPath: path).lastPathComponent)
        }

        private func matchesCompleteValue(_ value: String) -> Bool {
            guard let expression else {
                return false
            }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            return expression.firstMatch(in: value, range: range) != nil
        }
    }
}
