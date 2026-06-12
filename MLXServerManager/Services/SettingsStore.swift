import Foundation

struct SettingsSnapshot {
    var settings: AppSettings
    var models: [ModelConfig]
    var usedDefaults: Bool
}

enum SettingsStoreError: LocalizedError {
    case applicationSupportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            "Application Support directory is unavailable."
        }
    }
}

struct SettingsStore {
    let fileManager: FileManager
    let appDirectoryName: String

    init(
        fileManager: FileManager = .default,
        appDirectoryName: String = "MLX Server Manager"
    ) {
        self.fileManager = fileManager
        self.appDirectoryName = appDirectoryName
    }

    var settingsDirectoryURL: URL {
        get throws {
            guard let applicationSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw SettingsStoreError.applicationSupportDirectoryUnavailable
            }

            return applicationSupportURL.appendingPathComponent(appDirectoryName, isDirectory: true)
        }
    }

    var settingsFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("settings.json", isDirectory: false)
        }
    }

    var modelsFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("models.json", isDirectory: false)
        }
    }

    func load() throws -> SettingsSnapshot {
        let settings = try loadSettings()
        let models = try loadModels()

        return SettingsSnapshot(
            settings: settings.value,
            models: models.value,
            usedDefaults: settings.usedDefault || models.usedDefault
        )
    }

    func save(settings: AppSettings, models: [ModelConfig]) throws {
        try ensureSettingsDirectoryExists()
        try save(settings, to: try settingsFileURL)
        try save(models, to: try modelsFileURL)
    }

    func save(models: [ModelConfig]) throws {
        try ensureSettingsDirectoryExists()
        try save(models, to: try modelsFileURL)
    }

    private func loadSettings() throws -> (value: AppSettings, usedDefault: Bool) {
        let url = try settingsFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return (.defaults, true)
        }

        let data = try Data(contentsOf: url)
        return (try decoder.decode(AppSettings.self, from: data), false)
    }

    private func loadModels() throws -> (value: [ModelConfig], usedDefault: Bool) {
        let url = try modelsFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return (ModelConfig.defaults, true)
        }

        let data = try Data(contentsOf: url)
        let models = try decoder.decode([ModelConfig].self, from: data)
        return (models.isEmpty ? ModelConfig.defaults : models, models.isEmpty)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func ensureSettingsDirectoryExists() throws {
        try fileManager.createDirectory(
            at: try settingsDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }
}
