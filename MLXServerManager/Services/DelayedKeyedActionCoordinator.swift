import Foundation

@MainActor
final class DelayedKeyedActionCoordinator<Key: Hashable & Sendable> {
    private struct ScheduledAction: Sendable {
        let generation: UUID
        let task: Task<Void, Never>
    }

    private var scheduledActions: [Key: ScheduledAction] = [:]

    deinit {
        for scheduledAction in scheduledActions.values {
            scheduledAction.task.cancel()
        }
    }

    @discardableResult
    func scheduleIfAbsent(
        _ key: Key,
        delayNanoseconds: UInt64,
        action: @escaping @MainActor () -> Void
    ) -> Bool {
        guard scheduledActions[key] == nil else {
            return false
        }

        let generation = UUID()
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            guard let self,
                  self.finishIfCurrent(key, generation: generation) else {
                return
            }
            action()
        }
        scheduledActions[key] = ScheduledAction(
            generation: generation,
            task: task
        )
        return true
    }

    @discardableResult
    func cancel(_ key: Key) -> Bool {
        guard let scheduledAction = scheduledActions.removeValue(forKey: key) else {
            return false
        }
        scheduledAction.task.cancel()
        return true
    }

    func cancelAll() {
        let actions = scheduledActions.values
        scheduledActions.removeAll()
        for action in actions {
            action.task.cancel()
        }
    }

    func isScheduled(_ key: Key) -> Bool {
        scheduledActions[key] != nil
    }

    private func finishIfCurrent(
        _ key: Key,
        generation: UUID
    ) -> Bool {
        guard scheduledActions[key]?.generation == generation else {
            return false
        }
        scheduledActions[key] = nil
        return true
    }
}
