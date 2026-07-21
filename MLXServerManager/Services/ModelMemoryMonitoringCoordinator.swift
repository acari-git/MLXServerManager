import Foundation

private actor ModelMemorySamplingWorker {
    private let memoryMonitor: MemoryMonitor

    init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
    }

    func sample(
        processIdentifier: Int32,
        modelEstimateGigabytes: Double?,
        modelEstimateSource: String?
    ) async -> MemoryBreakdownMonitorResult {
        await memoryMonitor.currentBreakdown(
            processIdentifier: processIdentifier,
            modelEstimateGigabytes: modelEstimateGigabytes,
            modelEstimateSource: modelEstimateSource
        )
    }
}

@MainActor
final class ModelMemoryMonitoringCoordinator {
    typealias MonitorOperation = @Sendable (
        _ processIdentifier: Int32,
        _ modelEstimateGigabytes: Double?,
        _ modelEstimateSource: String?
    ) async -> MemoryBreakdownMonitorResult
    typealias MonitorOperationFactory = @MainActor () -> MonitorOperation
    typealias ResultHandler = @MainActor (
        _ result: MemoryBreakdownMonitorResult,
        _ profileID: ModelConfig.ID,
        _ processIdentifier: Int32
    ) -> Bool
    typealias SleepOperation = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private struct ActiveMonitor: Sendable {
        let generation: UUID
        let task: Task<Void, Never>
    }

    private let intervalNanoseconds: UInt64
    private let makeMonitorOperation: MonitorOperationFactory
    private let sleepOperation: SleepOperation
    private var activeMonitors: [ModelConfig.ID: ActiveMonitor] = [:]

    init(
        memoryMonitor: MemoryMonitor = MemoryMonitor(),
        intervalNanoseconds: UInt64 = 1_000_000_000,
        monitorOperation: MonitorOperation? = nil,
        sleepOperation: SleepOperation? = nil
    ) {
        self.intervalNanoseconds = intervalNanoseconds
        if let monitorOperation {
            self.makeMonitorOperation = { monitorOperation }
        } else {
            self.makeMonitorOperation = {
                let worker = ModelMemorySamplingWorker(memoryMonitor: memoryMonitor)
                return { processIdentifier, modelEstimateGigabytes, modelEstimateSource in
                    await worker.sample(
                        processIdentifier: processIdentifier,
                        modelEstimateGigabytes: modelEstimateGigabytes,
                        modelEstimateSource: modelEstimateSource
                    )
                }
            }
        }
        self.sleepOperation = sleepOperation ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    deinit {
        for monitor in activeMonitors.values {
            monitor.task.cancel()
        }
    }

    var activeProfileIDs: Set<ModelConfig.ID> {
        Set(activeMonitors.keys)
    }

    func isMonitoring(profileID: ModelConfig.ID) -> Bool {
        activeMonitors[profileID] != nil
    }

    func start(
        profileID: ModelConfig.ID,
        processIdentifier: Int32,
        modelEstimateGigabytes: Double?,
        modelEstimateSource: String?,
        resultHandler: @escaping ResultHandler
    ) {
        stop(profileID: profileID)

        let generation = UUID()
        let intervalNanoseconds = self.intervalNanoseconds
        let monitorOperation = makeMonitorOperation()
        let sleepOperation = self.sleepOperation

        let task = Task { [weak self] in
            defer {
                self?.removeMonitor(profileID: profileID, generation: generation)
            }

            while !Task.isCancelled {
                let samplingTask = Task.detached(priority: .utility) {
                    await monitorOperation(
                        processIdentifier,
                        modelEstimateGigabytes,
                        modelEstimateSource
                    )
                }
                let result = await withTaskCancellationHandler {
                    await samplingTask.value
                } onCancel: {
                    samplingTask.cancel()
                }

                guard !Task.isCancelled else {
                    return
                }

                let shouldContinue = resultHandler(result, profileID, processIdentifier)

                guard shouldContinue, !Task.isCancelled else {
                    return
                }

                do {
                    try await sleepOperation(intervalNanoseconds)
                } catch {
                    return
                }
            }
        }

        activeMonitors[profileID] = ActiveMonitor(
            generation: generation,
            task: task
        )
    }

    func stop(profileID: ModelConfig.ID) {
        guard let monitor = activeMonitors.removeValue(forKey: profileID) else {
            return
        }
        monitor.task.cancel()
    }

    func stopAll() {
        let monitors = activeMonitors.values
        activeMonitors.removeAll()
        for monitor in monitors {
            monitor.task.cancel()
        }
    }

    private func removeMonitor(profileID: ModelConfig.ID, generation: UUID) {
        guard activeMonitors[profileID]?.generation == generation else {
            return
        }
        activeMonitors[profileID] = nil
    }
}
