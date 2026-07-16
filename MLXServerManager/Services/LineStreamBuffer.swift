import Foundation

nonisolated final class LineStreamBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumLinesPerLabel: Int?
    private var pendingTextByLabel: [String: String] = [:]
    private var emittedLineCountByLabel: [String: Int] = [:]

    init(maximumLinesPerLabel: Int? = nil) {
        self.maximumLinesPerLabel = maximumLinesPerLabel
    }

    func reset() {
        lock.lock()
        pendingTextByLabel.removeAll()
        emittedLineCountByLabel.removeAll()
        lock.unlock()
    }

    func consume(_ chunk: String, label: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        var pending = pendingTextByLabel[label, default: ""]
        pending += chunk.replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []

        while let newlineIndex = pending.firstIndex(of: "\n") {
            let line = String(pending[..<newlineIndex])
            pending.removeSubrange(...newlineIndex)
            appendIfAllowed(line, label: label, to: &lines)
        }

        pendingTextByLabel[label] = pending
        return lines
    }

    func flush(label: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        let pending = pendingTextByLabel.removeValue(forKey: label) ?? ""
        var lines: [String] = []
        appendIfAllowed(pending, label: label, to: &lines)
        return lines
    }

    private func appendIfAllowed(_ line: String, label: String, to lines: inout [String]) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        if let maximumLinesPerLabel {
            let emittedCount = emittedLineCountByLabel[label, default: 0]
            guard emittedCount < maximumLinesPerLabel else {
                return
            }
            emittedLineCountByLabel[label] = emittedCount + 1
        }

        lines.append(line)
    }
}
