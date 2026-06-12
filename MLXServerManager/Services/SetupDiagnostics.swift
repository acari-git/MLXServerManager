import Foundation

struct SetupDiagnostics {
    private let settingsStore: SettingsStore
    private let portChecker: PortChecker
    private let readyChecker: ReadyChecker
    private let fileManager: FileManager

    init(
        settingsStore: SettingsStore = SettingsStore(),
        portChecker: PortChecker = PortChecker(),
        readyChecker: ReadyChecker = ReadyChecker(),
        fileManager: FileManager = .default
    ) {
        self.settingsStore = settingsStore
        self.portChecker = portChecker
        self.readyChecker = readyChecker
        self.fileManager = fileManager
    }

    func run(
        settings: AppSettings,
        selectedModel: ModelConfig?,
        managedProcessIdentifier: Int32?
    ) async -> [DiagnosticsResult] {
        let endpoint = endpoint(settings: settings, selectedModel: selectedModel)
        var results: [DiagnosticsResult] = []

        results.append(contentsOf: executablePathResults(settings.mlxServerExecutablePath))
        results.append(hostResult(endpoint.host))
        results.append(portResult(endpoint.port))
        results.append(storageResult())
        results.append(
            portAvailabilityResult(
                host: endpoint.host,
                port: endpoint.port,
                managedProcessIdentifier: managedProcessIdentifier
            )
        )
        results.append(await readyResult(host: endpoint.host, port: endpoint.port))

        return results
    }

    private func executablePathResults(_ path: String) -> [DiagnosticsResult] {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return [
                DiagnosticsResult(
                    check: .executablePathConfigured,
                    status: .fail,
                    message: "mlx_lm.server executable path is not set."
                ),
                DiagnosticsResult(
                    check: .executablePathExists,
                    status: .fail,
                    message: "Cannot check existence until the executable path is set."
                ),
                DiagnosticsResult(
                    check: .executablePathExecutable,
                    status: .fail,
                    message: "Cannot check executable permission until the executable path is set."
                )
            ]
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: trimmedPath, isDirectory: &isDirectory)

        guard exists else {
            return [
                DiagnosticsResult(
                    check: .executablePathConfigured,
                    status: .pass,
                    message: "Executable path is configured.",
                    detail: trimmedPath
                ),
                DiagnosticsResult(
                    check: .executablePathExists,
                    status: .fail,
                    message: "File does not exist.",
                    detail: trimmedPath
                ),
                DiagnosticsResult(
                    check: .executablePathExecutable,
                    status: .fail,
                    message: "Cannot check executable permission because the file does not exist.",
                    detail: trimmedPath
                )
            ]
        }

        guard !isDirectory.boolValue else {
            return [
                DiagnosticsResult(
                    check: .executablePathConfigured,
                    status: .pass,
                    message: "Executable path is configured.",
                    detail: trimmedPath
                ),
                DiagnosticsResult(
                    check: .executablePathExists,
                    status: .fail,
                    message: "Path exists but is a directory.",
                    detail: trimmedPath
                ),
                DiagnosticsResult(
                    check: .executablePathExecutable,
                    status: .fail,
                    message: "Directory cannot be used as mlx_lm.server executable.",
                    detail: trimmedPath
                )
            ]
        }

        let isExecutable = fileManager.isExecutableFile(atPath: trimmedPath)

