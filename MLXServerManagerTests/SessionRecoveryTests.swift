import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class SessionRecoveryTests: XCTestCase {
    func testLeftRunningRecordBecomesRecoveryCandidateWithoutRestoringOwnership() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("session-recovery.json")
        let endpoint = makeEndpoint()

        let firstStore = SessionRecoveryStore(fileURL: fileURL)
        XCTAssertNil(firstStore.beginSession())
        firstStore.recordLeftRunning(endpoints: [endpoint])

        let nextStore = SessionRecoveryStore(fileURL: fileURL)
        let previous = try XCTUnwrap(nextStore.beginSession())
        let current = try XCTUnwrap(nextStore.loadRecord())

        XCTAssertEqual(previous.disposition, .leftRunning)
        XCTAssertEqual(previous.endpoints, [endpoint])
        XCTAssertEqual(current.disposition, .active)
        XCTAssertEqual(current.endpoints, [endpoint])
    }

    func testRecoveryRecordContainsEndpointContextWithoutOwnershipOrSecrets() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("session-recovery.json")
        let store = SessionRecoveryStore(fileURL: fileURL)

        _ = store.beginSession()
        store.recordLeftRunning(endpoints: [makeEndpoint()])

        let record = try XCTUnwrap(store.loadRecord())
        XCTAssertEqual(record.endpoints, [makeEndpoint()])

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("processIdentifier"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("pid"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("apiKey"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("prompt"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("response"))
    }

    func testCleanShutdownDoesNotProduceRecoveryCandidates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("session-recovery.json")

        let firstStore = SessionRecoveryStore(fileURL: fileURL)
        _ = firstStore.beginSession()
        firstStore.recordActive(endpoints: [makeEndpoint()])
        firstStore.markCleanShutdown()

        let nextStore = SessionRecoveryStore(fileURL: fileURL)

        XCTAssertNil(nextStore.beginSession())
        XCTAssertEqual(nextStore.loadRecord()?.disposition, .active)
        XCTAssertEqual(nextStore.loadRecord()?.endpoints, [])
    }

    func testSystemShutdownRecordBecomesRecoveryCandidateWithoutBlockingNextLaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("session-recovery.json")
        let endpoint = makeEndpoint()

        let firstStore = SessionRecoveryStore(fileURL: fileURL)
        _ = firstStore.beginSession()
        firstStore.recordSystemShutdown(endpoints: [endpoint])

        let nextStore = SessionRecoveryStore(fileURL: fileURL)
        let previous = try XCTUnwrap(nextStore.beginSession())

        XCTAssertEqual(previous.disposition, .systemShutdown)
        XCTAssertEqual(previous.endpoints, [endpoint])
        XCTAssertEqual(
            previous.disposition.localizedTitle(language: .japanese),
            "前回のセッションはmacOS終了時に終了しました"
        )
    }

    func testUnexpectedActiveSessionIsPresentedForExplicitEndpointCheck() {
        let record = SessionRecoveryRecord(
            sessionID: UUID(),
            disposition: .active,
            endpoints: [makeEndpoint()]
        )
        var state = SessionRecoveryViewState.presenting(record: record)

        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.candidates.first?.status, .notChecked)

        state.beginCheck()
        XCTAssertTrue(state.isChecking)
        XCTAssertEqual(state.candidates.first?.status, .checking)

        state.complete([record.endpoints[0].id: .available(statusCode: 200)])
        XCTAssertFalse(state.isChecking)
        XCTAssertEqual(state.candidates.first?.status, .available(statusCode: 200))
        XCTAssertFalse(state.candidates.first?.isAdopted == true)

        state.markAdopted(record.endpoints[0].id)
        XCTAssertTrue(state.candidates.first?.isAdopted == true)
    }

    func testCleanDispositionNeverPresentsRecoverySheet() {
        let record = SessionRecoveryRecord(
            sessionID: UUID(),
            disposition: .clean,
            endpoints: []
        )

        let state = SessionRecoveryViewState.presenting(record: record)

        XCTAssertFalse(state.isPresented)
    }

    private func makeEndpoint() -> SessionRecoveryEndpoint {
        SessionRecoveryEndpoint(
            profileID: "model/recovery",
            displayName: "Recovery Model",
            modelID: "model/recovery",
            host: "127.0.0.1",
            port: 8080
        )
    }
}
