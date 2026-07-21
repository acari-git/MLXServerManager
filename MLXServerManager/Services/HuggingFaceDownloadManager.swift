import Darwin
import Foundation

struct HuggingFaceDownloadRequest: Equatable {
    let repositoryID: String
    let destinationPath: String
    let revision: String
    let includePatterns: [String]
    let excludePatterns: [String]
    let authorizationValue: String?
}

struct HuggingFaceDownloadResult: Equatable {
    let repositoryID: String
    let destinationPath: String
    let terminationStatus: Int32
}

struct HuggingFaceCLIResolution: Equatable {
    let executablePath: String
    let searchedPaths: [String]

    var displayPath: String {
        ModelAvailabilityPathFormatter.compact(path: executablePath)
    }
}

enum HuggingFaceDownloadError: LocalizedError, Equatable {
    case cancelled
    case commandNotAvailable(searchedPaths: [String])
    case destinationPreparationFailed(String)
    case processLaunchFailed(String)
    case processFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Download cancelled. The model was not added."
        case let .commandNotAvailable(searchedPaths):
            "The hf command is not available. Checked: \(searchedPaths.map { ModelAvailabilityPathFormatter.compact(path: $0) }.joined(separator: ", ")). Install Hugging Face CLI or restart the app after installing it."
        case let .destinationPreparationFailed(message):
            "Could not prepare the destination folder: \(message)"
        case let .processLaunchFailed(message):
            "Could not start the Hugging Face download: \(message)"
        case let .processFailed(status):
            "Hugging Face download failed with exit status \(status)."
        }
    }
}

protocol HuggingFaceModelDownloading: AnyObject {
    func download(
        request: HuggingFaceDownloadRequest,
        outputHandler: @escaping @Sendable (String) -> Void
    ) async throws -> HuggingFaceDownloadResult
    func cancel()
}

final class HuggingFaceDownloadManager: HuggingFaceModelDownloading {
    private struct ProcessCompletionState {
        let process: Process
        let request: HuggingFaceDownloadRequest
        let searchEnvironment: [String: String]
        let sensitiveOutputValues: [String]
        let outputHandler: @Sendable (String) -> Void
        let continuation: CheckedContinuation<HuggingFaceDownloadResult, Error>
        var terminationStatus: Int32?
        var stdoutReachedEOF = false
        var stderrReachedEOF = false
    }

