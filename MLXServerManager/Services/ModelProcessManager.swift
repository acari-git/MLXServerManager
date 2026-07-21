import Darwin
import Foundation

nonisolated struct ModelLaunchRequest: Equatable {
    let executablePath: String
    let backend: InferenceBackend
    let modelID: String
    let host: String
    let port: Int
    let enableThinking: Bool
    let advancedLaunchOptions: AdvancedLaunchOptions?

    init(
        executablePath: String,
        backend: InferenceBackend = .mlxLM,
        modelID: String,
        host: String,
        port: Int,
        enableThinking: Bool,
        advancedLaunchOptions: AdvancedLaunchOptions?
    ) {
        self.executablePath = executablePath
        self.backend = backend
        self.modelID = modelID
        self.host = host
        self.port = port
        self.enableThinking = enableThinking
        self.advancedLaunchOptions = advancedLaunchOptions
    }
}

nonisolated struct ModelLaunchResult: Equatable {
    let processIdentifier: Int32
    let commandSummary: String
}

nonisolated enum ModelStopMethod: Equatable {
    case terminate
    case interrupt
    case kill
}

nonisolated enum ModelStopResult: Equatable {
    case notRunning
    case stopped(processIdentifier: Int32, terminationStatus: Int32, stopMethod: ModelStopMethod)
    case timedOut(processIdentifier: Int32)
}

nonisolated enum ModelProcessManagerError: LocalizedError, Equatable {
    case executablePathMissing
    case executableNotFound(String)
    case executableNotRunnable(String)
    case alreadyRunning(processIdentifier: Int32)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .executablePathMissing:
            "Server executable path is not set."
        case let .executableNotFound(path):
            "Executable does not exist: \(path)"
        case let .executableNotRunnable(path):
            "Executable is not runnable: \(path)"
        case let .alreadyRunning(processIdentifier):
            "A managed server process is already running with pid \(processIdentifier)."
        case let .launchFailed(message):
            "Launch failed: \(message)"
        }
    }
}

protocol ModelProcessManaging: AnyObject {
    var managedProcessIdentifier: Int32? { get }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
    ) throws -> ModelLaunchResult

    func stop(
        gracefulTimeout: TimeInterval,
        interruptTimeout: TimeInterval
    ) async -> ModelStopResult
}

final class ModelProcessManager: ModelProcessManaging {
    private static let minimumForcedTerminationReapTimeout: TimeInterval = 1

    private struct ProcessCompletionState {
        let process: Process
        let stdoutPipe: Pipe
        let stderrPipe: Pipe
        let lineBuffer: LineStreamBuffer
        let outputHandler: @Sendable (String) -> Void
        let terminationHandler: @MainActor @Sendable (Int32) -> Void
        var terminationStatus: Int32?
        var stdoutReachedEOF = false
        var stderrReachedEOF = false
    }

    private var process: Process?
    private var completionStates: [ObjectIdentifier: ProcessCompletionState] = [:]
    private var outputDrainTimeoutTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private let outputDrainTimeoutNanoseconds: UInt64

    init(outputDrainTimeout: TimeInterval = 2) {
        outputDrainTimeoutNanoseconds = Self.nanoseconds(for: outputDrainTimeout)
    }

    var managedProcessIdentifier: Int32? {
        guard let process, process.isRunning else {
            return nil
        }

        return process.processIdentifier
    }

    func start(
        request: ModelLaunchRequest,
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @MainActor @Sendable (Int32) -> Void
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
        let lineBuffer = LineStreamBuffer(maximumLinesPerLabel: 200)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let processIdentifier = ObjectIdentifier(process)
        completionStates[processIdentifier] = ProcessCompletionState(
            process: process,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe,
            lineBuffer: lineBuffer,
            outputHandler: outputHandler,
            terminationHandler: terminationHandler
        )
        self.process = process
        configurePipe(
            stdoutPipe,
            process: process,
            lineBuffer: lineBuffer,
            label: "stdout",
            outputHandler: outputHandler
        )
        configurePipe(
            stderrPipe,
            process: process,
            lineBuffer: lineBuffer,
            label: "stderr",
            outputHandler: outputHandler
        )

        process.terminationHandler = { [weak self] process in
            let terminationStatus = process.terminationStatus
            Task { @MainActor [weak self, process] in
                self?.recordTermination(status: terminationStatus, for: process)
            }
        }

        do {
            try process.run()
        } catch {
            discardCompletionState(for: process)
            throw ModelProcessManagerError.launchFailed(error.localizedDescription)
        }

        return ModelLaunchResult(
            processIdentifier: process.processIdentifier,
            commandSummary: Self.commandPreview(for: request, executablePath: executablePath)
        )
    }

    nonisolated static func launchArguments(for request: ModelLaunchRequest) -> [String] {
        switch request.backend {
        case .mlxLM:
            mlxLMLaunchArguments(for: request)
        case .rapidMLX:
            rapidMLXLaunchArguments(for: request)
        }
    }

