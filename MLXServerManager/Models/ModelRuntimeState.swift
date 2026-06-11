import Foundation

enum ModelRuntimeState: Hashable {
    case stopped
    case checkingPort(host: String, port: Int)
    case portAvailable(host: String, port: Int)
    case portBusy(host: String, port: Int)
    case portCheckFailed(host: String, port: Int, message: String)

    var title: String {
        switch self {
        case .stopped:
            "Stopped"
        case .checkingPort:
            "Checking Port"
        case .portAvailable:
            "Port Available"
        case .portBusy:
            "Port Busy"
        case .portCheckFailed:
            "Port Check Failed"
        }
    }

    var detail: String {
        switch self {
        case .stopped:
            "mlx_lm.server is not running. Start / Stop / Restart wiring will be added after the UI skeleton is stable."
        case let .checkingPort(host, port):
            "Checking whether \(host):\(port) can be used before launch."
        case let .portAvailable(host, port):
            "\(host):\(port) is available for a future mlx_lm.server launch."
        case let .portBusy(host, port):
            "\(host):\(port) is already in use. Start is still not implemented."
        case let .portCheckFailed(host, port, message):
            "Could not check \(host):\(port): \(message)"
        }
    }

    var badgeDetail: String {
        switch self {
        case .stopped:
            "No process attached"
        case let .checkingPort(host, port):
            "\(host):\(port)"
        case let .portAvailable(host, port):
            "\(host):\(port)"
        case let .portBusy(host, port):
            "\(host):\(port)"
        case let .portCheckFailed(host, port, _):
            "\(host):\(port)"
        }
    }

}
