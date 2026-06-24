import Foundation

struct LaunchCommandBuilder {
    static func command(executablePath: String, model: ModelConfig) -> String {
        let executable = executablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "mlx_lm.server"
            : executablePath
        let request = ModelLaunchRequest(
            executablePath: executable,
            modelID: model.modelID,
            host: model.host,
            port: model.serverPort,
            advancedLaunchOptions: model.advancedLaunchOptions
        )
        return ModelProcessManager.commandPreview(for: request, executablePath: executable)
    }
}
