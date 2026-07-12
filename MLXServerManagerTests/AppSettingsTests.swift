import XCTest
@testable import MLXServerManager

final class AppSettingsTests: XCTestCase {
    func testDefaultsIncludeSavedChromePreferences() {
        let settings = AppSettings.defaults

        XCTAssertEqual(settings.uiLanguage, .system)
        XCTAssertEqual(settings.uiAppearance, "system")
        XCTAssertEqual(settings.hermesConfigPath, "~/.hermes/config.yaml")
    }

    func testDecodingLegacySettingsFillsChromePreferences() throws {
        let json = """
        {
          "mlxServerExecutablePath": "",
          "defaultHost": "127.0.0.1",
          "defaultPort": 8080,
          "apiKeyPlaceholder": "not-required-local"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.uiLanguage, .system)
        XCTAssertEqual(settings.uiAppearance, "system")
        XCTAssertEqual(settings.hermesConfigPath, "~/.hermes/config.yaml")
    }

    func testEncodingRoundTripsChromePreferences() throws {
        let original = AppSettings(
            mlxServerExecutablePath: "/tmp/mlx_lm.server",
            defaultHost: "127.0.0.1",
            defaultPort: 9999,
            apiKeyPlaceholder: "local-only",
            hermesConfigPath: "/tmp/hermes/config.yaml",
            uiLanguage: .english,
            uiAppearance: "dark"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.uiLanguage, .english)
        XCTAssertEqual(decoded.uiAppearance, "dark")
        XCTAssertEqual(decoded.hermesConfigPath, "/tmp/hermes/config.yaml")
    }

    func testEncodingOmitsRetiredDownloadBehaviorKeys() throws {
        let data = try JSONEncoder().encode(AppSettings.defaults)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(text.contains("downloadAutoAddToModelList"))
        XCTAssertFalse(text.contains("downloadAutoSelectAfterAdd"))
        XCTAssertFalse(text.contains("confirmFilesBeforeDownload"))
    }

    func testAutoUnloadSettingsRoundTripAndClampMinutes() throws {
        let original = AppSettings(
            mlxServerExecutablePath: "",
            defaultHost: "127.0.0.1",
            defaultPort: 8080,
            apiKeyPlaceholder: "not-required-local",
            autoUnloadEnabledByModelID: ["model-a": true],
            autoUnloadMinutesByModelID: ["model-a": 45, "model-b": 0]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.autoUnloadEnabledByModelID["model-a"], true)
        XCTAssertEqual(decoded.autoUnloadMinutesByModelID["model-a"], 45)
        XCTAssertEqual(decoded.autoUnloadMinutesByModelID["model-b"], 1)
    }

    func testSettingsStorePersistsBenchmarkResultsSeparately() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)")
        defer {
            if let url = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let result = BenchmarkResult(
            profileID: "model-a",
            modelID: "local/model-a",
            baseURL: "http://127.0.0.1:8000/v1",
            phase: .success,
            readinessLatencyMS: 100,
            selectedProfileName: "Model A",
            message: "ok"
        )
        let snapshot = BenchmarkResultsSnapshot(
            benchmarkResultsByProfileID: ["model-a": result],
            agenticBenchmarkResultsByProfileID: [:]
        )

        try store.save(benchmarkResults: snapshot)
        let loaded = try store.loadBenchmarkResults()

        XCTAssertFalse(loaded.usedDefault)
        XCTAssertEqual(loaded.value.benchmarkResultsByProfileID["model-a"]?.modelID, "local/model-a")
    }
}
