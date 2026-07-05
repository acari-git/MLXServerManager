import Foundation

struct AppSettings: Codable, Hashable {
    var mlxServerExecutablePath: String
    var defaultHost: String
    var defaultPort: Int
    var apiKeyPlaceholder: String
    var hermesConfigPath: String
    var downloadSaveDirectory: String
    var downloadAutoAddToModelList: Bool
    var downloadAutoSelectAfterAdd: Bool
    var maxConcurrentModelDownloads: Int
    var confirmFilesBeforeDownload: Bool
    var uiLanguage: AppLanguage
    var uiAppearance: String

    static let defaults = AppSettings(
        mlxServerExecutablePath: "",
        defaultHost: "127.0.0.1",
        defaultPort: 8080,
        apiKeyPlaceholder: "not-required-local",
        hermesConfigPath: "~/.hermes/config.yaml",
        downloadSaveDirectory: "~/Models/mlx",
        downloadAutoAddToModelList: true,
        downloadAutoSelectAfterAdd: true,
        maxConcurrentModelDownloads: 2,
        confirmFilesBeforeDownload: false,
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
        downloadAutoAddToModelList: Bool = true,
        downloadAutoSelectAfterAdd: Bool = true,
        maxConcurrentModelDownloads: Int = 2,
        confirmFilesBeforeDownload: Bool = false,
        uiLanguage: AppLanguage = .system,
        uiAppearance: String = "system"
    ) {
        self.mlxServerExecutablePath = mlxServerExecutablePath
        self.defaultHost = defaultHost
        self.defaultPort = defaultPort
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.hermesConfigPath = hermesConfigPath
        self.downloadSaveDirectory = downloadSaveDirectory
        self.downloadAutoAddToModelList = downloadAutoAddToModelList
        self.downloadAutoSelectAfterAdd = downloadAutoSelectAfterAdd
        self.maxConcurrentModelDownloads = min(max(maxConcurrentModelDownloads, 1), 5)
        self.confirmFilesBeforeDownload = confirmFilesBeforeDownload
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
        case downloadAutoAddToModelList
        case downloadAutoSelectAfterAdd
        case maxConcurrentModelDownloads
        case confirmFilesBeforeDownload
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
        downloadAutoAddToModelList = try container.decodeIfPresent(Bool.self, forKey: .downloadAutoAddToModelList) ?? true
        downloadAutoSelectAfterAdd = try container.decodeIfPresent(Bool.self, forKey: .downloadAutoSelectAfterAdd) ?? true
        let decodedConcurrentDownloads = try container.decodeIfPresent(Int.self, forKey: .maxConcurrentModelDownloads) ?? 2
        maxConcurrentModelDownloads = min(max(decodedConcurrentDownloads, 1), 5)
        confirmFilesBeforeDownload = try container.decodeIfPresent(Bool.self, forKey: .confirmFilesBeforeDownload) ?? false
        uiLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .uiLanguage) ?? .system
        uiAppearance = try container.decodeIfPresent(String.self, forKey: .uiAppearance) ?? "system"
    }
}
