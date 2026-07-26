import AppKit
import Foundation
import UniformTypeIdentifiers

extension AppViewModel {
    func applyDownloadSettingsToDraft() {
        huggingFaceDownloadDraft.saveDirectory = settings.downloadSaveDirectory
        huggingFaceDownloadDraft.autoAddToModelList = true
        huggingFaceDownloadDraft.autoSelectAfterAdd = true
    }

    @discardableResult
    func saveSettingsRequested(_ candidate: AppSettings? = nil) -> Bool {
        let nextSettings = candidate ?? settings
        do {
            let outcome = try settingsStore.save(settings: nextSettings, models: models)
            settings = nextSettings
            autoUnloadEnabledByModelID = nextSettings.autoUnloadEnabledByModelID
            autoUnloadMinutesByModelID = nextSettings.autoUnloadMinutesByModelID
            refreshDefaultUserFacingMessagesForCurrentLanguage()
            applyDownloadSettingsToDraft()
            invalidatePortCheckCache()
            appendLog("[settings] Saved settings state to \(settingsDirectoryPath).")
            appendSettingsSaveWarnings(outcome)
            return true
        } catch {
            appendLog("[settings] Failed to save settings: \(error.localizedDescription)")
            return false
        }
    }

    func appendSettingsSaveWarnings(_ outcome: SettingsSaveOutcome) {
        for warning in outcome.recoveryWarnings {
            appendLog("[settings] Recovery backup warning: \(warning)")
        }
        for warning in outcome.mirrorWarnings {
            appendLog("[settings] Compatibility mirror warning: \(warning)")
        }
    }

    func chooseMLXServerExecutableRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose mlx_lm.server executable", japanese: "mlx_lm.server実行ファイルを選択")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[settings] executable picker cancelled.")
            return
        }
        var nextSettings = settings
        nextSettings.mlxServerExecutablePath = url.path
        if saveSettingsRequested(nextSettings) {
            appendLog("[settings] executable path set to \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
        }
    }

    func chooseHermesAgentConfigRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose Hermes Agent config file", japanese: "Hermes Agent設定ファイルを選択")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .data]
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[hermes] config picker cancelled.")
            return
        }
        var nextSettings = settings
        nextSettings.hermesConfigPath = url.path
        if saveSettingsRequested(nextSettings) {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Hermes Agent config file selected.",
                japanese: "Hermes Agent設定ファイルを選択しました。"
            )
            inspectHermesAgentConfigRequested()
            appendLog("[hermes] config path set to \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
        }
    }

    func openHermesAgentConfigRequested() {
        let url = hermesAgentConfigService.expandedConfigURL(from: hermesAgentConfigPathText)
        guard FileManager.default.fileExists(atPath: url.path) else {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Hermes Agent config file was not found.",
                japanese: "Hermes Agent設定ファイルが見つかりません。"
            )
            appendLog("[hermes] open failed: config file not found at \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
            return
        }
        NSWorkspace.shared.open(url)
        appendLog("[hermes] opened config file: \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
    }

    func restoreHermesAgentConfigBackupRequested() {
        do {
            guard let backup = selectedHermesAgentBackup else {
                throw HermesAgentConfigServiceError.backupNotFound(hermesAgentConfigPathText)
            }
            let restoredBackupURL = try hermesAgentConfigService.restoreBackup(
                backup,
                configPath: hermesAgentConfigPathText
            )
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Restored latest Hermes Agent backup: \(ModelAvailabilityPathFormatter.compact(path: restoredBackupURL.path))",
                japanese: "最新のHermes Agentバックアップを復元しました: \(ModelAvailabilityPathFormatter.compact(path: restoredBackupURL.path))"
            )
            hermesAgentConfigInspection = try? hermesAgentConfigService.inspect(
                configPath: hermesAgentConfigPathText
            )
            refreshHermesAgentBackups()
            appendLog("[hermes] restored latest backup: \(ModelAvailabilityPathFormatter.compact(path: restoredBackupURL.path)).")
        } catch {
            hermesAgentConfigMessage = Self.localizedText(
                language: settings.uiLanguage,
                english: "Could not restore Hermes Agent backup: \(error.localizedDescription)",
                japanese: "Hermes Agentバックアップを復元できませんでした: \(error.localizedDescription)"
            )
            appendLog("[hermes] restore failed: \(error.localizedDescription)")
        }
    }

    func chooseLocalModelFolderRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Choose local model folder", japanese: "ローカルモデルフォルダを選択")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("[profile] local model folder picker cancelled.")
            return
        }
        localModelPath = url.path
        if localModelDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            localModelDisplayName = url.lastPathComponent
        }
        appendLog("[profile] local model folder selected: \(ModelAvailabilityPathFormatter.compact(path: url.path)).")
    }
}
