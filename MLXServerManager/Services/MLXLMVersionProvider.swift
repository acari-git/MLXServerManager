import Foundation

struct MLXLMVersionProvider {
    var fileManager: FileManager = .default
    var timeout: TimeInterval = 2

    func version(executablePath: String) async -> String? {
        let trimmedPath = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty,
              fileManager.fileExists(atPath: trimmedPath),
              fileManager.isExecutableFile(atPath: trimmedPath) else {
            return nil
        }

        let timeout = timeout
        return await Task.detached(priority: .utility) {
            Self.runVersionCommand(executablePath: trimmedPath, timeout: timeout)
        }.value
    }

    func version(executablePath: String, backend: InferenceBackend) async -> String? {
        await version(executablePath: executablePath)
    }

    nonisolated static func normalizedVersionOutput(_ output: String) -> String? {
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.first { line in
            let lowercased = line.lowercased()
            guard !lowercased.hasPrefix("usage:"),
                  !lowercased.contains("[--model model]"),
                  !lowercased.contains("optional arguments") else {
                return false
            }
            return line.range(of: #"(?i)(mlx[-_ ]?lm|mlx_lm).*([0-9]+\.[0-9]+)"#, options: .regularExpression) != nil
                || line.range(of: #"(?i)rapid[-_ ]?mlx.*([0-9]+\.[0-9]+)"#, options: .regularExpression) != nil
                || line.range(of: #"^[0-9]+\.[0-9]+(\.[0-9]+)?"#, options: .regularExpression) != nil
        }
    }

    private nonisolated static func runVersionCommand(
        executablePath: String,
        timeout: TimeInterval
    ) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard !process.isRunning else {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }
        return normalizedVersionOutput(output)
    }
}
