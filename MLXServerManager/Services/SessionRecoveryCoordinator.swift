import Foundation

@MainActor
final class SessionRecoveryCoordinator {
    typealias CheckOperation = @MainActor (SessionRecoveryEndpoint) async -> SessionRecoveryCheckStatus
    typealias CompletionHandler = @MainActor ([ModelConfig.ID: SessionRecoveryCheckStatus]) -> Void

    private var task: Task<Void, Never>?

    func check(
        endpoints: [SessionRecoveryEndpoint],
        operation: @escaping CheckOperation,
        completion: @escaping CompletionHandler
    ) {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            var results: [ModelConfig.ID: SessionRecoveryCheckStatus] = [:]
            for endpoint in endpoints {
                guard !Task.isCancelled else { break }
                results[endpoint.id] = await operation(endpoint)
            }
            guard !Task.isCancelled else {
                self?.task = nil
                return
            }
            self?.task = nil
            completion(results)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
