import Foundation

nonisolated struct LogBuffer {
    let maximumCount: Int
    private(set) var entries: [LogEntry]
    private(set) var text: String

    init(maximumCount: Int = 400, initialLines: [String] = []) {
        self.maximumCount = max(1, maximumCount)
        let initialEntries = initialLines.map { LogEntry(line: $0) }
        self.entries = Array(initialEntries.suffix(self.maximumCount))
        self.text = Self.joinedText(from: entries)
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    mutating func append(_ line: String) {
        append(contentsOf: [line])
    }

    mutating func append(contentsOf lines: [String]) {
        guard !lines.isEmpty else {
            return
        }

        entries.append(contentsOf: lines.map { LogEntry(line: $0) })
        if entries.count > maximumCount {
            trimIfNeeded()
            text = Self.joinedText(from: entries)
            return
        }

        let appendedText = lines.joined(separator: "\n")
        if text.isEmpty {
            text = appendedText
        } else {
            text += "\n\(appendedText)"
        }
    }

    mutating func clear() {
        entries.removeAll(keepingCapacity: true)
        text = ""
    }

    private mutating func trimIfNeeded() {
        guard entries.count > maximumCount else {
            return
        }

        entries.removeFirst(entries.count - maximumCount)
    }

    private static func joinedText(from entries: [LogEntry]) -> String {
        entries.map(\.line).joined(separator: "\n")
    }
}
