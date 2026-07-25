import Foundation

@MainActor
final class SharedKeyedTaskCoordinator<Key: Hashable & Sendable, Output: Sendable> {
    struct Generation: Equatable, Sendable {
        fileprivate let id = UUID()
    }

    struct Handle: Sendable {
        let generation: Generation
        let task: Task<Output, Never>
    }

    struct BeginResult: Sendable {
        let handle: Handle
        let startedNewTask: Bool
    }

    private struct ActiveTask: Sendable {
        let handle: Handle
        let completionTask: Task<Void, Never>?
    }

    private var activeTasks: [Key: ActiveTask] = [:]

    deinit {
        for activeTask in activeTasks.values {
            activeTask.handle.task.cancel()
            activeTask.completionTask?.cancel()
        }
    }

    func begin(
        _ key: Key,
        priority: TaskPriority = .utility,
        operation: @escaping @Sendable () -> Output,
        completion: (@MainActor (Output, Generation) -> Void)? = nil
    ) -> BeginResult {
        if let existing = activeTasks[key] {
            return BeginResult(
                handle: existing.handle,
                startedNewTask: false
            )
        }

        let generation = Generation()
        let task = Task.detached(priority: priority, operation: operation)
        let handle = Handle(generation: generation, task: task)
        let completionTask = completion.map { completion in
            Task { [weak self, task] in
                let output = await task.value
                guard let self,
                      self.removeIfCurrent(
                        key,
                        generation: generation,
                        cancelCompletionTask: false
                      ) else {
                    return
                }
                completion(output, generation)
            }
        }
        activeTasks[key] = ActiveTask(
            handle: handle,
            completionTask: completionTask
        )
        return BeginResult(
            handle: handle,
            startedNewTask: true
        )
    }

    @discardableResult
    func complete(
        _ key: Key,
        generation: Generation
    ) -> Bool {
        removeIfCurrent(
            key,
            generation: generation,
            cancelCompletionTask: true
        )
    }

    @discardableResult
    func cancel(_ key: Key) -> Bool {
        guard let activeTask = activeTasks.removeValue(forKey: key) else {
            return false
        }
        activeTask.handle.task.cancel()
        activeTask.completionTask?.cancel()
        return true
    }

    func cancelAll() {
        let tasks = activeTasks.values
        activeTasks.removeAll()
        for activeTask in tasks {
            activeTask.handle.task.cancel()
            activeTask.completionTask?.cancel()
        }
    }

    func isRunning(_ key: Key) -> Bool {
        activeTasks[key] != nil
    }

    func isCurrent(
        _ key: Key,
        generation: Generation
    ) -> Bool {
        activeTasks[key]?.handle.generation == generation
    }

    private func removeIfCurrent(
        _ key: Key,
        generation: Generation,
        cancelCompletionTask: Bool
    ) -> Bool {
        guard activeTasks[key]?.handle.generation == generation,
              let activeTask = activeTasks.removeValue(forKey: key) else {
            return false
        }
        if cancelCompletionTask {
            activeTask.completionTask?.cancel()
        }
        return true
    }
}
