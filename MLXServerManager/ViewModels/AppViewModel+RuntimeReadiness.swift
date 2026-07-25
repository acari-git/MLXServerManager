import Foundation

extension AppViewModel {
    var runtimeReadinessReports: [RuntimeReadinessReport] {
        runtimeReadinessViewState.reports
    }

    var isRuntimeReadinessChecking: Bool {
        runtimeReadinessViewState.isChecking
    }

    func refreshRuntimeReadinessRequested(settings assessmentSettings: AppSettings? = nil) {
        let settingsToAssess = assessmentSettings ?? settings
        runtimeReadinessRunCoordinator.start { [weak self] generation in
            guard let self else { return }

            var checkingState = self.runtimeReadinessViewState
            checkingState.begin(settings: settingsToAssess)
            self.runtimeReadinessViewState = checkingState
            self.appendRuntimeEvent(
                category: "Runtime",
                message: "Runtime readiness check started.",
                japaneseMessage: "ランタイム準備状態の確認を開始しました。"
            )

            let reports = await self.runtimeReadinessService.assess(settings: settingsToAssess)
            guard self.runtimeReadinessRunCoordinator.isCurrent(generation: generation) else {
                return
            }

            var completedState = self.runtimeReadinessViewState
            completedState.complete(reports)
            self.runtimeReadinessViewState = completedState

            let readyCount = reports.filter { $0.status == .ready }.count
            let warningCount = reports.filter { $0.status == .warning }.count
            let unavailableCount = reports.filter { $0.status == .unavailable }.count
            self.appendRuntimeEvent(
                category: "Runtime",
                severity: unavailableCount > 0 ? .failure : (warningCount > 0 ? .warning : .success),
                message: "Runtime readiness completed: \(readyCount) ready, \(warningCount) review, \(unavailableCount) unavailable.",
                japaneseMessage: "ランタイム準備確認が完了しました: 準備完了\(readyCount)件、要確認\(warningCount)件、利用不可\(unavailableCount)件。"
            )
        }
    }

    func cancelRuntimeReadinessRequested(settings assessmentSettings: AppSettings? = nil) {
        guard runtimeReadinessRunCoordinator.cancel() else { return }
        var nextState = runtimeReadinessViewState
        nextState.cancel(settings: assessmentSettings ?? settings)
        runtimeReadinessViewState = nextState
        appendRuntimeEvent(
            category: "Runtime",
            severity: .warning,
            message: "Runtime readiness check cancelled.",
            japaneseMessage: "ランタイム準備状態の確認をキャンセルしました。"
        )
    }
}
