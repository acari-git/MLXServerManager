import XCTest

final class DiagnosticFixtureLoadingTests: XCTestCase {
    private let resultFixtures = [
        "results/status_pass_app_configuration",
        "results/status_warning_selected_profile",
        "results/status_fail_executable_path",
        "results/status_fail_selected_profile_blocking",
        "results/status_skipped_external_server",
        "results/status_unknown_model_availability",
        "results/status_cancelled_diagnostics_run",
        "results/status_timeout_current_target"
    ]

    private let redactionFixtures = [
        "redaction/bearer_token_copy_safe",
        "redaction/huggingface_token_copy_safe",
        "redaction/home_path_compaction"
    ]

    private let negativeFixtures = [
        "negative/no_external_ownership_claim",
        "negative/no_profile_change",
        "negative/no_raw_command_output"
    ]

    func testDiagnosticsResultFixturesLoadAndUseAllowedValues() throws {
        let fixtures = try resultFixtures.map(loadJSONFixture)
        let ids = fixtures.compactMap { $0["id"] as? String }

        XCTAssertEqual(ids.count, resultFixtures.count)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(
            Set(fixtures.compactMap { $0["status"] as? String }),
            ["pass", "warning", "fail", "skipped", "unknown", "cancelled", "timeout"]
        )

        for fixture in fixtures {
            try assertResultLikeFixtureShape(fixture)
            XCTAssertTrue(allowedStatuses.contains(try requiredString("status", in: fixture)))
            XCTAssertTrue(allowedSeverities.contains(try requiredString("severity", in: fixture)))
            XCTAssertTrue(allowedScopes.contains(try requiredString("scope", in: fixture)))
            XCTAssertTrue(allowedCategories.contains(try requiredString("category", in: fixture)))
            XCTAssertEqual(try requiredString("redactionLevel", in: fixture), "copySafe")
        }
    }

    func testDiagnosticsRedactionFixturesLoadWithCopySafeExpectations() throws {
        for fixture in try redactionFixtures.map(loadJSONFixture) {
            try assertFixtureHeaderShape(fixture)
            XCTAssertTrue(allowedStatuses.contains(try requiredString("status", in: fixture)))
            XCTAssertTrue(allowedSeverities.contains(try requiredString("severity", in: fixture)))
            XCTAssertEqual(try requiredString("redactionLevel", in: fixture), "copySafe")
            XCTAssertNotNil(fixture["inputExample"] as? String)

            let expectedSummary = try requiredString("expectedSummary", in: fixture)
            let prohibitedValues = try XCTUnwrap(fixture["mustNotContain"] as? [String])
            XCTAssertFalse(prohibitedValues.isEmpty)
            for prohibitedValue in prohibitedValues {
                XCTAssertFalse(expectedSummary.contains(prohibitedValue))
            }
        }
    }

    func testDiagnosticsNegativeFixturesLoadWithExplicitAbsenceRules() throws {
        for fixture in try negativeFixtures.map(loadJSONFixture) {
            try assertResultLikeFixtureShape(fixture)
            XCTAssertEqual(try requiredString("redactionLevel", in: fixture), "copySafe")

            let mustNotContain = fixture["mustNotContain"] as? [String]
            let unchangedFields = fixture["unchangedFields"] as? [String]
            XCTAssertTrue((mustNotContain?.isEmpty == false) || (unchangedFields?.isEmpty == false))
        }
    }

    func testDiagnosticsAggregationFixtureReferencesExistingResultIDs() throws {
        let aggregation = try loadJSONFixture("aggregation/blocking_precedence")
        let resultIDs = Set(try resultFixtures.map { try requiredString("id", in: loadJSONFixture($0)) })
        let referencedIDs = try XCTUnwrap(aggregation["results"] as? [String])

        XCTAssertFalse(referencedIDs.isEmpty)
        XCTAssertTrue(Set(referencedIDs).isSubset(of: resultIDs))
        XCTAssertEqual(try requiredString("expectedHeadlineSeverity", in: aggregation), "error")
        XCTAssertEqual(try requiredString("redactionLevel", in: aggregation), "copySafe")
    }

    func testDiagnosticsCopiedSummaryFixtureLoadsAndStaysRedacted() throws {
        let summary = try loadTextFixture("summaries/mixed_status_copy_summary")

        XCTAssertTrue(summary.hasPrefix("MLX Server Manager Diagnostics Summary"))
        XCTAssertTrue(summary.contains("Checks: 8"))
        XCTAssertTrue(summary.contains("- [fail] [Profile] Selected profile has a blocking issue"))
        XCTAssertFalse(summary.localizedCaseInsensitiveContains("authorization:"))
        XCTAssertFalse(summary.localizedCaseInsensitiveContains("bearer "))
        XCTAssertFalse(summary.localizedCaseInsensitiveContains("hf_"))
        XCTAssertFalse(summary.contains("/Users/"))
        XCTAssertFalse(summary.contains("Traceback"))
    }

    private var allowedStatuses: Set<String> {
        ["pass", "warning", "fail", "skipped", "unknown", "cancelled", "timeout"]
    }

    private var allowedSeverities: Set<String> {
        ["info", "warning", "error", "blocking"]
    }

    private var allowedScopes: Set<String> {
        [
            "appConfiguration",
            "clientSetup",
            "currentTarget",
            "executablePath",
            "externalServer",
            "logsSummary",
            "modelAvailability",
            "selectedProfile"
        ]
    }

    private var allowedCategories: Set<String> {
        [
            "Configuration",
            "External Target",
            "Model Availability",
            "Privacy / Redaction",
            "Profile",
            "Runtime"
        ]
    }

    private func assertResultLikeFixtureShape(
        _ fixture: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertFixtureHeaderShape(fixture, file: file, line: line)
        XCTAssertFalse(try requiredString("summary", in: fixture).isEmpty, file: file, line: line)
    }

    private func assertFixtureHeaderShape(
        _ fixture: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertFalse(try requiredString("id", in: fixture).isEmpty, file: file, line: line)
        XCTAssertFalse(try requiredString("title", in: fixture).isEmpty, file: file, line: line)
        XCTAssertFalse(try requiredString("category", in: fixture).isEmpty, file: file, line: line)
        XCTAssertFalse(try requiredString("scope", in: fixture).isEmpty, file: file, line: line)
        XCTAssertFalse(try requiredString("redactionLevel", in: fixture).isEmpty, file: file, line: line)
    }

    private func requiredString(_ key: String, in fixture: [String: Any]) throws -> String {
        try XCTUnwrap(fixture[key] as? String, "Missing string value for key: \(key)")
    }

    private func loadJSONFixture(_ relativePath: String) throws -> [String: Any] {
        let data = try fixtureData(relativePath, extension: "json")
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any], "Expected object fixture: \(relativePath).json")
    }

    private func loadTextFixture(_ relativePath: String) throws -> String {
        let data = try fixtureData(relativePath, extension: "txt")
        return String(decoding: data, as: UTF8.self)
    }

    private func fixtureData(_ relativePath: String, extension fileExtension: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let pathParts = relativePath.split(separator: "/").map(String.init)
        let name = try XCTUnwrap(pathParts.last)
        let nestedDirectory = pathParts.dropLast().joined(separator: "/")
        let subdirectory = nestedDirectory.isEmpty ? "Fixtures/Diagnostics" : "Fixtures/Diagnostics/\(nestedDirectory)"

        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
                ?? bundle.url(forResource: name, withExtension: fileExtension),
            "Missing diagnostics fixture: \(relativePath).\(fileExtension)"
        )
        return try Data(contentsOf: url)
    }
}
