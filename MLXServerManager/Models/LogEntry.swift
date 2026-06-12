import Foundation

struct LogEntry: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let category: String
    let message: String
    let line: String

    init(line: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.line = line

        let parsed = Self.parse(line)
        self.category = parsed.category
        self.message = parsed.message
    }

    private static func parse(_ line: String) -> (category: String, message: String) {
        guard line.first == "[",
              let closingBracketIndex = line.firstIndex(of: "]") else {
            return ("info", line)
        }

        let categoryStart = line.index(after: line.startIndex)
        let category = String(line[categoryStart..<closingBracketIndex])
        let messageStart = line.index(after: closingBracketIndex)
        let message = String(line[messageStart...])
            .trimmingCharacters(in: .whitespaces)

        return (category.isEmpty ? "info" : category, message)
    }
}
