import CryptoKit
import Foundation

nonisolated enum BenchmarkExecutionFingerprint {
    private struct Payload: Encodable {
        let version: Int
        let modelID: String
        let host: String
        let port: Int
        let backend: InferenceBackend
        let enableThinking: Bool
        let executablePath: String
        let advancedLaunchOptions: AdvancedLaunchOptions?
    }

    static func make(model: ModelConfig, executablePath: String) -> String {
        let normalizedExecutablePath = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = Payload(
            version: 1,
            modelID: model.modelID,
            host: normalizedHost(model.host),
            port: model.serverPort,
            backend: model.resolvedBackend,
            enableThinking: model.enableThinking,
            executablePath: normalizedExecutablePath.isEmpty
                ? ""
                : URL(fileURLWithPath: normalizedExecutablePath).standardizedFileURL.path,
            advancedLaunchOptions: model.advancedLaunchOptions?.normalized()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else {
            return "unavailable"
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedHost(_ host: String) -> String {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "localhost" ? "127.0.0.1" : normalized
    }
}
