import Foundation

enum DiagnosticsCheck: String, CaseIterable, Hashable {
    case executablePathConfigured
    case executablePathExists
    case executablePathExecutable
    case hostConfigured
    case portInRange
    case settingsStorageLocation
    case portAvailability
    case readyCheck

    var title: String {
        switch self {
        case .executablePathConfigured:
            "Executable path configured"
        case .executablePathExists:
            "Executable path exists"
        case .executablePathExecutable:
            "Executable path executable"
        case .hostConfigured:
            "Host configured"
        case .portInRange:
            "Port in range"
        case .settingsStorageLocation:
            "Settings storage location"
        case .portAvailability:
            "Port availability"
        case .readyCheck:
            "Ready check"
        }
    }
}
