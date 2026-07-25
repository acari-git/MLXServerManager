import Foundation

nonisolated protocol RegisteredModelHealthAssessing: Sendable {
    func assess(models: [ModelConfig]) async -> [RegisteredModelHealthReport]
}

actor RegisteredModelHealthService: RegisteredModelHealthAssessing {
    private let fileManager: FileManager
    private let integrityChecker: any LocalModelIntegrityChecking

    init(
        fileManager: FileManager = .default,
        integrityChecker: any LocalModelIntegrityChecking = FileSystemLocalModelIntegrityChecker()
    ) {
        self.fileManager = fileManager
        self.integrityChecker = integrityChecker
    }

    func assess(models: [ModelConfig]) async -> [RegisteredModelHealthReport] {
        let localPaths = Dictionary(grouping: models.compactMap { model -> (String, ModelConfig.ID)? in
            guard let path = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
                return nil
            }
            return (URL(fileURLWithPath: path).standardizedFileURL.path, model.id)
        }, by: { $0.0 })

        var reports: [RegisteredModelHealthReport] = []
        for model in models {
            guard !Task.isCancelled else { break }
            reports.append(report(for: model, localPaths: localPaths))
        }
        return reports
    }

    private func report(
        for model: ModelConfig,
        localPaths: [String: [(String, ModelConfig.ID)]]
    ) -> RegisteredModelHealthReport {
        let checkedAt = Date()
        guard let rawPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
            return RegisteredModelHealthReport(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                status: .externalIdentifier,
                localPath: nil,
                issue: nil,
                message: nil,
                sizeGigabytes: nil,
                modificationDate: nil,
                duplicateProfileIDs: [],
                checkedAt: checkedAt
            )
        }

        let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path
        let duplicateIDs = (localPaths[path] ?? [])
            .map(\.1)
            .filter { $0 != model.id }
            .sorted()
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return RegisteredModelHealthReport(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                status: .missing,
                localPath: path,
                issue: nil,
                message: nil,
                sizeGigabytes: nil,
                modificationDate: nil,
                duplicateProfileIDs: duplicateIDs,
                checkedAt: checkedAt
            )
        }

        let attributes = try? fileManager.attributesOfItem(atPath: path)
        let modificationDate = attributes?[.modificationDate] as? Date
        let sizeGigabytes = directorySizeGigabytes(path: path)

        switch integrityChecker.check(path: path) {
        case .ready:
            return RegisteredModelHealthReport(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                status: duplicateIDs.isEmpty ? .ready : .duplicatePath,
                localPath: path,
                issue: nil,
                message: nil,
                sizeGigabytes: sizeGigabytes,
                modificationDate: modificationDate,
                duplicateProfileIDs: duplicateIDs,
                checkedAt: checkedAt
            )
        case let .incomplete(issue):
            return RegisteredModelHealthReport(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                status: .incomplete,
                localPath: path,
                issue: issue,
                message: nil,
                sizeGigabytes: sizeGigabytes,
                modificationDate: modificationDate,
                duplicateProfileIDs: duplicateIDs,
                checkedAt: checkedAt
            )
        case let .notInspectable(message):
            return RegisteredModelHealthReport(
                profileID: model.id,
                displayName: model.displayName,
                modelID: model.modelID,
                status: .uninspectable,
                localPath: path,
                issue: nil,
                message: message,
                sizeGigabytes: sizeGigabytes,
                modificationDate: modificationDate,
                duplicateProfileIDs: duplicateIDs,
                checkedAt: checkedAt
            )
        }
    }

    private func directorySizeGigabytes(path: String) -> Double? {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path, isDirectory: true),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        var totalBytes: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard !Task.isCancelled else { return nil }
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  size > 0 else {
                continue
            }
            totalBytes += UInt64(size)
        }
        return Double(totalBytes) / 1_073_741_824
    }
}
