import Foundation

nonisolated struct HuggingFaceDownloadViewState: Equatable, Sendable {
    private(set) var status: HuggingFaceDownloadStatus
    private(set) var entries: [HuggingFaceDownloadQueueEntry]

    static let waiting = HuggingFaceDownloadViewState(
        status: .waiting,
        entries: []
    )

    mutating func setStatus(_ status: HuggingFaceDownloadStatus) {
        self.status = status
    }

    mutating func insert(_ entry: HuggingFaceDownloadQueueEntry, at index: Int = 0) {
        entries.insert(entry, at: min(max(index, 0), entries.count))
    }

    mutating func replaceEntries(_ entries: [HuggingFaceDownloadQueueEntry]) {
        self.entries = entries
    }

    @discardableResult
    mutating func updateEntry(
        id: UUID,
        phase: HuggingFaceDownloadPhase,
        message: String,
        progress: Double? = nil
    ) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return false
        }

        entries[index].phase = phase
        entries[index].message = message
        if let progress,
           let totalBytes = entries[index].totalBytes,
           totalBytes > 0 {
            let clampedProgress = min(max(progress, 0), 1)
            entries[index].downloadedBytes = Int64(clampedProgress * Double(totalBytes))
        }
        return true
    }

    @discardableResult
    mutating func updateMeasuredProgress(
        queueEntryID: UUID,
        downloadedBytes: Int64,
        downloadedFileCount: Int,
        totalBytes: Int64?,
        speedBytesPerSecond: Int64?,
        language: AppLanguage = .english
    ) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == queueEntryID }),
              !entries[index].phase.isTerminal else {
            return false
        }

        let safeDownloadedBytes = max(downloadedBytes, 0)
        entries[index].phase = .downloading
        entries[index].downloadedFileCount = min(
            max(downloadedFileCount, 0),
            entries[index].fileCount ?? max(downloadedFileCount, 0)
        )
        entries[index].speedBytesPerSecond = speedBytesPerSecond

        if let totalBytes, totalBytes > 0 {
            let clampedDownloadedBytes = min(safeDownloadedBytes, totalBytes)
            let progress = min(max(Double(clampedDownloadedBytes) / Double(totalBytes), 0), 1)
            entries[index].message = AppLocalization(language: language).text(
                english: "Downloading... \(Int(progress * 100))%",
                japanese: "ダウンロード中... \(Int(progress * 100))%"
            )
            entries[index].downloadedBytes = clampedDownloadedBytes
            entries[index].totalBytes = totalBytes
        } else {
            let downloadedText = ByteCountFormatter.string(
                fromByteCount: safeDownloadedBytes,
                countStyle: .file
            )
            entries[index].message = AppLocalization(language: language).text(
                english: "Downloading... \(downloadedText)",
                japanese: "ダウンロード中... \(downloadedText)"
            )
            entries[index].downloadedBytes = safeDownloadedBytes
        }
        return true
    }

    @discardableResult
    mutating func refreshAggregateStatus(
        primaryID: UUID?,
        outputLinesByID: [UUID: [String]]
    ) -> UUID? {
        let primaryEntry = primaryID.flatMap { id in
            entries.first(where: { $0.id == id && !$0.phase.isTerminal })
        }
        let fallbackEntry = entries.first(where: { !$0.phase.isTerminal })
            ?? entries.first

        guard let entry = primaryEntry ?? fallbackEntry else {
            return nil
        }

        status = HuggingFaceDownloadStatus(
            phase: entry.phase,
            message: entry.message,
            repositoryID: entry.repositoryID,
            destinationPath: entry.destinationPath,
            progress: entry.progressFraction,
            outputLines: outputLinesByID[entry.id] ?? []
        )
        return entry.id
    }
}
