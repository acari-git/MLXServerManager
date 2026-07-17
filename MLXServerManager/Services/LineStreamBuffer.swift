import Foundation

nonisolated final class LineStreamBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumLinesPerLabel: Int?
    private let maximumCharactersPerLine: Int?
    private var pendingTextByLabel: [String: String] = [:]
    private var emittedLineCountByLabel: [String: Int] = [:]
    private var omittedCharacterCountByLabel: [String: Int] = [:]

    init(
        maximumLinesPerLabel: Int? = nil,
        maximumCharactersPerLine: Int? = 65_536
    ) {
        self.maximumLinesPerLabel = maximumLinesPerLabel
        self.maximumCharactersPerLine = maximumCharactersPerLine.map { max(1, $0) }
    }

    func reset() {
        lock.lock()
        pendingTextByLabel.removeAll()
        emittedLineCountByLabel.removeAll()
        omittedCharacterCountByLabel.removeAll()
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
            appendIfAllowed(boundedLine(line, label: label), label: label, to: &lines)
        }

        boundPendingText(&pending, label: label)
        pendingTextByLabel[label] = pending
        return lines
    }

    func flush(label: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        let pending = pendingTextByLabel.removeValue(forKey: label) ?? ""
        var lines: [String] = []
        appendIfAllowed(boundedLine(pending, label: label), label: label, to: &lines)
        return lines
    }

    private func boundPendingText(_ pending: inout String, label: String) {
        guard let maximumCharactersPerLine,
              pending.count > maximumCharactersPerLine else {
            return
        }

        let omittedCount = pending.count - maximumCharactersPerLine
        omittedCharacterCountByLabel[label, default: 0] += omittedCount
        pending = String(pending.suffix(maximumCharactersPerLine))
    }

    private func boundedLine(_ line: String, label: String) -> String {
        var omittedCount = omittedCharacterCountByLabel.removeValue(forKey: label) ?? 0
        var retainedLine = line

        if let maximumCharactersPerLine,
           retainedLine.count > maximumCharactersPerLine {
            omittedCount += retainedLine.count - maximumCharactersPerLine
            retainedLine = String(retainedLine.suffix(maximumCharactersPerLine))
        }

        guard omittedCount > 0 else {
            return retainedLine
        }

        return "[output truncated: \(omittedCount) characters omitted] \(retainedLine)"
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
