import Foundation

enum ModelRuntimeState: Hashable {
    case stopped
    case starting(host: String, port: Int)
    case loading(host: String, port: Int, processIdentifier: Int32)
    case checkingPort(host: String, port: Int)
    case portAvailable(host: String, port: Int)
    case portBusy(host: String, port: Int)
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
        case .checkingPort:
            "Checking Port"
        case .portAvailable:
            "Port Available"
        case .portBusy:
            "Port Busy"
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
            "mlx_lm.server is not running. Start is available; Stop and Restart are not implemented yet."
        case let .starting(host, port):
            "Starting managed mlx_lm.server for \(host):\(port)."
        case let .loading(host, port, processIdentifier):
            "Managed process pid \(processIdentifier) is loading at \(host):\(port)."
        case let .checkingPort(host, port):
            "Checking whether \(host):\(port) can be used before launch."
        case let .portAvailable(host, port):
            "\(host):\(port) is available for mlx_lm.server launch."
        case let .portBusy(host, port):
            "\(host):\(port) is already in use. Start will not launch a second server on this port."
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
        case let .checkingPort(host, port):
            "\(host):\(port)"
        case let .portAvailable(host, port):
            "\(host):\(port)"
        case let .portBusy(host, port):
            "\(host):\(port)"
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

}
