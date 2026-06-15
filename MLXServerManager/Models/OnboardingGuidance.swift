import Foundation

struct OnboardingGuidance: Hashable {
    enum Tone: Hashable {
        case setup
        case neutral
        case ready
        case warning
    }

    var title: String
    var tone: Tone
    var messages: [String]
    var actionHints: [String]

    var directModeNote: String {
        "Direct Mode: OpenAI-compatible client -> server -> MLX model."
    }

    var proxyBoundaryNote: String {
        "MLX Server Manager does not proxy inference requests."
    }
}
