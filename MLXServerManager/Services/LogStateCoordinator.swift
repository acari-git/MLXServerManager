import Foundation

nonisolated struct LogStateCoordinator {
    private var buffer: LogBuffer
    private(set) var filter: String
    private(set) var state: LogViewState

    init(
        maximumCount: Int = 400,
        initialLines: [String] = [],
        filter: String = "All"
    ) {
        let buffer = LogBuffer(maximumCount: maximumCount, initialLines: initialLines)
        self.buffer = buffer
        self.filter = filter
        self.state = Self.makeState(buffer: buffer, filter: filter)
    }

    var isEmpty: Bool {
        buffer.isEmpty
    }

    var text: String {
        buffer.text
    }

    @discardableResult
    mutating func setFilter(_ filter: String) -> LogViewState {
        self.filter = filter
        state = Self.makeState(buffer: buffer, filter: filter)
        return state
    }

    @discardableResult
    mutating func append(_ line: String) -> LogViewState {
        append(contentsOf: [line])
    }

    @discardableResult
    mutating func append(contentsOf lines: [String]) -> LogViewState {
        guard !lines.isEmpty else {
            return state
        }

        buffer.append(contentsOf: lines)
        state = Self.makeState(buffer: buffer, filter: filter)
        return state
    }

    @discardableResult
    mutating func clear(replacementLine: String? = nil) -> LogViewState {
        buffer.clear()
        if let replacementLine, !replacementLine.isEmpty {
            buffer.append(replacementLine)
        }
        state = Self.makeState(buffer: buffer, filter: filter)
        return state
    }

    private static func makeState(buffer: LogBuffer, filter: String) -> LogViewState {
        let entries = buffer.entries
        return LogViewState(
            text: buffer.text,
            entries: entries,
            categoryFilterOptions: makeCategoryFilterOptions(from: entries),
            visibleEntries: visibleEntries(from: entries, filter: filter),
            latestImportantEntry: findLatestImportantEntry(in: entries)
        )
    }

    private static func makeCategoryFilterOptions(from entries: [LogEntry]) -> [String] {
        ["All"] + Array(Set(entries.map(\.category))).sorted()
    }

    private static func visibleEntries(from entries: [LogEntry], filter: String) -> [LogEntry] {
        filter == "All" ? entries : entries.filter { $0.category == filter }
    }

    private static func findLatestImportantEntry(in entries: [LogEntry]) -> LogEntry? {
        entries.reversed().first { entry in
            entry.message.localizedCaseInsensitiveContains("failed")
                || entry.message.localizedCaseInsensitiveContains("warning")
                || entry.category.localizedCaseInsensitiveContains("error")
        }
    }
}
