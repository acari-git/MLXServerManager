import Foundation

enum ModelRuntimeState: Hashable {
    case stopped

    var title: String {
        switch self {
        case .stopped:
            "Stopped"
        }
    }

    var detail: String {
        switch self {
        case .stopped:
            "mlx_lm.server is not running. Start / Stop / Restart wiring will be added after the UI skeleton is stable."
        }
    }

    var badgeDetail: String {
        switch self {
        case .stopped:
            "No process attached"
        }
    }
}

