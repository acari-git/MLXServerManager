import Foundation

extension AppViewModel {
    func loadSettings() {
        do {
            let snapshot = try settingsStore.load()
            settings = snapshot.settings
            autoUnloadEnabledByModelID = settings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = settings.autoUnloadMinutesByModelID
            invalidateModelSizeCache()
            invalidatePortCheckCache()
            models = snapshot.models

            if snapshot.usedDefaults {
                appendLog("[settings] settings.json or models.json not found. Using defaults until saved.")
            } else {
                appendLog("[settings] Loaded settings.json and models.json from \(settingsDirectoryPath).")
            }
            if let recoveryNotice = snapshot.recoveryNotice {
                appendLog("[settings] recovery: \(recoveryNotice)")
            }
            loadPersistedBenchmarkResults()
        } catch {
            settings = .defaults
            autoUnloadEnabledByModelID = settings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = settings.autoUnloadMinutesByModelID
            invalidateModelSizeCache()
            invalidatePortCheckCache()
            models = ModelConfig.defaults
            appendLog("[settings] Failed to load settings. Using defaults: \(error.localizedDescription)")
            loadPersistedBenchmarkResults()
        }
    }

    func loadPersistedHuggingFaceDownloadRetries() {
        do {
            let persisted = try settingsStore.loadHuggingFaceDownloadRetries()
            guard persisted.value.schemaVersion == HuggingFaceDownloadRetrySnapshot.currentSchemaVersion else {
                appendLog("[hf] ignored download retry state with unsupported schema version \(persisted.value.schemaVersion).")
                return
            }

            let limitedRecords = Array(
                persisted.value.records.prefix(Self.maximumTerminalHuggingFaceDownloadHistory)
            )
            let restoredEntries = huggingFaceDownloadRetryStore.restore(
                from: HuggingFaceDownloadRetrySnapshot(records: limitedRecords)
            )
            huggingFaceOutputStateCoordinator.setPrimary(restoredEntries.first?.id)
            replaceHuggingFaceDownloadQueue(restoredEntries)

            if !restoredEntries.isEmpty {
                appendLog("[hf] restored \(restoredEntries.count) retryable download(s) from the previous session.")
            }
            if !persisted.usedDefault,
               restoredEntries.count != persisted.value.records.count {
                appendLog("[hf] ignored invalid or excess persisted download retry records.")
                persistHuggingFaceDownloadRetries()
            }
        } catch {
            appendLog("[hf] failed to load persisted download retries: \(error.localizedDescription)")
        }
    }

    func persistHuggingFaceDownloadRetries() {
        do {
            try settingsStore.save(
                huggingFaceDownloadRetries: huggingFaceDownloadRetryStore.persistenceSnapshot(
                    entries: huggingFaceDownloadQueue
                )
            )
        } catch {
            appendLog("[hf] failed to save download retry state: \(error.localizedDescription)")
        }
    }

    func loadPersistedBenchmarkResults() {
        do {
            let snapshot = try settingsStore.loadBenchmarkResults()
            benchmarkViewState.replacePersistedResults(with: snapshot.value)
            if snapshot.usedDefault {
                appendLog("[benchmark] benchmark-results.json not found. Model benchmark results will be saved after the next run.")
            } else {
                appendLog("[benchmark] Loaded benchmark-results.json from \(settingsDirectoryPath).")
            }
        } catch {
            benchmarkViewState.clearPersistedResults()
            appendLog("[benchmark] Failed to load benchmark-results.json: \(error.localizedDescription)")
        }
    }

    func savePersistedBenchmarkResults() {
        do {
            try settingsStore.save(benchmarkResults: benchmarkViewState.persistedResultsSnapshot)
        } catch {
            appendLog("[benchmark] Failed to save benchmark-results.json: \(error.localizedDescription)")
        }
    }
}
