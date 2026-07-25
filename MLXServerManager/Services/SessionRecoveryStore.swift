import Foundation

@MainActor
final class SessionRecoveryStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private(set) var currentSessionID = UUID()

    init(
        fileManager: FileManager = .default,
        appDirectoryName: String = "MLX Server Manager",
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.fileURL = applicationSupport
                .appendingPathComponent(appDirectoryName, isDirectory: true)
                .appendingPathComponent("session-recovery.json", isDirectory: false)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func beginSession() -> SessionRecoveryRecord? {
        let previous = loadRecord()
        let recoverablePrevious: SessionRecoveryRecord?
        if let previous,
           previous.schemaVersion == SessionRecoveryRecord.schemaVersion,
           previous.disposition != .clean,
           !previous.endpoints.isEmpty {
            recoverablePrevious = previous
        } else {
            recoverablePrevious = nil
        }

        currentSessionID = UUID()
        writeRecord(
            SessionRecoveryRecord(
                sessionID: currentSessionID,
                disposition: .active,
                endpoints: recoverablePrevious?.endpoints ?? []
            )
        )
        return recoverablePrevious
    }

    func recordActive(endpoints: [SessionRecoveryEndpoint]) {
        writeRecord(
            SessionRecoveryRecord(
                sessionID: currentSessionID,
                disposition: .active,
                endpoints: endpoints
            )
        )
    }

    func recordLeftRunning(endpoints: [SessionRecoveryEndpoint]) {
        writeRecord(
            SessionRecoveryRecord(
                sessionID: currentSessionID,
                disposition: .leftRunning,
                endpoints: endpoints
            )
        )
    }

    func recordSystemShutdown(endpoints: [SessionRecoveryEndpoint]) {
        writeRecord(
            SessionRecoveryRecord(
                sessionID: currentSessionID,
                disposition: .systemShutdown,
                endpoints: endpoints
            )
        )
    }

    func markCleanShutdown() {
        writeRecord(
            SessionRecoveryRecord(
                sessionID: currentSessionID,
                disposition: .clean,
                endpoints: []
            )
        )
    }

    func loadRecord() -> SessionRecoveryRecord? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(SessionRecoveryRecord.self, from: data)
    }

    private func writeRecord(_ record: SessionRecoveryRecord) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(record)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Session recovery is best-effort and must never block core runtime operations.
        }
    }
}
