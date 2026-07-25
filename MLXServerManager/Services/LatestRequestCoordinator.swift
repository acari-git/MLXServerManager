import Foundation

@MainActor
final class LatestRequestCoordinator {
    struct Generation: Equatable, Sendable {
        fileprivate let id = UUID()
    }

    typealias Operation = @MainActor (_ generation: Generation) async -> Void

    private struct ActiveRequest: Sendable {
        let generation: Generation
        let task: Task<Void, Never>
    }

    private var activeRequest: ActiveRequest?

    deinit {
        activeRequest?.task.cancel()
    }

    var isRunning: Bool {
        activeRequest != nil
    }

    func start(operation: @escaping Operation) {
        cancel()

        let generation = Generation()
        let task = Task { [weak self] in
            await operation(generation)
            self?.finish(generation: generation)
        }
        activeRequest = ActiveRequest(generation: generation, task: task)
    }

    @discardableResult
    func cancel() -> Bool {
        guard let activeRequest else {
            return false
        }
        self.activeRequest = nil
        activeRequest.task.cancel()
        return true
    }

    func isCurrent(generation: Generation) -> Bool {
        activeRequest?.generation == generation
    }

    private func finish(generation: Generation) {
        guard activeRequest?.generation == generation else {
            return
        }
        activeRequest = nil
    }
}

@MainActor
final class LatestKeyedRequestCoordinator<Key: Hashable & Sendable> {
    struct Generation: Equatable, Sendable {
        fileprivate let id = UUID()
    }

    typealias Operation = @MainActor (_ generation: Generation) async -> Void

    private struct ActiveRequest: Sendable {
        let generation: Generation
        let task: Task<Void, Never>
    }

    private var activeRequests: [Key: ActiveRequest] = [:]

    deinit {
        for activeRequest in activeRequests.values {
            activeRequest.task.cancel()
        }
    }

    func start(
        _ key: Key,
        operation: @escaping Operation
    ) {
        cancel(key)

        let generation = Generation()
        let task = Task { [weak self] in
            await operation(generation)
            self?.finish(key, generation: generation)
        }
        activeRequests[key] = ActiveRequest(
            generation: generation,
            task: task
        )
    }

    @discardableResult
    func cancel(_ key: Key) -> Bool {
        guard let activeRequest = activeRequests.removeValue(forKey: key) else {
            return false
        }
        activeRequest.task.cancel()
        return true
    }

    func cancelAll() {
        let requests = activeRequests.values
        activeRequests.removeAll()
        for request in requests {
            request.task.cancel()
        }
    }

    func isCurrent(
        _ key: Key,
        generation: Generation
    ) -> Bool {
        activeRequests[key]?.generation == generation
    }

    func isRunning(_ key: Key) -> Bool {
        activeRequests[key] != nil
    }

    private func finish(
        _ key: Key,
        generation: Generation
    ) {
        guard activeRequests[key]?.generation == generation else {
            return
        }
        activeRequests[key] = nil
    }
}
