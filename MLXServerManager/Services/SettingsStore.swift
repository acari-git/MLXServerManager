import Foundation

nonisolated struct SettingsSnapshot {
    var settings: AppSettings
    var models: [ModelConfig]
    var usedDefaults: Bool
    var recoveryNotice: String?
}

nonisolated struct SettingsSaveOutcome: Equatable {
    let mirrorWarnings: [String]
    let recoveryWarnings: [String]

    var hasWarnings: Bool {
        !allWarnings.isEmpty
    }

    var allWarnings: [String] {
        recoveryWarnings + mirrorWarnings
    }
}

private nonisolated struct PersistedSettingsSnapshot: Codable {
    static let currentSchemaVersion = 3

    let schemaVersion: Int
    let settings: AppSettings
    let models: [ModelConfig]

    init(settings: AppSettings, models: [ModelConfig]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.settings = settings
        self.models = models
    }
}

private nonisolated struct PersistedSettingsSnapshotV1: Codable {
    let schemaVersion: Int
    let settings: AppSettings
    let models: [ModelConfig]
}

private nonisolated struct PersistedSettingsSnapshotV2: Codable {
    let schemaVersion: Int
    let settings: AppSettings
    let models: [ModelConfig]
}

private nonisolated struct PersistedSettingsSchemaEnvelope: Codable {
    let schemaVersion: Int
}

private nonisolated struct DecodedPersistedSettingsSnapshot {
    let snapshot: PersistedSettingsSnapshot
    let sourceSchemaVersion: Int
}

nonisolated enum SettingsStoreError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case authoritativeStateCorrupted
    case saveBlockedAfterLoadFailure(String)
    case unsupportedStateSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            "Application Support directory is unavailable."
        case .authoritativeStateCorrupted:
            "The authoritative settings state and its recovery backup could not be decoded. Compatibility mirrors were not loaded because they may be stale."
        case let .saveBlockedAfterLoadFailure(reason):
            "Saving is blocked because settings failed to load earlier in this app session. Existing files were left unchanged. Restore the settings files or restart the app before saving. Load error: \(reason)"
        case let .unsupportedStateSchemaVersion(version):
            "The settings state uses unsupported schema version \(version)."
        }
    }
}

nonisolated final class SettingsStoreTransactionCoordinator: @unchecked Sendable {
    private enum State {
        case unverified
        case writable
        case blocked(String)
    }

    private let lock = NSRecursiveLock()
    private var state: State = .unverified

    func performLoad<Result>(_ operation: () throws -> Result) throws -> Result {
        lock.lock()
        defer { lock.unlock() }
        do {
            let result = try operation()
            if case .unverified = state {
                state = .writable
            }
            return result
        } catch {
            state = .blocked(error.localizedDescription)
            throw error
        }
    }

    func performSave<Result>(_ operation: () throws -> Result) throws -> Result {
        lock.lock()
        defer { lock.unlock() }
        try validateSaveLocked()
        let result = try operation()
        state = .writable
        return result
    }

    func performReadModifyWrite<ReadResult, WriteResult>(
        read: () throws -> ReadResult,
        write: (ReadResult) throws -> WriteResult
    ) throws -> WriteResult {
        lock.lock()
        defer { lock.unlock() }
        try validateSaveLocked()

        let readResult: ReadResult
        do {
            readResult = try read()
        } catch {
            state = .blocked(error.localizedDescription)
            throw error
        }

        let result = try write(readResult)
        state = .writable
        return result
    }

    private func validateSaveLocked() throws {
        guard case let .blocked(reason) = state else { return }
        throw SettingsStoreError.saveBlockedAfterLoadFailure(reason)
    }
}

private nonisolated final class SettingsStoreCoordinatorRegistry: @unchecked Sendable {
    static let shared = SettingsStoreCoordinatorRegistry()

    private let lock = NSLock()
    private var coordinators: [String: SettingsStoreTransactionCoordinator] = [:]

    func coordinator(for key: String) -> SettingsStoreTransactionCoordinator {
        lock.lock()
        defer { lock.unlock() }
        if let coordinator = coordinators[key] {
            return coordinator
        }
        let coordinator = SettingsStoreTransactionCoordinator()
        coordinators[key] = coordinator
        return coordinator
    }
}

private nonisolated struct LoadedPersistedSettingsSnapshot {
    let snapshot: PersistedSettingsSnapshot
    let recoveryNotice: String?
}

