import Darwin
import XCTest
@testable import MLXServerManager

final class ShortLivedProcessRunnerTests: XCTestCase {
    func testVersionProviderCompletesAfterLargeStdoutAndStderrOutput() async throws {
        let fixture = try makeScript(
            body: """
            i=0
            while [ "$i" -lt 4096 ]; do
              printf 'stdout-payload-012345678901234567890123456789012345678901234567890123456789\\n'
              printf 'stderr-payload-012345678901234567890123456789012345678901234567890123456789\\n' >&2
              i=$((i + 1))
            done
            printf 'mlx-lm 9.9.9\\n'
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let version = await MLXLMVersionProvider(timeout: 5).version(
            executablePath: fixture.executable.path
        )

        XCTAssertEqual(version, "mlx-lm 9.9.9")
    }

    func testTimeoutTerminatesProcessWithoutLeavingItRunning() throws {
        let processIdentifierURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManager-Test-PID-\(UUID().uuidString)")
        let fixture = try makeScript(
            body: """
            trap '' TERM INT
            printf '%s' "$$" > '\(processIdentifierURL.path)'
            while :; do :; done
            """
        )
        defer {
            try? FileManager.default.removeItem(at: fixture.directory)
            try? FileManager.default.removeItem(at: processIdentifierURL)
        }

        let result = ShortLivedProcessRunner.run(
            executablePath: fixture.executable.path,
            arguments: [],
            timeout: 0.5,
            terminationGracePeriod: 0.05
        )

        XCTAssertEqual(result?.timedOut, true)
        XCTAssertEqual(result?.cancelled, false)
        XCTAssertTrue([SIGTERM, SIGKILL].contains(result?.terminationStatus ?? 0))
        if let processIdentifierText = try? String(contentsOf: processIdentifierURL, encoding: .utf8),
           let processIdentifier = Int32(processIdentifierText) {
            let killResult = Darwin.kill(processIdentifier, 0)
            let killError = errno
            XCTAssertEqual(killResult, -1)
            XCTAssertEqual(killError, ESRCH)
        }
    }

    func testTaskCancellationTerminatesSignalIgnoringProcess() async throws {
        let processIdentifierURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManager-Test-PID-\(UUID().uuidString)")
        let fixture = try makeScript(
            body: """
            trap '' TERM INT
            printf '%s' "$$" > '\(processIdentifierURL.path)'
            while :; do :; done
            """
        )
        defer {
            try? FileManager.default.removeItem(at: fixture.directory)
            try? FileManager.default.removeItem(at: processIdentifierURL)
        }

        let task = Task {
            await ShortLivedProcessRunner.runAsync(
                executablePath: fixture.executable.path,
                arguments: [],
                timeout: 10,
                terminationGracePeriod: 0.05
            )
        }
        try await waitForFile(at: processIdentifierURL, timeout: 2)
        task.cancel()

        let result = await task.value

        XCTAssertEqual(result?.timedOut, false)
        XCTAssertEqual(result?.cancelled, true)
        XCTAssertEqual(result?.terminationStatus, SIGKILL)
        let processIdentifierText = try String(contentsOf: processIdentifierURL, encoding: .utf8)
        let processIdentifier = try XCTUnwrap(Int32(processIdentifierText))
        let killResult = Darwin.kill(processIdentifier, 0)
        let killError = errno
        XCTAssertEqual(killResult, -1)
        XCTAssertEqual(killError, ESRCH)
    }

    func testSystemHardwareProviderHandlesLargeOutputWithoutBlocking() async throws {
        let fixture = try makeScript(
            body: """
            i=0
            while [ "$i" -lt 4096 ]; do
              printf 'diagnostic-payload-012345678901234567890123456789012345678901234567890123456789\\n' >&2
              i=$((i + 1))
            done
            cat <<'EOF'
            Hardware:
              Model Name: Test Mac
              Chip: Apple Test
              Total Number of Cores: 12
              Memory: 32 GB
            Graphics/Displays:
              Total Number of Cores: 18
            EOF
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let provider = SystemHardwareInfoProvider(
            executablePath: fixture.executable.path,
            arguments: [],
            timeout: 5
        )

        let info = await provider.loadHardwareInfo()

        XCTAssertEqual(info["Model Name"], "Test Mac")
        XCTAssertEqual(info["Chip"], "Apple Test")
        XCTAssertEqual(info["Total Number of Cores"], "12")
        XCTAssertEqual(info["GPU Cores"], "18")
        XCTAssertEqual(info["Memory"], "32 GB")
    }

    func testSystemHardwareProviderRejectsValidLookingOutputFromFailedProcess() async throws {
        let fixture = try makeScript(
            body: """
            cat <<'EOF'
            Hardware:
              Model Name: Must Not Be Used
              Chip: Apple Test
            EOF
            exit 7
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let provider = SystemHardwareInfoProvider(
            executablePath: fixture.executable.path,
            arguments: [],
            timeout: 5
        )

        let info = await provider.loadHardwareInfo()

        XCTAssertTrue(info.isEmpty)
    }

    private func makeScript(body: String) throws -> ProcessFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManager-Process-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("fixture.sh")
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: executable, options: .atomic)
        XCTAssertEqual(chmod(executable.path, 0o755), 0)
        return ProcessFixture(directory: directory, executable: executable)
    }

    private func waitForFile(at url: URL, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !FileManager.default.fileExists(atPath: url.path) {
            guard Date() < deadline else {
                throw FixtureError.startTimedOut
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private struct ProcessFixture {
    let directory: URL
    let executable: URL
}

private enum FixtureError: Error {
    case startTimedOut
}
