import Foundation

enum ModelRuntimeState: Hashable {
    case stopped
    case starting(host: String, port: Int)
    case loading(host: String, port: Int, processIdentifier: Int32)
    case stopping(processIdentifier: Int32)
    case checkingPort(host: String, port: Int)
    case portAvailable(host: String, port: Int)
    case portBusy(host: String, port: Int)
    case externalServerDetected(host: String, port: Int, baseURL: String, message: String)
    case adoptedExternalServer(host: String, port: Int, baseURL: String, message: String)
    case portCheckFailed(host: String, port: Int, message: String)
    case checkingReady(host: String, port: Int)
    case ready(host: String, port: Int, processIdentifier: Int32?)
    case readyCheckFailed(host: String, port: Int, message: String)
    case error(message: String)
    case unknown(message: String)

    var title: String {
        switch self {
        case .stopped:
            "Stopped"
        case .starting:
            "Starting"
        case .loading:
            "Loading"
        case .stopping:
            "Stopping"
        case .checkingPort:
            "Checking Port"
        case .portAvailable:
            "Port Available"
        case .portBusy:
            "Port Busy"
        case .externalServerDetected:
            "External Server Detected"
        case .adoptedExternalServer:
            "Adopted External Server"
        case .portCheckFailed:
            "Port Check Failed"
        case .checkingReady:
            "Checking Ready"
        case .ready:
            "Ready"
        case .readyCheckFailed:
            "Ready Check Failed"
        case .error:
            "Error"
        case .unknown:
            "Unknown"
        }
    }

    var detail: String {
        switch self {
        case .stopped:
            "mlx_lm.server is not running. Start, Stop, and Restart are available."
        case let .starting(host, port):
            "Starting managed mlx_lm.server for \(host):\(port)."
        case let .loading(host, port, processIdentifier):
            "Managed process pid \(processIdentifier) is loading at \(host):\(port)."
        case let .stopping(processIdentifier):
            "Stopping managed mlx_lm.server process pid \(processIdentifier)."
        case let .checkingPort(host, port):
            "Checking whether \(host):\(port) can be used before launch."
        case let .portAvailable(host, port):
            "\(host):\(port) is available for mlx_lm.server launch."
        case let .portBusy(host, port):
            "\(host):\(port) is already in use. Start will not launch a second server on this port."
        case let .externalServerDetected(host, port, baseURL, message):
            "\(message) \(baseURL) is ready at \(host):\(port). This server was not started by MLX Server Manager."
        case let .adoptedExternalServer(host, port, baseURL, message):
            "\(message) \(baseURL) is the adopted connection context at \(host):\(port). This server is not managed by MLX Server Manager."
        case let .portCheckFailed(host, port, message):
            "Could not check \(host):\(port): \(message)"
        case let .checkingReady(host, port):
            "Checking http://\(host):\(port)/v1/models."
        case let .ready(host, port, processIdentifier):
            if let processIdentifier {
                "OpenAI-compatible endpoint is responding at \(host):\(port). Managed pid \(processIdentifier)."
            } else {
                "OpenAI-compatible endpoint is responding at \(host):\(port)."
            }
        case let .readyCheckFailed(host, port, message):
            "Ready check failed for \(host):\(port): \(message)"
        case let .error(message):
            message
        case let .unknown(message):
            message
        }
    }

    var badgeDetail: String {
        switch self {
        case .stopped:
            "No process attached"
        case let .starting(host, port):
            "\(host):\(port)"
        case let .loading(host, port, processIdentifier):
            "\(host):\(port), pid \(processIdentifier)"
        case let .stopping(processIdentifier):
            "pid \(processIdentifier)"
        case let .checkingPort(host, port):
            "\(host):\(port)"
        case let .portAvailable(host, port):
            "\(host):\(port)"
        case let .portBusy(host, port):
            "\(host):\(port)"
        case let .externalServerDetected(host, port, _, _):
            "\(host):\(port), external"
        case let .adoptedExternalServer(host, port, _, _):
            "\(host):\(port), adopted external"
        case let .portCheckFailed(host, port, _):
            "\(host):\(port)"
        case let .checkingReady(host, port):
            "\(host):\(port)"
        case let .ready(host, port, processIdentifier):
            if let processIdentifier {
                "\(host):\(port), pid \(processIdentifier)"
            } else {
                "\(host):\(port)"
            }
        case let .readyCheckFailed(host, port, _):
            "\(host):\(port)"
        case .error:
            "Action failed"
        case .unknown:
            "Check logs"
        }
    }

    var menuBarStatus: String {
        switch self {
        case .stopped, .portAvailable:
            "stopped"
        case .starting, .loading, .checkingPort, .checkingReady:
            "starting"
        case .ready, .externalServerDetected, .adoptedExternalServer:
            "ready"
        case .stopping:
            "stopping"
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            "failed"
        }
    }

    var isExternalServerDetected: Bool {
        if case .externalServerDetected = self {
            return true
        }

        return false
    }

    var isAdoptedExternalServer: Bool {
        if case .adoptedExternalServer = self {
            return true
        }

        return false
    }

    var isExternalServerContext: Bool {
        isExternalServerDetected || isAdoptedExternalServer
    }

}