        return [
            DiagnosticsResult(
                check: .executablePathConfigured,
                status: .pass,
                message: "Executable path is configured.",
                detail: trimmedPath
            ),
            DiagnosticsResult(
                check: .executablePathExists,
                status: .pass,
                message: "File exists.",
                detail: trimmedPath
            ),
            DiagnosticsResult(
                check: .executablePathExecutable,
                status: isExecutable ? .pass : .fail,
                message: isExecutable ? "File is executable." : "File is not executable.",
                detail: trimmedPath
            )
        ]
    }

    private func hostResult(_ host: String) -> DiagnosticsResult {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            return DiagnosticsResult(
                check: .hostConfigured,
                status: .fail,
                message: "Host is empty."
            )
        }

        return DiagnosticsResult(
            check: .hostConfigured,
            status: .pass,
            message: "Host is configured.",
            detail: trimmedHost
        )
    }

    private func portResult(_ port: Int) -> DiagnosticsResult {
        guard (1...65535).contains(port) else {
            return DiagnosticsResult(
                check: .portInRange,
                status: .fail,
                message: "Port must be between 1 and 65535.",
                detail: "\(port)"
            )
        }

        return DiagnosticsResult(
            check: .portInRange,
            status: .pass,
            message: "Port is within the valid TCP range.",
            detail: "\(port)"
        )
    }

    private func storageResult() -> DiagnosticsResult {
        do {
            let settingsURL = try settingsStore.settingsFileURL
            let modelsURL = try settingsStore.modelsFileURL
            return DiagnosticsResult(
                check: .settingsStorageLocation,
                status: .pass,
                message: "Settings storage location is available.",
                detail: "\(settingsURL.path), \(modelsURL.path)"
            )
        } catch {
            return DiagnosticsResult(
                check: .settingsStorageLocation,
                status: .fail,
                message: "Could not resolve settings storage location.",
                detail: error.localizedDescription
            )
        }
    }

    private func portAvailabilityResult(
        host: String,
        port: Int,
        managedProcessIdentifier: Int32?
    ) -> DiagnosticsResult {
        switch portChecker.check(host: host, port: port) {
        case let .available(host, port):
            return DiagnosticsResult(
                check: .portAvailability,
                status: .pass,
                message: "Port is available.",
                detail: "\(host):\(port)"
            )
        case let .busy(host, port):
            let message: String
            let detail: String

            if let managedProcessIdentifier {
                message = "Port is busy because the managed server is running."
                detail = "\(host):\(port), pid \(managedProcessIdentifier)"
            } else {
                message = "Port is busy. Another process may be using this port."
                detail = "\(host):\(port)"
            }

            return DiagnosticsResult(
                check: .portAvailability,
                status: .warning,
                message: message,
                detail: detail
            )
        case let .invalidInput(message):
            return DiagnosticsResult(
                check: .portAvailability,
                status: .fail,
                message: "Port check input is invalid.",
                detail: message
            )
        case let .failed(host, port, message):
            return DiagnosticsResult(
                check: .portAvailability,
                status: .fail,
                message: "Port check failed for \(host):\(port).",
                detail: message
            )
        }
    }

    private func readyResult(host: String, port: Int) async -> DiagnosticsResult {
        switch await readyChecker.check(host: host, port: port) {
        case let .ready(url, statusCode):
            return DiagnosticsResult(
                check: .readyCheck,
                status: .pass,
                message: "/v1/models is ready.",
                detail: "\(url.absoluteString) returned HTTP \(statusCode)"
            )
        case let .notReady(url, statusCode):
            return DiagnosticsResult(
                check: .readyCheck,
                status: .warning,
                message: "/v1/models responded but is not ready.",
                detail: "\(url.absoluteString) returned HTTP \(statusCode)"
            )
        case let .invalidInput(message):
            return DiagnosticsResult(
                check: .readyCheck,
                status: .fail,
                message: "Ready check input is invalid.",
                detail: message
            )
        case let .failed(url, message):
            return DiagnosticsResult(
                check: .readyCheck,
                status: .warning,
                message: "/v1/models is not reachable. This is expected when the server is not running.",
                detail: "\(url?.absoluteString ?? "\(host):\(port)"): \(message)"
            )
        case let .timedOut(url):
            return DiagnosticsResult(
                check: .readyCheck,
                status: .warning,
                message: "/v1/models timed out. The server may not be running or may still be loading.",
                detail: url.absoluteString
            )
        }
    }

    private func endpoint(
        settings: AppSettings,
        selectedModel: ModelConfig?
    ) -> (host: String, port: Int) {
        (
            selectedModel?.host ?? settings.defaultHost,
            selectedModel?.serverPort ?? settings.defaultPort
        )
    }
}
