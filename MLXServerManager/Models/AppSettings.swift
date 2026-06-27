import Foundation

struct AppSettings: Codable, Hashable {
    var mlxServerExecutablePath: String
    var defaultHost: String
    var defaultPort: Int
    var apiKeyPlaceholder: String
    var uiLanguage: AppLanguage
    var uiAccentColor: String
    var uiAppearance: String

    static let defaults = AppSettings(
        mlxServerExecutablePath: "",
        defaultHost: "127.0.0.1",
        defaultPort: 8080,
        apiKeyPlaceholder: "not-required-local",
        uiLanguage: .system,
        uiAccentColor: "blue",
        uiAppearance: "system"
    )

    init(
        mlxServerExecutablePath: String,
        defaultHost: String,
        defaultPort: Int,
        apiKeyPlaceholder: String,
        uiLanguage: AppLanguage = .system,
        uiAccentColor: String = "blue",
        uiAppearance: String = "system"
    ) {
        self.mlxServerExecutablePath = mlxServerExecutablePath
        self.defaultHost = defaultHost
        self.defaultPort = defaultPort
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.uiLanguage = uiLanguage
        self.uiAccentColor = uiAccentColor
        self.uiAppearance = uiAppearance
    }

    private enum CodingKeys: String, CodingKey {
        case mlxServerExecutablePath
        case defaultHost
        case defaultPort
        case apiKeyPlaceholder
        case uiLanguage
        case uiAccentColor
        case uiAppearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mlxServerExecutablePath = try container.decode(String.self, forKey: .mlxServerExecutablePath)
        defaultHost = try container.decode(String.self, forKey: .defaultHost)
        defaultPort = try container.decode(Int.self, forKey: .defaultPort)
        apiKeyPlaceholder = try container.decode(String.self, forKey: .apiKeyPlaceholder)
        uiLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .uiLanguage) ?? .system
        uiAccentColor = try container.decodeIfPresent(String.self, forKey: .uiAccentColor) ?? "blue"
        uiAppearance = try container.decodeIfPresent(String.self, forKey: .uiAppearance) ?? "system"
    }
}

