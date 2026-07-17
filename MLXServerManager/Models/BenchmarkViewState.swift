import Foundation

nonisolated struct BenchmarkViewState: Equatable {
    private(set) var isSpeedTestRunning = false
    private(set) var latestSpeedTestMessage: String
    private(set) var latestSpeedTestDurationMS: Double?
    private(set) var latestBenchmarkResult: BenchmarkResult?
    private(set) var benchmarkHistory: [BenchmarkResult] = []
    private(set) var benchmarkResultsByProfileID: [ModelConfig.ID: BenchmarkResult] = [:]
    private(set) var benchmarkSessionsByProfileID: [ModelConfig.ID: BenchmarkSessionResult] = [:]
    private(set) var benchmarkSampleIndex = 0
    private(set) var benchmarkSampleCount = 0
    private(set) var isAgenticBenchmarkRunning = false
    private(set) var latestAgenticBenchmarkResult: AgenticBenchmarkResult?
    private(set) var agenticBenchmarkHistory: [AgenticBenchmarkResult] = []
    private(set) var agenticBenchmarkResultsByProfileID: [ModelConfig.ID: AgenticBenchmarkResult] = [:]

    init(latestSpeedTestMessage: String) {
        self.latestSpeedTestMessage = latestSpeedTestMessage
    }

    mutating func setLatestSpeedTestMessage(_ message: String) {
        latestSpeedTestMessage = message
    }

    mutating func beginBenchmark(sampleCount: Int, message: String) {
        isSpeedTestRunning = true
        benchmarkSampleIndex = 0
        benchmarkSampleCount = sampleCount
        latestSpeedTestMessage = message
        latestSpeedTestDurationMS = nil
    }

    mutating func beginBenchmarkSample(index: Int) {
        benchmarkSampleIndex = index
    }

    mutating func recordBenchmarkSample(_ result: BenchmarkResult) {
        benchmarkHistory.insert(result, at: 0)
    }

    mutating func cancelBenchmark(message: String) {
        latestSpeedTestMessage = message
        endBenchmark()
    }

    mutating func recordBenchmarkCompletion(
        result: BenchmarkResult,
        session: BenchmarkSessionResult,
        durationMS: Double,
        message: String
    ) {
        latestSpeedTestDurationMS = durationMS
        latestSpeedTestMessage = message
        latestBenchmarkResult = result
        benchmarkResultsByProfileID[result.profileID] = result
        benchmarkSessionsByProfileID[result.profileID] = session
    }

    mutating func endBenchmark() {
        benchmarkSampleIndex = 0
        benchmarkSampleCount = 0
        isSpeedTestRunning = false
    }

    mutating func beginAgenticBenchmark() {
        isAgenticBenchmarkRunning = true
    }

    mutating func recordAgenticBenchmarkCompletion(_ result: AgenticBenchmarkResult) {
        latestAgenticBenchmarkResult = result
        agenticBenchmarkHistory.insert(result, at: 0)
        agenticBenchmarkResultsByProfileID[result.profileID] = result
    }

    mutating func endAgenticBenchmark() {
        isAgenticBenchmarkRunning = false
    }

    mutating func replacePersistedResults(with snapshot: BenchmarkResultsSnapshot) {
        benchmarkResultsByProfileID = snapshot.benchmarkResultsByProfileID
        agenticBenchmarkResultsByProfileID = snapshot.agenticBenchmarkResultsByProfileID
        benchmarkSessionsByProfileID = snapshot.benchmarkSessionsByProfileID

        if benchmarkSessionsByProfileID.isEmpty, !benchmarkResultsByProfileID.isEmpty {
            benchmarkSessionsByProfileID = benchmarkResultsByProfileID.mapValues { result in
                BenchmarkSessionResult(
                    timestamp: result.timestamp,
                    profileID: result.profileID,
                    modelID: result.modelID,
                    selectedProfileName: result.selectedProfileName,
                    preset: .standard,
                    samples: [result]
                )
            }
        }
    }

    mutating func clearPersistedResults() {
        benchmarkResultsByProfileID = [:]
        agenticBenchmarkResultsByProfileID = [:]
        benchmarkSessionsByProfileID = [:]
    }

    var persistedResultsSnapshot: BenchmarkResultsSnapshot {
        BenchmarkResultsSnapshot(
            benchmarkResultsByProfileID: benchmarkResultsByProfileID,
            agenticBenchmarkResultsByProfileID: agenticBenchmarkResultsByProfileID,
            benchmarkSessionsByProfileID: benchmarkSessionsByProfileID
        )
    }
}
