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

        let launch = try registry.start(
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
        XCTAssertEqual(Darwin.kill(launch.processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testTerminationWaitsForFinalStdoutAndStderrWithoutNewlines() async throws {
        let fixture = try ProcessFixture(
            script: """
            #!/bin/sh
            printf 'final-stdout-without-newline'
            printf 'final-stderr-without-newline' >&2
            exit 0
            """
        )
        defer { fixture.remove() }

        let terminated = expectation(description: "process termination after output drain")
        let collector = ProcessOutputCollector()
        let manager = ModelProcessManager()

        _ = try manager.start(
            request: Self.request(executablePath: fixture.url.path, modelID: "final-output", port: 8251),
            outputHandler: { line in
                collector.append(line)
            },
            terminationHandler: { status in
                XCTAssertEqual(status, 0)
                terminated.fulfill()
            }
        )

        await fulfillment(of: [terminated], timeout: 3)
        XCTAssertTrue(collector.values.contains("[process:stdout] final-stdout-without-newline"))
        XCTAssertTrue(collector.values.contains("[process:stderr] final-stderr-without-newline"))
    }

    func testCancelledStopStillAllowsGracefulTermination() async throws {
        let fixture = try ProcessFixture(
            script: """
            #!/bin/sh
            trap 'exit 0' TERM
            echo "ready"
            while true; do sleep 0.05; done
            """
        )
        defer { fixture.remove() }

        let started = expectation(description: "process installed graceful termination handler")
        let manager = ModelProcessManager()
        let launch = try manager.start(
            request: Self.request(executablePath: fixture.url.path, modelID: "cancelled-graceful-stop", port: 8290),
            outputHandler: { line in
                if line.contains("ready") { started.fulfill() }
            },
            terminationHandler: { _ in }
        )

        await fulfillment(of: [started], timeout: 3)
        let stopTask = Task {
            await manager.stop(gracefulTimeout: 1, interruptTimeout: 0.1)
        }
        stopTask.cancel()
        let result = await stopTask.value

        guard case let .stopped(processIdentifier, terminationStatus, stopMethod) = result else {
            return XCTFail("Expected cancellation-safe graceful termination, got \(result).")
        }
        XCTAssertEqual(processIdentifier, launch.processIdentifier)
        XCTAssertEqual(terminationStatus, 0)
        XCTAssertEqual(stopMethod, .terminate)
        XCTAssertNil(manager.managedProcessIdentifier)
        XCTAssertEqual(Darwin.kill(processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testCancelledStopStillWaitsForForcedTerminationAndReleasesManagedState() async throws {
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
            request: Self.request(executablePath: fixture.url.path, modelID: "cancelled-stop", port: 8291),
            outputHandler: { line in
                if line.contains("ready") { started.fulfill() }
            },
            terminationHandler: { _ in }
        )

        await fulfillment(of: [started], timeout: 3)
        let stopTask = Task {
            await manager.stop(gracefulTimeout: 0.1, interruptTimeout: 0.1)
        }
        stopTask.cancel()
        let result = await stopTask.value

        guard case let .stopped(processIdentifier, terminationStatus, stopMethod) = result else {
            return XCTFail("Expected cancellation-safe forced termination, got \(result).")
        }
        XCTAssertEqual(processIdentifier, launch.processIdentifier)
        XCTAssertEqual(terminationStatus, SIGKILL)
        XCTAssertEqual(stopMethod, .kill)
        XCTAssertNil(manager.managedProcessIdentifier)
        XCTAssertEqual(Darwin.kill(processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testDelayedPreviousOutputDrainDoesNotClearImmediatelyRestartedProcess() async throws {
        let fixture = try ProcessFixture(
            script: """
            #!/bin/sh
            if [ "$2" = "first" ]; then
                (sleep 0.3) &
            fi
            trap 'exit 0' TERM
            echo "ready:$2"
            while true; do sleep 0.05; done
            """
        )
        defer { fixture.remove() }

        let firstStarted = expectation(description: "first process started")
        let secondStarted = expectation(description: "second process started")
        let manager = ModelProcessManager(outputDrainTimeout: 0.05)
        let firstLaunch = try manager.start(
            request: Self.request(executablePath: fixture.url.path, modelID: "first", port: 8293),
            outputHandler: { line in
                if line.contains("ready:first") { firstStarted.fulfill() }
            },
            terminationHandler: { _ in }
        )
        await fulfillment(of: [firstStarted], timeout: 3)

        guard case .stopped = await manager.stop(gracefulTimeout: 1, interruptTimeout: 0.1) else {
            return XCTFail("Expected the first process to stop before restart.")
        }

        let secondLaunch = try manager.start(
            request: Self.request(executablePath: fixture.url.path, modelID: "second", port: 8294),
            outputHandler: { line in
                if line.contains("ready:second") { secondStarted.fulfill() }
            },
            terminationHandler: { _ in }
        )
        await fulfillment(of: [secondStarted], timeout: 3)
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertNotEqual(firstLaunch.processIdentifier, secondLaunch.processIdentifier)
        XCTAssertEqual(manager.managedProcessIdentifier, secondLaunch.processIdentifier)
        XCTAssertEqual(Darwin.kill(firstLaunch.processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)

        guard case .stopped = await manager.stop(gracefulTimeout: 1, interruptTimeout: 0.1) else {
            return XCTFail("Expected the restarted process to stop cleanly.")
        }
        XCTAssertNil(manager.managedProcessIdentifier)
        XCTAssertEqual(Darwin.kill(secondLaunch.processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    func testZeroInterruptTimeoutStillReapsProcessAfterSIGKILL() async throws {
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
            request: Self.request(executablePath: fixture.url.path, modelID: "zero-kill-wait", port: 8292),
            outputHandler: { line in
                if line.contains("ready") { started.fulfill() }
            },
            terminationHandler: { _ in }
        )

        await fulfillment(of: [started], timeout: 3)
        let result = await manager.stop(gracefulTimeout: 0.1, interruptTimeout: 0)

        guard case let .stopped(processIdentifier, terminationStatus, stopMethod) = result else {
            return XCTFail("Expected SIGKILL termination to be reaped even with a zero interrupt timeout, got \(result).")
        }
        XCTAssertEqual(processIdentifier, launch.processIdentifier)
        XCTAssertEqual(terminationStatus, SIGKILL)
        XCTAssertEqual(stopMethod, .kill)
        XCTAssertNil(manager.managedProcessIdentifier)
        XCTAssertEqual(Darwin.kill(processIdentifier, 0), -1)
        XCTAssertEqual(errno, ESRCH)
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

    func testPortCheckerReportsTIMEWAITConnectionAsAvailable() throws {
        let port = try createTimeWaitPort()

        XCTAssertEqual(
            PortChecker().check(host: "127.0.0.1", port: port),
            .available(host: "127.0.0.1", port: port)
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

private final class ProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    func append(_ value: String) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
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

private func createTimeWaitPort() throws -> Int {
    var listenerDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard listenerDescriptor >= 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    defer {
        if listenerDescriptor >= 0 {
            Darwin.close(listenerDescriptor)
        }
    }

    var reuseAddress: Int32 = 1
    guard setsockopt(
        listenerDescriptor,
        SOL_SOCKET,
        SO_REUSEADDR,
        &reuseAddress,
        socklen_t(MemoryLayout<Int32>.size)
    ) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
            Darwin.bind(
                listenerDescriptor,
                socketPointer,
                socklen_t(MemoryLayout<sockaddr_in>.size)
            )
        }
    }
    guard bindResult == 0, Darwin.listen(listenerDescriptor, 1) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    var boundAddress = sockaddr_in()
    var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
            getsockname(listenerDescriptor, socketPointer, &boundAddressLength)
        }
    }
    guard nameResult == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    let port = Int(UInt16(bigEndian: boundAddress.sin_port))

    var clientDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard clientDescriptor >= 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    defer {
        if clientDescriptor >= 0 {
            Darwin.close(clientDescriptor)
        }
    }

    let connectResult = withUnsafePointer(to: &boundAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
            Darwin.connect(
                clientDescriptor,
                socketPointer,
                socklen_t(MemoryLayout<sockaddr_in>.size)
            )
        }
    }
    guard connectResult == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    var acceptedDescriptor = Darwin.accept(listenerDescriptor, nil, nil)
    guard acceptedDescriptor >= 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    Darwin.close(acceptedDescriptor)
    acceptedDescriptor = -1

    var byte: UInt8 = 0
    while Darwin.read(clientDescriptor, &byte, 1) > 0 {}
    Darwin.close(clientDescriptor)
    clientDescriptor = -1
    Darwin.close(listenerDescriptor)
    listenerDescriptor = -1

    return port
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
