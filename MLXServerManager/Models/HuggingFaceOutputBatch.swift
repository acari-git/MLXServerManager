import Foundation

nonisolated struct HuggingFaceOutputBatch: Equatable, Sendable {
    private(set) var lines: [String] = []

    var isEmpty: Bool {
        lines.isEmpty
    }

    var containsProgress: Bool {
        lines.contains { HuggingFaceDownloadPlanner.progressFraction(from: $0) != nil }
    }

    mutating func append(_ line: String) {
        lines.append(line)
    }

    mutating func drain() -> [String] {
        defer { lines.removeAll(keepingCapacity: true) }
        return lines
    }

    static func boundedHistory(
        existing: [String],
        appending newLines: [String],
        maximumCount: Int
    ) -> [String] {
        let limit = max(maximumCount, 0)
        guard limit > 0 else {
            return []
        }
        return Array((existing + newLines).suffix(limit))
    }
}

nonisolated enum HuggingFaceOutputLinePolicy {
    private static let immediateFragments = [
        "error",
        "failed",
        "failure",
        "fatal",
        "exception",
        "traceback",
        "warning",
        "unauthorized",
        "forbidden",
        "permission denied",
        "no space left",
        "disk full",
        "cancelled",
        "canceled",
        "download completed",
        "download complete",
        "successfully downloaded"
    ]

    static func requiresImmediateFlush(_ line: String) -> Bool {
        let normalized = line.lowercased()
        return immediateFragments.contains { normalized.contains($0) }
    }
}
