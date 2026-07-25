import Foundation

extension AppViewModel {
    func runDiagnosticsRequested() {
        let selectedModel = selectedModel
        let diagnosticSettings = settings
        let host = selectedModel?.host ?? diagnosticSettings.defaultHost
        let port = selectedModel?.serverPort ?? diagnosticSettings.defaultPort
        let targetModelID = selectedModel?.id
        let managedProcessIdentifier = selectedModel.flatMap {
            serverLifecycleCoordinator.processIdentifier(for: $0.id)
        }
        updateDiagnosticsViewState { state in
            state.beginRun()
        }
        appendLog("[diagnostics] running setup diagnostics for \(host):\(port)")

        diagnosticsRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let results = await self.setupDiagnostics.run(
                settings: diagnosticSettings,
                selectedModel: selectedModel,
                managedProcessIdentifier: managedProcessIdentifier
            )

            guard !Task.isCancelled,
                  self.diagnosticsRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            guard self.matchesCurrentDiagnosticsTarget(
                modelID: targetModelID,
                host: host,
                port: port
            ) else {
                self.cancelDiagnostics(
                    reason: "the diagnostic connection target changed"
                )
                return
            }
            self.updateDiagnosticsViewState { state in
                state.completeRun(with: results)
            }

            let failedCount = results.filter { $0.status == .fail }.count
            let warningCount = results.filter { $0.status == .warning }.count
            self.appendLogs(
                results.map(\.logLine) + [
                    "[diagnostics] completed with \(failedCount) failure(s), \(warningCount) warning(s)."
                ]
            )
        }
    }

    private func matchesCurrentDiagnosticsTarget(
        modelID: ModelConfig.ID?,
        host: String,
        port: Int
    ) -> Bool {
        guard selectedModelID == modelID else {
            return false
        }

        if let selectedModel {
            return selectedModel.host == host && selectedModel.serverPort == port
        }

        return settings.defaultHost == host && settings.defaultPort == port
    }

    func cancelDiagnostics(reason: String) {
        let hadActiveRun = diagnosticsRunCoordinator.cancel() || diagnosticsViewState.isRunning
        updateDiagnosticsViewState { state in
            state.reset()
        }
        if hadActiveRun {
            appendLog("[diagnostics] cancelled because \(reason).")
        }
    }

    func updateDiagnosticsViewState(
        _ update: (inout DiagnosticsViewState) -> Void
    ) {
        var nextState = diagnosticsViewState
        update(&nextState)
        guard nextState != diagnosticsViewState else {
            return
        }
        diagnosticsViewState = nextState
    }
}
