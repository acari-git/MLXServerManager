import Foundation

extension AppViewModel {
    func startRequested() {
        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[start] failed: \(message)")
            appendRuntimeEvent(
                category: "Lifecycle",
                severity: .failure,
                message: message,
                japaneseMessage: "モデルが選択されていません。"
            )
            return
        }
        appendRuntimeEvent(
            category: "Lifecycle",
            message: "Start requested.",
            japaneseMessage: "起動を要求しました。",
            modelID: selectedModel.modelID,
            endpoint: "\(selectedModel.host):\(selectedModel.serverPort)"
        )
        startRequested(for: selectedModel)
    }

    func stopRequested() {
        guard let model = selectedModel.flatMap({ runningModelIDs.contains($0.id) ? $0 : nil })
            ?? models.first(where: { runningModelIDs.contains($0.id) }) else {
            let endpoint = endpointForCurrentRuntimeState()
            if runtimeState.isExternalServerContext {
                appendLog("[stop] managed process is not running. External servers are not stopped by this app.")
                appendRuntimeEvent(
                    category: "Lifecycle",
                    severity: .warning,
                    message: "Stop skipped because the current endpoint is external and is not owned by this app.",
                    japaneseMessage: "現在の接続先は外部サーバーで、このアプリの管理対象ではないため停止しませんでした。",
                    endpoint: "\(endpoint.host):\(endpoint.port)"
                )
            } else {
                _ = serverLifecycleCoordinator.checkPortRelease(
                    host: endpoint.host,
                    port: endpoint.port,
                    announceBusy: true,
                    portCheckOperation: { host, port in
                        self.freshPortCheck(host: host, port: port)
                    },
                    eventHandler: { event in
                        self.handleServerStopEvent(
                            event,
                            modelID: self.selectedModelID,
                            host: endpoint.host,
                            port: endpoint.port,
                            logPrefix: "stop"
                        )
                    }
                )
                appendLog("[stop] managed process is not running.")
            }
            return
        }

        requestStop(for: model, logPrefix: "stop")
    }

    func requestStop(for model: ModelConfig, logPrefix: String) {
        if case .stopping = runtimeState(for: model) {
            appendLog("[\(logPrefix)] ignored duplicate stop request for \(model.displayName).")
            return
        }

        cancelModelStartPreparation(modelID: model.id)
        cancelManagedStartTask(modelID: model.id)
        guard let processIdentifier = serverLifecycleCoordinator.processIdentifier(for: model.id) else {
            clearRunningModel(modelID: model.id, logPrefix: logPrefix)
            setRuntimeState(.stopped, for: model.id)
            appendLog("[\(logPrefix)] managed process is not running for \(model.displayName).")
            return
        }

        setRuntimeState(.stopping(processIdentifier: processIdentifier), for: model.id)
        appendLog("[\(logPrefix)] requested for managed pid \(processIdentifier) (\(model.displayName))")
        appendRuntimeEvent(
            category: "Lifecycle",
            message: "\(logPrefix.capitalized) requested for managed process \(processIdentifier).",
            japaneseMessage: "管理プロセス\(processIdentifier)の\(logPrefix == "restart" ? "再起動" : "停止")を要求しました。",
            modelID: model.modelID,
            endpoint: "\(model.host):\(model.serverPort)"
        )

        lifecycleRunCoordinator.start(model.id) { [weak self] generation in
            guard let self,
                  self.lifecycleRunCoordinator.isCurrent(
                    model.id,
                    generation: generation
                  ) else {
                return
            }
            _ = await self.stopManagedServerAndWaitForPortRelease(
                modelID: model.id,
                host: model.host,
                port: model.serverPort,
                logPrefix: logPrefix
            )
        }
    }

    func restartRequested() {
        guard !runtimeState.isExternalServerContext else {
            appendLog("[restart] unavailable for external servers. Start a managed server only after the port is available.")
            return
        }

        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[restart] failed: \(message)")
            return
        }

        guard !blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "restart") else {
            return
        }

        cancelModelStartPreparation(modelID: selectedModel.id)
        cancelManagedStartTask(modelID: selectedModel.id)
        guard let processIdentifier = serverLifecycleCoordinator.processIdentifier(for: selectedModel.id) else {
            appendLog("[restart] unavailable because the selected managed server is not running.")
            return
        }
        guard !isModelTransitioning(selectedModel) else {
            appendLog("[restart] ignored because a lifecycle transition is already active for \(selectedModel.displayName).")
            return
        }

        appendLog("[restart] requested for \(selectedModel.modelID) at \(selectedModel.host):\(selectedModel.serverPort)")
        appendRuntimeEvent(
            category: "Lifecycle",
            message: "Restart requested.",
            japaneseMessage: "再起動を要求しました。",
            modelID: selectedModel.modelID,
            endpoint: "\(selectedModel.host):\(selectedModel.serverPort)"
        )
        setRuntimeState(.stopping(processIdentifier: processIdentifier), for: selectedModel.id)

        lifecycleRunCoordinator.start(selectedModel.id) { [weak self] generation in
            guard let self,
                  self.lifecycleRunCoordinator.isCurrent(
                    selectedModel.id,
                    generation: generation
                  ) else {
                return
            }
            self.appendLog("[restart] stopping managed pid \(processIdentifier)")
            let didStop = await self.stopManagedServerAndWaitForPortRelease(
                modelID: selectedModel.id,
                host: selectedModel.host,
                port: selectedModel.serverPort,
                logPrefix: "restart"
            )

            guard didStop else {
                self.appendLog("[restart] cancelled because stop did not complete cleanly.")
                return
            }

            _ = await self.resolvedModelSizeGigabytes(for: selectedModel)
            guard !Task.isCancelled,
                  self.lifecycleRunCoordinator.isCurrent(
                    selectedModel.id,
                    generation: generation
                  ),
                  !self.blockManagedLaunchDuringRuntimeMemoryEmergency(logPrefix: "restart") else {
                return
            }

            let didStart = await self.startManagedServer(model: selectedModel, logPrefix: "restart")
            if didStart {
                self.appendLog("[restart] completed.")
            }
        }
    }

    func checkPortRequested() {
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        let degradedState = degradedRuntimeStateToPreserve(
            modelID: selectedModelID,
            host: host,
            port: port
        )
        if degradedState == nil {
            runtimeState = .checkingPort(host: host, port: port)
        }

        switch freshPortCheck(host: host, port: port) {
        case let .available(host, port):
            if degradedState == nil {
                runtimeState = .portAvailable(host: host, port: port)
            }
            appendLog("[port] port available: \(host):\(port)")
            appendRuntimeEvent(
                category: "Port",
                severity: .success,
                message: "Port is available.",
                japaneseMessage: "ポートを利用できます。",
                modelID: selectedModel?.modelID,
                endpoint: "\(host):\(port)"
            )
        case let .busy(host, port, pid):
            if degradedState == nil {
                runtimeState = .portBusy(host: host, port: port)
            }
            if let pid {
                appendLog("[port] port busy: \(host):\(port) PID=\(pid)")
            } else {
                appendLog("[port] port busy: \(host):\(port)")
            }
            appendRuntimeEvent(
                category: "Port",
                severity: .warning,
                message: pid.map { "Port is busy by process \($0)." } ?? "Port is busy.",
                japaneseMessage: pid.map { "プロセス\($0)がポートを使用中です。" } ?? "ポートは使用中です。",
                modelID: selectedModel?.modelID,
                endpoint: "\(host):\(port)"
            )
        case let .invalidInput(message):
            if degradedState == nil {
                runtimeState = .portCheckFailed(host: host, port: port, message: message)
            }
            appendLog("[port] port check failed: \(message)")
            appendRuntimeEvent(
                category: "Port",
                severity: .failure,
                message: message,
                japaneseMessage: "ポート確認に失敗しました: \(message)",
                modelID: selectedModel?.modelID,
                endpoint: "\(host):\(port)"
            )
        case let .failed(host, port, message):
            if degradedState == nil {
                runtimeState = .portCheckFailed(host: host, port: port, message: message)
            }
            appendLog("[port] port check failed for \(host):\(port): \(message)")
            appendRuntimeEvent(
                category: "Port",
                severity: .failure,
                message: message,
                japaneseMessage: "ポート確認に失敗しました: \(message)",
                modelID: selectedModel?.modelID,
                endpoint: "\(host):\(port)"
            )
        }
        if let degradedState {
            setRuntimeState(degradedState, forOptionalModelID: selectedModelID)
            appendLog("[runtime-health] port check completed without replacing the degraded state.")
        }
    }

    func checkReadyRequested() {
        let targetModel = selectedModel
        let targetModelID = targetModel?.id
        let host = targetModel?.host ?? settings.defaultHost
        let port = targetModel?.serverPort ?? settings.defaultPort
        let expectedModelID = targetModel?.modelID
        let previousRuntimeState = targetModelID.flatMap { runtimeStatesByModelID[$0] } ?? runtimeState
        let requestKey = targetModelID.map(ReadyCheckRequestKey.profile) ?? .defaultEndpoint

        if !previousRuntimeState.isExternalServerContext {
            setRuntimeState(
                .checkingReady(host: host, port: port),
                forOptionalModelID: targetModelID
            )
        }
        appendRuntimeEvent(
            category: "Ready",
            message: "Ready Check started.",
            japaneseMessage: "準備状態の確認を開始しました。",
            modelID: targetModel?.modelID,
            endpoint: "\(host):\(port)"
        )
        appendLog("[ready] checking: http://\(host):\(port)/v1/models")

        readyCheckRunCoordinator.start(requestKey) { [weak self] generation in
            guard let self else { return }
            let result = await serverLifecycleCoordinator.checkReady(
                host: host,
                port: port,
                expectedModelID: expectedModelID
            )
            guard self.readyCheckRunCoordinator.isCurrent(requestKey, generation: generation) else {
                appendLog("[ready] ignored stale manual ready check result for \(host):\(port).")
                return
            }
            handleReadyCheckResult(
                result,
                fallbackHost: host,
                fallbackPort: port,
                targetModelID: targetModelID,
                previousRuntimeState: previousRuntimeState
            )
        }
    }
}
