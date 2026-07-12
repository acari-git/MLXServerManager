import Foundation

struct HuggingFaceFilePreviewIdentity: Equatable, Sendable {
    let repositoryID: String
    let revision: String

    init(repositoryID: String, revision: String) {
        self.repositoryID = repositoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRevision = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        self.revision = trimmedRevision.isEmpty ? "main" : trimmedRevision
    }
}

struct HuggingFaceDownloadProgressSnapshot: Equatable, Sendable {
    let downloadedBytes: Int64
    let completedFileCount: Int
    let expectedFileCount: Int
}

enum HuggingFaceDownloadProgressMeasurer {
    nonisolated static func snapshot(
        destinationPath: String,
        expectedFiles: [HuggingFaceDownloadPreviewFile],
        fileManager: FileManager = .default
    ) -> HuggingFaceDownloadProgressSnapshot {
        guard !expectedFiles.isEmpty else {
            return HuggingFaceDownloadProgressSnapshot(
                downloadedBytes: 0,
                completedFileCount: 0,
                expectedFileCount: 0
            )
        }

        let destinationURL = URL(fileURLWithPath: destinationPath, isDirectory: true)
        var downloadedBytes: Int64 = 0
        var completedFileCount = 0

        for expectedFile in expectedFiles {
            let fileURL = destinationURL.appendingPathComponent(expectedFile.path, isDirectory: false)
            var isDirectory = ObjCBool(false)
            guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                continue
            }

            let actualSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                .map(Int64.init) ?? 0

            if let expectedSize = expectedFile.size, expectedSize >= 0 {
                downloadedBytes += min(max(actualSize, 0), expectedSize)
                if actualSize >= expectedSize {
                    completedFileCount += 1
                }
            } else {
                downloadedBytes += max(actualSize, 0)
                completedFileCount += 1
            }
        }

        return HuggingFaceDownloadProgressSnapshot(
            downloadedBytes: downloadedBytes,
            completedFileCount: completedFileCount,
            expectedFileCount: expectedFiles.count
        )
    }
}
