import Foundation

nonisolated struct ManagedServerRuntimeFault: Equatable, Sendable {
    nonisolated enum Kind: Equatable, Sendable {
        case generationWorkerTerminated
    }

    let kind: Kind
    let diagnostic: String
}

nonisolated struct ManagedServerRuntimeFaultDetector {
    func detect(
        line: String,
        backend: InferenceBackend
    ) -> ManagedServerRuntimeFault? {
        guard backend == .mlxLM else {
            return nil
        }

        let normalized = line.lowercased()
        guard normalized.contains("[process:stderr]") else {
            return nil
        }

        let mentionsGenerationWorker = Self.generationWorkerMarkers.contains(where: normalized.contains)
        let reportsThreadException = normalized.contains("exception in thread")
            && mentionsGenerationWorker
        let reportsWorkerTermination = mentionsGenerationWorker
            && Self.terminationMarkers.contains(where: normalized.contains)
        guard reportsThreadException || reportsWorkerTermination else {
            return nil
        }

        return ManagedServerRuntimeFault(
            kind: .generationWorkerTerminated,
            diagnostic: line
        )
    }

    private static let generationWorkerMarkers = [
        "(_generate)",
        "(generation_worker)",
        "(generation worker)",
        "generation worker",
        "generation_worker",
        "generation thread"
    ]

    private static let terminationMarkers = [
        "stopped unexpectedly",
        "terminated unexpectedly",
        "exited unexpectedly",
        "crashed",
        "has stopped",
        "is no longer running"
    ]
}
