import Foundation

struct ModelLaunchRequest: Equatable {
    let executablePath: String
    let modelID: String
    let host: String
    let port: Int
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
        process.arguments = [
            "--model",
            request.modelID,
            "--host",
            request.host,
            "--port",
            String(request.port)
        ]

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
            commandSummary: commandSummary(for: request, executablePath: executablePath)
        )
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

    private func commandSummary(for request: ModelLaunchRequest, executablePath: String) -> String {
        "\(executablePath) --model \(request.modelID) --host \(request.host) --port \(request.port)"
    }
}
