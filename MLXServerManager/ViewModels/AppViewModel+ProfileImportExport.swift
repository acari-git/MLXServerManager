import AppKit
import Foundation
import UniformTypeIdentifiers

extension AppViewModel {
    func exportProfilesRequested() {
        guard !models.isEmpty else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "No model profiles are available to export.", japanese: "エクスポートできるモデルプロファイルがありません。")
            modelProfileExportMessage = message
            appendLog("[profile] export failed: \(message)")
            return
        }

        let panel = NSSavePanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Export Model Profiles", japanese: "モデルプロファイルをエクスポート")
        panel.nameFieldStringValue = "MLXServerManager-Profiles.json"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            modelProfileExportMessage = Self.localizedText(language: settings.uiLanguage, english: "Export cancelled.", japanese: "エクスポートをキャンセルしました。")
            appendLog("[profile] export cancelled.")
            return
        }

        do {
            let data = try modelProfileExportService.exportData(from: models)
            try data.write(to: url, options: [.atomic])

            let message = Self.localizedText(language: settings.uiLanguage, english: "Exported \(models.count) profile(s) to \(url.lastPathComponent).", japanese: "\(models.count)件のプロファイルを\(url.lastPathComponent)へエクスポートしました。")
            modelProfileExportMessage = message
            appendLog("[profile] \(message)")
            appendLog("[profile] export includes profile metadata only. It does not include API keys, tokens, model weights, caches, logs, executable paths, or runtime state.")
        } catch {
            let message = error.localizedDescription
            modelProfileExportMessage = Self.localizedText(language: settings.uiLanguage, english: "Export failed: \(message)", japanese: "エクスポートに失敗しました: \(message)")
            appendLog("[profile] export failed: \(message)")
        }
    }

    func importProfilesPreviewRequested() {
        let panel = NSOpenPanel()
        panel.title = Self.localizedText(language: settings.uiLanguage, english: "Import Model Profiles Preview", japanese: "モデルプロファイルのインポートプレビュー")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Import preview cancelled.", japanese: "インポートプレビューをキャンセルしました。")
            appendLog("[profile] import preview cancelled.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let result = modelProfileImportPreviewService.preview(
                data: data,
                sourceFileName: url.lastPathComponent,
                existingModels: models
            )

            importPreviewResult = result
            isImportPreviewPresented = true
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Previewed \(result.totalProfiles) profile row(s) from \(result.sourceFileName).", japanese: "\(result.sourceFileName)から\(result.totalProfiles)件のプロファイル行をプレビューしました。")
            appendLog("[profile] import preview loaded \(result.sourceFileName): \(result.validProfilesCount) valid, \(result.invalidProfilesCount) invalid, \(result.warningCount) warning(s).")
            appendLog("[profile] import preview only. No profiles were saved, no server lifecycle action was taken, and no external request was made.")
        } catch {
            let result = modelProfileImportPreviewService.preview(
                data: Data(),
                sourceFileName: url.lastPathComponent,
                existingModels: models
            )

            importPreviewResult = result
            isImportPreviewPresented = true
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Import preview failed: \(error.localizedDescription)", japanese: "インポートプレビューに失敗しました: \(error.localizedDescription)")
            appendLog("[profile] import preview failed: \(error.localizedDescription)")
        }
    }

    func dismissImportPreview() {
        isImportPreviewPresented = false
    }

    func importSelectedProfilesRequested(requests: [ImportSelectedProfileRequest]) {
        guard let importPreviewResult else {
            let message = Self.localizedText(language: settings.uiLanguage, english: "No import preview is available.", japanese: "利用できるインポートプレビューがありません。")
            modelProfileImportMessage = message
            appendLog("[profile] import failed: \(message)")
            return
        }

        let importResult = modelProfileImportPreviewService.importSelectedProfiles(
            from: importPreviewResult,
            requests: requests,
            existingModels: models
        )

        if let runningReplacement = importResult.replacedProfiles.first(where: { runningModelIDs.contains($0.previousModelID) }) {
            let message = Self.localizedText(
                language: settings.uiLanguage,
                english: "Stop \(runningReplacement.previousDisplayName) before replacing its profile.",
                japanese: "\(runningReplacement.previousDisplayName)を停止してからプロファイルを置換してください。"
            )
            modelProfileImportMessage = message
            appendLog("[profile] import failed: \(message)")
            return
        }

        for message in importResult.messages {
            appendLog("[profile] \(message)")
        }

        guard importResult.didChangeModels else {
            let message = importResult.messages.last ?? Self.localizedText(language: settings.uiLanguage, english: "No profiles were imported or replaced.", japanese: "インポートまたは置換されたプロファイルはありません。")
            modelProfileImportMessage = message
            return
        }

        let previousSelectedModelID = selectedModelID
        let nextModels = importResult.modelsAfterImport

        do {
            let outcome = try settingsStore.save(models: nextModels)
            invalidateModelSizeCache()
            invalidatePortCheckCache()
            models = nextModels

            let selectionUpdate = ModelProfileImportSelectionUpdate.preservingSelection(
                previousSelectedModelID: previousSelectedModelID,
                nextModels: nextModels,
                replacedProfiles: importResult.replacedProfiles
            )
            if selectionUpdate.preservedThroughReplacement {
                selectedModelID = selectionUpdate.selectedModelID
                appendLog("[profile] selected profile identity updated from \(previousSelectedModelID ?? "unknown") to \(selectionUpdate.selectedModelID ?? "unknown") after Replace.")
            }

            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Imported \(importResult.importedCount) profile(s). Renamed \(importResult.renamedCount) profile(s). Replaced \(importResult.replacedCount) profile(s). Skipped \(importResult.skippedCount) profile(s).", japanese: "\(importResult.importedCount)件をインポート、\(importResult.renamedCount)件をリネーム、\(importResult.replacedCount)件を置換、\(importResult.skippedCount)件をスキップしました。")
            appendLog("[profile] profile metadata changes saved to models.json.")
            if selectionUpdate.preservedThroughReplacement {
                appendLog("[profile] selected profile was preserved through the explicit Replace action. No server lifecycle action was taken.")
            } else {
                appendLog("[profile] selected profile was not changed. No server lifecycle action was taken.")
            }
            isImportPreviewPresented = false
            appendSettingsSaveWarnings(outcome)
        } catch {
            modelProfileImportMessage = Self.localizedText(language: settings.uiLanguage, english: "Import failed: \(error.localizedDescription)", japanese: "インポートに失敗しました: \(error.localizedDescription)")
            appendLog("[profile] import failed: \(error.localizedDescription)")
        }
    }
}
