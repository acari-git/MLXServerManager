import AppKit

extension AppViewModel {
    var operationalHistoryCategories: [String] {
        OperationalHistoryProjection.availableCategories(events: runtimeEvents)
    }

    var visibleOperationalHistoryEvents: [RuntimeEvent] {
        OperationalHistoryProjection.project(
            events: runtimeEvents,
            category: operationalHistoryCategoryFilter,
            severity: operationalHistorySeverityFilter
        )
    }

    func appendRuntimeEvent(
        category: String,
        severity: RuntimeEventSeverity = .info,
        message: String,
        japaneseMessage: String? = nil,
        modelID: String? = nil,
        endpoint: String? = nil
    ) {
        runtimeEvents.insert(
            RuntimeEvent(
                category: category,
                severity: severity,
                message: message,
                japaneseMessage: japaneseMessage,
                modelID: modelID,
                endpoint: endpoint
            ),
            at: 0
        )
        if runtimeEvents.count > Self.maximumRuntimeEventHistory {
            runtimeEvents.removeLast(runtimeEvents.count - Self.maximumRuntimeEventHistory)
        }
        if !operationalHistoryCategories.contains(operationalHistoryCategoryFilter) {
            operationalHistoryCategoryFilter = OperationalHistoryProjection.allCategories
        }
    }

    func clearOperationalHistoryRequested() {
        runtimeEvents.removeAll(keepingCapacity: true)
        operationalHistoryCategoryFilter = OperationalHistoryProjection.allCategories
        operationalHistorySeverityFilter = .all
    }

    func copyOperationalHistoryRequested() {
        _ = copyToPasteboard(
            OperationalHistoryProjection.copyText(
                events: visibleOperationalHistoryEvents,
                language: settings.uiLanguage
            )
        )
    }

    func appendLog(_ line: String) {
        appendLogs([line])
    }

    func appendLogs(_ lines: [String]) {
        guard !lines.isEmpty else {
            return
        }
        logViewState = logStateCoordinator.append(contentsOf: lines)
    }

    func diagnosticsSummaryCopyText() -> String {
        var lines = [
            "MLX Server Manager Diagnostics Summary",
            diagnosticsSummaryText,
            "",
            "Checks:"
        ]

        lines.append(
            contentsOf: diagnosticsResults.map { result in
                var line = "- [\(result.status.rawValue)] \(result.check.title): \(result.message)"

                if let detail = result.detail, !detail.isEmpty {
                    line += " (\(detail))"
                }

                return line
            }
        )

        return lines.joined(separator: "\n")
    }

    @discardableResult
    func copyToPasteboard(_ value: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
    }
}
