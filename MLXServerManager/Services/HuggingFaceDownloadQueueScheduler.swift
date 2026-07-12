import Foundation

enum HuggingFaceDownloadQueueScheduler {
    nonisolated static func startableIDs(
        entries: [HuggingFaceDownloadQueueEntry],
        queuedIDs: Set<UUID>,
        activeIDs: Set<UUID>,
        maximumConcurrentDownloads: Int
    ) -> [UUID] {
        let maximum = min(max(maximumConcurrentDownloads, 1), 5)
        let availableSlots = max(maximum - activeIDs.count, 0)
        guard availableSlots > 0 else {
            return []
        }

        return entries
            .reversed()
            .filter { entry in
                queuedIDs.contains(entry.id)
                    && !activeIDs.contains(entry.id)
                    && (entry.phase == .waiting || entry.phase == .preparing)
            }
            .prefix(availableSlots)
            .map(\.id)
    }

    nonisolated static func cancellableIDs(
        entries: [HuggingFaceDownloadQueueEntry],
        requestedID: UUID? = nil
    ) -> Set<UUID> {
        Set(entries.compactMap { entry in
            if let requestedID, entry.id != requestedID {
                return nil
            }

            switch entry.phase {
            case .waiting, .preparing, .downloading, .finalizing:
                return entry.id
            case .completed, .failed, .cancelled:
                return nil
            }
        })
    }
}
