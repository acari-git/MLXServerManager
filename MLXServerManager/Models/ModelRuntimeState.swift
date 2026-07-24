import Foundation

nonisolated enum ModelRuntimeState: Hashable, Sendable {
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
    case degraded(host: String, port: Int, processIdentifier: Int32?, message: String)
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
        case .degraded:
            "Degraded"
        case .readyCheckFailed:
            "Ready Check Failed"
        case .error:
            "Error"
        case .unknown:
            "Unknown"
        }
    }

    func localizedTitle(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return title
        }

        switch self {
        case .stopped:
            return "停止"
        case .starting:
            return "起動中"
        case .loading:
            return "ロード中"
        case .stopping:
            return "停止中"
        case .checkingPort:
            return "ポート確認中"
        case .portAvailable:
            return "ポート利用可能"
        case .portBusy:
            return "ポート使用中"
        case .externalServerDetected:
            return "外部サーバー検出"
        case .adoptedExternalServer:
            return "外部サーバー採用済み"
        case .portCheckFailed:
            return "ポート確認失敗"
        case .checkingReady:
            return "Ready確認中"
        case .ready:
            return "準備完了"
        case .degraded:
            return "異常"
        case .readyCheckFailed:
            return "Ready確認失敗"
        case .error:
            return "エラー"
        case .unknown:
            return "不明"
        }
    }

    var detail: String {
        switch self {
        case .stopped:
            "No managed inference server is running. Start, Stop, and Restart are available."
        case let .starting(host, port):
            "Starting managed inference server for \(host):\(port)."
        case let .loading(host, port, processIdentifier):
            "Managed process pid \(processIdentifier) is loading at \(host):\(port)."
        case let .stopping(processIdentifier):
            "Stopping managed inference server process pid \(processIdentifier)."
        case let .checkingPort(host, port):
            "Checking whether \(host):\(port) can be used before launch."
        case let .portAvailable(host, port):
            "\(host):\(port) is available for managed server launch."
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
        case let .degraded(host, port, processIdentifier, message):
            if let processIdentifier {
                "\(message) Managed pid \(processIdentifier) remains active at \(host):\(port)."
            } else {
                "\(message) The managed endpoint remains active at \(host):\(port)."
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
        case let .degraded(host, port, processIdentifier, _):
            if let processIdentifier {
                "\(host):\(port), pid \(processIdentifier), degraded"
            } else {
                "\(host):\(port), degraded"
            }
        case let .readyCheckFailed(host, port, _):
            "\(host):\(port)"
        case .error:
            "Action failed"
        case .unknown:
            "Check logs"
        }
    }

    func localizedBadgeDetail(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return badgeDetail
        }

        switch self {
        case .stopped:
            return "プロセス未接続"
        case let .starting(host, port),
             let .checkingPort(host, port),
             let .portAvailable(host, port),
             let .portBusy(host, port),
             let .portCheckFailed(host, port, _),
             let .checkingReady(host, port),
             let .readyCheckFailed(host, port, _):
            return "\(host):\(port)"
        case let .loading(host, port, processIdentifier):
            return "\(host):\(port), pid \(processIdentifier)"
        case let .stopping(processIdentifier):
            return "pid \(processIdentifier)"
        case let .externalServerDetected(host, port, _, _):
            return "\(host):\(port), 外部"
        case let .adoptedExternalServer(host, port, _, _):
            return "\(host):\(port), 採用済み外部"
        case let .ready(host, port, processIdentifier):
            if let processIdentifier {
                return "\(host):\(port), pid \(processIdentifier)"
            }
            return "\(host):\(port)"
        case let .degraded(host, port, processIdentifier, _):
            if let processIdentifier {
                return "\(host):\(port), pid \(processIdentifier), 異常"
            }
            return "\(host):\(port), 異常"
        case .error:
            return "操作失敗"
        case .unknown:
            return "ログを確認"
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
        case .degraded, .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            "failed"
        }
    }

    func localizedMenuBarStatus(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return menuBarStatus
        }

        switch self {
        case .stopped, .portAvailable:
            return "停止"
        case .starting, .loading, .checkingPort, .checkingReady:
            return "起動中"
        case .ready, .externalServerDetected, .adoptedExternalServer:
            return "準備完了"
        case .stopping:
            return "停止中"
        case .degraded, .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            return "失敗"
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

    var isDegraded: Bool {
        if case .degraded = self {
            return true
        }

        return false
    }

}
