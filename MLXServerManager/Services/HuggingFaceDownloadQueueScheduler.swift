import Foundation

enum HuggingFaceDownloadQueueScheduler {
    nonisolated static func pruningTerminalHistory(
        entries: [HuggingFaceDownloadQueueEntry],
        maximumTerminalEntries: Int
    ) -> (entries: [HuggingFaceDownloadQueueEntry], removedIDs: Set<UUID>) {
        let maximum = max(maximumTerminalEntries, 0)
        var terminalCount = 0
        var retainedEntries: [HuggingFaceDownloadQueueEntry] = []
        var removedIDs: Set<UUID> = []

        for entry in entries {
            if entry.phase.isTerminal {
                terminalCount += 1
                if terminalCount > maximum {
                    removedIDs.insert(entry.id)
                    continue
                }
            }
            retainedEntries.append(entry)
        }

        return (retainedEntries, removedIDs)
    }

    nonisolated static func startableIDs(
        entries: [HuggingFaceDownloadQueueEntry],
        queuedIDs: Set<UUID>,
        activeIDs: Set<UUID>,
        activeDestinationPaths: Set<String> = [],
        maximumConcurrentDownloads: Int
    ) -> [UUID] {
        let maximum = min(max(maximumConcurrentDownloads, 1), 5)
        let availableSlots = max(maximum - activeIDs.count, 0)
        guard availableSlots > 0 else {
            return []
        }

        var reservedDestinationIdentities = Set(
            activeDestinationPaths.map { HuggingFaceDownloadPlanner.destinationIdentity(path: $0) }
        )
        var startableIDs: [UUID] = []

        for entry in entries.reversed() {
            guard startableIDs.count < availableSlots,
                  queuedIDs.contains(entry.id),
                  !activeIDs.contains(entry.id),
                  entry.phase == .waiting || entry.phase == .preparing,
                  reservedDestinationIdentities.insert(
                      HuggingFaceDownloadPlanner.destinationIdentity(path: entry.destinationPath)
                  ).inserted else {
                continue
            }
            startableIDs.append(entry.id)
        }

        return startableIDs
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
