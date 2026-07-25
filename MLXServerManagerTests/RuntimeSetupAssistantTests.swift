import Foundation
import XCTest
@testable import MLXServerManager

final class RuntimeSetupAssistantTests: XCTestCase {
    func testDiscoveryFindsExecutableFromPATHAndReportsVersion() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("mlx_lm.server")
        try makeExecutable(
            at: executable,
            content: "#!/bin/sh\necho 'mlx-lm 1.2.3'\n"
        )
        let service = RuntimeSetupAssistantService(
            environment: ["PATH": directory.path],
            homeDirectory: directory.appendingPathComponent("home").path
        )

        let candidates = await service.discover(settings: .defaults)
        let candidate = try XCTUnwrap(candidates.first { $0.backend == .mlxLM })

        XCTAssertEqual(candidate.executablePath, executable.path)
        XCTAssertEqual(candidate.source, .environmentPath)
        XCTAssertEqual(candidate.version, "mlx-lm 1.2.3")
    }

    func testConfiguredPathWinsWhenSameExecutableAlsoAppearsInPATH() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("rapid-mlx")
        try makeExecutable(
            at: executable,
            content: "#!/bin/sh\necho 'rapid-mlx 0.9.0'\n"
        )
        var settings = AppSettings.defaults
        settings.rapidMLXExecutablePath = executable.path
        let service = RuntimeSetupAssistantService(
            environment: ["PATH": directory.path],
            homeDirectory: directory.appendingPathComponent("home").path
        )

        let candidates = await service.discover(settings: settings)
        let candidate = try XCTUnwrap(candidates.first { $0.backend == .rapidMLX })

        XCTAssertEqual(candidates.filter { $0.backend == .rapidMLX }.count, 1)
        XCTAssertEqual(candidate.source, .configured)
        XCTAssertEqual(candidate.version, "rapid-mlx 0.9.0")
    }

    func testDiscoveryDoesNotReturnNonExecutableFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("mlx_lm.server")
        try Data("not executable".utf8).write(to: file)
        let service = RuntimeSetupAssistantService(
            environment: ["PATH": directory.path],
            homeDirectory: directory.appendingPathComponent("home").path
        )

        let candidates = await service.discover(settings: .defaults)

        XCTAssertTrue(candidates.isEmpty)
    }

    private func makeExecutable(at url: URL, content: String) throws {
        try Data(content.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: url.path
        )
    }
}
