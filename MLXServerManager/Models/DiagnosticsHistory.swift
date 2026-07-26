import Foundation

nonisolated struct DiagnosticsSnapshotItem: Codable, Equatable {
    let checkRawValue: String
    let statusRawValue: String
    let message: String
    let detail: String?

    init(result: DiagnosticsResult) {
        checkRawValue = result.check.rawValue
        statusRawValue = result.status.rawValue
        message = result.message
        detail = result.detail
    }
}

nonisolated struct DiagnosticsSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let targetKey: String
    let targetName: String
    let createdAt: Date
    let items: [DiagnosticsSnapshotItem]

    init(targetKey: String, targetName: String, createdAt: Date = Date(), results: [DiagnosticsResult]) {
        id = UUID()
        self.targetKey = targetKey
        self.targetName = targetName
        self.createdAt = createdAt
        items = results.map(DiagnosticsSnapshotItem.init)
    }
}

nonisolated enum DiagnosticsTrend: String, Equatable {
    case initial
    case improved
    case worsened
    case unchanged
}

nonisolated struct DiagnosticsComparisonRow: Identifiable, Equatable {
    let checkRawValue: String
    let previousStatusRawValue: String?
    let currentStatusRawValue: String?
    let previousMessage: String?
    let currentMessage: String?

    var id: String { checkRawValue }
}

nonisolated struct DiagnosticsComparison: Equatable {
    let trend: DiagnosticsTrend
    let improvedCount: Int
    let worsenedCount: Int
    let unchangedCount: Int

    static func compare(current: DiagnosticsSnapshot, previous: DiagnosticsSnapshot?) -> DiagnosticsComparison {
        guard let previous else {
            return DiagnosticsComparison(trend: .initial, improvedCount: 0, worsenedCount: 0, unchangedCount: current.items.count)
        }
        let previousByCheck = Dictionary(uniqueKeysWithValues: previous.items.map { ($0.checkRawValue, $0.statusRawValue) })
        var improved = 0
        var worsened = 0
        var unchanged = 0
        for item in current.items {
            guard let old = previousByCheck[item.checkRawValue] else {
                unchanged += 1
                continue
            }
            let oldRank = rank(old)
            let newRank = rank(item.statusRawValue)
            if newRank < oldRank { improved += 1 }
            else if newRank > oldRank { worsened += 1 }
            else { unchanged += 1 }
        }
        let trend: DiagnosticsTrend
        if worsened > 0 { trend = .worsened }
        else if improved > 0 { trend = .improved }
        else { trend = .unchanged }
        return DiagnosticsComparison(trend: trend, improvedCount: improved, worsenedCount: worsened, unchangedCount: unchanged)
    }

    static func rows(current: DiagnosticsSnapshot, previous: DiagnosticsSnapshot) -> [DiagnosticsComparisonRow] {
        let currentByCheck = Dictionary(uniqueKeysWithValues: current.items.map { ($0.checkRawValue, $0) })
        let previousByCheck = Dictionary(uniqueKeysWithValues: previous.items.map { ($0.checkRawValue, $0) })
        let keys = Set(currentByCheck.keys).union(previousByCheck.keys)
        return keys.sorted().map { key in
            let currentItem = currentByCheck[key]
            let previousItem = previousByCheck[key]
            return DiagnosticsComparisonRow(
                checkRawValue: key,
                previousStatusRawValue: previousItem?.statusRawValue,
                currentStatusRawValue: currentItem?.statusRawValue,
                previousMessage: previousItem?.message,
                currentMessage: currentItem?.message
            )
        }
    }

    private static func rank(_ rawValue: String) -> Int {
        switch rawValue {
        case DiagnosticsStatus.pass.rawValue: 0
        case DiagnosticsStatus.warning.rawValue: 1
        case DiagnosticsStatus.fail.rawValue: 2
        default: 1
        }
    }
}

nonisolated enum DiagnosticsHistoryStore {
    static let defaultsKey = "diagnostics-history-v1"
    static let maximumPerTarget = 12

    static func load(defaults: UserDefaults = .standard) -> [DiagnosticsSnapshot] {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode([DiagnosticsSnapshot].self, from: data) else { return [] }
        return value.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    static func record(_ snapshot: DiagnosticsSnapshot, history: [DiagnosticsSnapshot], defaults: UserDefaults = .standard) -> [DiagnosticsSnapshot] {
        var next = history
        next.insert(snapshot, at: 0)
        var counts: [String: Int] = [:]
        next = next.filter { item in
            let count = counts[item.targetKey, default: 0]
            guard count < maximumPerTarget else { return false }
            counts[item.targetKey] = count + 1
            return true
        }
        if let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: defaultsKey)
        }
        return next
    }

    static func snapshots(for targetKey: String, in history: [DiagnosticsSnapshot]) -> [DiagnosticsSnapshot] {
        history.filter { $0.targetKey == targetKey }.sorted { $0.createdAt > $1.createdAt }
    }

    static func removeSnapshots(for targetKey: String, history: [DiagnosticsSnapshot], defaults: UserDefaults = .standard) -> [DiagnosticsSnapshot] {
        let next = history.filter { $0.targetKey != targetKey }
        if let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: defaultsKey)
        }
        return next
    }
}

nonisolated enum DiagnosticsReportBuilder {
    static func markdown(current: DiagnosticsSnapshot, previous: DiagnosticsSnapshot?) -> String {
        let comparison = DiagnosticsComparison.compare(current: current, previous: previous)
        var lines = [
            "# Diagnostics Report",
            "",
            "- Target: \(current.targetName)",
            "- Date: \(ISO8601DateFormatter().string(from: current.createdAt))",
            "- Trend: \(comparison.trend.rawValue)",
            "- Improved: \(comparison.improvedCount)",
            "- Worsened: \(comparison.worsenedCount)",
            "",
            "## Results",
            "",
            "| Check | Status | Message | Detail |",
            "|---|---|---|---|"
        ]
        for item in current.items {
            let message = item.message.replacingOccurrences(of: "|", with: "\\|")
            let detail = (item.detail ?? "").replacingOccurrences(of: "|", with: "\\|")
            lines.append("| \(item.checkRawValue) | \(item.statusRawValue) | \(message) | \(detail) |")
        }
        if let previous {
            lines += ["", "## Comparison", "", "Previous run: \(ISO8601DateFormatter().string(from: previous.createdAt))"]
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
