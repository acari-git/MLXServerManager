import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class ModelStorageEstimationTests: XCTestCase {
    func testModelSizeLookupDoesNotBlockMainActorWhileStorageIsEstimated() async {
        let estimationCompleted = expectation(description: "Storage estimation completed")
        let model = ModelConfig(
            modelID: "/tmp/model-storage-estimation",
            displayName: "Storage Estimation Model",
            family: "Test",
            quantization: "4bit",
            localName: "/tmp/model-storage-estimation",
            host: "127.0.0.1",
            serverPort: 58101,
            enableThinking: false,
            notes: ""
        )
        let store = SettingsStore(appDirectoryName: "MLXServerManagerStorageEstimationTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(
            settingsStore: store,
            modelStorageEstimateOperation: { _ in
                Thread.sleep(forTimeInterval: 0.3)
                estimationCompleted.fulfill()
                return 2
            }
        )

        let startedAt = ContinuousClock.now
        let initialText = viewModel.modelSizeText(for: model)
        let elapsed = startedAt.duration(to: .now)

        XCTAssertEqual(initialText, "-")
        XCTAssertLessThan(elapsed, .milliseconds(100))

        await fulfillment(of: [estimationCompleted], timeout: 1)
        for _ in 0..<20 where viewModel.modelSizeText(for: model) == "-" {
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(viewModel.modelSizeText(for: model), "2.00 GB")
    }

    func testRepeatedLookupsShareOneInFlightEstimation() async {
        let estimationStarted = expectation(description: "Storage estimation started")
        let estimationFinished = expectation(description: "Storage estimation finished")
        let releaseEstimation = DispatchSemaphore(value: 0)
        let callCount = LockedCounter()
        let model = Self.model(path: "/tmp/model-storage-estimation-dedup", port: 58102)
        let store = Self.store()
        defer {
            releaseEstimation.signal()
            Self.removeStoreDirectory(store)
        }
        let viewModel = AppViewModel(
            settingsStore: store,
            modelStorageEstimateOperation: { _ in
                callCount.increment()
                estimationStarted.fulfill()
                releaseEstimation.wait()
                estimationFinished.fulfill()
                return 3
            }
        )

        XCTAssertEqual(viewModel.modelSizeText(for: model), "-")
        await fulfillment(of: [estimationStarted], timeout: 1)

        for _ in 0..<20 {
            XCTAssertEqual(viewModel.modelSizeText(for: model), "-")
        }
        XCTAssertEqual(callCount.value, 1)

        releaseEstimation.signal()
        await fulfillment(of: [estimationFinished], timeout: 1)
        for _ in 0..<20 where viewModel.modelSizeText(for: model) == "-" {
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(viewModel.modelSizeText(for: model), "3.00 GB")
        XCTAssertEqual(callCount.value, 1)
    }

    func testStopCancelsPendingStartPreparationBeforeEstimateCompletes() async throws {
        let estimationStarted = expectation(description: "Start preparation estimation started")
        let releaseEstimation = DispatchSemaphore(value: 0)
        let model = Self.model(path: "/tmp/model-storage-estimation-cancelled-start", port: 58104)
        let store = Self.store()
        defer {
            releaseEstimation.signal()
            Self.removeStoreDirectory(store)
        }
        try store.save(settings: .defaults, models: [model])
        let viewModel = AppViewModel(
            settingsStore: store,
            modelStorageEstimateOperation: { _ in
                estimationStarted.fulfill()
                releaseEstimation.wait()
                return 60
            },
            systemMemorySnapshotProvider: {
                SystemMemorySnapshot(
                    totalBytes: 64 * 1_073_741_824,
                    availableBytes: 8 * 1_073_741_824
                )
            }
        )

        viewModel.startRequested(for: model)
        await fulfillment(of: [estimationStarted], timeout: 1)
        viewModel.stopRequested(for: model)
        releaseEstimation.signal()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(viewModel.isMemoryRiskStartConfirmationPresented)
        XCTAssertNil(viewModel.pendingMemoryRiskAssessment)
        XCTAssertFalse(viewModel.isManagedProcessRunning)
    }

    func testUnavailableEstimateIsCachedWithoutRepeatedDirectoryScans() async {
        let estimationCompleted = expectation(description: "Unavailable estimation completed")
        let callCount = LockedCounter()
        let model = Self.model(path: "/tmp/model-storage-estimation-unavailable", port: 58103)
        let store = Self.store()
        defer { Self.removeStoreDirectory(store) }
        let viewModel = AppViewModel(
            settingsStore: store,
            modelStorageEstimateOperation: { _ in
                callCount.increment()
                estimationCompleted.fulfill()
                return nil
            }
        )

        XCTAssertEqual(viewModel.modelSizeText(for: model), "-")
        await fulfillment(of: [estimationCompleted], timeout: 1)
        try? await Task.sleep(for: .milliseconds(50))

        for _ in 0..<20 {
            XCTAssertEqual(viewModel.modelSizeText(for: model), "-")
        }
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(callCount.value, 1)
    }

    private static func model(path: String, port: Int) -> ModelConfig {
        ModelConfig(
            modelID: path,
            displayName: "Storage Estimation Model",
            family: "Test",
            quantization: "4bit",
            localName: path,
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: false,
            notes: ""
        )
    }

    private static func store() -> SettingsStore {
        SettingsStore(appDirectoryName: "MLXServerManagerStorageEstimationTests-\(UUID().uuidString)")
    }

    private static func removeStoreDirectory(_ store: SettingsStore) {
        if let directory = try? store.settingsDirectoryURL {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    func increment() {
        lock.withLock {
            storage += 1
        }
    }
}