    private let fileManager: FileManager
    private let environment: [String: String]
    private var activeProcess: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var processCompletionState: ProcessCompletionState?
    private var cancellationEscalationTask: Task<Void, Never>?
    private var outputDrainTimeoutTask: Task<Void, Never>?
    private var cancellationRequestedProcess: Process?
    private let lineBuffer = LineStreamBuffer(maximumLinesPerLabel: 1_000)
    private let cancellationGracePeriodNanoseconds: UInt64
    private let cancellationInterruptPeriodNanoseconds: UInt64
    private let outputDrainTimeoutNanoseconds: UInt64

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        cancellationGracePeriod: TimeInterval = 1,
        cancellationInterruptPeriod: TimeInterval = 1,
        outputDrainTimeout: TimeInterval = 2
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.cancellationGracePeriodNanoseconds = Self.nanoseconds(for: cancellationGracePeriod)
        self.cancellationInterruptPeriodNanoseconds = Self.nanoseconds(for: cancellationInterruptPeriod)
        self.outputDrainTimeoutNanoseconds = Self.nanoseconds(for: outputDrainTimeout)
    }

    func download(
        request: HuggingFaceDownloadRequest,
        outputHandler: @escaping @Sendable (String) -> Void
    ) async throws -> HuggingFaceDownloadResult {
        try Self.checkCancellation()

        let destinationURL = URL(fileURLWithPath: request.destinationPath, isDirectory: true)
        let parentURL = destinationURL.deletingLastPathComponent()
        let searchEnvironment = environment

        do {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        } catch {
            throw HuggingFaceDownloadError.destinationPreparationFailed(error.localizedDescription)
        }

        guard let resolution = Self.resolveCLI(
            fileManager: fileManager,
            environment: searchEnvironment
        ) else {
            throw HuggingFaceDownloadError.commandNotAvailable(
                searchedPaths: Self.candidateExecutablePaths(environment: searchEnvironment)
            )
        }

        do {
            try HuggingFaceDownloadProvenanceStore(fileManager: fileManager).prepare(
                destinationURL: destinationURL,
                repositoryID: request.repositoryID,
                revision: request.revision
            )
        } catch {
            throw HuggingFaceDownloadError.destinationPreparationFailed(error.localizedDescription)
        }

        outputHandler("[hf] using \(resolution.displayPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolution.executablePath)
        let subcommand = "down" + "load"
        var arguments = [subcommand, request.repositoryID, "--revision", request.revision, "--local-dir", request.destinationPath]
        for pattern in request.includePatterns {
            arguments.append(contentsOf: ["--include", pattern])
        }
        for pattern in request.excludePatterns {
            arguments.append(contentsOf: ["--exclude", pattern])
        }
        process.arguments = arguments

        var processEnvironment = searchEnvironment
        if let authorizationValue = request.authorizationValue, !authorizationValue.isEmpty {
            processEnvironment["HF_TOKEN"] = authorizationValue
        }
        let sensitiveOutputValues = Self.sensitiveOutputValues(
            authorizationValue: request.authorizationValue,
            environment: processEnvironment
        )
        let candidateDirectories = Self.candidateExecutablePaths(environment: searchEnvironment)
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
        let path = processEnvironment["PATH", default: ""]
        processEnvironment["PATH"] = (candidateDirectories + [path])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        process.environment = processEnvironment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        lineBuffer.reset()
        cancellationRequestedProcess = nil
        activeProcess = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        configurePipe(
            stdoutPipe,
            process: process,
            label: "stdout",
            sensitiveValues: sensitiveOutputValues,
            outputHandler: outputHandler
        )
        configurePipe(
            stderrPipe,
            process: process,
            label: "stderr",
            sensitiveValues: sensitiveOutputValues,
            outputHandler: outputHandler
        )

        do {
            try Self.checkCancellation()
        } catch {
            clearIfMatching(process)
            throw error
        }

        return try await withCheckedThrowingContinuation { continuation in
            processCompletionState = ProcessCompletionState(
                process: process,
                request: request,
                searchEnvironment: searchEnvironment,
                sensitiveOutputValues: sensitiveOutputValues,
                outputHandler: outputHandler,
                continuation: continuation
            )
            process.terminationHandler = { [weak self] process in
                let status = process.terminationStatus
                Task { @MainActor [weak self] in
                    self?.recordTermination(status: status, for: process)
                }
            }

            do {
                try process.run()
            } catch {
                processCompletionState = nil
                clearIfMatching(process)
                continuation.resume(throwing: HuggingFaceDownloadError.processLaunchFailed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        guard let process = activeProcess, process.isRunning else {
            return
        }
        guard cancellationRequestedProcess !== process else {
            return
        }

        cancellationRequestedProcess = process
        process.terminate()

        cancellationEscalationTask = Task { @MainActor [weak self, process] in
            guard let self else { return }
            await waitForCancellationPeriod(cancellationGracePeriodNanoseconds)
            guard !Task.isCancelled,
                  activeProcess === process,
                  process.isRunning else {
                return
            }

            process.interrupt()
            await waitForCancellationPeriod(cancellationInterruptPeriodNanoseconds)
            guard !Task.isCancelled,
                  activeProcess === process,
                  process.isRunning else {
                return
            }

            Darwin.kill(process.processIdentifier, SIGKILL)
        }
    }

    private func configurePipe(
        _ pipe: Pipe,
        process: Process,
        label: String,
        sensitiveValues: [String],
        outputHandler: @escaping @Sendable (String) -> Void
    ) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard let self else { return }

            if data.isEmpty {
                emit(
                    lineBuffer.flush(label: label),
                    label: label,
                    sensitiveValues: sensitiveValues,
                    outputHandler: outputHandler
                )
                Task { @MainActor [weak self, process] in
                    self?.recordPipeEOF(label: label, for: process)
                }
                return
            }

            guard let chunk = String(data: data, encoding: .utf8) else {
                return
            }
            emit(
                lineBuffer.consume(chunk, label: label),
                label: label,
                sensitiveValues: sensitiveValues,
                outputHandler: outputHandler
            )
        }
    }

    private func recordTermination(status: Int32, for process: Process) {
        guard var state = processCompletionState,
              state.process === process else {
            return
        }

        state.terminationStatus = status
        processCompletionState = state
        scheduleOutputDrainTimeout(for: process)
        completeProcessIfReady(process)
    }

    private func recordPipeEOF(label: String, for process: Process) {
        guard var state = processCompletionState,
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
        processCompletionState = state
        completeProcessIfReady(process)
    }

    private func completeProcessIfReady(_ process: Process, allowMissingEOF: Bool = false) {
        guard let state = processCompletionState,
              state.process === process,
              let status = state.terminationStatus,
              allowMissingEOF || (state.stdoutReachedEOF && state.stderrReachedEOF) else {
            return
        }

        processCompletionState = nil
        let wasCancelled = cancellationRequestedProcess === process
        flushPendingOutput(
            sensitiveValues: state.sensitiveOutputValues,
            outputHandler: state.outputHandler
        )
        clearIfMatching(process)

        if wasCancelled {
            state.continuation.resume(throwing: HuggingFaceDownloadError.cancelled)
        } else if status == 0 {
            state.continuation.resume(
                returning: HuggingFaceDownloadResult(
                    repositoryID: state.request.repositoryID,
                    destinationPath: state.request.destinationPath,
                    terminationStatus: status
                )
            )
        } else if status == 127 {
            state.continuation.resume(
                throwing: HuggingFaceDownloadError.commandNotAvailable(
                    searchedPaths: Self.candidateExecutablePaths(environment: state.searchEnvironment)
                )
            )
        } else {
            state.continuation.resume(throwing: HuggingFaceDownloadError.processFailed(status: status))
        }
    }

    private func scheduleOutputDrainTimeout(for process: Process) {
        outputDrainTimeoutTask?.cancel()
        outputDrainTimeoutTask = Task { @MainActor [weak self, process] in
            guard let self else { return }
            await waitForCancellationPeriod(outputDrainTimeoutNanoseconds)
            guard !Task.isCancelled else { return }
            completeProcessIfReady(process, allowMissingEOF: true)
        }
    }

    private func flushPendingOutput(
        sensitiveValues: [String],
        outputHandler: @escaping @Sendable (String) -> Void
    ) {
        for label in ["stdout", "stderr"] {
            emit(
                lineBuffer.flush(label: label),
                label: label,
                sensitiveValues: sensitiveValues,
                outputHandler: outputHandler
            )
        }
    }

    nonisolated private func emit(
        _ lines: [String],
        label: String,
        sensitiveValues: [String],
        outputHandler: @escaping @Sendable (String) -> Void
    ) {
        for line in lines {
            let sanitized = HuggingFaceDownloadPlanner.sanitizedOutputLine(
                line,
                sensitiveValues: sensitiveValues
            )
            guard !sanitized.isEmpty else { continue }
            outputHandler("[hf:\(label)] \(sanitized)")
        }
    }

    nonisolated private static func sensitiveOutputValues(
        authorizationValue: String?,
        environment: [String: String]
    ) -> [String] {
        let values: [String] = [
            authorizationValue,
            environment["HF_TOKEN"],
            environment["HUGGING_FACE_HUB_TOKEN"],
            environment["HUGGINGFACE_HUB_TOKEN"]
        ]
        .compactMap { value -> String? in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return values.reduce(into: [String]()) { result, value in
            guard !result.contains(value) else { return }
            result.append(value)
        }
    }

    nonisolated static func resolveCLI(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HuggingFaceCLIResolution? {
        let candidates = candidateExecutablePaths(environment: environment)
        guard let executablePath = candidates.first(where: { path in
            fileManager.isExecutableFile(atPath: path)
        }) else {
            return nil
        }

        return HuggingFaceCLIResolution(
            executablePath: executablePath,
            searchedPaths: candidates
        )
    }

    nonisolated static func candidateExecutablePaths(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        var candidates: [String] = []
        let home = environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        if !home.isEmpty {
            candidates.append(URL(fileURLWithPath: home).appendingPathComponent(".local/bin/hf").path)
            candidates.append(URL(fileURLWithPath: home).appendingPathComponent(".hf-cli/bin/hf").path)
        }

        candidates.append("/opt/homebrew/bin/hf")
        candidates.append("/usr/local/bin/hf")
        candidates.append("/usr/bin/hf")

        let pathEntries = environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }
        for directory in pathEntries {
            candidates.append(URL(fileURLWithPath: directory).appendingPathComponent("hf").path)
        }

        var unique: [String] = []
        for candidate in candidates {
            let standardized = URL(fileURLWithPath: candidate).standardizedFileURL.path
            if !unique.contains(standardized) {
                unique.append(standardized)
            }
        }
        return unique
    }

    private func clearIfMatching(_ process: Process) {
        guard activeProcess === process else {
            return
        }
        cancellationEscalationTask?.cancel()
        cancellationEscalationTask = nil
        outputDrainTimeoutTask?.cancel()
        outputDrainTimeoutTask = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        try? stdoutPipe?.fileHandleForReading.close()
        try? stderrPipe?.fileHandleForReading.close()
        activeProcess = nil
        stdoutPipe = nil
        stderrPipe = nil
        if cancellationRequestedProcess === process {
            cancellationRequestedProcess = nil
        }
    }

    private func waitForCancellationPeriod(_ nanoseconds: UInt64) async {
        guard nanoseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    nonisolated private static func nanoseconds(for interval: TimeInterval) -> UInt64 {
        guard interval > 0 else { return 0 }
        return UInt64(min(interval, TimeInterval(UInt64.max) / 1_000_000_000) * 1_000_000_000)
    }

    nonisolated private static func checkCancellation() throws {
        guard !Task.isCancelled else {
            throw HuggingFaceDownloadError.cancelled
        }
    }
}
