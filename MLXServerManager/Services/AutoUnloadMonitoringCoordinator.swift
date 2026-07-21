import Foundation

@MainActor
final class AutoUnloadMonitoringCoordinator {
    typealias TickOperation = @MainActor () async -> Bool
    typealias SleepOperation = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private struct ActiveMonitor: Sendable {
        let generation: UUID
        let task: Task<Void, Never>
    }

    private let intervalNanoseconds: UInt64
    private let sleepOperation: SleepOperation
    private var activeMonitor: ActiveMonitor?

    init(
        intervalNanoseconds: UInt64 = 1_000_000_000,
        sleepOperation: SleepOperation? = nil
    ) {
        self.intervalNanoseconds = intervalNanoseconds
        self.sleepOperation = sleepOperation ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    deinit {
        activeMonitor?.task.cancel()
    }

    var isMonitoring: Bool {
        activeMonitor != nil
    }

    func start(tickOperation: @escaping TickOperation) {
        stop()

        let generation = UUID()
        let intervalNanoseconds = self.intervalNanoseconds
        let sleepOperation = self.sleepOperation

        let task = Task { [weak self] in
            defer {
                self?.removeMonitor(generation: generation)
            }

            while !Task.isCancelled {
                let shouldContinue = await tickOperation()

                guard shouldContinue, !Task.isCancelled else {
                    return
                }

                do {
                    try await sleepOperation(intervalNanoseconds)
                } catch {
                    return
                }
            }
        }

        activeMonitor = ActiveMonitor(
            generation: generation,
            task: task
        )
    }

    func stop() {
        guard let monitor = activeMonitor else {
            return
        }
        activeMonitor = nil
        monitor.task.cancel()
    }

    private func removeMonitor(generation: UUID) {
        guard activeMonitor?.generation == generation else {
            return
        }
        activeMonitor = nil
    }
}
