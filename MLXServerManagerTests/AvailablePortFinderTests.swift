import XCTest
@testable import MLXServerManager

final class AvailablePortFinderTests: XCTestCase {
    func testReservedPortsAreSkippedWithoutProbingThem() {
        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            return .available(host: host, port: port)
        }

        let port = finder.firstAvailablePort(
            host: "127.0.0.1",
            preferredPort: 8_000,
            reservedPorts: [8_000, 8_001]
        )

        XCTAssertEqual(port, 8_002)
        XCTAssertEqual(checkedPorts, [8_002])
    }

    func testBusyAndFailedPortsAreSkippedUntilAnAvailablePortIsFound() {
        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            switch port {
            case 8_000:
                return .busy(host: host, port: port, pid: nil)
            case 8_001:
                return .failed(host: host, port: port, message: "test failure")
            default:
                return .available(host: host, port: port)
            }
        }

        let port = finder.firstAvailablePort(
            host: "127.0.0.1",
            preferredPort: 8_000,
            reservedPorts: []
        )

        XCTAssertEqual(port, 8_002)
        XCTAssertEqual(checkedPorts, [8_000, 8_001, 8_002])
    }

    func testInvalidInputStopsTheSearch() {
        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { _, port in
            checkedPorts.append(port)
            return .invalidInput(message: "invalid host")
        }

        let port = finder.firstAvailablePort(
            host: "invalid",
            preferredPort: 8_000,
            reservedPorts: []
        )

        XCTAssertNil(port)
        XCTAssertEqual(checkedPorts, [8_000])
    }

    func testSearchLimitBoundsTheNumberOfProbes() {
        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            return .busy(host: host, port: port, pid: nil)
        }

        let port = finder.firstAvailablePort(
            host: "127.0.0.1",
            preferredPort: 8_000,
            reservedPorts: [],
            searchLimit: 3
        )

        XCTAssertNil(port)
        XCTAssertEqual(checkedPorts, [8_000, 8_001, 8_002])
    }

    func testSearchAtMaximumPortDoesNotOverflow() {
        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            return .available(host: host, port: port)
        }

        let port = finder.firstAvailablePort(
            host: "127.0.0.1",
            preferredPort: 65_535,
            reservedPorts: [],
            searchLimit: .max
        )

        XCTAssertEqual(port, 65_535)
        XCTAssertEqual(checkedPorts, [65_535])
    }
}

@MainActor
final class AvailablePortSuggestionFlowTests: XCTestCase {
    func testAddingProfileSuggestsNextPortForEquivalentReservedHost() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerPortSuggestionTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let existingModel = ModelConfig(
            modelID: "example/model",
            displayName: "Existing Model",
            family: "Test",
            quantization: "4bit",
            localName: "example/model",
            host: "localhost",
            serverPort: 8_000,
            enableThinking: false,
            notes: ""
        )
        try store.save(
            settings: AppSettings(
                mlxServerExecutablePath: "/usr/bin/false",
                defaultHost: "127.0.0.1",
                defaultPort: 8_000,
                apiKeyPlaceholder: "not-required-local",
                uiLanguage: .japanese,
                uiAppearance: "system"
            ),
            models: [existingModel]
        )

        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            return .available(host: host, port: port)
        }
        let viewModel = AppViewModel(
            settingsStore: store,
            availablePortFinder: finder
        )

        viewModel.addProfileRequested()

        XCTAssertTrue(viewModel.isAddProfilePresented)
        XCTAssertEqual(viewModel.addProfileDraft.serverPortText, "8001")
        XCTAssertEqual(checkedPorts, [8_001])
        XCTAssertEqual(
            viewModel.addProfilePortSuggestionMessage,
            "手前のポートが割り当て済みまたは使用中のため、ポート8001を選択しました。"
        )
        XCTAssertFalse(viewModel.isManagedProcessRunning)

        viewModel.addProfileDraft.serverPortText = "9000"
        viewModel.addProfileEndpointInputChanged()

        XCTAssertNil(viewModel.addProfilePortSuggestionMessage)
    }

    func testEditingProfileExcludesCurrentProfileButReservesOtherProfiles() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerEditPortSuggestionTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let editedModel = ModelConfig(
            modelID: "example/edited-model",
            displayName: "Edited Model",
            family: "Test",
            quantization: "4bit",
            localName: "example/edited-model",
            host: "localhost",
            serverPort: 8_000,
            enableThinking: false,
            notes: ""
        )
        let otherModel = ModelConfig(
            modelID: "example/other-model",
            displayName: "Other Model",
            family: "Test",
            quantization: "4bit",
            localName: "example/other-model",
            host: "127.0.0.1",
            serverPort: 8_001,
            enableThinking: false,
            notes: ""
        )
        try store.save(
            settings: AppSettings(
                mlxServerExecutablePath: "/usr/bin/false",
                defaultHost: "127.0.0.1",
                defaultPort: 8_000,
                apiKeyPlaceholder: "not-required-local",
                uiLanguage: .japanese,
                uiAppearance: "system"
            ),
            models: [editedModel, otherModel]
        )

        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            return .available(host: host, port: port)
        }
        let viewModel = AppViewModel(
            settingsStore: store,
            availablePortFinder: finder
        )

        viewModel.editProfileRequested(for: editedModel)
        viewModel.suggestAvailablePortForProfileEditor()

        XCTAssertTrue(viewModel.isProfileEditorPresented)
        XCTAssertEqual(viewModel.profileEditorDraft.serverPortText, "8000")
        XCTAssertEqual(checkedPorts, [8_000])
        XCTAssertEqual(
            viewModel.profileEditorPortSuggestionMessage,
            "ポート8000は利用可能です。"
        )

        viewModel.profileEditorDraft.serverPortText = "8001"
        viewModel.profileEditorEndpointInputChanged()
        XCTAssertNil(viewModel.profileEditorPortSuggestionMessage)

        viewModel.suggestAvailablePortForProfileEditor()

        XCTAssertEqual(viewModel.profileEditorDraft.serverPortText, "8002")
        XCTAssertEqual(checkedPorts, [8_000, 8_002])
        XCTAssertEqual(
            viewModel.profileEditorPortSuggestionMessage,
            "手前のポートが割り当て済みまたは使用中のため、ポート8002を選択しました。"
        )
        XCTAssertFalse(viewModel.isManagedProcessRunning)
    }

    func testAddingProfileReservesPortAssignedToWildcardHost() throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerWildcardPortSuggestionTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let wildcardModel = ModelConfig(
            modelID: "example/wildcard-model",
            displayName: "Wildcard Model",
            family: "Test",
            quantization: "4bit",
            localName: "example/wildcard-model",
            host: "0.0.0.0",
            serverPort: 8_000,
            enableThinking: false,
            notes: ""
        )
        try store.save(
            settings: AppSettings(
                mlxServerExecutablePath: "/usr/bin/false",
                defaultHost: "127.0.0.1",
                defaultPort: 8_000,
                apiKeyPlaceholder: "not-required-local",
                uiLanguage: .japanese,
                uiAppearance: "system"
            ),
            models: [wildcardModel]
        )

        var checkedPorts: [Int] = []
        let finder = AvailablePortFinder { host, port in
            checkedPorts.append(port)
            return .available(host: host, port: port)
        }
        let viewModel = AppViewModel(
            settingsStore: store,
            availablePortFinder: finder
        )

        viewModel.addProfileRequested()

        XCTAssertEqual(viewModel.addProfileDraft.serverPortText, "8001")
        XCTAssertEqual(checkedPorts, [8_001])
    }
}
