import Foundation

@MainActor
final class HuggingFaceOutputStateCoordinator {
    private(set) var outputLinesByID: [UUID: [String]] = [:]
    private(set) var primaryID: UUID?

    private var pendingBatches: [UUID: HuggingFaceOutputBatch] = [:]
    private let flushCoordinator = HuggingFaceOutputFlushCoordinator()

    func selectPrimaryIfNeeded(_ id: UUID) {
        if primaryID == nil {
            primaryID = id
        }
    }

    func setPrimary(_ id: UUID?) {
        primaryID = id
    }

    func clearPrimaryIfRemoved(_ ids: Set<UUID>) {
        guard let primaryID, ids.contains(primaryID) else {
            return
        }
        self.primaryID = nil
    }

    func appendPending(
        _ line: String,
        queueEntryID: UUID,
        flushDelayNanoseconds: UInt64,
        onDelayedFlush: @escaping @MainActor () -> Void
    ) -> Bool {
        var batch = pendingBatches[queueEntryID] ?? HuggingFaceOutputBatch()
        batch.append(line)
        pendingBatches[queueEntryID] = batch

        if HuggingFaceOutputLinePolicy.requiresImmediateFlush(line) {
            return true
        }

        flushCoordinator.scheduleIfAbsent(
            queueEntryID,
            delayNanoseconds: flushDelayNanoseconds,
            action: onDelayedFlush
        )
        return false
    }

    func drainPending(
        queueEntryID: UUID,
        cancelScheduledFlush: Bool
    ) -> [String] {
        if cancelScheduledFlush {
            flushCoordinator.cancel(queueEntryID)
        }

        guard var batch = pendingBatches.removeValue(forKey: queueEntryID) else {
            return []
        }
        return batch.drain()
    }

    func appendHistory(
        _ lines: [String],
        queueEntryID: UUID,
        maximumCount: Int
    ) {
        outputLinesByID[queueEntryID] = HuggingFaceOutputBatch.boundedHistory(
            existing: outputLinesByID[queueEntryID] ?? [],
            appending: lines,
            maximumCount: maximumCount
        )
    }

    func discard(queueEntryID: UUID) {
        flushCoordinator.cancel(queueEntryID)
        pendingBatches[queueEntryID] = nil
        outputLinesByID[queueEntryID] = nil
        if primaryID == queueEntryID {
            primaryID = nil
        }
    }

    func removeOutput(queueEntryID: UUID) {
        outputLinesByID[queueEntryID] = nil
    }

    func reset() {
        flushCoordinator.cancelAll()
        pendingBatches.removeAll()
        outputLinesByID.removeAll()
        primaryID = nil
    }
}