    nonisolated private static func mlxLMLaunchArguments(for request: ModelLaunchRequest) -> [String] {
        var arguments = [
            "--model",
            request.modelID,
            "--host",
            request.host,
            "--port",
            String(request.port)
        ]

        let advancedOptions = request.advancedLaunchOptions?.normalized()
        let chatTemplateArgs = advancedOptions?.chatTemplateArgs ?? thinkingChatTemplateArgs(isEnabled: request.enableThinking)
        appendValue(chatTemplateArgs, flag: "--chat-template-args", to: &arguments)

        guard let advancedOptions else {
            return arguments
        }
        appendValue(advancedOptions.defaultTemperature, flag: "--temp", to: &arguments)
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

        if let rawExtraArgs = advancedOptions.rawExtraArgs,
           let parsedArguments = try? ShellArgumentParser.parse(rawExtraArgs) {
            arguments.append(contentsOf: ManagedLaunchArgumentPolicy.removingForbiddenArguments(
                from: parsedArguments,
                backend: .mlxLM
            ))
        }

        return arguments
    }

    nonisolated private static func rapidMLXLaunchArguments(for request: ModelLaunchRequest) -> [String] {
        var arguments = [
            "serve",
            request.modelID,
            "--host",
            request.host,
            "--port",
            String(request.port)
        ]

        if !request.enableThinking {
            arguments.append("--no-thinking")
        }

        guard let options = request.advancedLaunchOptions?.normalized() else {
            return arguments
        }

        appendValue(options.defaultTemperature, flag: "--default-temperature", to: &arguments)
        appendValue(options.defaultTopP, flag: "--default-top-p", to: &arguments)
        appendValue(options.defaultTopK, flag: "--default-top-k", to: &arguments)
        appendValue(options.defaultMinP, flag: "--default-min-p", to: &arguments)
        appendValue(options.defaultMaxTokens, flag: "--max-tokens", to: &arguments)
        appendMultipleValues(options.allowedOrigins, flag: "--cors-origins", to: &arguments)
        appendValue(options.logLevel?.uppercased(), flag: "--log-level", to: &arguments)
        appendValue(options.decodeConcurrency, flag: "--max-num-seqs", to: &arguments)
        appendValue(options.promptConcurrency, flag: "--max-concurrent-requests", to: &arguments)
        appendValue(options.prefillStepSize, flag: "--prefill-step-size", to: &arguments)
        appendValue(options.promptCacheSize, flag: "--prefix-cache-size", to: &arguments)
        appendCacheMemoryMegabytes(options.promptCacheBytes, to: &arguments)

        if let rawExtraArgs = options.rawExtraArgs,
           let parsedArguments = try? ShellArgumentParser.parse(rawExtraArgs) {
            arguments.append(contentsOf: ManagedLaunchArgumentPolicy.removingForbiddenArguments(
                from: parsedArguments,
                backend: .rapidMLX
            ))
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
            return .notRunning
        }

        let processIdentifier = process.processIdentifier
        process.terminate()

        if await waitForExit(process, timeout: gracefulTimeout) {
            let terminationStatus = process.terminationStatus
            return .stopped(
                processIdentifier: processIdentifier,
                terminationStatus: terminationStatus,
                stopMethod: .terminate
            )
        }

        if process.isRunning {
            process.interrupt()
        }

        if await waitForExit(process, timeout: interruptTimeout) {
            let terminationStatus = process.terminationStatus
            return .stopped(
                processIdentifier: processIdentifier,
                terminationStatus: terminationStatus,
                stopMethod: .interrupt
            )
        }

        if process.isRunning {
            Darwin.kill(processIdentifier, SIGKILL)
        }

        let forcedTerminationReapTimeout = max(
            interruptTimeout,
            Self.minimumForcedTerminationReapTimeout
        )
        if await waitForExit(process, timeout: forcedTerminationReapTimeout) {
            let terminationStatus = process.terminationStatus
            return .stopped(
                processIdentifier: processIdentifier,
                terminationStatus: terminationStatus,
                stopMethod: .kill
            )
        }

        return .timedOut(processIdentifier: processIdentifier)
    }

    private func configurePipe(
        _ pipe: Pipe,
        process: Process,
        lineBuffer: LineStreamBuffer,
        label: String,
        outputHandler: @escaping @Sendable (String) -> Void
    ) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard let self else { return }

            if data.isEmpty {
                for line in lineBuffer.flush(label: label) {
                    outputHandler("[process:\(label)] \(line)")
                }
                Task { @MainActor [weak self, process] in
                    self?.recordPipeEOF(label: label, for: process)
                }
                return
            }

