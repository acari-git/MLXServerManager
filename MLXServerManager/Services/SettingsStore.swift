import Foundation

nonisolated struct SettingsSnapshot {
    var settings: AppSettings
    var models: [ModelConfig]
    var usedDefaults: Bool
}

private nonisolated struct PersistedSettingsSnapshot: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let settings: AppSettings
    let models: [ModelConfig]

    init(settings: AppSettings, models: [ModelConfig]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.settings = settings
        self.models = models
    }
}

nonisolated enum SettingsStoreError: LocalizedError {
    case applicationSupportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            "Application Support directory is unavailable."
        }
    }
}

nonisolated struct SettingsStore {
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

    var benchmarkResultsFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("benchmark-results.json", isDirectory: false)
        }
    }

    var stateSnapshotFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("settings-state.json", isDirectory: false)
        }
    }

    func load() throws -> SettingsSnapshot {
        if let persistedSnapshot = try loadPersistedSnapshot() {
            let models = persistedSnapshot.models.isEmpty ? ModelConfig.defaults : persistedSnapshot.models
            return SettingsSnapshot(
                settings: persistedSnapshot.settings,
                models: models,
                usedDefaults: persistedSnapshot.models.isEmpty
            )
        }

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
        let snapshot = PersistedSettingsSnapshot(settings: settings, models: models)

        // The combined snapshot is the authoritative atomic state. The two legacy
        // files remain as human-readable compatibility mirrors.
        try save(snapshot, to: try stateSnapshotFileURL)
        try save(settings, to: try settingsFileURL)
        try save(models, to: try modelsFileURL)
    }

    func save(models: [ModelConfig]) throws {
        let currentSettings = try load().settings
        try save(settings: currentSettings, models: models)
    }

    func loadBenchmarkResults() throws -> (value: BenchmarkResultsSnapshot, usedDefault: Bool) {
        let url = try benchmarkResultsFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return (.empty, true)
        }

        let data = try Data(contentsOf: url)
        return (try decoder.decode(BenchmarkResultsSnapshot.self, from: data), false)
    }

    func save(benchmarkResults: BenchmarkResultsSnapshot) throws {
        try ensureSettingsDirectoryExists()
        try save(benchmarkResults, to: try benchmarkResultsFileURL)
    }

    private func loadPersistedSnapshot() throws -> PersistedSettingsSnapshot? {
        let url = try stateSnapshotFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(PersistedSettingsSnapshot.self, from: data)
        } catch {
            // Recover from an interrupted or externally edited snapshot by using
            // the legacy mirrors. The next successful save recreates the snapshot.
            return nil
        }
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
