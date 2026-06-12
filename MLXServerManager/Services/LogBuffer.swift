import Foundation

struct LogBuffer {
    let maximumCount: Int
    private(set) var entries: [LogEntry]

    init(maximumCount: Int = 400, initialLines: [String] = []) {
        self.maximumCount = max(1, maximumCount)
        self.entries = initialLines.map { LogEntry(line: $0) }
        trimIfNeeded()
    }

    var text: String {
        entries.map(\.line).joined(separator: "\n")
    }

    mutating func append(_ line: String) {
        entries.append(LogEntry(line: line))
        trimIfNeeded()
    }

    mutating func clear() {
        entries.removeAll(keepingCapacity: true)
    }

    private mutating func trimIfNeeded() {
        guard entries.count > maximumCount else {
            return
        }

        entries.removeFirst(entries.count - maximumCount)
    }
}
