import Foundation

nonisolated struct HuggingFaceDownloadJob: Codable, Equatable {
    let id: UUID
    let reference: HuggingFaceModelReference
    let destinationPath: String
    let displayName: String
    let draft: HuggingFaceDownloadDraft
    let expectedFiles: [HuggingFaceDownloadPreviewFile]
    let expectedBytes: Int64?
    let includePatterns: [String]
    let excludePatterns: [String]

    func retrying(withID id: UUID) -> HuggingFaceDownloadJob {
        HuggingFaceDownloadJob(
            id: id,
            reference: reference,
            destinationPath: destinationPath,
            displayName: displayName,
            draft: draft,
            expectedFiles: expectedFiles,
            expectedBytes: expectedBytes,
            includePatterns: includePatterns,
            excludePatterns: excludePatterns
        )
    }
}

nonisolated enum HuggingFaceDownloadRetryKind: String, Codable, Equatable {
    case download
    case profileRegistration
}

nonisolated struct HuggingFaceDownloadRetryRecord: Codable, Equatable {
    let entry: HuggingFaceDownloadQueueEntry
    let job: HuggingFaceDownloadJob
    let kind: HuggingFaceDownloadRetryKind
}

nonisolated struct HuggingFaceDownloadRetrySnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let empty = HuggingFaceDownloadRetrySnapshot(records: [])

    let schemaVersion: Int
    let records: [HuggingFaceDownloadRetryRecord]

    init(records: [HuggingFaceDownloadRetryRecord]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.records = records
    }
}

struct HuggingFaceDownloadRetryStore {
    private struct Snapshot {
        let job: HuggingFaceDownloadJob
        let kind: HuggingFaceDownloadRetryKind
    }

    private var snapshotsByQueueEntryID: [UUID: Snapshot] = [:]

    mutating func record(
        _ job: HuggingFaceDownloadJob,
        kind: HuggingFaceDownloadRetryKind = .download
    ) {
        snapshotsByQueueEntryID[job.id] = Snapshot(job: job, kind: kind)
    }

    mutating func discard(queueEntryID: UUID) {
        snapshotsByQueueEntryID[queueEntryID] = nil
    }

    mutating func retain(queueEntryIDs: Set<UUID>) {
        snapshotsByQueueEntryID = snapshotsByQueueEntryID.filter { queueEntryIDs.contains($0.key) }
    }

    func retryKind(queueEntryID: UUID) -> HuggingFaceDownloadRetryKind? {
        snapshotsByQueueEntryID[queueEntryID]?.kind
    }

    func isRetryable(_ entry: HuggingFaceDownloadQueueEntry) -> Bool {
        (entry.phase == .failed || entry.phase == .cancelled)
            && snapshotsByQueueEntryID[entry.id] != nil
    }

    func latestRetryableEntry(
        in entries: [HuggingFaceDownloadQueueEntry]
    ) -> HuggingFaceDownloadQueueEntry? {
        entries.first(where: isRetryable)
    }

    func persistenceSnapshot(
        entries: [HuggingFaceDownloadQueueEntry]
    ) -> HuggingFaceDownloadRetrySnapshot {
        let records = entries.compactMap { entry -> HuggingFaceDownloadRetryRecord? in
            guard let snapshot = snapshotsByQueueEntryID[entry.id],
                  Self.shouldPersist(entry: entry, snapshot: snapshot) else {
                return nil
            }
            return HuggingFaceDownloadRetryRecord(
                entry: entry,
                job: snapshot.job,
                kind: snapshot.kind
            )
        }
        return HuggingFaceDownloadRetrySnapshot(records: records)
    }

    mutating func restore(
        from persistenceSnapshot: HuggingFaceDownloadRetrySnapshot
    ) -> [HuggingFaceDownloadQueueEntry] {
        snapshotsByQueueEntryID.removeAll(keepingCapacity: true)
        guard persistenceSnapshot.schemaVersion == HuggingFaceDownloadRetrySnapshot.currentSchemaVersion else {
            return []
        }

        var restoredEntries: [HuggingFaceDownloadQueueEntry] = []
        var restoredIDs: Set<UUID> = []
        for record in persistenceSnapshot.records {
            guard restoredIDs.insert(record.entry.id).inserted,
                  Self.isValid(record) else {
                continue
            }
            snapshotsByQueueEntryID[record.entry.id] = Snapshot(
                job: record.job,
                kind: record.kind
            )
            restoredEntries.append(Self.restoredEntry(from: record.entry))
        }
        return restoredEntries
    }

    mutating func consumeRetry(
        queueEntryID: UUID,
        newQueueEntryID: UUID
    ) -> HuggingFaceDownloadJob? {
        snapshotsByQueueEntryID.removeValue(forKey: queueEntryID)?
            .job
            .retrying(withID: newQueueEntryID)
    }

    nonisolated private static func isValid(_ record: HuggingFaceDownloadRetryRecord) -> Bool {
        guard record.entry.phase != .completed else {
            return false
        }
        guard record.entry.id == record.job.id
            && record.entry.repositoryID == record.job.reference.repositoryID
            && HuggingFaceDownloadPlanner.destinationsMatch(
                record.entry.destinationPath,
                record.job.destinationPath
            ) else {
            return false
        }

        return record.entry.phase.isTerminal || record.kind == .download
    }

    private static func shouldPersist(
        entry: HuggingFaceDownloadQueueEntry,
        snapshot: Snapshot
    ) -> Bool {
        guard entry.phase != .completed else {
            return false
        }
        return entry.phase.isTerminal || snapshot.kind == .download
    }

    nonisolated private static func restoredEntry(
        from entry: HuggingFaceDownloadQueueEntry
    ) -> HuggingFaceDownloadQueueEntry {
        guard !entry.phase.isTerminal else {
            return entry
        }

        var restored = entry
        restored.phase = .cancelled
        restored.message = "Download was interrupted in the previous session. Retry to continue from existing files."
        restored.speedBytesPerSecond = nil
        return restored
    }
}
