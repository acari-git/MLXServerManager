import Foundation

@MainActor
final class ApplicationTerminationCoordinator {
    typealias StopOperation = @MainActor (ManagedTerminationTarget) async -> Bool
    typealias ProgressHandler = @MainActor (_ completed: Int, _ total: Int) -> Void
    typealias CompletionHandler = @MainActor ([ManagedTerminationFailure]) -> Void

    private var task: Task<Void, Never>?

    var isRunning: Bool {
        task != nil
    }

    func stopAll(
        targets: [ManagedTerminationTarget],
        stopOperation: @escaping StopOperation,
        progressHandler: @escaping ProgressHandler,
        completionHandler: @escaping CompletionHandler
    ) {
        task?.cancel()
        let total = targets.count
        task = Task { @MainActor [weak self] in
            var failures: [ManagedTerminationFailure] = []
            for (index, target) in targets.enumerated() {
                guard !Task.isCancelled else {
                    failures.append(contentsOf: targets[index...].map { pendingTarget in
                        ManagedTerminationFailure(
                            target: pendingTarget,
                            message: "Shutdown was cancelled before this managed server stopped."
                        )
                    })
                    break
                }

                let didStop = await stopOperation(target)
                if !didStop {
                    failures.append(
                        ManagedTerminationFailure(
                            target: target,
                            message: "The managed process or its port did not stop cleanly."
                        )
                    )
                }
                progressHandler(index + 1, total)
            }

            guard !Task.isCancelled else {
                self?.task = nil
                completionHandler(failures)
                return
            }
            self?.task = nil
            completionHandler(failures)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