            guard let chunk = String(data: data, encoding: .utf8) else {
                return
            }
            for line in lineBuffer.consume(chunk, label: label) {
                outputHandler("[process:\(label)] \(line)")
            }
        }
    }

    private func recordTermination(status: Int32, for process: Process) {
        let identifier = ObjectIdentifier(process)
        guard var state = completionStates[identifier],
              state.process === process else {
            return
        }

        state.terminationStatus = status
        completionStates[identifier] = state
        scheduleOutputDrainTimeout(for: process)
        completeProcessIfReady(process)
    }

    private func recordPipeEOF(label: String, for process: Process) {
        let identifier = ObjectIdentifier(process)
        guard var state = completionStates[identifier],
              state.process === process else {
            return
        }

        switch label {
        case "stdout":
            state.stdoutReachedEOF = true
        case "stderr":
            state.stderrReachedEOF = true
        default:
            return
        }
        completionStates[identifier] = state
        completeProcessIfReady(process)
    }

    private func completeProcessIfReady(_ process: Process, allowMissingEOF: Bool = false) {
        let identifier = ObjectIdentifier(process)
        guard let state = completionStates[identifier],
              state.process === process,
              let terminationStatus = state.terminationStatus,
              allowMissingEOF || (state.stdoutReachedEOF && state.stderrReachedEOF) else {
            return
        }

        flushPendingOutput(state)
        discardCompletionState(for: process)
        state.terminationHandler(terminationStatus)
    }

    private func scheduleOutputDrainTimeout(for process: Process) {
        let identifier = ObjectIdentifier(process)
        outputDrainTimeoutTasks[identifier]?.cancel()
        outputDrainTimeoutTasks[identifier] = Task { @MainActor [weak self, process] in
            guard let self else { return }
            if outputDrainTimeoutNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: outputDrainTimeoutNanoseconds)
            }
            guard !Task.isCancelled else { return }
            completeProcessIfReady(process, allowMissingEOF: true)
        }
    }

    private func flushPendingOutput(_ state: ProcessCompletionState) {
        for label in ["stdout", "stderr"] {
            for line in state.lineBuffer.flush(label: label) {
                state.outputHandler("[process:\(label)] \(line)")
            }
        }
    }

    private func waitForExit(_ process: Process, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(max(timeout, 0))

        while process.isRunning {
            let remainingInterval = deadline.timeIntervalSinceNow
            guard remainingInterval > 0 else {
                break
            }

            let pollingInterval = min(remainingInterval, 0.1)
            await Self.sleepIgnoringCancellation(
                nanoseconds: Self.nanoseconds(for: pollingInterval)
            )
        }

        return !process.isRunning
    }

    nonisolated private static func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        guard nanoseconds > 0 else { return }
        await Task.detached {
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                // Detached tasks do not inherit the caller's cancellation. This catch is defensive.
            }
        }.value
    }

    private func discardCompletionState(for process: Process) {
        let identifier = ObjectIdentifier(process)
        outputDrainTimeoutTasks.removeValue(forKey: identifier)?.cancel()
        if let state = completionStates.removeValue(forKey: identifier) {
            state.stdoutPipe.fileHandleForReading.readabilityHandler = nil
            state.stderrPipe.fileHandleForReading.readabilityHandler = nil
            try? state.stdoutPipe.fileHandleForReading.close()
            try? state.stderrPipe.fileHandleForReading.close()
        }
        if self.process === process {
            self.process = nil
        }
    }

    nonisolated private static func nanoseconds(for interval: TimeInterval) -> UInt64 {
        guard interval > 0 else { return 0 }
        return UInt64(min(interval, TimeInterval(UInt64.max) / 1_000_000_000) * 1_000_000_000)
    }

    nonisolated private static func thinkingChatTemplateArgs(isEnabled: Bool) -> String? {
        guard isEnabled else { return nil }
        return "{\"enable_thinking\":true}"
    }

    nonisolated private static func appendValue(_ value: String?, flag: String, to arguments: inout [String]) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        arguments.append(flag)
        arguments.append(value)
    }

    nonisolated private static func appendMultipleValues(_ value: String?, flag: String, to arguments: inout [String]) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let shellValues = (try? ShellArgumentParser.parse(trimmed)) ?? [trimmed]
        let parsed = shellValues.flatMap { value in
            value.split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        guard !parsed.isEmpty else { return }

        arguments.append(flag)
        arguments.append(contentsOf: parsed)
    }

    nonisolated private static func appendCacheMemoryMegabytes(_ byteText: String?, to arguments: inout [String]) {
        guard let byteText,
              let bytes = Int64(byteText.trimmingCharacters(in: .whitespacesAndNewlines)),
              bytes > 0 else {
            return
        }

        let bytesPerMegabyte: Int64 = 1_048_576
        let megabytes = max(1, (bytes + bytesPerMegabyte - 1) / bytesPerMegabyte)
        appendValue(String(megabytes), flag: "--cache-memory-mb", to: &arguments)
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
