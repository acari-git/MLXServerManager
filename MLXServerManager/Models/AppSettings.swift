import Foundation

struct AppSettings: Codable, Hashable {
    var mlxServerExecutablePath: String
    var defaultHost: String
    var defaultPort: Int
    var apiKeyPlaceholder: String
    var hermesConfigPath: String
    var downloadSaveDirectory: String
    var maxConcurrentModelDownloads: Int
    var autoUnloadEnabledByModelID: [String: Bool]
    var autoUnloadMinutesByModelID: [String: Int]
    var uiLanguage: AppLanguage
    var uiAppearance: String

    static let defaults = AppSettings(
        mlxServerExecutablePath: "",
        defaultHost: "127.0.0.1",
        defaultPort: 8080,
        apiKeyPlaceholder: "not-required-local",
        hermesConfigPath: "~/.hermes/config.yaml",
        downloadSaveDirectory: "~/Models/mlx",
        maxConcurrentModelDownloads: 2,
        autoUnloadEnabledByModelID: [:],
        autoUnloadMinutesByModelID: [:],
        uiLanguage: .system,
        uiAppearance: "system"
    )

    init(
        mlxServerExecutablePath: String,
        defaultHost: String,
        defaultPort: Int,
        apiKeyPlaceholder: String,
        hermesConfigPath: String = "~/.hermes/config.yaml",
        downloadSaveDirectory: String = "~/Models/mlx",
        maxConcurrentModelDownloads: Int = 2,
        autoUnloadEnabledByModelID: [String: Bool] = [:],
        autoUnloadMinutesByModelID: [String: Int] = [:],
        uiLanguage: AppLanguage = .system,
        uiAppearance: String = "system"
    ) {
        self.mlxServerExecutablePath = mlxServerExecutablePath
        self.defaultHost = defaultHost
        self.defaultPort = defaultPort
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.hermesConfigPath = hermesConfigPath
        self.downloadSaveDirectory = downloadSaveDirectory
        self.maxConcurrentModelDownloads = min(max(maxConcurrentModelDownloads, 1), 5)
        self.autoUnloadEnabledByModelID = autoUnloadEnabledByModelID
        self.autoUnloadMinutesByModelID = autoUnloadMinutesByModelID.mapValues { min(max($0, 1), 999) }
        self.uiLanguage = uiLanguage
        self.uiAppearance = uiAppearance
    }

    private enum CodingKeys: String, CodingKey {
        case mlxServerExecutablePath
        case defaultHost
        case defaultPort
        case apiKeyPlaceholder
        case hermesConfigPath
        case downloadSaveDirectory
        case maxConcurrentModelDownloads
        case autoUnloadEnabledByModelID
        case autoUnloadMinutesByModelID
        case uiLanguage
        case uiAppearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mlxServerExecutablePath = try container.decode(String.self, forKey: .mlxServerExecutablePath)
        defaultHost = try container.decode(String.self, forKey: .defaultHost)
        defaultPort = try container.decode(Int.self, forKey: .defaultPort)
        apiKeyPlaceholder = try container.decode(String.self, forKey: .apiKeyPlaceholder)
        hermesConfigPath = try container.decodeIfPresent(String.self, forKey: .hermesConfigPath) ?? "~/.hermes/config.yaml"
        downloadSaveDirectory = try container.decodeIfPresent(String.self, forKey: .downloadSaveDirectory) ?? "~/Models/mlx"
        let decodedConcurrentDownloads = try container.decodeIfPresent(Int.self, forKey: .maxConcurrentModelDownloads) ?? 2
        maxConcurrentModelDownloads = min(max(decodedConcurrentDownloads, 1), 5)
        autoUnloadEnabledByModelID = try container.decodeIfPresent([String: Bool].self, forKey: .autoUnloadEnabledByModelID) ?? [:]
        let decodedAutoUnloadMinutes = try container.decodeIfPresent([String: Int].self, forKey: .autoUnloadMinutesByModelID) ?? [:]
        autoUnloadMinutesByModelID = decodedAutoUnloadMinutes.mapValues { min(max($0, 1), 999) }
        uiLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .uiLanguage) ?? .system
        uiAppearance = try container.decodeIfPresent(String.self, forKey: .uiAppearance) ?? "system"
    }
}
