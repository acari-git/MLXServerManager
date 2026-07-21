import Foundation

nonisolated struct DownloadStorageExpectedFile: Equatable, Sendable {
    let path: String
    let expectedSizeBytes: Int64?
    let existingSizeBytes: Int64?

    init(
        path: String,
        expectedSizeBytes: Int64?,
        existingSizeBytes: Int64? = nil
    ) {
        self.path = path
        self.expectedSizeBytes = expectedSizeBytes
        self.existingSizeBytes = existingSizeBytes
    }
}

nonisolated struct DownloadStorageRequirement: Equatable, Sendable {
    let knownRemainingBytes: Int64
    let totalRemainingBytes: Int64?
    let unknownSizePaths: [String]

    var hasUnknownSizes: Bool {
        !unknownSizePaths.isEmpty
    }
}

nonisolated protocol DownloadStorageCapacityProviding {
    func availableCapacityForImportantUsage(at destinationDirectoryURL: URL) -> Int64?
}

nonisolated struct FoundationDownloadStorageCapacityProvider: DownloadStorageCapacityProviding {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func availableCapacityForImportantUsage(at destinationDirectoryURL: URL) -> Int64? {
        let probeURL = nearestExistingDirectory(to: destinationDirectoryURL)
        return try? probeURL
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    private func nearestExistingDirectory(to destinationDirectoryURL: URL) -> URL {
        var probeURL = destinationDirectoryURL.standardizedFileURL
        var isDirectory = ObjCBool(false)

        while !fileManager.fileExists(atPath: probeURL.path, isDirectory: &isDirectory)
            || !isDirectory.boolValue {
            let parentURL = probeURL.deletingLastPathComponent()
            guard parentURL.path != probeURL.path else {
                return probeURL
            }
            probeURL = parentURL
        }

        return probeURL
    }
}

nonisolated enum DownloadStorageAssessmentKind: String, Equatable, Sendable {
    case capacityUnknown
    case requiredUnknown
    case sufficient
    case insufficient
}

nonisolated struct DownloadStorageAssessment: Equatable, Sendable {
    let kind: DownloadStorageAssessmentKind
    let requirement: DownloadStorageRequirement
    let availableCapacityBytes: Int64?

    var blocksDownload: Bool {
        kind == .insufficient
    }

    func title(language: AppLanguage) -> String {
        switch (language.resolved, kind) {
        case (.english, .capacityUnknown): "Available storage could not be checked"
        case (.english, .requiredUnknown): "Required storage is not fully known"
        case (.english, .sufficient): "Enough storage is available"
        case (.english, .insufficient): "Not enough storage is available"
        case (_, .capacityUnknown): "空き容量を確認できません"
        case (_, .requiredUnknown): "必要容量の一部が不明です"
        case (_, .sufficient): "保存容量は十分です"
        case (_, .insufficient): "保存容量が不足しています"
        }
    }

    func detail(language: AppLanguage) -> String {
        let requiredText = Self.bytesText(requirement.knownRemainingBytes)

        switch kind {
        case .capacityUnknown:
            return localized(
                language,
                english: "The download still requires \(requiredText), but available capacity on the destination volume could not be measured. The download is not blocked.",
                japanese: "ダウンロードには残り\(requiredText)が必要ですが、保存先ボリュームの空き容量を取得できません。ダウンロードはブロックしません。"
            )
        case .requiredUnknown:
            let unknownCount = requirement.unknownSizePaths.count
            return localized(
                language,
                english: "\(unknownCount) selected file(s) have an unknown size. At least \(requiredText) is still required, so total required storage cannot be confirmed. The download is not blocked.",
                japanese: "選択した\(unknownCount)件のファイルはサイズが不明です。少なくとも残り\(requiredText)が必要ですが、必要容量の合計は確定できません。ダウンロードはブロックしません。"
            )
        case .sufficient:
            let availableText = Self.bytesText(availableCapacityBytes ?? 0)
            return localized(
                language,
                english: "The download still requires \(requiredText), and \(availableText) is available on the destination volume.",
                japanese: "ダウンロードには残り\(requiredText)が必要で、保存先ボリュームには\(availableText)の空き容量があります。"
            )
        case .insufficient:
            let availableBytes = availableCapacityBytes ?? 0
            let availableText = Self.bytesText(availableBytes)
            let shortageText = Self.bytesText(max(requirement.knownRemainingBytes - availableBytes, 0))
            return localized(
                language,
                english: "The download still requires \(requiredText), but only \(availableText) is available. Free at least \(shortageText) before downloading.",
                japanese: "ダウンロードには残り\(requiredText)が必要ですが、空き容量は\(availableText)です。ダウンロード前に少なくとも\(shortageText)を空けてください。"
            )
        }
    }

    private func localized(_ language: AppLanguage, english: String, japanese: String) -> String {
        language.resolved == .english ? english : japanese
    }

    private static func bytesText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

nonisolated enum DownloadStorageAdvisor {
    static func requirement(for files: [DownloadStorageExpectedFile]) -> DownloadStorageRequirement {
        var knownRemainingBytes: Int64 = 0
        var unknownSizePaths: [String] = []

        for file in files {
            guard let expectedSizeBytes = file.expectedSizeBytes else {
                unknownSizePaths.append(file.path)
                continue
            }

            let normalizedExpectedBytes = max(expectedSizeBytes, 0)
            let normalizedExistingBytes = max(file.existingSizeBytes ?? 0, 0)
            let remainingBytes = max(normalizedExpectedBytes - normalizedExistingBytes, 0)
            let (sum, overflowed) = knownRemainingBytes.addingReportingOverflow(remainingBytes)
            knownRemainingBytes = overflowed ? Int64.max : sum
        }

        return DownloadStorageRequirement(
            knownRemainingBytes: knownRemainingBytes,
            totalRemainingBytes: unknownSizePaths.isEmpty ? knownRemainingBytes : nil,
            unknownSizePaths: unknownSizePaths
        )
    }

    static func assess(
        files: [DownloadStorageExpectedFile],
        destinationDirectoryURL: URL
    ) -> DownloadStorageAssessment {
        assess(
            files: files,
            destinationDirectoryURL: destinationDirectoryURL,
            capacityProvider: FoundationDownloadStorageCapacityProvider()
        )
    }

    static func assess(
        files: [DownloadStorageExpectedFile],
        destinationDirectoryURL: URL,
        capacityProvider: any DownloadStorageCapacityProviding
    ) -> DownloadStorageAssessment {
        let requirement = requirement(for: files)
        let measuredCapacity = capacityProvider.availableCapacityForImportantUsage(
            at: destinationDirectoryURL
        )
        let availableCapacityBytes = measuredCapacity.map { max($0, 0) }

        let kind: DownloadStorageAssessmentKind
        if requirement.totalRemainingBytes == nil {
            kind = .requiredUnknown
        } else if availableCapacityBytes == nil {
            kind = .capacityUnknown
        } else if requirement.knownRemainingBytes <= (availableCapacityBytes ?? 0) {
            kind = .sufficient
        } else {
            kind = .insufficient
        }

        return DownloadStorageAssessment(
            kind: kind,
            requirement: requirement,
            availableCapacityBytes: availableCapacityBytes
        )
    }
}
