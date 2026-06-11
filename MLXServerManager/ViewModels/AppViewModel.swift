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
        "[info] Server launch and readiness checks are not implemented in Step 4."
    ]

    private let settingsStore: SettingsStore
    private let portChecker: PortChecker

    init(
        settingsStore: SettingsStore = SettingsStore(),
        portChecker: PortChecker = PortChecker()
    ) {
        self.settingsStore = settingsStore
        self.portChecker = portChecker
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
        appendLog("[ui] Start requested. Server launch is intentionally not implemented in Step 4.")
    }

    func stopRequested() {
        appendLog("[ui] Stop requested. Server termination is intentionally not implemented in Step 4.")
    }

    func restartRequested() {
        appendLog("[ui] Restart requested. Restart wiring is intentionally not implemented in Step 4.")
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
