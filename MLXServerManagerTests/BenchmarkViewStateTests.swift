import XCTest
@testable import MLXServerManager

final class BenchmarkViewStateTests: XCTestCase {
    func testBenchmarkLifecycleKeepsCompletionVisibleUntilRunEnds() {
        var state = BenchmarkViewState(latestSpeedTestMessage: "Not run")
        let result = makeBenchmarkResult(profileID: "model-a", latencyMS: 120)
        let session = BenchmarkSessionResult(
            profileID: result.profileID,
            modelID: result.modelID,
            selectedProfileName: result.selectedProfileName,
            preset: .standard,
            samples: [result]
        )

        state.beginBenchmark(sampleCount: 3, message: "Running")
        state.beginBenchmarkSample(index: 1)
        state.recordBenchmarkSample(result)
        state.recordBenchmarkCompletion(
            result: result,
            session: session,
            durationMS: 450,
            message: "Completed"
        )

        XCTAssertTrue(state.isSpeedTestRunning)
        XCTAssertEqual(state.benchmarkSampleIndex, 1)
        XCTAssertEqual(state.benchmarkSampleCount, 3)
        XCTAssertEqual(state.latestSpeedTestMessage, "Completed")
        XCTAssertEqual(state.latestSpeedTestDurationMS, 450)
        XCTAssertEqual(state.latestBenchmarkResult, result)
        XCTAssertEqual(state.benchmarkHistory, [result])
        XCTAssertEqual(state.benchmarkResultsByProfileID[result.profileID], result)
        XCTAssertEqual(state.benchmarkSessionsByProfileID[result.profileID], session)

        state.endBenchmark()

        XCTAssertFalse(state.isSpeedTestRunning)
        XCTAssertEqual(state.benchmarkSampleIndex, 0)
        XCTAssertEqual(state.benchmarkSampleCount, 0)
    }

    func testCancelledBenchmarkResetsProgressWithoutDiscardingHistory() {
        var state = BenchmarkViewState(latestSpeedTestMessage: "Not run")
        let result = makeBenchmarkResult(profileID: "model-a", latencyMS: 120)

        state.beginBenchmark(sampleCount: 5, message: "Running")
        state.beginBenchmarkSample(index: 2)
        state.recordBenchmarkSample(result)
        state.cancelBenchmark(message: "Cancelled")

        XCTAssertFalse(state.isSpeedTestRunning)
        XCTAssertEqual(state.benchmarkSampleIndex, 0)
        XCTAssertEqual(state.benchmarkSampleCount, 0)
        XCTAssertEqual(state.latestSpeedTestMessage, "Cancelled")
        XCTAssertEqual(state.benchmarkHistory, [result])
    }

    func testPersistedLegacyBenchmarkResultSynthesizesStandardSession() {
        var state = BenchmarkViewState(latestSpeedTestMessage: "Not run")
        let result = makeBenchmarkResult(profileID: "model-a", latencyMS: 120)
        let snapshot = BenchmarkResultsSnapshot(
            benchmarkResultsByProfileID: [result.profileID: result],
            agenticBenchmarkResultsByProfileID: [:]
        )

        state.replacePersistedResults(with: snapshot)

        let synthesizedSession = state.benchmarkSessionsByProfileID[result.profileID]
        XCTAssertEqual(synthesizedSession?.preset, .standard)
        XCTAssertEqual(synthesizedSession?.samples, [result])
        XCTAssertEqual(state.persistedResultsSnapshot.benchmarkResultsByProfileID[result.profileID], result)
        XCTAssertEqual(
            state.persistedResultsSnapshot.benchmarkSessionsByProfileID[result.profileID],
            synthesizedSession
        )
    }

    func testAgenticBenchmarkLifecycleStoresResultBeforeRunEnds() {
        var state = BenchmarkViewState(latestSpeedTestMessage: "Not run")
        let result = AgenticBenchmarkResult(
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            selectedProfileName: "Model A",
            phase: .success,
            message: "ok"
        )

        state.beginAgenticBenchmark()
        state.recordAgenticBenchmarkCompletion(result)

        XCTAssertTrue(state.isAgenticBenchmarkRunning)
        XCTAssertEqual(state.latestAgenticBenchmarkResult, result)
        XCTAssertEqual(state.agenticBenchmarkHistory, [result])
        XCTAssertEqual(state.agenticBenchmarkResultsByProfileID[result.profileID], result)

        state.endAgenticBenchmark()

        XCTAssertFalse(state.isAgenticBenchmarkRunning)
    }

    private func makeBenchmarkResult(profileID: String, latencyMS: Double) -> BenchmarkResult {
        BenchmarkResult(
            profileID: profileID,
            modelID: "local/\(profileID)",
            baseURL: "http://127.0.0.1:8000/v1",
            phase: .success,
            readinessLatencyMS: latencyMS,
            selectedProfileName: profileID,
            message: "ok"
        )
    }
}
