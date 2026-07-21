import Foundation

nonisolated enum RuntimeMemoryHeadroomLevel: String, Equatable {
    case normal
    case caution
    case critical
    case unavailable
}

nonisolated struct RuntimeMemoryHeadroomEnvironment: Equatable {
    let totalMemoryGigabytes: Double?
    let availableMemoryGigabytes: Double?
}

nonisolated struct RuntimeMemoryHeadroomAssessment: Equatable {
    let level: RuntimeMemoryHeadroomLevel
    let totalMemoryGigabytes: Double?
    let availableMemoryGigabytes: Double?
    let cautionThresholdGigabytes: Double?
    let criticalThresholdGigabytes: Double?

    var needsAttention: Bool {
        level == .caution || level == .critical
    }

    func title(language: AppLanguage) -> String {
        switch (language.resolved, level) {
        case (.english, .normal): "Runtime memory headroom is available"
        case (.english, .caution): "Runtime memory headroom is low"
        case (.english, .critical): "Runtime memory headroom is critical"
        case (.english, .unavailable): "Runtime memory headroom is unavailable"
        case (_, .normal): "実行時メモリに余裕があります"
        case (_, .caution): "実行時メモリの余力が少なくなっています"
        case (_, .critical): "実行時メモリの余力が危険域です"
        case (_, .unavailable): "実行時メモリの余力を取得できません"
        }
    }

    func detail(language: AppLanguage) -> String {
        guard let availableMemoryGigabytes,
              let cautionThresholdGigabytes,
              let criticalThresholdGigabytes else {
            return localized(
                language,
                english: "Available system memory could not be measured. The app will not stop a managed server automatically.",
                japanese: "システムの空きメモリを取得できません。管理サーバーを自動停止することはありません。"
            )
        }

        let available = Self.gigabytesText(availableMemoryGigabytes)
        switch level {
        case .normal:
            return localized(
                language,
                english: "Available memory is \(available), above the \(Self.gigabytesText(cautionThresholdGigabytes)) reserve target.",
                japanese: "空きメモリは\(available)で、確保目標の\(Self.gigabytesText(cautionThresholdGigabytes))を上回っています。"
            )
        case .caution:
            return localized(
                language,
                english: "Available memory is \(available). Unload an unused model or reduce its KV cache before starting another workload.",
                japanese: "空きメモリは\(available)です。別の処理を始める前に、未使用モデルを停止するかKVキャッシュを減らしてください。"
            )
        case .critical:
            return localized(
                language,
                english: "Available memory is \(available), below the \(Self.gigabytesText(criticalThresholdGigabytes)) emergency floor. Stop an unused managed model to reduce the risk of an out-of-memory termination.",
                japanese: "空きメモリは\(available)で、緊急目安の\(Self.gigabytesText(criticalThresholdGigabytes))を下回っています。メモリ不足による終了を避けるため、未使用の管理モデルを停止してください。"
            )
        case .unavailable:
            return localized(
                language,
                english: "Available system memory could not be measured. The app will not stop a managed server automatically.",
                japanese: "システムの空きメモリを取得できません。管理サーバーを自動停止することはありません。"
            )
        }
    }

    private func localized(_ language: AppLanguage, english: String, japanese: String) -> String {
        language.resolved == .english ? english : japanese
    }

    private static func gigabytesText(_ value: Double) -> String {
        String(format: "%.1f GB", value)
    }
}

nonisolated enum RuntimeMemoryProtectionLevel: String, Equatable, Sendable {
    case normal
    case caution
    case emergency
}

nonisolated struct RuntimeMemoryProtectionState: Equatable, Sendable {
    let level: RuntimeMemoryProtectionLevel
    let assessment: RuntimeMemoryHeadroomAssessment?

    var blocksManagedStart: Bool {
        level == .emergency
    }

    static let normal = RuntimeMemoryProtectionState(
        level: .normal,
        assessment: nil
    )
}

nonisolated struct RuntimeMemoryEmergencyGuard: Sendable {
    private let criticalSamplesRequired: Int
    private let recoverySamplesRequired: Int
    private(set) var state: RuntimeMemoryProtectionState = .normal
    private var consecutiveCriticalSamples = 0
    private var consecutiveRecoverySamples = 0

    init(
        criticalSamplesRequired: Int = 3,
        recoverySamplesRequired: Int = 3
    ) {
        self.criticalSamplesRequired = max(criticalSamplesRequired, 1)
        self.recoverySamplesRequired = max(recoverySamplesRequired, 1)
    }

    @discardableResult
    mutating func observe(
        _ assessment: RuntimeMemoryHeadroomAssessment
    ) -> RuntimeMemoryProtectionState {
        switch assessment.level {
        case .critical:
            consecutiveRecoverySamples = 0
            consecutiveCriticalSamples += 1
            if state.level == .emergency || consecutiveCriticalSamples >= criticalSamplesRequired {
                state = RuntimeMemoryProtectionState(
                    level: .emergency,
                    assessment: assessment
                )
            } else {
                state = RuntimeMemoryProtectionState(
                    level: .caution,
                    assessment: assessment
                )
            }
        case .caution:
            consecutiveCriticalSamples = 0
            consecutiveRecoverySamples = 0
            if state.level != .emergency {
                state = RuntimeMemoryProtectionState(
                    level: .caution,
                    assessment: assessment
                )
            }
        case .normal:
            consecutiveCriticalSamples = 0
            if state.level == .emergency {
                consecutiveRecoverySamples += 1
                if consecutiveRecoverySamples >= recoverySamplesRequired {
                    consecutiveRecoverySamples = 0
                    state = .normal
                }
            } else {
                consecutiveRecoverySamples = 0
                state = .normal
            }
        case .unavailable:
            consecutiveCriticalSamples = 0
            consecutiveRecoverySamples = 0
        }

        return state
    }
}

nonisolated enum RuntimeMemoryHeadroomAdvisor {
    static func assess(environment: RuntimeMemoryHeadroomEnvironment) -> RuntimeMemoryHeadroomAssessment {
        guard let totalMemoryGigabytes = environment.totalMemoryGigabytes,
              totalMemoryGigabytes > 0,
              let measuredAvailableMemoryGigabytes = environment.availableMemoryGigabytes else {
            return RuntimeMemoryHeadroomAssessment(
                level: .unavailable,
                totalMemoryGigabytes: environment.totalMemoryGigabytes,
                availableMemoryGigabytes: environment.availableMemoryGigabytes,
                cautionThresholdGigabytes: nil,
                criticalThresholdGigabytes: nil
            )
        }

        let availableMemoryGigabytes = min(max(measuredAvailableMemoryGigabytes, 0), totalMemoryGigabytes)
        let cautionThresholdGigabytes = max(totalMemoryGigabytes * 0.15, 6)
        let criticalThresholdGigabytes = max(totalMemoryGigabytes * 0.05, 2)

        let level: RuntimeMemoryHeadroomLevel
        if availableMemoryGigabytes < criticalThresholdGigabytes {
            level = .critical
        } else if availableMemoryGigabytes < cautionThresholdGigabytes {
            level = .caution
        } else {
            level = .normal
        }

        return RuntimeMemoryHeadroomAssessment(
            level: level,
            totalMemoryGigabytes: totalMemoryGigabytes,
            availableMemoryGigabytes: availableMemoryGigabytes,
            cautionThresholdGigabytes: cautionThresholdGigabytes,
            criticalThresholdGigabytes: criticalThresholdGigabytes
        )
    }
}
