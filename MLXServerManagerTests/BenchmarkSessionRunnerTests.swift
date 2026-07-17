import XCTest
@testable import MLXServerManager

@MainActor
final class BenchmarkSessionRunnerTests: XCTestCase {
    func testQuickPresetSkipsWarmUpAndRunsOneSample() async throws {
        var warmUpCount = 0
        var sampleCount = 0
        var events: [BenchmarkSessionRunEvent] = []
        let expected = makeResult(index: 1)
        let runner = BenchmarkSessionRunner(
            warmUp: { _ in
                warmUpCount += 1
                return true
            },
            runSample: { _ in
                sampleCount += 1
                return expected
            }
        )

        let outcome = await runner.run(
            configuration: makeConfiguration(),
            preset: .quick,
            executionFingerprint: "fingerprint",
            onEvent: { events.append($0) }
        )

        XCTAssertEqual(warmUpCount, 0)
        XCTAssertEqual(sampleCount, 1)
        XCTAssertEqual(outcome.session?.samples, [expected])
        XCTAssertEqual(outcome.session?.executionFingerprint, "fingerprint")
        XCTAssertEqual(events, [
            .sampleStarted(index: 1, total: 1),
            .sampleCompleted(index: 1, total: 1, result: expected)
        ])
    }

    func testStandardPresetReportsWarmUpAndEverySampleInOrder() async {
        var nextSampleIndex = 0
        var events: [BenchmarkSessionRunEvent] = []
        let runner = BenchmarkSessionRunner(
            warmUp: { _ in false },
            runSample: { _ in
                nextSampleIndex += 1
                return self.makeResult(index: nextSampleIndex)
            }
        )

        let outcome = await runner.run(
            configuration: makeConfiguration(),
            preset: .standard,
            executionFingerprint: nil,
            onEvent: { events.append($0) }
        )

        XCTAssertEqual(outcome.session?.samples.count, 3)
        XCTAssertEqual(events.count, 8)
        XCTAssertEqual(events[0], .warmUpStarted)
        XCTAssertEqual(events[1], .warmUpCompleted(succeeded: false))
        XCTAssertEqual(events[2], .sampleStarted(index: 1, total: 3))
        XCTAssertEqual(events[3], .sampleCompleted(index: 1, total: 3, result: makeResult(index: 1)))
        XCTAssertEqual(events[6], .sampleStarted(index: 3, total: 3))
        XCTAssertEqual(events[7], .sampleCompleted(index: 3, total: 3, result: makeResult(index: 3)))
    }

    func testRunnerPreservesSessionIdentityAndRepresentativeResult() async {
        let configuration = makeConfiguration()
        let slow = makeResult(index: 1, outputTokensPerSecond: 10)
        let median = makeResult(index: 2, outputTokensPerSecond: 20)
        let fast = makeResult(index: 3, outputTokensPerSecond: 30)
        var results = [slow, median, fast]
        let runner = BenchmarkSessionRunner(
            warmUp: { _ in true },
            runSample: { _ in results.removeFirst() }
        )

        let outcome = await runner.run(
            configuration: configuration,
            preset: .standard,
            executionFingerprint: "execution-v1",
            onEvent: { _ in }
        )

        XCTAssertEqual(outcome.session?.profileID, configuration.profileID)
        XCTAssertEqual(outcome.session?.modelID, configuration.modelID)
        XCTAssertEqual(outcome.session?.selectedProfileName, configuration.selectedProfileName)
        XCTAssertEqual(outcome.session?.executionFingerprint, "execution-v1")
        XCTAssertEqual(outcome.representativeResult, median)
        XCTAssertGreaterThanOrEqual(outcome.elapsedMilliseconds, 0)
    }

    private func makeConfiguration() -> BenchmarkRunConfiguration {
        BenchmarkRunConfiguration(
            host: "127.0.0.1",
            port: 8000,
            baseURL: "http://127.0.0.1:8000/v1",
            profileID: "profile-a",
            modelID: "local/model-a",
            selectedProfileName: "Model A",
            runningProfileID: "profile-a",
            managedProcessID: nil,
            chipName: "Apple M4 Pro",
            memoryText: "64 GB",
            backend: .mlxLM,
            serverExecutablePath: "/tmp/mlx_lm.server",
            includesAgentProbes: true
        )
    }

    private func makeResult(
        index: Int,
        outputTokensPerSecond: Double = 20
    ) -> BenchmarkResult {
        let metrics = BenchmarkSpeedMetrics(
            readinessLatencyMS: 100,
            ttftMS: Double(index * 100),
            totalLatencyMS: 1_000,
            outputTokensPerSecond: outputTokensPerSecond,
            outputTokenCount: 18,
            finishReason: "stop",
            httpStatusCode: 200,
            timedOut: false,
            errorMessage: nil,
            managedMemoryGigabytes: 20,
            availableMemoryGigabytes: 20
        )
        return BenchmarkResult(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
            timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
            profileID: "profile-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            phase: .success,
            readinessLatencyMS: 100,
            statusCode: 200,
            selectedProfileName: "Model A",
            runningProfileID: "profile-a",
            message: "sample \(index)",
            speedMetrics: metrics
        )
    }
}
