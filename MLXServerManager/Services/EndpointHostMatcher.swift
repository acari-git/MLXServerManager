import Foundation

nonisolated enum EndpointHostMatcher {
    static func normalized(_ host: String) -> String {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedHost == "localhost" ? "127.0.0.1" : normalizedHost
    }

    static func conflicts(_ firstHost: String, _ secondHost: String) -> Bool {
        let first = normalized(firstHost)
        let second = normalized(secondHost)
        return first == second || first == "0.0.0.0" || second == "0.0.0.0"
    }
}
