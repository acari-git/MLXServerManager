import Foundation

nonisolated struct DiagnosticsViewState: Equatable, Sendable {
    private(set) var results: [DiagnosticsResult]
    private(set) var didRun: Bool
    private(set) var isRunning: Bool

    static let notRun = DiagnosticsViewState(
        results: [],
        didRun: false,
        isRunning: false
    )

    mutating func beginRun() {
        isRunning = true
    }

    mutating func completeRun(with results: [DiagnosticsResult]) {
        self.results = results
        didRun = true
        isRunning = false
    }

    mutating func cancelRun() {
        isRunning = false
    }

    mutating func reset() {
        self = .notRun
    }
}
