import Foundation

nonisolated struct LogViewState: Equatable, Sendable {
    let text: String
    let entries: [LogEntry]
    let categoryFilterOptions: [String]
    let visibleEntries: [LogEntry]
    let latestImportantEntry: LogEntry?
}
