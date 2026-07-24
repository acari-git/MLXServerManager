import Foundation

nonisolated struct MemoryHistorySample: Equatable, Sendable {
    let usedFraction: Double
    let managedProcessFraction: Double
    let timestamp: Date
}

nonisolated struct SystemUsageHistorySample: Equatable, Sendable {
    let cpuFraction: Double
    let gpuFraction: Double?
    let timestamp: Date
}

nonisolated struct MonitoringViewState: Equatable, Sendable {
    private(set) var memoryUsageGB: Double?
    private(set) var memoryUsageByModelID: [ModelConfig.ID: Double]
    private(set) var memoryBreakdown: MemoryBreakdownSnapshot?
    private(set) var memoryBreakdownByModelID: [ModelConfig.ID: MemoryBreakdownSnapshot]
    private(set) var systemMemorySnapshot: SystemMemorySnapshot?
    private(set) var runtimeMemoryProtectionState: RuntimeMemoryProtectionState
    private(set) var memoryHistory: [MemoryHistorySample]
    private(set) var cpuUsagePercent: Double?
    private(set) var gpuUsagePercent: Double?
    private(set) var systemUsageHistory: [SystemUsageHistorySample]

    static let empty = MonitoringViewState(
        memoryUsageGB: nil,
        memoryUsageByModelID: [:],
        memoryBreakdown: nil,
        memoryBreakdownByModelID: [:],
        systemMemorySnapshot: nil,
        runtimeMemoryProtectionState: .normal,
        memoryHistory: [],
        cpuUsagePercent: nil,
        gpuUsagePercent: nil,
        systemUsageHistory: []
    )

    mutating func setModelMemory(
        _ snapshot: MemoryBreakdownSnapshot?,
        for modelID: ModelConfig.ID
    ) {
        if let snapshot {
            memoryUsageByModelID[modelID] = snapshot.managedProcessGigabytes
            memoryBreakdownByModelID[modelID] = snapshot
        } else {
            memoryUsageByModelID.removeValue(forKey: modelID)
            memoryBreakdownByModelID.removeValue(forKey: modelID)
        }
        refreshAggregateMemoryProjection()
    }

    mutating func applySystemUsage(
        _ sample: SystemUsageMonitorSample,
        protectionState: RuntimeMemoryProtectionState,
        timestamp: Date = Date()
    ) {
        cpuUsagePercent = sample.cpuPercent
        gpuUsagePercent = sample.gpuPercent
        systemMemorySnapshot = sample.systemMemorySnapshot
        runtimeMemoryProtectionState = protectionState

        if let usedGigabytes = sample.systemMemorySnapshot.usedGigabytes,
           sample.systemMemorySnapshot.totalGigabytes > 0 {
            memoryHistory.append(
                MemoryHistorySample(
                    usedFraction: min(
                        max(usedGigabytes / sample.systemMemorySnapshot.totalGigabytes, 0),
                        1
                    ),
                    managedProcessFraction: min(
                        max((memoryUsageGB ?? 0) / sample.systemMemorySnapshot.totalGigabytes, 0),
                        1
                    ),
                    timestamp: timestamp
                )
            )
            if memoryHistory.count > 60 {
                memoryHistory.removeFirst(memoryHistory.count - 60)
            }
        }

        systemUsageHistory.append(
            SystemUsageHistorySample(
                cpuFraction: min(max((sample.cpuPercent ?? 0) / 100, 0), 1),
                gpuFraction: sample.gpuPercent.map { min(max($0 / 100, 0), 1) },
                timestamp: timestamp
            )
        )
        if systemUsageHistory.count > 60 {
            systemUsageHistory.removeFirst(systemUsageHistory.count - 60)
        }
    }

    private mutating func refreshAggregateMemoryProjection() {
        memoryUsageGB = memoryUsageByModelID.isEmpty
            ? nil
            : memoryUsageByModelID.values.reduce(0, +)

        let snapshots = Array(memoryBreakdownByModelID.values)
        guard !snapshots.isEmpty else {
            memoryBreakdown = nil
            return
        }
        if snapshots.count == 1 {
            memoryBreakdown = snapshots[0]
            return
        }

        guard let latestSnapshot = snapshots.max(by: { $0.updatedAt < $1.updatedAt }) else {
            memoryBreakdown = nil
            return
        }
        let modelEstimates = snapshots.compactMap(\.modelEstimateGigabytes)
        memoryBreakdown = MemoryBreakdownSnapshot(
            processIdentifier: 0,
            rssKilobytes: snapshots.reduce(Int64(0)) { $0 + $1.rssKilobytes },
            system: latestSnapshot.system,
            modelEstimateGigabytes: modelEstimates.count == snapshots.count
                ? modelEstimates.reduce(0, +)
                : nil,
            modelEstimateSource: modelEstimates.count == snapshots.count
                ? "\(snapshots.count) managed model(s)"
                : nil,
            updatedAt: latestSnapshot.updatedAt
        )
    }
}
