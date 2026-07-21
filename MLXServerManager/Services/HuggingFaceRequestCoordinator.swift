import Foundation

nonisolated enum HuggingFaceRequest: Hashable, Sendable {
    case search
    case filePreview
}

@MainActor
final class HuggingFaceRequestCoordinator {
    struct Generation: Equatable, Sendable {
        fileprivate let id = UUID()
    }

    typealias Operation = @MainActor (_ generation: Generation) async -> Void

    private struct ActiveRequest: Sendable {
        let generation: Generation
        let task: Task<Void, Never>
    }

    private var activeRequests: [HuggingFaceRequest: ActiveRequest] = [:]

    deinit {
        for activeRequest in activeRequests.values {
            activeRequest.task.cancel()
        }
    }

    func start(
        _ request: HuggingFaceRequest,
        operation: @escaping Operation
    ) {
        cancel(request)

        let generation = Generation()
        let task = Task { [weak self] in
            await operation(generation)
            self?.finish(request, generation: generation)
        }

        activeRequests[request] = ActiveRequest(
            generation: generation,
            task: task
        )
    }

    func cancel(_ request: HuggingFaceRequest) {
        guard let activeRequest = activeRequests.removeValue(forKey: request) else {
            return
        }
        activeRequest.task.cancel()
    }

    func isCurrent(
        _ request: HuggingFaceRequest,
        generation: Generation
    ) -> Bool {
        activeRequests[request]?.generation == generation
    }

    func isRunning(_ request: HuggingFaceRequest) -> Bool {
        activeRequests[request] != nil
    }

    private func finish(
        _ request: HuggingFaceRequest,
        generation: Generation
    ) {
        guard activeRequests[request]?.generation == generation else {
            return
        }
        activeRequests[request] = nil
    }
}
