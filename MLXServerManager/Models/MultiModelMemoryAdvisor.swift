import Foundation

nonisolated enum MultiModelMemoryRiskLevel: String, Equatable {
    case safe
    case caution
    case critical
    case unavailable
}

nonisolated struct MultiModelMemoryEnvironment: Equatable {
    let totalMemoryGigabytes: Double
    let availableMemoryGigabytes: Double?
    let managedMemoryGigabytes: Double
    let runningModelCount: Int
    let candidateModelGigabytes: Double?
    let candidateCacheBytes: UInt64?
}

nonisolated struct MultiModelMemoryAssessment: Equatable {
    let level: MultiModelMemoryRiskLevel
    let runningModelCount: Int
    let currentManagedMemoryGigabytes: Double
    let candidateFootprintGigabytes: Double?
    let projectedManagedMemoryGigabytes: Double?
    let projectedAvailableMemoryGigabytes: Double?
    let reservedSystemMemoryGigabytes: Double

    var requiresConfirmation: Bool {
        level == .critical
    }

    func title(language: AppLanguage) -> String {
        switch (language.resolved, level) {
        case (.english, .safe): "Memory capacity is available"
        case (.english, .caution): "Memory headroom will be limited"
        case (.english, .critical): "Memory pressure is likely"
        case (.english, .unavailable): "Memory capacity could not be estimated"
        case (_, .safe): "メモリ容量に余裕があります"
        case (_, .caution): "メモリ余力が少なくなります"
        case (_, .critical): "メモリ圧迫が予想されます"
        case (_, .unavailable): "メモリ容量を推定できません"
        }
    }

    func detail(language: AppLanguage) -> String {
        guard let candidateFootprintGigabytes,
              let projectedAvailableMemoryGigabytes,
              let projectedManagedMemoryGigabytes else {
            return localized(
                language,
                english: "The model size or current available memory is unknown. The app will not block an explicit start, but memory pressure cannot be predicted.",
                japanese: "モデル容量または現在の空きメモリを取得できません。明示的な起動は妨げませんが、メモリ圧迫を予測できません。"
            )
        }

        let candidate = Self.gigabytesText(candidateFootprintGigabytes)
        let projectedAvailable = Self.gigabytesText(max(projectedAvailableMemoryGigabytes, 0))
        let projectedManaged = Self.gigabytesText(projectedManagedMemoryGigabytes)
        let reserve = Self.gigabytesText(reservedSystemMemoryGigabytes)

        return localized(
            language,
            english: "Estimated new process: \(candidate). Managed total after start: \(projectedManaged). Projected available memory: \(projectedAvailable), with \(reserve) reserved for macOS and other apps.",
            japanese: "新規プロセスの推定: \(candidate)。起動後の管理対象合計: \(projectedManaged)。起動後の空きメモリ推定: \(projectedAvailable)、macOSと他のアプリ用の確保目標: \(reserve)。"
        )
    }

    private func localized(_ language: AppLanguage, english: String, japanese: String) -> String {
        language.resolved == .english ? english : japanese
    }

    private static func gigabytesText(_ value: Double) -> String {
        String(format: "%.1f GB", value)
    }
}

nonisolated enum MultiModelMemoryAdvisor {
    static func assess(environment: MultiModelMemoryEnvironment) -> MultiModelMemoryAssessment {
        let totalMemory = max(environment.totalMemoryGigabytes, 1)
        let managedMemory = max(environment.managedMemoryGigabytes, 0)
        let reserve = max(totalMemory * 0.15, 6)

        guard let availableMemory = environment.availableMemoryGigabytes,
              let modelMemory = environment.candidateModelGigabytes,
              availableMemory >= 0,
              modelMemory > 0 else {
            return MultiModelMemoryAssessment(
                level: .unavailable,
                runningModelCount: max(environment.runningModelCount, 0),
                currentManagedMemoryGigabytes: managedMemory,
                candidateFootprintGigabytes: nil,
                projectedManagedMemoryGigabytes: nil,
                projectedAvailableMemoryGigabytes: nil,
                reservedSystemMemoryGigabytes: reserve
            )
        }

        let cacheGigabytes = environment.candidateCacheBytes.map {
            Double($0) / 1_073_741_824
        } ?? 0
        let runtimeOverhead = max(modelMemory * 0.10, 1)
        let candidateFootprint = modelMemory + runtimeOverhead + cacheGigabytes
        let projectedAvailable = availableMemory - candidateFootprint
        let projectedManaged = managedMemory + candidateFootprint
        let emergencyFloor = max(totalMemory * 0.05, 2)

        let level: MultiModelMemoryRiskLevel
        if projectedAvailable < emergencyFloor {
            level = .critical
        } else if projectedAvailable < reserve {
            level = .caution
        } else {
            level = .safe
        }

        return MultiModelMemoryAssessment(
            level: level,
            runningModelCount: max(environment.runningModelCount, 0),
            currentManagedMemoryGigabytes: managedMemory,
            candidateFootprintGigabytes: candidateFootprint,
            projectedManagedMemoryGigabytes: projectedManaged,
            projectedAvailableMemoryGigabytes: projectedAvailable,
            reservedSystemMemoryGigabytes: reserve
        )
    }
}
