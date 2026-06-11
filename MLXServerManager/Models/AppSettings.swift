import Foundation

struct AppSettings: Codable, Hashable {
    var mlxServerExecutablePath: String
    var defaultHost: String
    var defaultPort: Int
    var apiKeyPlaceholder: String

    static let defaults = AppSettings(
        mlxServerExecutablePath: "",
        defaultHost: "127.0.0.1",
        defaultPort: 8080,
        apiKeyPlaceholder: "not-required-local"
    )
}

