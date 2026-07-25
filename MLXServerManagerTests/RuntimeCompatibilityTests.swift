import Foundation
import XCTest
@testable import MLXServerManager

final class RuntimeCompatibilityTests: XCTestCase {
    func testFlagParserReturnsDistinctLongOptions() {
        let flags = RuntimeCompatibilityService.parseFlags(
            "usage: server --model MODEL --host HOST --model OTHER --tool-call-parser NAME"
        )

        XCTAssertEqual(flags, ["--model", "--host", "--tool-call-parser"])
    }

    func testCompatibilityAssessmentUsesDetectedFlagsAndVersion() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("rapid-mlx")
        let script = """
        #!/bin/sh
        if [ "$1" = "--version" ]; then
          echo "rapid-mlx 1.4.0"
        else
          echo "usage: rapid-mlx --model MODEL --host HOST --port PORT --cors-origins ORIGINS --reasoning-parser NAME --tool-call-parser NAME --draft-model MODEL"
        fi
        """
        try makeExecutable(at: executable, content: script)
        var settings = AppSettings.defaults
        settings.rapidMLXExecutablePath = executable.path
        let service = RuntimeCompatibilityService()

        let reports = await service.assess(settings: settings)
        let report = try XCTUnwrap(reports.first { $0.backend == .rapidMLX })

        XCTAssertEqual(report.version, "rapid-mlx 1.4.0")
        XCTAssertEqual(report.supportedFlags?.contains("--tool-call-parser"), true)
        XCTAssertEqual(support(for: .modelSelection, in: report), .supported)
        XCTAssertEqual(support(for: .hostAndPort, in: report), .supported)
        XCTAssertEqual(support(for: .cors, in: report), .supported)
        XCTAssertEqual(support(for: .reasoningControl, in: report), .supported)
        XCTAssertEqual(support(for: .toolCallParser, in: report), .supported)
        XCTAssertEqual(support(for: .speculativeDecoding, in: report), .partial)
        XCTAssertEqual(support(for: .chatTemplate, in: report), .unsupported)
    }

    func testMissingExecutableProducesUnknownFeatureResults() async {
        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = "/missing/mlx_lm.server"
        let service = RuntimeCompatibilityService()

        let reports = await service.assess(settings: settings)
        let report = reports.first { $0.backend == .mlxLM }

        XCTAssertNil(report?.supportedFlags)
        XCTAssertTrue(report?.features.allSatisfy { $0.support == .unknown } == true)
    }

    private func support(
        for feature: RuntimeCompatibilityFeature,
        in report: RuntimeCompatibilityReport
    ) -> RuntimeCompatibilitySupport? {
        report.features.first { $0.feature == feature }?.support
    }

    private func makeExecutable(at url: URL, content: String) throws {
        try Data(content.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: url.path
        )
    }
}
