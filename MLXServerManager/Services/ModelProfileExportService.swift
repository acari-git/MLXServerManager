import Foundation

struct ModelProfileExportDocument: Codable {
    let schemaVersion: Int
    let app: String
    let exportedAt: Date
    let profiles: [ExportedModelProfile]

    @MainActor static func make(
        from models: [ModelConfig],
        exportedAt: Date = Date()
    ) -> ModelProfileExportDocument {
        ModelProfileExportDocument(
            schemaVersion: 1,
            app: "MLXServerManager",
            exportedAt: exportedAt,
            profiles: models.map(ExportedModelProfile.init(model:))
        )
    }
}

struct ExportedModelProfile: Codable {
    let name: String
    let modelID: String
    let host: String
    let port: Int
    let advancedLaunchOptions: AdvancedLaunchOptions?

    @MainActor init(model: ModelConfig) {
        let displayName = model.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = displayName.isEmpty ? model.modelID : displayName
        self.modelID = model.modelID
        self.host = model.host
        self.port = model.serverPort
        self.advancedLaunchOptions = model.advancedLaunchOptions?.normalized()
    }
}

struct ModelProfileExportService {
    @MainActor func exportData(from models: [ModelConfig], exportedAt: Date = Date()) throws -> Data {
        let document = ModelProfileExportDocument.make(from: models, exportedAt: exportedAt)
        return try encoder.encode(document)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
