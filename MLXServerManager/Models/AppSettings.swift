import Foundation

nonisolated struct AppSettings: Codable, Hashable {
    var mlxServerExecutablePath: String
    var rapidMLXExecutablePath: String
    var defaultHost: String
    var defaultPort: Int
    var apiKeyPlaceholder: String
    var hermesConfigPath: String
    var downloadSaveDirectory: String
    var maxConcurrentModelDownloads: Int
    var autoUnloadEnabledByModelID: [String: Bool]
    var autoUnloadMinutesByModelID: [String: Int]
    var benchmarkPreset: BenchmarkPreset
    var uiLanguage: AppLanguage
    var uiAppearance: String

    static let defaults = AppSettings(
        mlxServerExecutablePath: "",
        rapidMLXExecutablePath: "",
        defaultHost: "127.0.0.1",
        defaultPort: 8080,
        apiKeyPlaceholder: "not-required-local",
        hermesConfigPath: "~/.hermes/config.yaml",
        downloadSaveDirectory: "~/Models/mlx",
        maxConcurrentModelDownloads: 2,
        autoUnloadEnabledByModelID: [:],
        autoUnloadMinutesByModelID: [:],
        benchmarkPreset: .standard,
        uiLanguage: .system,
        uiAppearance: "system"
    )

    init(
        mlxServerExecutablePath: String,
        rapidMLXExecutablePath: String = "",
        defaultHost: String,
        defaultPort: Int,
        apiKeyPlaceholder: String,
        hermesConfigPath: String = "~/.hermes/config.yaml",
        downloadSaveDirectory: String = "~/Models/mlx",
        maxConcurrentModelDownloads: Int = 2,
        autoUnloadEnabledByModelID: [String: Bool] = [:],
        autoUnloadMinutesByModelID: [String: Int] = [:],
        benchmarkPreset: BenchmarkPreset = .standard,
        uiLanguage: AppLanguage = .system,
        uiAppearance: String = "system"
    ) {
        self.mlxServerExecutablePath = mlxServerExecutablePath
        self.rapidMLXExecutablePath = rapidMLXExecutablePath
        self.defaultHost = defaultHost
        self.defaultPort = defaultPort
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.hermesConfigPath = hermesConfigPath
        self.downloadSaveDirectory = downloadSaveDirectory
        self.maxConcurrentModelDownloads = min(max(maxConcurrentModelDownloads, 1), 5)
        self.autoUnloadEnabledByModelID = autoUnloadEnabledByModelID
        self.autoUnloadMinutesByModelID = autoUnloadMinutesByModelID.mapValues { min(max($0, 1), 999) }
        self.benchmarkPreset = benchmarkPreset
        self.uiLanguage = uiLanguage
        self.uiAppearance = uiAppearance
    }

    private enum CodingKeys: String, CodingKey {
        case mlxServerExecutablePath
        case rapidMLXExecutablePath
        case defaultHost
        case defaultPort
        case apiKeyPlaceholder
        case hermesConfigPath
        case downloadSaveDirectory
        case maxConcurrentModelDownloads
        case autoUnloadEnabledByModelID
        case autoUnloadMinutesByModelID
        case benchmarkPreset
        case uiLanguage
        case uiAppearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mlxServerExecutablePath = try container.decode(String.self, forKey: .mlxServerExecutablePath)
        rapidMLXExecutablePath = try container.decodeIfPresent(String.self, forKey: .rapidMLXExecutablePath) ?? ""
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
        benchmarkPreset = try container.decodeIfPresent(BenchmarkPreset.self, forKey: .benchmarkPreset) ?? .standard
        uiLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .uiLanguage) ?? .system
        uiAppearance = try container.decodeIfPresent(String.self, forKey: .uiAppearance) ?? "system"
    }

    func executablePath(for backend: InferenceBackend) -> String {
        switch backend {
        case .mlxLM:
            mlxServerExecutablePath
        case .rapidMLX:
            rapidMLXExecutablePath
        }
    }
}
