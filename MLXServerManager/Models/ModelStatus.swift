import Foundation

enum ModelStatus: String, Codable, Hashable {
    case verified = "Verified"
    case candidate = "Candidate"

    var detail: String {
        switch self {
        case .verified:
            "Confirmed for local MLX use."
        case .candidate:
            "Configured as a future selectable profile."
        }
    }
}
