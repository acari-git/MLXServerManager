import Darwin
import XCTest
@testable import MLXServerManager

@MainActor
final class ModelProcessIntegrationTests: XCTestCase {
    func testRealProcessesStartIndependentlyAndStoppingOneKeepsTheOtherRunning() async throws {
        let fixture = try ProcessFixture(
            script: """
            #!/bin/sh
            trap 'exit 0' TERM INT
            echo "started:$2"
            while true; do sleep 0.1; done
            """
        )
        defer { fixture.remove() }

        let firstOutput = expectation(description: "first process output")
        let secondOutput = expectation(description: "second process output")
        let registry = ModelProcessRegistry()

        _ = try registry.start(
            profileID: "first",
            request: Self.request(executablePath: fixture.url.path, modelID: "first", port: 8101),
            outputHandler: { line in
                if line.contains("started:first") { firstOutput.fulfill() }
            },
            terminationHandler: { _ in }
        )
        _ = try registry.start(
            profileID: "second",
            request: Self.request(executablePath: fixture.url.path, modelID: "second", port: 8102),
            outputHandler: { line in
                if line.contains("started:second") { secondOutput.fulfill() }
            },
            terminationHandler: { _ in }
        )

        await fulfillment(of: [firstOutput, secondOutput], timeout: 3)
        XCTAssertEqual(registry.runningProfileIDs, ["first", "second"])

        let firstStop = await registry.stop(
            profileID: "first",
            gracefulTimeout: 2,
            interruptTimeout: 1
        )
        guard case .stopped = firstStop else {
            return XCTFail("Expected the first real process to stop, got \(firstStop).")
        }
        XCTAssertFalse(registry.isRunning("first"))
        XCTAssertTrue(registry.isRunning("second"))

        let secondStop = await registry.stop(
            profileID: "second",
            gracefulTimeout: 2,
            interruptTimeout: 1
        )
        guard case .stopped = secondStop else {
            return XCTFail("Expected the second real process to stop, got \(secondStop).")
        }
        XCTAssertFalse(registry.isAnyProcessRunning)
    }

    func testUnexpectedRealProcessExitRemovesOnlyItsRegistryEntry() async throws {
        let fixture = try ProcessFixture(
            script: """
            #!/bin/sh
            echo "exiting:$2"
            sleep 0.1
            exit 17
            """
        )
        defer { fixture.remove() }

        let terminated = expectation(description: "unexpected process termination")
        let registry = ModelProcessRegistry()

        _ = try registry.start(
            profileID: "exiting",
            request: Self.request(executablePath: fixture.url.path, modelID: "exiting", port: 8201),
            outputHandler: { _ in },
            terminationHandler: { status in
                XCTAssertEqual(status, 17)
                terminated.fulfill()
            }
        )

        await fulfillment(of: [terminated], timeout: 3)
        XCTAssertFalse(registry.isRunning("exiting"))
        XCTAssertFalse(registry.isAnyProcessRunning)
    }

    func testStopForceKillsAnOwnedProcessThatIgnoresTerminateAndInterrupt() async throws {
        let fixture = try ProcessFixture(
            script: """
            #!/bin/sh
            trap '' TERM INT
            echo "ready"
            while true; do sleep 0.05; done
            """
        )
        defer { fixture.remove() }

        let started = expectation(description: "process installed signal handlers")
        let manager = ModelProcessManager()
        let launch = try manager.start(
            request: Self.request(executablePath: fixture.url.path, modelID: "stubborn", port: 8301),
            outputHandler: { line in
                if line.contains("ready") { started.fulfill() }
            },
            terminationHandler: { _ in }
        )

        await fulfillment(of: [started], timeout: 3)
        let result = await manager.stop(gracefulTimeout: 0.1, interruptTimeout: 0.1)

        guard case let .stopped(processIdentifier, terminationStatus, stopMethod) = result else {
            return XCTFail("Expected the stubborn process to be force stopped, got \(result).")
        }
        XCTAssertEqual(processIdentifier, launch.processIdentifier)
        XCTAssertEqual(terminationStatus, SIGKILL)
        XCTAssertEqual(stopMethod, .kill)
        XCTAssertNil(manager.managedProcessIdentifier)
        XCTAssertEqual(Darwin.kill(processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testPortCheckerReportsAnActualListeningSocketAsBusy() throws {
        let socket = try ListeningSocket()
        defer { socket.closeSocket() }

        XCTAssertEqual(
            PortChecker().check(host: "127.0.0.1", port: socket.port),
            .busy(host: "127.0.0.1", port: socket.port, pid: nil)
        )
    }

    private static func request(executablePath: String, modelID: String, port: Int) -> ModelLaunchRequest {
        ModelLaunchRequest(
            executablePath: executablePath,
            modelID: modelID,
            host: "127.0.0.1",
            port: port,
            enableThinking: false,
            advancedLaunchOptions: nil
        )
    }
}

private struct ProcessFixture {
    let directory: URL
    let url: URL

    init(script: String) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerProcessTests-\(UUID().uuidString)", isDirectory: true)
        url = directory.appendingPathComponent("fixture-server")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(script.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class ListeningSocket {
    private let descriptor: Int32
    let port: Int

    init() throws {
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketDescriptor >= 0 else {
            throw POSIXError(.EIO)
        }

        var reuseAddress: Int32 = 1
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuseAddress,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
                Darwin.bind(
                    socketDescriptor,
                    socketPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0, Darwin.listen(socketDescriptor, 1) == 0 else {
            Darwin.close(socketDescriptor)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
                getsockname(socketDescriptor, socketPointer, &length)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(socketDescriptor)
            throw POSIXError(.EIO)
        }
        descriptor = socketDescriptor
        port = Int(UInt16(bigEndian: boundAddress.sin_port))
    }

    func closeSocket() {
        guard descriptor >= 0 else { return }
        Darwin.close(descriptor)
    }
}