nonisolated struct SettingsStore {
    let fileManager: FileManager
    let appDirectoryName: String
    private let transactionCoordinator: SettingsStoreTransactionCoordinator

    init(
        fileManager: FileManager = .default,
        appDirectoryName: String = "MLX Server Manager"
    ) {
        self.fileManager = fileManager
        self.appDirectoryName = appDirectoryName
        let directoryKey = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent(appDirectoryName, isDirectory: true)
            .resolvingSymlinksInPath()
            .path ?? appDirectoryName
        self.transactionCoordinator = SettingsStoreCoordinatorRegistry.shared.coordinator(
            for: directoryKey
        )
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

    var huggingFaceDownloadRetriesFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("download-retries.json", isDirectory: false)
        }
    }

    var stateSnapshotFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("settings-state.json", isDirectory: false)
        }
    }

    var stateSnapshotBackupFileURL: URL {
        get throws {
            try settingsDirectoryURL.appendingPathComponent("settings-state.backup.json", isDirectory: false)
        }
    }

    func load() throws -> SettingsSnapshot {
        try transactionCoordinator.performLoad {
            try loadUnlocked()
        }
    }

    @discardableResult
    func save(settings: AppSettings, models: [ModelConfig]) throws -> SettingsSaveOutcome {
        try transactionCoordinator.performSave {
            try saveUnlocked(settings: settings, models: models)
        }
    }

    @discardableResult
    func save(models: [ModelConfig]) throws -> SettingsSaveOutcome {
        try transactionCoordinator.performReadModifyWrite(
            read: { try loadUnlocked().settings },
            write: { settings in
                try saveUnlocked(settings: settings, models: models)
            }
        )
    }

    private func loadUnlocked() throws -> SettingsSnapshot {
        if let persistedSnapshot = try loadPersistedSnapshot() {
            let models = persistedSnapshot.snapshot.models.isEmpty
                ? ModelConfig.defaults
                : persistedSnapshot.snapshot.models
            return SettingsSnapshot(
                settings: persistedSnapshot.snapshot.settings,
                models: models,
                usedDefaults: persistedSnapshot.snapshot.models.isEmpty,
                recoveryNotice: persistedSnapshot.recoveryNotice
            )
        }

        let settings = try loadSettings()
        let models = try loadModels()
        return SettingsSnapshot(
            settings: settings.value,
            models: models.value,
            usedDefaults: settings.usedDefault || models.usedDefault,
            recoveryNotice: nil
        )
    }

    private func saveUnlocked(
        settings: AppSettings,
        models: [ModelConfig]
    ) throws -> SettingsSaveOutcome {
        try ensureSettingsDirectoryExists()
        let snapshot = PersistedSettingsSnapshot(settings: settings, models: models)
        let snapshotData = try encoder.encode(snapshot)

        // The combined snapshot is the authoritative atomic state. The two legacy
        // files remain as human-readable compatibility mirrors.
        try snapshotData.write(to: try stateSnapshotFileURL, options: [.atomic])

        var recoveryWarnings: [String] = []
        do {
            try snapshotData.write(to: try stateSnapshotBackupFileURL, options: [.atomic])
        } catch {
            recoveryWarnings.append("settings-state.backup.json: \(error.localizedDescription)")
        }

        var mirrorWarnings: [String] = []
        do {
            try save(settings, to: try settingsFileURL)
        } catch {
            mirrorWarnings.append("settings.json: \(error.localizedDescription)")
        }
        do {
            try save(models, to: try modelsFileURL)
        } catch {
            mirrorWarnings.append("models.json: \(error.localizedDescription)")
        }
        return SettingsSaveOutcome(
            mirrorWarnings: mirrorWarnings,
            recoveryWarnings: recoveryWarnings
        )
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

    func loadHuggingFaceDownloadRetries() throws -> (value: HuggingFaceDownloadRetrySnapshot, usedDefault: Bool) {
        let url = try huggingFaceDownloadRetriesFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            return (.empty, true)
        }

        let data = try Data(contentsOf: url)
        return (try decoder.decode(HuggingFaceDownloadRetrySnapshot.self, from: data), false)
    }

    func save(huggingFaceDownloadRetries: HuggingFaceDownloadRetrySnapshot) throws {
        try ensureSettingsDirectoryExists()
        try save(huggingFaceDownloadRetries, to: try huggingFaceDownloadRetriesFileURL)
    }

    private func loadPersistedSnapshot() throws -> LoadedPersistedSettingsSnapshot? {
        let stateURL = try stateSnapshotFileURL
        let backupURL = try stateSnapshotBackupFileURL
        let stateExists = fileManager.fileExists(atPath: stateURL.path)
        let backupExists = fileManager.fileExists(atPath: backupURL.path)

        guard stateExists || backupExists else {
            // Compatibility mirrors are consulted only when no authoritative
            // state has ever been written, which preserves legacy migration.
            return nil
        }

        if stateExists {
            do {
                let decoded = try decodePersistedSnapshot(at: stateURL)
                let migrationNotice = migratePersistedSnapshotIfNeeded(
                    decoded,
                    stateURL: stateURL,
                    backupURL: backupURL
                )
                return LoadedPersistedSettingsSnapshot(
                    snapshot: decoded.snapshot,
                    recoveryNotice: migrationNotice
                )
            } catch let error as SettingsStoreError {
                throw error
            } catch is DecodingError {
                return try recoverPersistedSnapshot(from: backupURL, repairing: stateURL)
            }
        }

        return try recoverPersistedSnapshot(from: backupURL, repairing: stateURL)
    }

    private func decodePersistedSnapshot(at url: URL) throws -> DecodedPersistedSettingsSnapshot {
        let data = try Data(contentsOf: url)
        let envelope = try decoder.decode(PersistedSettingsSchemaEnvelope.self, from: data)

        switch envelope.schemaVersion {
        case 1:
            let legacy = try decoder.decode(PersistedSettingsSnapshotV1.self, from: data)
            return DecodedPersistedSettingsSnapshot(
                snapshot: PersistedSettingsSnapshot(
                    settings: legacy.settings,
                    models: legacy.models
                ),
                sourceSchemaVersion: 1
            )
        case 2:
            let legacy = try decoder.decode(PersistedSettingsSnapshotV2.self, from: data)
            return DecodedPersistedSettingsSnapshot(
                snapshot: PersistedSettingsSnapshot(
                    settings: legacy.settings,
                    models: legacy.models
                ),
                sourceSchemaVersion: 2
            )
        case PersistedSettingsSnapshot.currentSchemaVersion:
            return DecodedPersistedSettingsSnapshot(
                snapshot: try decoder.decode(PersistedSettingsSnapshot.self, from: data),
                sourceSchemaVersion: PersistedSettingsSnapshot.currentSchemaVersion
            )
        default:
            throw SettingsStoreError.unsupportedStateSchemaVersion(envelope.schemaVersion)
        }
    }

    private func migratePersistedSnapshotIfNeeded(
        _ decoded: DecodedPersistedSettingsSnapshot,
        stateURL: URL,
        backupURL: URL
    ) -> String? {
        guard decoded.sourceSchemaVersion < PersistedSettingsSnapshot.currentSchemaVersion else {
            return nil
        }

        do {
            let data = try encoder.encode(decoded.snapshot)
            try data.write(to: stateURL, options: [.atomic])
            do {
                try data.write(to: backupURL, options: [.atomic])
                return "Migrated settings-state.json from schema \(decoded.sourceSchemaVersion) to \(PersistedSettingsSnapshot.currentSchemaVersion)."
            } catch {
                return "Migrated settings-state.json from schema \(decoded.sourceSchemaVersion) to \(PersistedSettingsSnapshot.currentSchemaVersion), but the recovery backup could not be updated: \(error.localizedDescription)"
            }
        } catch {
            return "Loaded settings schema \(decoded.sourceSchemaVersion), but automatic migration to schema \(PersistedSettingsSnapshot.currentSchemaVersion) could not be saved: \(error.localizedDescription)"
        }
    }

    private func recoverPersistedSnapshot(
        from backupURL: URL,
        repairing stateURL: URL
    ) throws -> LoadedPersistedSettingsSnapshot {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw SettingsStoreError.authoritativeStateCorrupted
        }

        let decoded: DecodedPersistedSettingsSnapshot
        do {
            decoded = try decodePersistedSnapshot(at: backupURL)
        } catch let error as SettingsStoreError {
            throw error
        } catch {
            throw SettingsStoreError.authoritativeStateCorrupted
        }

        var notices: [String] = []
        do {
            try save(decoded.snapshot, to: stateURL)
            notices.append("Recovered settings-state.json from settings-state.backup.json.")
        } catch {
            notices.append("Loaded settings-state.backup.json, but settings-state.json could not be repaired: \(error.localizedDescription)")
        }

        if decoded.sourceSchemaVersion < PersistedSettingsSnapshot.currentSchemaVersion {
            do {
                try save(decoded.snapshot, to: backupURL)
                notices.append("Migrated the recovery backup from schema \(decoded.sourceSchemaVersion) to \(PersistedSettingsSnapshot.currentSchemaVersion).")
            } catch {
                notices.append("Loaded schema \(decoded.sourceSchemaVersion), but the recovery backup could not be migrated: \(error.localizedDescription)")
            }
        }

        return LoadedPersistedSettingsSnapshot(
            snapshot: decoded.snapshot,
            recoveryNotice: notices.joined(separator: " ")
        )
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
