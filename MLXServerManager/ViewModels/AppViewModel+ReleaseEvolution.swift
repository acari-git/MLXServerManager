import AppKit
import Foundation

extension AppViewModel {
    func discoverRuntimeCandidatesRequested(settings: AppSettings) {
        runtimeSetupAssistantViewState.begin()
        runtimeSetupAssistantRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let candidates = await runtimeSetupAssistantService.discover(settings: settings)
            guard runtimeSetupAssistantRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            runtimeSetupAssistantViewState.complete(candidates)
            appendRuntimeEvent(
                category: "Runtime Setup",
                severity: candidates.isEmpty ? .warning : .success,
                message: candidates.isEmpty
                    ? "Runtime discovery completed without finding an executable."
                    : "Runtime discovery found \(candidates.count) executable candidate(s).",
                japaneseMessage: candidates.isEmpty
                    ? "ランタイム検索は完了しましたが、実行ファイルは見つかりませんでした。"
                    : "ランタイム検索で実行ファイル候補を\(candidates.count)件検出しました。"
            )
        }
    }

    func cancelRuntimeCandidateDiscoveryRequested() {
        runtimeSetupAssistantRunCoordinator.cancel()
        runtimeSetupAssistantViewState.cancel()
    }

    func refreshRuntimeCompatibilityRequested(settings: AppSettings) {
        runtimeCompatibilityViewState.begin()
        runtimeCompatibilityRunCoordinator.start { [weak self] generation in
            guard let self else { return }
            let reports = await runtimeCompatibilityService.assess(settings: settings)
            guard runtimeCompatibilityRunCoordinator.isCurrent(generation: generation) else {
                return
            }
            runtimeCompatibilityViewState.complete(reports)
            appendRuntimeEvent(
                category: "Runtime Compatibility",
                severity: .success,
                message: "Runtime compatibility inspection completed.",
                japaneseMessage: "ランタイム互換性の確認が完了しました。"
            )
        }
    }

    func cancelRuntimeCompatibilityRequested() {
        runtimeCompatibilityRunCoordinator.cancel()
        runtimeCompatibilityViewState.cancel()
    }

    func applicationShouldTerminateRequested() -> NSApplication.TerminateReply {
        if applicationTerminationPhase.isStopping || applicationTerminationPhase.isPrompting {
            return .terminateLater
        }

        let targets = currentManagedTerminationTargets()
        guard !targets.isEmpty else {
            sessionRecoveryStore.markCleanShutdown()
            return .terminateNow
        }

        applicationTerminationPhase = .prompting(targets: targets)
        return .terminateLater
    }

    func applicationShouldTerminateForSystemShutdownRequested() -> NSApplication.TerminateReply {
        applicationTerminationCoordinator.cancel()
        applicationTerminationPhase = .idle
        sessionRecoveryStore.recordSystemShutdown(
            endpoints: currentSessionRecoveryEndpoints()
        )
        return .terminateNow
    }

    func stopAllManagedServersAndQuitRequested() {
        guard case let .prompting(targets) = applicationTerminationPhase else {
            return
        }
        applicationTerminationPhase = .stopping(completed: 0, total: targets.count)
        applicationTerminationCoordinator.stopAll(
            targets: targets,
            stopOperation: { [weak self] target in
                guard let self else { return false }
                return await self.stopManagedServerAndWaitForPortRelease(
                    modelID: target.profileID,
                    host: target.host,
                    port: target.port,
                    logPrefix: "quit"
                )
            },
            progressHandler: { [weak self] completed, total in
                self?.applicationTerminationPhase = .stopping(
                    completed: completed,
                    total: total
                )
            },
            completionHandler: { [weak self] failures in
                guard let self else { return }
                if failures.isEmpty {
                    self.sessionRecoveryStore.markCleanShutdown()
                    self.applicationTerminationPhase = .idle
                    NSApp.reply(toApplicationShouldTerminate: true)
                } else {
                    self.applicationTerminationPhase = .failed(failures: failures)
                    NSApp.reply(toApplicationShouldTerminate: false)
                }
            }
        )
    }

    func leaveManagedServersRunningAndQuitRequested() {
        sessionRecoveryStore.recordLeftRunning(endpoints: currentSessionRecoveryEndpoints())
        applicationTerminationPhase = .idle
        NSApp.reply(toApplicationShouldTerminate: true)
    }

    func cancelApplicationTerminationRequested() {
        applicationTerminationCoordinator.cancel()
        applicationTerminationPhase = .idle
        NSApp.reply(toApplicationShouldTerminate: false)
    }

    func dismissApplicationTerminationFailure() {
        applicationTerminationPhase = .idle
    }

    func beginSessionRecoveryTracking() {
        guard let previousRecord = sessionRecoveryStore.beginSession() else {
            return
        }
        sessionRecoveryViewState = .presenting(record: previousRecord)
        let messages: (english: String, japanese: String)
        switch previousRecord.disposition {
        case .active:
            messages = (
                "A previous session ended before its managed endpoints were cleared.",
                "前回のセッションは管理エンドポイントが解除される前に終了しました。"
            )
        case .leftRunning:
            messages = (
                "A previous session intentionally left managed endpoints running.",
                "前回のセッションでは管理エンドポイントを意図的に残して終了しました。"
            )
        case .systemShutdown:
            messages = (
                "The previous session ended during macOS shutdown with managed endpoints recorded.",
                "前回のセッションはmacOS終了時に管理エンドポイントを記録して終了しました。"
            )
        case .clean:
            messages = (
                "The previous session closed normally.",
                "前回のセッションは正常に終了しました。"
            )
        }
        appendRuntimeEvent(
            category: "Session Recovery",
            severity: .warning,
            message: messages.english,
            japaneseMessage: messages.japanese
        )
    }

    func updateSessionRecoveryTracking() {
        sessionRecoveryStore.recordActive(endpoints: currentSessionRecoveryEndpoints())
    }

    func checkSessionRecoveryEndpointsRequested() {
        guard !sessionRecoveryViewState.candidates.isEmpty else { return }
        sessionRecoveryViewState.beginCheck()
        let endpoints = sessionRecoveryViewState.candidates.map(\.endpoint)
        sessionRecoveryCoordinator.check(
            endpoints: endpoints,
            operation: { [weak self] endpoint in
                guard let self else {
                    return .unavailable(message: "Application unavailable")
                }
                let result = await serverLifecycleCoordinator.checkReady(
                    host: endpoint.host,
                    port: endpoint.port,
                    expectedModelID: endpoint.modelID
                )
                switch result {
                case let .ready(_, statusCode):
                    return .available(statusCode: statusCode)
                case let .notReady(_, statusCode):
                    return .unavailable(message: "HTTP \(statusCode)")
                case let .invalidInput(message), let .failed(_, message):
                    return .unavailable(message: message)
                case .timedOut:
                    return .unavailable(message: "Timed out")
                }
            },
            completion: { [weak self] results in
                self?.sessionRecoveryViewState.complete(results)
            }
        )
    }

    func adoptSessionRecoveryCandidateRequested(_ candidateID: ModelConfig.ID) {
        guard let candidate = sessionRecoveryViewState.candidates.first(where: { $0.id == candidateID }),
              candidate.status.isAvailable,
              models.contains(where: { $0.id == candidateID }) else {
            return
        }

        selectedModelID = candidateID
        setRuntimeState(
            .adoptedExternalServer(
                host: candidate.endpoint.host,
                port: candidate.endpoint.port,
                baseURL: candidate.endpoint.baseURL,
                message: Self.localizedText(
                    language: settings.uiLanguage,
                    english: "Recovered as external connection context. Process ownership was not restored.",
                    japanese: "外部接続コンテキストとして復旧しました。プロセス所有権は復元していません。"
                )
            ),
            for: candidateID
        )
        sessionRecoveryViewState.markAdopted(candidateID)
        appendRuntimeEvent(
            category: "Session Recovery",
            severity: .success,
            message: "A remaining endpoint was adopted as external connection context.",
            japaneseMessage: "残存エンドポイントを外部接続コンテキストとして採用しました。",
            modelID: candidate.endpoint.modelID,
            endpoint: "\(candidate.endpoint.host):\(candidate.endpoint.port)"
        )
    }

    func dismissSessionRecoveryRequested() {
        sessionRecoveryCoordinator.cancel()
        sessionRecoveryViewState.isPresented = false
        sessionRecoveryViewState.isChecking = false
        sessionRecoveryStore.recordActive(endpoints: currentSessionRecoveryEndpoints())
    }

    private func currentManagedTerminationTargets() -> [ManagedTerminationTarget] {
        ApplicationTerminationPolicy.targets(
            models: models,
            runningProfileIDs: serverLifecycleCoordinator.runningProfileIDs,
            processIdentifier: { serverLifecycleCoordinator.processIdentifier(for: $0) }
        )
    }

    private func currentSessionRecoveryEndpoints() -> [SessionRecoveryEndpoint] {
        let runningIDs = serverLifecycleCoordinator.runningProfileIDs
        return models.compactMap { model in
            guard runningIDs.contains(model.id) else { return nil }
            return SessionRecoveryEndpoint(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                host: model.host,
                port: model.serverPort
            )
        }
    }
}
