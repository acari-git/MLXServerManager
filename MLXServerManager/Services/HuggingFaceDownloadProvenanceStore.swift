import Foundation

nonisolated struct HuggingFaceDownloadProvenance: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let repositoryID: String
    let revision: String

    init(repositoryID: String, revision: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.repositoryID = repositoryID
        self.revision = revision
    }
}

nonisolated enum HuggingFaceDownloadProvenanceError: LocalizedError, Equatable {
    case destinationIsFile
    case destinationContainsUntrackedFiles
    case invalidMetadata
    case unsupportedMetadataVersion(Int)
    case sourceMismatch(existingRepositoryID: String, existingRevision: String)

    var errorDescription: String? {
        switch self {
        case .destinationIsFile:
            "The destination path is an existing file."
        case .destinationContainsUntrackedFiles:
            "The destination folder already contains files, but its Hugging Face source cannot be verified. Choose another save folder to avoid mixing model files."
        case .invalidMetadata:
            "The destination folder contains unreadable MLX Server Manager download metadata. Choose another save folder to avoid mixing model files."
        case let .unsupportedMetadataVersion(version):
            "The destination folder uses unsupported MLX Server Manager download metadata version \(version)."
        case let .sourceMismatch(existingRepositoryID, existingRevision):
            "The destination folder belongs to \(existingRepositoryID) at revision \(existingRevision). Choose another save folder to avoid mixing model files."
        }
    }
}

nonisolated enum HuggingFaceDownloadDestinationInspection: Equatable {
    case newDestination
    case emptyDirectory
    case matchingSource
    case blocked(HuggingFaceDownloadProvenanceError)

    var canUse: Bool {
        switch self {
        case .newDestination, .emptyDirectory, .matchingSource:
            true
        case .blocked:
            false
        }
    }
}

nonisolated struct HuggingFaceDownloadProvenanceStore {
    static let metadataFileName = ".mlxservermanager-download-source.json"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspect(
        destinationURL: URL,
        repositoryID: String,
        revision: String
    ) -> HuggingFaceDownloadDestinationInspection {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) else {
            return .newDestination
        }
        guard isDirectory.boolValue else {
            return .blocked(.destinationIsFile)
        }

        let metadataURL = destinationURL.appendingPathComponent(Self.metadataFileName, isDirectory: false)
        if fileManager.fileExists(atPath: metadataURL.path) {
            do {
                let provenance = try readProvenance(from: metadataURL)
                guard provenance.schemaVersion == HuggingFaceDownloadProvenance.currentSchemaVersion else {
                    return .blocked(.unsupportedMetadataVersion(provenance.schemaVersion))
                }
                guard provenance.repositoryID == repositoryID,
                      provenance.revision == revision else {
                    return .blocked(
                        .sourceMismatch(
                            existingRepositoryID: provenance.repositoryID,
                            existingRevision: provenance.revision
                        )
                    )
                }
                return .matchingSource
            } catch let error as HuggingFaceDownloadProvenanceError {
                return .blocked(error)
            } catch {
                return .blocked(.invalidMetadata)
            }
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: destinationURL,
                includingPropertiesForKeys: nil,
                options: []
            )
            return contents.isEmpty ? .emptyDirectory : .blocked(.destinationContainsUntrackedFiles)
        } catch {
            return .blocked(.invalidMetadata)
        }
    }

    func prepare(
        destinationURL: URL,
        repositoryID: String,
        revision: String
    ) throws {
        let inspection = inspect(
            destinationURL: destinationURL,
            repositoryID: repositoryID,
            revision: revision
        )
        if case let .blocked(error) = inspection {
            throw error
        }

        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        guard inspection != .matchingSource else {
            return
        }

        let provenance = HuggingFaceDownloadProvenance(
            repositoryID: repositoryID,
            revision: revision
        )
        let data = try JSONEncoder().encode(provenance)
        let metadataURL = destinationURL.appendingPathComponent(Self.metadataFileName, isDirectory: false)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func readProvenance(from metadataURL: URL) throws -> HuggingFaceDownloadProvenance {
        do {
            let data = try Data(contentsOf: metadataURL)
            return try JSONDecoder().decode(HuggingFaceDownloadProvenance.self, from: data)
        } catch {
            throw HuggingFaceDownloadProvenanceError.invalidMetadata
        }
    }
}
