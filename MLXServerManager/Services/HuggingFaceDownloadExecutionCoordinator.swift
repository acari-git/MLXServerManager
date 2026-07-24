import Foundation

nonisolated struct HuggingFaceDownloadExecutionProgress: Equatable, Sendable {
    let downloadedBytes: Int64
    let downloadedFileCount: Int
    let totalBytes: Int64?
    let speedBytesPerSecond: Int64
}

@MainActor
final class HuggingFaceDownloadExecutionCoordinator {
    enum Outcome {
        case succeeded(HuggingFaceDownloadResult)
        case failed(Error)
    }

    struct Completion {
        let outcome: Outcome
        let cancellationRequested: Bool
    }

    typealias OutputHandler = @MainActor (_ line: String) -> Void
    typealias ProgressHandler = @MainActor (_ progress: HuggingFaceDownloadExecutionProgress) -> Void
    typealias CompletionHandler = @MainActor (_ completion: Completion) -> Void
    typealias ProgressSnapshotOperation = @Sendable (
        _ destinationPath: String,
        _ expectedFiles: [HuggingFaceDownloadPreviewFile]
    ) async -> HuggingFaceDownloadProgressSnapshot
    typealias SleepOperation = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private struct ActiveDownload {
        let generation: UUID
        let destinationPath: String
        let destinationIdentity: String
        let manager: HuggingFaceModelDownloading
        let executionTask: Task<Void, Never>
        let progressTask: Task<Void, Never>
        var cancellationRequested: Bool
    }

    private let progressIntervalNanoseconds: UInt64
    private let progressSnapshotOperation: ProgressSnapshotOperation
    private let sleepOperation: SleepOperation
    private var activeDownloads: [UUID: ActiveDownload] = [:]

    init(
        progressIntervalNanoseconds: UInt64 = 700_000_000,
        progressSnapshotOperation: ProgressSnapshotOperation? = nil,
        sleepOperation: SleepOperation? = nil
    ) {
        self.progressIntervalNanoseconds = progressIntervalNanoseconds
        self.progressSnapshotOperation = progressSnapshotOperation ?? { destinationPath, expectedFiles in
            await Task.detached(priority: .utility) {
                HuggingFaceDownloadProgressMeasurer.snapshot(
                    destinationPath: destinationPath,
                    expectedFiles: expectedFiles
                )
            }.value
        }
        self.sleepOperation = sleepOperation ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    var activeIDs: Set<UUID> {
        Set(activeDownloads.keys)
    }

    var activeCount: Int {
        activeDownloads.count
    }

    var activeDestinationPaths: Set<String> {
        Set(activeDownloads.values.map(\.destinationPath))
    }

    var isRunning: Bool {
        !activeDownloads.isEmpty
    }

    func isActive(_ id: UUID) -> Bool {
        activeDownloads[id] != nil
    }

    func isDestinationActive(_ destinationPath: String) -> Bool {
        let destinationIdentity = HuggingFaceDownloadPlanner.destinationIdentity(path: destinationPath)
        return activeDownloads.values.contains { $0.destinationIdentity == destinationIdentity }
    }

    @discardableResult
    func start(
        id: UUID,
        manager: HuggingFaceModelDownloading,
        request: HuggingFaceDownloadRequest,
        expectedFiles: [HuggingFaceDownloadPreviewFile],
        totalBytes: Int64?,
        outputHandler: @escaping OutputHandler,
        progressHandler: @escaping ProgressHandler,
        completionHandler: @escaping CompletionHandler
    ) -> Bool {
        let destinationIdentity = HuggingFaceDownloadPlanner.destinationIdentity(path: request.destinationPath)
        guard activeDownloads[id] == nil,
              !activeDownloads.values.contains(where: { $0.destinationIdentity == destinationIdentity }) else {
            return false
        }

        let generation = UUID()
        let destinationPath = request.destinationPath
        let progressIntervalNanoseconds = self.progressIntervalNanoseconds
        let progressSnapshotOperation = self.progressSnapshotOperation
        let sleepOperation = self.sleepOperation
        let (outputStream, outputContinuation) = AsyncStream.makeStream(of: String.self)
        let outputDeliveryTask = Task {
            for await line in outputStream {
                outputHandler(line)
            }
        }

        let progressTask = Task { [weak self] in
            var lastBytes: Int64 = 0
            var lastDate = Date()

            while !Task.isCancelled {
                let snapshot = await progressSnapshotOperation(destinationPath, expectedFiles)
                guard let self,
                      !Task.isCancelled,
                      self.isCurrent(id: id, generation: generation) else {
                    return
                }

                let downloadedBytes = snapshot.downloadedBytes
                let now = Date()
                let elapsed = max(now.timeIntervalSince(lastDate), 0.001)
                let byteDelta = max(downloadedBytes - lastBytes, 0)
                let speed = Int64(Double(byteDelta) / elapsed)
                lastBytes = downloadedBytes
                lastDate = now

                progressHandler(
                    HuggingFaceDownloadExecutionProgress(
                        downloadedBytes: downloadedBytes,
                        downloadedFileCount: snapshot.completedFileCount,
                        totalBytes: totalBytes,
                        speedBytesPerSecond: speed
                    )
                )

                do {
                    try await sleepOperation(progressIntervalNanoseconds)
                } catch {
                    return
                }
            }
        }

        let executionTask = Task { [weak self] in
            let outcome: Outcome
            if Task.isCancelled {
                outcome = .failed(CancellationError())
            } else {
                do {
                    let result = try await manager.download(
                        request: request,
                        outputHandler: { line in
                            outputContinuation.yield(line)
                        }
                    )
                    outcome = .succeeded(result)
                } catch {
                    outcome = .failed(error)
                }
            }

            outputContinuation.finish()
            await outputDeliveryTask.value
            self?.complete(
                id: id,
                generation: generation,
                outcome: outcome,
                completionHandler: completionHandler
            )
        }

        activeDownloads[id] = ActiveDownload(
            generation: generation,
            destinationPath: request.destinationPath,
            destinationIdentity: destinationIdentity,
            manager: manager,
            executionTask: executionTask,
            progressTask: progressTask,
            cancellationRequested: false
        )
        return true
    }

    @discardableResult
    func cancel(_ id: UUID) -> Bool {
        guard var activeDownload = activeDownloads[id],
              !activeDownload.cancellationRequested else {
            return false
        }

        activeDownload.cancellationRequested = true
        activeDownloads[id] = activeDownload
        activeDownload.progressTask.cancel()
        activeDownload.executionTask.cancel()
        activeDownload.manager.cancel()
        return true
    }

    func cancelAll() {
        for id in activeDownloads.keys {
            cancel(id)
        }
    }

    private func isCurrent(id: UUID, generation: UUID) -> Bool {
        activeDownloads[id]?.generation == generation
    }

    private func complete(
        id: UUID,
        generation: UUID,
        outcome: Outcome,
        completionHandler: CompletionHandler
    ) {
        guard let activeDownload = activeDownloads[id],
              activeDownload.generation == generation else {
            return
        }

        activeDownloads[id] = nil
        activeDownload.progressTask.cancel()
        completionHandler(
            Completion(
                outcome: outcome,
                cancellationRequested: activeDownload.cancellationRequested
            )
        )
    }
}
