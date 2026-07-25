import Foundation

@MainActor
final class LaunchFailureDiagnosticCoordinator {
    private let maximumLinesPerModel: Int
    private var linesByModelID: [ModelConfig.ID: [String]] = [:]

    init(maximumLinesPerModel: Int = 80) {
        self.maximumLinesPerModel = max(maximumLinesPerModel, 10)
    }

    func begin(modelID: ModelConfig.ID) {
        linesByModelID[modelID] = []
    }

    func append(_ line: String, modelID: ModelConfig.ID) {
        var lines = linesByModelID[modelID] ?? []
        lines.append(line)
        if lines.count > maximumLinesPerModel {
            lines.removeFirst(lines.count - maximumLinesPerModel)
        }
        linesByModelID[modelID] = lines
    }

    func diagnose(
        modelID: ModelConfig.ID,
        backend: InferenceBackend,
        fallbackMessage: String
    ) -> LaunchFailureDiagnosis {
        LaunchFailureClassifier.classify(
            modelID: modelID,
            backend: backend,
            lines: linesByModelID[modelID] ?? [],
            fallbackMessage: fallbackMessage
        )
    }

    func clear(modelID: ModelConfig.ID) {
        linesByModelID[modelID] = nil
    }

    func clearAll() {
        linesByModelID.removeAll()
    }
}
