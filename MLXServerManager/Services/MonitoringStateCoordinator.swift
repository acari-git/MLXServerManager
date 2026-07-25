import Foundation

nonisolated struct MonitoringSystemUsageUpdate: Equatable, Sendable {
    let state: MonitoringViewState
    let previousProtectionState: RuntimeMemoryProtectionState
    let nextProtectionState: RuntimeMemoryProtectionState

    var didChangeProtectionLevel: Bool {
        previousProtectionState.level != nextProtectionState.level
    }
}

nonisolated struct MonitoringStateCoordinator: Sendable {
    private(set) var state: MonitoringViewState
    private var runtimeMemoryEmergencyGuard: RuntimeMemoryEmergencyGuard

    init(
        criticalSamplesRequired: Int = 3,
        recoverySamplesRequired: Int = 3
    ) {
        self.state = .empty
        self.runtimeMemoryEmergencyGuard = RuntimeMemoryEmergencyGuard(
            criticalSamplesRequired: criticalSamplesRequired,
            recoverySamplesRequired: recoverySamplesRequired
        )
    }

    @discardableResult
    mutating func setModelMemory(
        _ snapshot: MemoryBreakdownSnapshot?,
        for modelID: ModelConfig.ID
    ) -> MonitoringViewState {
        state.setModelMemory(snapshot, for: modelID)
        return state
    }

    @discardableResult
    mutating func applySystemUsage(
        _ sample: SystemUsageMonitorSample,
        assessment: RuntimeMemoryHeadroomAssessment,
        timestamp: Date = Date()
    ) -> MonitoringSystemUsageUpdate {
        let previousProtectionState = runtimeMemoryEmergencyGuard.state
        let nextProtectionState = runtimeMemoryEmergencyGuard.observe(assessment)
        state.applySystemUsage(
            sample,
            protectionState: nextProtectionState,
            timestamp: timestamp
        )
        return MonitoringSystemUsageUpdate(
            state: state,
            previousProtectionState: previousProtectionState,
            nextProtectionState: nextProtectionState
        )
    }
}
