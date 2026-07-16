import Foundation

nonisolated struct LaunchCommandBuilder {
    static func command(executablePath: String, model: ModelConfig) -> String {
        let executable = executablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? model.resolvedBackend.defaultExecutableName
            : executablePath
        let request = ModelLaunchRequest(
            executablePath: executable,
            backend: model.resolvedBackend,
            modelID: model.modelID,
            host: model.host,
            port: model.serverPort,
            enableThinking: model.enableThinking,
            advancedLaunchOptions: model.advancedLaunchOptions
        )
        return ModelProcessManager.commandPreview(for: request, executablePath: executable)
    }
}
