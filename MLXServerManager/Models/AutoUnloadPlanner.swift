import Foundation

nonisolated struct AutoUnloadCandidate: Equatable, Sendable {
    let modelID: String
    let startedAt: Date
    let limitMinutes: Int
    let isEnabled: Bool
    let isTransitioning: Bool
}

nonisolated enum AutoUnloadPlanner {
    static func expiredModelIDs(
        from candidates: [AutoUnloadCandidate],
        now: Date
    ) -> [String] {
        candidates
            .filter { candidate in
                guard candidate.isEnabled, !candidate.isTransitioning else {
                    return false
                }

                let limitSeconds = TimeInterval(max(candidate.limitMinutes, 1) * 60)
                return now.timeIntervalSince(candidate.startedAt) >= limitSeconds
            }
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt {
                    return lhs.modelID < rhs.modelID
                }
                return lhs.startedAt < rhs.startedAt
            }
            .map(\.modelID)
    }
}
