import Foundation

nonisolated enum BenchmarkSessionRunEvent: Equatable {
    case warmUpStarted
    case warmUpCompleted(succeeded: Bool)
    case sampleStarted(index: Int, total: Int)
    case sampleCompleted(index: Int, total: Int, result: BenchmarkResult)
}

nonisolated struct BenchmarkSessionRunOutcome: Equatable {
    let session: BenchmarkSessionResult?
    let elapsedMilliseconds: Double

    var representativeResult: BenchmarkResult? {
        session?.representativeResult
    }
}

@MainActor
struct BenchmarkSessionRunner {
    typealias WarmUpHandler = (BenchmarkRunConfiguration) async -> Bool
    typealias SampleHandler = (BenchmarkRunConfiguration) async -> BenchmarkResult

    private let warmUpHandler: WarmUpHandler
    private let sampleHandler: SampleHandler

    init(service: BenchmarkService) {
        warmUpHandler = { configuration in
            await service.warmUp(configuration: configuration)
        }
        sampleHandler = { configuration in
            await service.run(configuration: configuration)
        }
    }

    init(
        warmUp: @escaping WarmUpHandler,
        runSample: @escaping SampleHandler
    ) {
        warmUpHandler = warmUp
        sampleHandler = runSample
    }

    func run(
        configuration: BenchmarkRunConfiguration,
        preset: BenchmarkPreset,
        executionFingerprint: String?,
        onEvent: (BenchmarkSessionRunEvent) -> Void
    ) async -> BenchmarkSessionRunOutcome {
        let startedAt = Date()
        var samples: [BenchmarkResult] = []

        if preset.usesWarmup {
            onEvent(.warmUpStarted)
            let succeeded = await warmUpHandler(configuration)
            onEvent(.warmUpCompleted(succeeded: succeeded))
        }

        for index in 1...preset.sampleCount {
            guard !Task.isCancelled else { break }
            onEvent(.sampleStarted(index: index, total: preset.sampleCount))
            let result = await sampleHandler(configuration)
            samples.append(result)
            onEvent(.sampleCompleted(index: index, total: preset.sampleCount, result: result))
        }

        let elapsedMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
        guard !samples.isEmpty else {
            return BenchmarkSessionRunOutcome(
                session: nil,
                elapsedMilliseconds: elapsedMilliseconds
            )
        }

        return BenchmarkSessionRunOutcome(
            session: BenchmarkSessionResult(
                profileID: configuration.profileID,
                modelID: configuration.modelID,
                selectedProfileName: configuration.selectedProfileName,
                preset: preset,
                executionFingerprint: executionFingerprint,
                samples: samples
            ),
            elapsedMilliseconds: elapsedMilliseconds
        )
    }
}
