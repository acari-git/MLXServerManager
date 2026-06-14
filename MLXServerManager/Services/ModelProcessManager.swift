import Foundation

struct ModelLaunchRequest: Equatable {
    let executablePath: String
    let modelID: String
    let host: String
    let port: Int
    let advancedLaunchOptions: AdvancedLaunchOptions?
}

struct ModelLaunchResult: Equatable {
    let processIdentifier: Int32
    let commandSummary: String
}

enum ModelStopResult: Equatable {
    case notRunning
    case stopped(processIdentifier: Int32, terminationStatus: Int32, usedInterrupt: Bool)
    case timedOut(processIdentifier: Int32)
}

enum ModelProcessManagerError: LocalizedError, Equatable {
    case executablePathMissing
    case executableNotFound(String)
    case executableNotRunnable(String)
    case alreadyRunning(processIdentifier: Int32)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .executablePathMissing:
            "mlx_lm.server executable path is not set."
        case let .executableNotFound(path):
            "Executable does not exist: \(path)"
        case let .executableNotRunnable(path):
            "Executable is not runnable: \(path)"
        case let .alreadyRunning(processIdentifier):
            "A managed mlx_lm.server process is already running with pid \(processIdentifier)."
        case let .launchFailed(message):
            "Launch failed: \(message)"
        }
    }
}

final class ModelProcessManager {
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutLineCount = 0
    private var stderrLineCount = 0
    private let maximumCapturedLines = 12

    var managedProcessIdentifier: Int32? {
        guard let process, process.isRunning else {
            return nil
        }

        return process.processIdentifier
    }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (Int32) -> Void
    ) throws -> ModelLaunchResult {
        let executablePath = request.executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else {
            throw ModelProcessManagerError.executablePathMissing
        }

        guard FileManager.default.fileExists(atPath: executablePath) else {
            throw ModelProcessManagerError.executableNotFound(executablePath)
        }

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw ModelProcessManagerError.executableNotRunnable(executablePath)
        }

        if let runningPID = managedProcessIdentifier {
            throw ModelProcessManagerError.alreadyRunning(processIdentifier: runningPID)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = Self.launchArguments(for: request)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        resetPipeCounters()
        configurePipe(stdoutPipe, label: "stdout", outputHandler: outputHandler)
        configurePipe(stderrPipe, label: "stderr", outputHandler: outputHandler)

        process.terminationHandler = { [weak self] process in
            let terminationStatus = process.terminationStatus
            Task { @MainActor in
                self?.clearManagedProcessIfMatching(process)
                terminationHandler(terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw ModelProcessManagerError.launchFailed(error.localizedDescription)
        }

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        return ModelLaunchResult(
            processIdentifier: process.processIdentifier,
            commandSummary: Self.commandPreview(for: request, executablePath: executablePath)
        )
    }

    nonisolated static func launchArguments(for request: ModelLaunchRequest) -> [String] {
        var arguments = [
            "--model",
            request.modelID,
            "--host",
            request.host,
            "--port",
            String(request.port)
        ]

        guard let advancedOptions = request.advancedLaunchOptions?.normalized() else {
            return arguments
        }

        appendValue(advancedOptions.chatTemplateArgs, flag: "--chat-template-args", to: &arguments)
        appendValue(advancedOptions.defaultTemperature, flag: "--temperature", to: &arguments)
        appendValue(advancedOptions.defaultTopP, flag: "--top-p", to: &arguments)
        appendValue(advancedOptions.defaultTopK, flag: "--top-k", to: &arguments)
        appendValue(advancedOptions.defaultMinP, flag: "--min-p", to: &arguments)
        appendValue(advancedOptions.defaultMaxTokens, flag: "--max-tokens", to: &arguments)
        appendValue(advancedOptions.allowedOrigins, flag: "--allowed-origins", to: &arguments)
        appendValue(advancedOptions.logLevel, flag: "--log-level", to: &arguments)
        appendValue(advancedOptions.decodeConcurrency, flag: "--decode-concurrency", to: &arguments)
        appendValue(advancedOptions.promptConcurrency, flag: "--prompt-concurrency", to: &arguments)
        appendValue(advancedOptions.prefillStepSize, flag: "--prefill-step-size", to: &arguments)
        appendValue(advancedOptions.promptCacheSize, flag: "--prompt-cache-size", to: &arguments)
        appendValue(advancedOptions.promptCacheBytes, flag: "--prompt-cache-bytes", to: &arguments)

        if let rawExtraArgs = advancedOptions.rawExtraArgs {
            arguments.append(contentsOf: rawExtraArgs.split(whereSeparator: \.isWhitespace).map(String.init))
        }

        return arguments
    }

    nonisolated static func commandPreview(for request: ModelLaunchRequest, executablePath: String) -> String {
        ([executablePath] + launchArguments(for: request))
            .map(shellEscaped)
            .joined(separator: " ")
    }

    func stop(
        gracefulTimeout: TimeInterval = 5,
        interruptTimeout: TimeInterval = 2
    ) async -> ModelStopResult {
        guard let process else {
            return .notRunning
        }

        guard process.isRunning else {
            clearManagedProcessIfMatching(process)
            return .notRunning
        }

        let processIdentifier = process.processIdentifier
        process.terminate()

        if await waitForExit(process, timeout: gracefulTimeout) {
            let terminationStatus = process.terminationStatus
            clearManagedProcessIfMatching(process)
            return .stopped(
                processIdentifier: processIdentifier,
                terminationStatus: terminationStatus,
                usedInterrupt: false
            )
        }

        if process.isRunning {
            process.interrupt()
        }

        if await waitForExit(process, timeout: interruptTimeout) {
            let terminationStatus = process.terminationStatus
            clearManagedProcessIfMatching(process)
            return .stopped(
                processIdentifier: processIdentifier,
                terminationStatus: terminationStatus,
                usedInterrupt: true
            )
        }

        return .timedOut(processIdentifier: processIdentifier)
    }

    private func configurePipe(
        _ pipe: Pipe,
        label: String,
        outputHandler: @escaping (String) -> Void
    ) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                return
            }

            self?.emitLines(from: chunk, label: label, outputHandler: outputHandler)
        }
    }

    private func emitLines(
        from chunk: String,
        label: String,
        outputHandler: @escaping (String) -> Void
    ) {
        let lines = chunk
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for line in lines {
            guard shouldEmitLine(label: label) else {
                return
            }

            outputHandler("[process:\(label)] \(line)")
        }
    }

    private func shouldEmitLine(label: String) -> Bool {
        switch label {
        case "stdout":
            guard stdoutLineCount < maximumCapturedLines else {
                return false
            }

            stdoutLineCount += 1
            return true
        default:
            guard stderrLineCount < maximumCapturedLines else {
                return false
            }

            stderrLineCount += 1
            return true
        }
    }

    private func resetPipeCounters() {
        stdoutLineCount = 0
        stderrLineCount = 0
    }

    private func waitForExit(_ process: Process, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while process.isRunning, Date() < deadline {
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                return !process.isRunning
            }
        }

        return !process.isRunning
    }

    private func clearManagedProcessIfMatching(_ process: Process) {
        guard self.process === process else {
            return
        }

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        self.process = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    nonisolated private static func appendValue(_ value: String?, flag: String, to arguments: inout [String]) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        arguments.append(flag)
        arguments.append(value)
    }

    nonisolated private static func shellEscaped(_ value: String) -> String {
        guard !value.isEmpty else {
            return "''"
        }

        let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/:=")
        if value.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return value
        }

        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
