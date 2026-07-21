import Foundation

struct SystemUsageMonitorSample: Equatable, Sendable {
    let cpuPercent: Double?
    let gpuPercent: Double?
    let systemMemorySnapshot: SystemMemorySnapshot
}

private actor SystemUsageSamplingWorker {
    private let memoryMonitor: MemoryMonitor
    private var cpuUsageSampler = CPUUsageSampler()

    init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
    }

    func sample() -> SystemUsageMonitorSample {
        SystemUsageMonitorSample(
            cpuPercent: cpuUsageSampler.samplePercent(),
            gpuPercent: nil,
            systemMemorySnapshot: memoryMonitor.currentSystemSnapshot()
        )
    }
}

@MainActor
final class SystemUsageMonitoringCoordinator {
    typealias SampleOperation = @Sendable () async -> SystemUsageMonitorSample
    typealias SampleOperationFactory = @MainActor () -> SampleOperation
    typealias ResultHandler = @MainActor (_ sample: SystemUsageMonitorSample) -> Bool
    typealias SleepOperation = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private struct ActiveMonitor: Sendable {
        let generation: UUID
        let task: Task<Void, Never>
    }

    private let intervalNanoseconds: UInt64
    private let makeSampleOperation: SampleOperationFactory
    private let sleepOperation: SleepOperation
    private var activeMonitor: ActiveMonitor?

    init(
        memoryMonitor: MemoryMonitor = MemoryMonitor(),
        intervalNanoseconds: UInt64 = 1_000_000_000,
        sampleOperation: SampleOperation? = nil,
        sleepOperation: SleepOperation? = nil
    ) {
        self.intervalNanoseconds = intervalNanoseconds
        if let sampleOperation {
            self.makeSampleOperation = { sampleOperation }
        } else {
            self.makeSampleOperation = {
                let worker = SystemUsageSamplingWorker(memoryMonitor: memoryMonitor)
                return { await worker.sample() }
            }
        }
        self.sleepOperation = sleepOperation ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    deinit {
        activeMonitor?.task.cancel()
    }

    var isMonitoring: Bool {
        activeMonitor != nil
    }

    func start(resultHandler: @escaping ResultHandler) {
        stop()

        let generation = UUID()
        let intervalNanoseconds = self.intervalNanoseconds
        let sampleOperation = makeSampleOperation()
        let sleepOperation = self.sleepOperation

        let task = Task { [weak self] in
            defer {
                self?.removeMonitor(generation: generation)
            }

            while !Task.isCancelled {
                let sample = await sampleOperation()

                guard !Task.isCancelled else {
                    return
                }

                let shouldContinue = resultHandler(sample)

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

        activeMonitor = ActiveMonitor(
            generation: generation,
            task: task
        )
    }

    func stop() {
        guard let monitor = activeMonitor else {
            return
        }
        activeMonitor = nil
        monitor.task.cancel()
    }

    private func removeMonitor(generation: UUID) {
        guard activeMonitor?.generation == generation else {
            return
        }
        activeMonitor = nil
    }
}
