import AppKit
import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: AppSettings = .defaults
    @Published var models: [ModelConfig] = ModelConfig.defaults
    @Published var selectedModelID: ModelConfig.ID?
    @Published private(set) var runtimeState: ModelRuntimeState = .stopped
    @Published private(set) var memoryUsageGB: Double?
    @Published private(set) var logText: String

    private let settingsStore: SettingsStore
    private let portChecker: PortChecker
    private let readyChecker: ReadyChecker
    private let processManager: ModelProcessManager
    private let memoryMonitor: MemoryMonitor
    private let setupDiagnostics: SetupDiagnostics
    private var logBuffer: LogBuffer
    private var memoryMonitorTask: Task<Void, Never>?

    private static let initialLogLines = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Start, Stop, and Restart are available.",
        "[info] Memory monitoring starts after managed process launch."
    ]

    init(
        settingsStore: SettingsStore? = nil,
        portChecker: PortChecker? = nil,
        readyChecker: ReadyChecker? = nil,
        processManager: ModelProcessManager? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        setupDiagnostics: SetupDiagnostics? = nil
    ) {
        self.settingsStore = settingsStore ?? SettingsStore()
        self.portChecker = portChecker ?? PortChecker()
        self.readyChecker = readyChecker ?? ReadyChecker()
        self.processManager = processManager ?? ModelProcessManager()
        self.memoryMonitor = memoryMonitor ?? MemoryMonitor()
        self.setupDiagnostics = setupDiagnostics ?? SetupDiagnostics(
            settingsStore: self.settingsStore,
            portChecker: self.portChecker,
            readyChecker: self.readyChecker
        )
        self.logBuffer = LogBuffer(initialLines: Self.initialLogLines)
        self.logText = logBuffer.text
        loadSettings()
        selectedModelID = models.first?.id
    }

    var selectedModel: ModelConfig? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    var baseURL: String {
        connectionConfigBuilder.baseURL
    }

    var selectedModelIdentifier: String {
        selectedModel?.modelID ?? "No model selected"
    }

    var apiKeyPlaceholder: String {
        settings.apiKeyPlaceholder
    }

    var memoryUsageText: String {
        guard let memoryUsageGB else {
            return "Memory: Not running"
        }

        return String(format: "Memory: %.2f GB", memoryUsageGB)
    }

    var copyableConfig: String {
        connectionConfigBuilder.configText(modelID: selectedModelIdentifier)
    }

    var modelsCurlCommand: String {
        connectionConfigBuilder.modelsCurlCommand()
    }

    var chatCompletionsCurlCommand: String {
        connectionConfigBuilder.chatCompletionsCurlCommand(modelID: selectedModelIdentifier)
    }

    var settingsDirectoryPath: String {
        do {
            return try settingsStore.settingsDirectoryURL.path
        } catch {
            return "Application Support directory unavailable"
        }
    }

    func startRequested() {
        Task {
            _ = await startManagedServer(logPrefix: "start")
        }
    }

    func stopRequested() {
        guard let processIdentifier = processManager.managedProcessIdentifier else {
            runtimeState = .stopped
            appendLog("[stop] managed process is not running.")
            return
        }

        let endpoint = endpointForCurrentRuntimeState()
        runtimeState = .stopping(processIdentifier: processIdentifier)
        appendLog("[stop] requested for managed pid \(processIdentifier)")

        Task {
            let result = await processManager.stop()
            _ = await handleStopResult(result, host: endpoint.host, port: endpoint.port)
        }
    }

    func restartRequested() {
        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[restart] failed: \(message)")
            return
        }

        let endpoint = endpointForCurrentRuntimeState()
        appendLog("[restart] requested for \(selectedModel.modelID) at \(selectedModel.host):\(selectedModel.serverPort)")

        Task {
            if let processIdentifier = processManager.managedProcessIdentifier {
                runtimeState = .stopping(processIdentifier: processIdentifier)
                appendLog("[restart] stopping managed pid \(processIdentifier)")

                let stopResult = await processManager.stop()
                let didStop = await handleStopResult(
                    stopResult,
                    host: endpoint.host,
                    port: endpoint.port,
                    logPrefix: "restart"
                )

                guard didStop else {
                    appendLog("[restart] cancelled because stop did not complete cleanly.")
                    return
                }
            } else {
                appendLog("[restart] managed process is not running. Starting a new managed server.")
            }

            let didStart = await startManagedServer(logPrefix: "restart")
            if didStart {
                appendLog("[restart] completed.")
            }
        }
    }

    func checkPortRequested() {
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        runtimeState = .checkingPort(host: host, port: port)

        switch portChecker.check(host: host, port: port) {
        case let .available(host, port):
            runtimeState = .portAvailable(host: host, port: port)
            appendLog("[port] port available: \(host):\(port)")
        case let .busy(host, port):
            runtimeState = .portBusy(host: host, port: port)
            appendLog("[port] port busy: \(host):\(port)")
        case let .invalidInput(message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[port] port check failed: \(message)")
        case let .failed(host, port, message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[port] port check failed for \(host):\(port): \(message)")
        }
    }

    func checkReadyRequested() {
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort
        runtimeState = .checkingReady(host: host, port: port)
        appendLog("[ready] checking: http://\(host):\(port)/v1/models")

        Task {
            let result = await readyChecker.check(host: host, port: port)
            handleReadyCheckResult(result, fallbackHost: host, fallbackPort: port)
        }
    }

    func saveSettingsRequested() {
        do {
            try settingsStore.save(settings: settings, models: models)
            appendLog("[settings] Saved settings.json and models.json to \(settingsDirectoryPath).")
        } catch {
            appendLog("[settings] Failed to save settings: \(error.localizedDescription)")
        }
    }

    func runDiagnosticsRequested() {
        let selectedModel = selectedModel
        let host = selectedModel?.host ?? settings.defaultHost
        let port = selectedModel?.serverPort ?? settings.defaultPort

        appendLog("[diagnostics] running setup diagnostics for \(host):\(port)")

        Task {
            let results = await setupDiagnostics.run(
                settings: settings,
                selectedModel: selectedModel
            )

            for result in results {
                appendLog(result.logLine)
            }

            let failedCount = results.filter { $0.status == .fail }.count
            let warningCount = results.filter { $0.status == .warning }.count
            appendLog("[diagnostics] completed with \(failedCount) failure(s), \(warningCount) warning(s).")
        }
    }

    func copyBaseURL() {
        copyToPasteboard(baseURL)
        appendLog("[ui] Copied Base URL.")
    }

    func copyModelID() {
        copyToPasteboard(selectedModelIdentifier)
        appendLog("[ui] Copied Model ID.")
    }

    func copyConfig() {
        copyToPasteboard(copyableConfig)
        appendLog("[ui] Copied OpenAI-compatible config.")
    }

    func copyModelsCurl() {
        copyToPasteboard(modelsCurlCommand)
        appendLog("[ui] Copied OpenAI-compatible curl /v1/models command.")
    }

    func copyChatCompletionsCurl() {
        copyToPasteboard(chatCompletionsCurlCommand)
        appendLog("[ui] Copied OpenAI-compatible curl /v1/chat/completions command.")
    }

    func clearLogsRequested() {
        logBuffer.clear()
        syncLogText()
        appendLog("[info] logs cleared")
    }

    private func startManagedServer(logPrefix: String) async -> Bool {
        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[\(logPrefix)] failed: \(message)")
            return false
        }

        let host = selectedModel.host
        let port = selectedModel.serverPort
        appendLog("[\(logPrefix)] starting \(selectedModel.modelID) at \(host):\(port)")
        appendLog("[\(logPrefix)] checking port before launch: \(host):\(port)")
        runtimeState = .checkingPort(host: host, port: port)

        switch portChecker.check(host: host, port: port) {
        case .available:
            appendLog("[\(logPrefix)] port available: \(host):\(port)")
        case .busy:
            runtimeState = .portBusy(host: host, port: port)
            appendLog("[\(logPrefix)] port busy: \(host):\(port). Start cancelled.")
            return false
        case let .invalidInput(message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[\(logPrefix)] port check failed: \(message)")
            return false
        case let .failed(_, _, message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[\(logPrefix)] port check failed for \(host):\(port): \(message)")
            return false
        }

        let request = ModelLaunchRequest(
            executablePath: settings.mlxServerExecutablePath,
            modelID: selectedModel.modelID,
            host: host,
            port: port
        )

        runtimeState = .starting(host: host, port: port)

        do {
            let launchResult = try processManager.start(
                request: request,
                outputHandler: { [weak self] line in
                    Task { @MainActor in
                        self?.appendLog(line)
                    }
                },
                terminationHandler: { [weak self] status in
                    Task { @MainActor in
                        self?.appendLog("[process] managed server exited with status \(status)")
                    }
                }
            )

            appendLog("[\(logPrefix)] command: \(launchResult.commandSummary)")
            appendLog("[\(logPrefix)] pid: \(launchResult.processIdentifier)")
            startMemoryMonitoring(processIdentifier: launchResult.processIdentifier)
            runtimeState = .loading(
                host: host,
                port: port,
                processIdentifier: launchResult.processIdentifier
            )

            let ready = await waitForReadyAfterStart(
                host: host,
                port: port,
                processIdentifier: launchResult.processIdentifier
            )
            if ready {
                appendLog("[\(logPrefix)] ready check succeeded for pid \(launchResult.processIdentifier).")
            } else {
                appendLog("[\(logPrefix)] ready check did not complete successfully for pid \(launchResult.processIdentifier).")
            }

            return ready
        } catch {
            runtimeState = .error(message: error.localizedDescription)
            appendLog("[\(logPrefix)] failed: \(error.localizedDescription)")
            return false
        }
    }

    private func loadSettings() {
        do {
            let snapshot = try settingsStore.load()
            settings = snapshot.settings
            models = snapshot.models

            if snapshot.usedDefaults {
                appendLog("[settings] settings.json or models.json not found. Using defaults until saved.")
            } else {
                appendLog("[settings] Loaded settings.json and models.json from \(settingsDirectoryPath).")
            }
        } catch {
            settings = .defaults
            models = ModelConfig.defaults
            appendLog("[settings] Failed to load settings. Using defaults: \(error.localizedDescription)")
        }
    }

    private func handleReadyCheckResult(
        _ result: ReadyCheckResult,
        fallbackHost: String,
        fallbackPort: Int
    ) {
        switch result {
        case let .ready(url, statusCode):
            runtimeState = .ready(
                host: fallbackHost,
                port: fallbackPort,
                processIdentifier: processManager.managedProcessIdentifier
            )
            appendLog("[ready] ready: \(url.absoluteString) returned HTTP \(statusCode)")
        case let .notReady(url, statusCode):
            runtimeState = .readyCheckFailed(
                host: fallbackHost,
                port: fallbackPort,
                message: "HTTP \(statusCode)"
            )
            appendLog("[ready] not ready: \(url.absoluteString) returned HTTP \(statusCode)")
        case let .invalidInput(message):
            runtimeState = .readyCheckFailed(
                host: fallbackHost,
                port: fallbackPort,
                message: message
            )
            appendLog("[ready] ready check failed: \(message)")
        case let .failed(url, message):
            runtimeState = .readyCheckFailed(
                host: fallbackHost,
                port: fallbackPort,
                message: message
            )
            appendLog("[ready] ready check failed for \(url?.absoluteString ?? "\(fallbackHost):\(fallbackPort)"): \(message)")
        case let .timedOut(url):
            runtimeState = .readyCheckFailed(
                host: fallbackHost,
                port: fallbackPort,
                message: "Timed out"
            )
            appendLog("[ready] timed out: \(url.absoluteString)")
        }
    }

    private func waitForReadyAfterStart(
        host: String,
        port: Int,
        processIdentifier: Int32
    ) async -> Bool {
        appendLog("[ready] waiting for http://\(host):\(port)/v1/models")

        for attempt in 1...10 {
            guard processManager.managedProcessIdentifier == processIdentifier else {
                appendLog("[ready] wait ended because managed process is no longer running.")
                return false
            }

            if case .stopping = runtimeState {
                appendLog("[ready] wait cancelled because stop was requested.")
                return false
            }

            let result = await readyChecker.check(host: host, port: port)

            switch result {
            case let .ready(url, statusCode):
                guard processManager.managedProcessIdentifier == processIdentifier else {
                    appendLog("[ready] ready response ignored because managed process is no longer running.")
                    return false
                }

                runtimeState = .ready(
                    host: host,
                    port: port,
                    processIdentifier: processIdentifier
                )
                appendLog("[ready] ready after start: \(url.absoluteString) returned HTTP \(statusCode)")
                return true
            case let .notReady(url, statusCode):
                appendLog("[ready] attempt \(attempt) not ready: \(url.absoluteString) returned HTTP \(statusCode)")
            case let .invalidInput(message):
                runtimeState = .readyCheckFailed(host: host, port: port, message: message)
                appendLog("[ready] ready check failed: \(message)")
                return false
            case let .failed(url, message):
                appendLog("[ready] attempt \(attempt) failed for \(url?.absoluteString ?? "\(host):\(port)"): \(message)")
            case let .timedOut(url):
                appendLog("[ready] attempt \(attempt) timed out: \(url.absoluteString)")
            }

            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                runtimeState = .unknown(message: "Ready wait was cancelled.")
                appendLog("[ready] wait cancelled.")
                return false
            }
        }

        let message = "Ready check did not succeed after launch."
        runtimeState = .unknown(message: message)
        appendLog("[ready] \(message)")
        return false
    }

    private func handleStopResult(
        _ result: ModelStopResult,
        host: String,
        port: Int,
        logPrefix: String = "stop"
    ) async -> Bool {
        switch result {
        case .notRunning:
            stopMemoryMonitoring()
            runtimeState = .stopped
            appendLog("[\(logPrefix)] managed process is not running.")
            return true
        case let .stopped(processIdentifier, terminationStatus, usedInterrupt):
            stopMemoryMonitoring()
            if usedInterrupt {
                appendLog("[\(logPrefix)] interrupt was sent after graceful timeout for pid \(processIdentifier).")
            }
            appendLog("[\(logPrefix)] stopped managed pid \(processIdentifier) with status \(terminationStatus).")

            if await waitForPortRelease(host: host, port: port, logPrefix: logPrefix) {
                runtimeState = .stopped
                return true
            } else {
                runtimeState = .portBusy(host: host, port: port)
                appendLog("[\(logPrefix)] warning: port still busy after waiting for release: \(host):\(port)")
                return false
            }
        case let .timedOut(processIdentifier):
            let message = "Stop timed out for managed pid \(processIdentifier)."
            runtimeState = .error(message: message)
            appendLog("[\(logPrefix)] \(message)")
            return false
        }
    }

    private func waitForPortRelease(
        host: String,
        port: Int,
        logPrefix: String = "stop"
    ) async -> Bool {
        appendLog("[\(logPrefix)] waiting for port release: \(host):\(port)")

        for _ in 1...20 {
            switch portChecker.check(host: host, port: port) {
            case .available:
                appendLog("[\(logPrefix)] port released: \(host):\(port)")
                return true
            case .busy:
                break
            case let .invalidInput(message):
                appendLog("[\(logPrefix)] warning: port release check failed: \(message)")
                return false
            case let .failed(_, _, message):
                appendLog("[\(logPrefix)] warning: port release check failed for \(host):\(port): \(message)")
                return false
            }

            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                appendLog("[\(logPrefix)] warning: port release wait cancelled.")
                return false
            }
        }

        switch portChecker.check(host: host, port: port) {
        case .available:
            appendLog("[\(logPrefix)] port released: \(host):\(port)")
            return true
        case .busy:
            return false
        case let .invalidInput(message):
            appendLog("[\(logPrefix)] warning: final port release check failed: \(message)")
            return false
        case let .failed(_, _, message):
            appendLog("[\(logPrefix)] warning: final port release check failed for \(host):\(port): \(message)")
            return false
        }
    }

    private func endpointForCurrentRuntimeState() -> (host: String, port: Int) {
        switch runtimeState {
        case let .starting(host, port),
             let .checkingPort(host, port),
             let .portAvailable(host, port),
             let .portBusy(host, port),
             let .checkingReady(host, port):
            return (host, port)
        case let .loading(host, port, _),
             let .ready(host, port, _):
            return (host, port)
        case let .portCheckFailed(host, port, _),
             let .readyCheckFailed(host, port, _):
            return (host, port)
        case .stopped, .stopping, .error, .unknown:
            return (
                selectedModel?.host ?? settings.defaultHost,
                selectedModel?.serverPort ?? settings.defaultPort
            )
        }
    }

    private func startMemoryMonitoring(processIdentifier: Int32) {
        stopMemoryMonitoring(resetUsage: true)

        appendLog("[memory] monitoring managed pid \(processIdentifier).")
        let monitor = memoryMonitor

        memoryMonitorTask = Task { [weak self, monitor] in
            while !Task.isCancelled {
                let result = await monitor.currentUsage(processIdentifier: processIdentifier)
                let shouldContinue = await MainActor.run {
                    self?.handleMemoryMonitorResult(
                        result,
                        processIdentifier: processIdentifier
                    ) ?? false
                }

                guard shouldContinue, !Task.isCancelled else {
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: 4_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func stopMemoryMonitoring(resetUsage: Bool = true) {
        memoryMonitorTask?.cancel()
        memoryMonitorTask = nil

        if resetUsage {
            memoryUsageGB = nil
        }
    }

    private func handleMemoryMonitorResult(
        _ result: MemoryMonitorResult,
        processIdentifier: Int32
    ) -> Bool {
        guard processManager.managedProcessIdentifier == processIdentifier else {
            memoryUsageGB = nil
            appendLog("[memory] monitoring stopped because managed pid changed.")
            return false
        }

        switch result {
        case let .usage(snapshot):
            memoryUsageGB = snapshot.gigabytes
            return true
        case let .notRunning(processIdentifier):
            memoryUsageGB = nil
            appendLog("[memory] warning: managed pid \(processIdentifier) is no longer reporting RSS.")
            return false
        case let .invalidInput(message):
            memoryUsageGB = nil
            appendLog("[memory] warning: \(message)")
            return false
        case let .failed(processIdentifier, message):
            appendLog("[memory] warning: failed to read RSS for pid \(processIdentifier): \(message)")
            return true
        }
    }

    private var connectionConfigBuilder: ConnectionConfigBuilder {
        ConnectionConfigBuilder(
            scheme: "http",
            host: selectedModel?.host ?? settings.defaultHost,
            port: selectedModel?.serverPort ?? settings.defaultPort,
            apiBasePath: "/v1",
            apiKeyPlaceholder: settings.apiKeyPlaceholder
        )
    }

    private func appendLog(_ line: String) {
        logBuffer.append(line)
        syncLogText()
    }

    private func syncLogText() {
        logText = logBuffer.text
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
