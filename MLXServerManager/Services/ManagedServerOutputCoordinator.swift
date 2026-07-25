import Foundation

@MainActor
final class ManagedServerOutputCoordinator {
    struct Generation: Equatable, Sendable {
        fileprivate let id = UUID()
    }

    private let faultDetector: ManagedServerRuntimeFaultDetector
    private var generations: [ModelConfig.ID: Generation] = [:]
    private var faults: [ModelConfig.ID: ManagedServerRuntimeFault] = [:]

    init(
        faultDetector: ManagedServerRuntimeFaultDetector = ManagedServerRuntimeFaultDetector()
    ) {
        self.faultDetector = faultDetector
    }

    func begin(
        modelID: ModelConfig.ID,
        backend: InferenceBackend,
        handler: @escaping @MainActor (String, ManagedServerRuntimeFault?) -> Void
    ) -> @Sendable (String) -> Void {
        let generation = Generation()
        generations[modelID] = generation
        faults[modelID] = nil

        return { [weak self] line in
            Task { @MainActor [weak self] in
                guard let self,
                      self.generations[modelID] == generation else {
                    return
                }

                let detectedFault: ManagedServerRuntimeFault?
                if self.faults[modelID] == nil,
                   let fault = self.faultDetector.detect(
                    line: line,
                    backend: backend
                   ) {
                    self.faults[modelID] = fault
                    detectedFault = fault
                } else {
                    detectedFault = nil
                }

                handler(line, detectedFault)
            }
        }
    }

    func hasFault(for modelID: ModelConfig.ID) -> Bool {
        faults[modelID] != nil
    }

    func fault(for modelID: ModelConfig.ID) -> ManagedServerRuntimeFault? {
        faults[modelID]
    }

    func invalidate(_ modelID: ModelConfig.ID) {
        generations[modelID] = nil
        faults[modelID] = nil
    }

    func invalidateAll() {
        generations.removeAll()
        faults.removeAll()
    }

    func isActive(_ modelID: ModelConfig.ID) -> Bool {
        generations[modelID] != nil
    }
}
