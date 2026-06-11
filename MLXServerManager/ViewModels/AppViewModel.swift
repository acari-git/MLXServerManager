import AppKit
import Combine
import Foundation

final class AppViewModel: ObservableObject {
    @Published var settings: AppSettings = .defaults
    @Published var models: [ModelConfig] = ModelConfig.defaults
    @Published var selectedModelID: ModelConfig.ID?
    @Published private(set) var runtimeState: ModelRuntimeState = .stopped
    @Published private(set) var logLines: [String] = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Start and Stop are available. Restart is not implemented yet."
    ]

    private let settingsStore: SettingsStore
    private let portChecker: PortChecker
    private let readyChecker: ReadyChecker
    private let processManager: ModelProcessManager

    init(
        settingsStore: SettingsStore = SettingsStore(),
        portChecker: PortChecker = PortChecker(),
        readyChecker: ReadyChecker = ReadyChecker(),
        processManager: ModelProcessManager = ModelProcessManager()
    ) {
        self.settingsStore = settingsStore
        self.portChecker = portChecker
        self.readyChecker = readyChecker
        self.processManager = processManager
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

    var copyableConfig: String {
        connectionConfigBuilder.configText(modelID: selectedModelIdentifier)
    }

    var logText: String {
        logLines.joined(separator: "\n")
    }

    var settingsDirectoryPath: String {
        do {
            return try settingsStore.settingsDirectoryURL.path
        } catch {
            return "Application Support directory unavailable"
        }
    }

    func startRequested() {
        guard let selectedModel else {
            let message = "No model is selected."
            runtimeState = .error(message: message)
            appendLog("[start] failed: \(message)")
            return
        }

        let host = selectedModel.host
        let port = selectedModel.serverPort
        appendLog("[start] requested for \(selectedModel.modelID) at \(host):\(port)")
        appendLog("[start] checking port before launch: \(host):\(port)")
        runtimeState = .checkingPort(host: host, port: port)

        switch portChecker.check(host: host, port: port) {
        case .available:
            appendLog("[start] port available: \(host):\(port)")
        case .busy:
            runtimeState = .portBusy(host: host, port: port)
            appendLog("[start] port busy: \(host):\(port). Start cancelled.")
            return
        case let .invalidInput(message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[start] port check failed: \(message)")
            return
        case let .failed(_, _, message):
            runtimeState = .portCheckFailed(host: host, port: port, message: message)
            appendLog("[start] port check failed for \(host):\(port): \(message)")
            return
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

            appendLog("[start] command: \(launchResult.commandSummary)")
            appendLog("[start] pid: \(launchResult.processIdentifier)")
            runtimeState = .loading(
                host: host,
                port: port,
                processIdentifier: launchResult.processIdentifier
            )

            Task {
                await waitForReadyAfterStart(
                    host: host,
                    port: port,
                    processIdentifier: launchResult.processIdentifier
                )
            }
        } catch {
            runtimeState = .error(message: error.localizedDescription)
            appendLog("[start] failed: \(error.localizedDescription)")
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
            await handleStopResult(result, host: endpoint.host, port: endpoint.port)
        }
    }

    func restartRequested() {
        appendLog("[ui] Restart requested. Restart is not implemented in Step 7.")
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
    ) async {
        appendLog("[ready] waiting for http://\(host):\(port)/v1/models")

        for attempt in 1...10 {
            guard processManager.managedProcessIdentifier == processIdentifier else {
                appendLog("[ready] wait ended because managed process is no longer running.")
                return
            }

            if case .stopping = runtimeState {
                appendLog("[ready] wait cancelled because stop was requested.")
                return
            }

            let result = await readyChecker.check(host: host, port: port)

            switch result {
            case let .ready(url, statusCode):
                guard processManager.managedProcessIdentifier == processIdentifier else {
                    appendLog("[ready] ready response ignored because managed process is no longer running.")
                    return
                }

                runtimeState = .ready(
                    host: host,
                    port: port,
                    processIdentifier: processIdentifier
                )
                appendLog("[ready] ready after start: \(url.absoluteString) returned HTTP \(statusCode)")
                return
            case let .notReady(url, statusCode):
                appendLog("[ready] attempt \(attempt) not ready: \(url.absoluteString) returned HTTP \(statusCode)")
            case let .invalidInput(message):
                runtimeState = .readyCheckFailed(host: host, port: port, message: message)
                appendLog("[ready] ready check failed: \(message)")
                return
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
                return
            }
        }

        let message = "Ready check did not succeed after launch."
        runtimeState = .unknown(message: message)
        appendLog("[ready] \(message)")
    }

    private func handleStopResult(
        _ result: ModelStopResult,
        host: String,
        port: Int
    ) async {
        switch result {
        case .notRunning:
            runtimeState = .stopped
            appendLog("[stop] managed process is not running.")
        case let .stopped(processIdentifier, terminationStatus, usedInterrupt):
            if usedInterrupt {
                appendLog("[stop] interrupt was sent after graceful timeout for pid \(processIdentifier).")
            }
            appendLog("[stop] stopped managed pid \(processIdentifier) with status \(terminationStatus).")

            if await waitForPortRelease(host: host, port: port) {
                runtimeState = .stopped
            } else {
                runtimeState = .portBusy(host: host, port: port)
                appendLog("[stop] warning: port still busy after waiting for release: \(host):\(port)")
            }
        case let .timedOut(processIdentifier):
            let message = "Stop timed out for managed pid \(processIdentifier)."
            runtimeState = .error(message: message)
            appendLog("[stop] \(message)")
        }
    }

    private func waitForPortRelease(host: String, port: Int) async -> Bool {
        appendLog("[stop] waiting for port release: \(host):\(port)")

        for _ in 1...20 {
            switch portChecker.check(host: host, port: port) {
            case .available:
                appendLog("[stop] port released: \(host):\(port)")
                return true
            case .busy:
                break
            case let .invalidInput(message):
                appendLog("[stop] warning: port release check failed: \(message)")
                return false
            case let .failed(_, _, message):
                appendLog("[stop] warning: port release check failed for \(host):\(port): \(message)")
                return false
            }

            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                appendLog("[stop] warning: port release wait cancelled.")
                return false
            }
        }

        switch portChecker.check(host: host, port: port) {
        case .available:
            appendLog("[stop] port released: \(host):\(port)")
            return true
        case .busy:
            return false
        case let .invalidInput(message):
            appendLog("[stop] warning: final port release check failed: \(message)")
            return false
        case let .failed(_, _, message):
            appendLog("[stop] warning: final port release check failed for \(host):\(port): \(message)")
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
        logLines.append(line)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
