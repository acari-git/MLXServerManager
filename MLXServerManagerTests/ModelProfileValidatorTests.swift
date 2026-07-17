import XCTest
@testable import MLXServerManager

final class ModelProfileValidatorTests: XCTestCase {
    private let validator = ModelProfileValidator()

    func testNewProfileTrimsFieldsAndBuildsExpectedModel() throws {
        var draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8_000)
        draft.modelID = "  owner/model-name  "
        draft.displayName = "  Display Name  "
        draft.host = "  localhost  "
        draft.notes = "  Notes  "
        draft.enableThinking = true

        let model = try validModel(from: validator.validateNewProfile(draft, existingModels: []))

        XCTAssertEqual(model.modelID, "owner/model-name")
        XCTAssertEqual(model.displayName, "Display Name")
        XCTAssertEqual(model.localName, "model-name")
        XCTAssertEqual(model.host, "localhost")
        XCTAssertEqual(model.serverPort, 8_000)
        XCTAssertEqual(model.notes, "Notes")
        XCTAssertTrue(model.enableThinking)
        XCTAssertEqual(model.resolvedBackend, .mlxLM)
    }

    func testNewProfileRejectsRequiredFieldsPortAndDuplicateModelID() {
        var draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8_000)
        XCTAssertEqual(invalidMessage(from: validator.validateNewProfile(draft, existingModels: [])), "Model ID is required.")

        draft.modelID = "owner/model"
        draft.host = " "
        XCTAssertEqual(invalidMessage(from: validator.validateNewProfile(draft, existingModels: [])), "Host is required.")

        draft.host = "127.0.0.1"
        draft.serverPortText = "70000"
        XCTAssertEqual(invalidMessage(from: validator.validateNewProfile(draft, existingModels: [])), "Port must be between 1 and 65535.")

        draft.serverPortText = "8000"
        XCTAssertEqual(
            invalidMessage(from: validator.validateNewProfile(draft, existingModels: [makeModel()])),
            "A model profile with this Model ID already exists."
        )
    }

    func testRunningProfileRejectsRuntimeTargetChangesWithLocalizedMessage() {
        let existingModel = makeModel()
        var draft = ModelProfileDraft(model: existingModel)
        draft.host = "0.0.0.0"

        let message = invalidMessage(from: validator.validateProfileEdit(
            draft,
            existingModel: existingModel,
            isRunning: true,
            language: .japanese
        ))

        XCTAssertEqual(
            message,
            "このモデルを停止してから、モデルパス、バックエンド、Host、Port、詳細起動オプションを変更してください。"
        )
    }

    func testRunningProfileAllowsMetadataAndThinkingChanges() throws {
        let existingModel = makeModel()
        var draft = ModelProfileDraft(model: existingModel)
        draft.displayName = "  Renamed  "
        draft.notes = "  Updated notes  "
        draft.enableThinking.toggle()

        let model = try validModel(from: validator.validateProfileEdit(
            draft,
            existingModel: existingModel,
            isRunning: true,
            language: .english
        ))

        XCTAssertEqual(model.displayName, "Renamed")
        XCTAssertEqual(model.notes, "Updated notes")
        XCTAssertNotEqual(model.enableThinking, existingModel.enableThinking)
        XCTAssertEqual(model.modelID, existingModel.modelID)
        XCTAssertEqual(model.host, existingModel.host)
        XCTAssertEqual(model.serverPort, existingModel.serverPort)
    }

    func testAdvancedOptionsNormalizeValidValues() throws {
        let options = AdvancedLaunchOptions(
            rawExtraArgs: #"  --flag "value with spaces"  "#,
            chatTemplateArgs: #"  {"enable_thinking":false}  "#,
            defaultTemperature: " 0.7 ",
            defaultTopK: " 40 ",
            logLevel: " info "
        )

        let normalized = try validAdvancedOptions(from: validator.validateAdvancedLaunchOptions(options, backend: .mlxLM))

        XCTAssertEqual(normalized?.rawExtraArgs, #"--flag "value with spaces""#)
        XCTAssertEqual(normalized?.chatTemplateArgs, #"{"enable_thinking":false}"#)
        XCTAssertEqual(normalized?.defaultTemperature, "0.7")
        XCTAssertEqual(normalized?.defaultTopK, "40")
        XCTAssertEqual(normalized?.logLevel, "info")
    }

    func testAdvancedOptionsRejectInvalidNumericValues() {
        var options = AdvancedLaunchOptions.empty
        options.defaultTemperature = "1.1"
        XCTAssertEqual(
            invalidMessage(from: validator.validateAdvancedLaunchOptions(options, backend: .mlxLM)),
            "Default Temperature must be between 0 and 1."
        )

        options = .empty
        options.promptCacheSize = "0"
        XCTAssertEqual(
            invalidMessage(from: validator.validateAdvancedLaunchOptions(options, backend: .mlxLM)),
            "Prompt Cache Size must be a positive integer."
        )
    }

    func testAdvancedOptionsRejectUnsupportedOrMalformedChatTemplateArgs() {
        var options = AdvancedLaunchOptions.empty
        options.chatTemplateArgs = #"{"enable_thinking":false}"#
        XCTAssertEqual(
            invalidMessage(from: validator.validateAdvancedLaunchOptions(options, backend: .rapidMLX)),
            "Chat Template Args are supported by mlx-lm profiles only."
        )

        options.chatTemplateArgs = "{not-json}"
        XCTAssertEqual(
            invalidMessage(from: validator.validateAdvancedLaunchOptions(options, backend: .mlxLM)),
            "Chat Template Args must be valid JSON."
        )
    }

    func testAdvancedOptionsRejectInvalidRapidMLXLogLevelAndRawArguments() {
        var options = AdvancedLaunchOptions.empty
        options.logLevel = "TRACE"
        XCTAssertEqual(
            invalidMessage(from: validator.validateAdvancedLaunchOptions(options, backend: .rapidMLX)),
            "Rapid-MLX Log Level must be DEBUG, INFO, WARNING, or ERROR."
        )

        options = .empty
        options.rawExtraArgs = #"--path "/unterminated"#
        let message = invalidMessage(from: validator.validateAdvancedLaunchOptions(options, backend: .mlxLM))
        XCTAssertFalse(message?.isEmpty ?? true)
    }

    func testEmptyAdvancedOptionsRemainNil() throws {
        let options = try validAdvancedOptions(
            from: validator.validateAdvancedLaunchOptions(.empty, backend: .mlxLM)
        )
        XCTAssertNil(options)
    }

    private func makeModel() -> ModelConfig {
        ModelConfig(
            modelID: "owner/model",
            displayName: "Model",
            family: "Custom",
            quantization: "User configured",
            localName: "model",
            host: "127.0.0.1",
            serverPort: 8_000,
            enableThinking: false,
            notes: "Notes",
            advancedLaunchOptions: nil,
            backend: .mlxLM
        )
    }

    private func validModel(from result: ModelProfileValidationResult) throws -> ModelConfig {
        guard case let .valid(model) = result else {
            XCTFail("Expected a valid model, got \(result)")
            throw ValidationTestError.unexpectedResult
        }
        return model
    }

    private func validAdvancedOptions(
        from result: AdvancedLaunchOptionsValidationResult
    ) throws -> AdvancedLaunchOptions? {
        guard case let .valid(options) = result else {
            XCTFail("Expected valid advanced options, got \(result)")
            throw ValidationTestError.unexpectedResult
        }
        return options
    }

    private func invalidMessage(from result: ModelProfileValidationResult) -> String? {
        guard case let .invalid(message) = result else {
            XCTFail("Expected an invalid result, got \(result)")
            return nil
        }
        return message
    }

    private func invalidMessage(from result: AdvancedLaunchOptionsValidationResult) -> String? {
        guard case let .invalid(message) = result else {
            XCTFail("Expected an invalid result, got \(result)")
            return nil
        }
        return message
    }
}

private enum ValidationTestError: Error {
    case unexpectedResult
}

@MainActor
final class AppViewModelProfileIntegrationTests: XCTestCase {
    func testSaveNewProfilePersistsNormalizedValidatorOutput() throws {
        let store = makeStore()
        defer { removeStore(store) }
        try store.save(settings: .defaults, models: [makeExistingModel()])
        let viewModel = AppViewModel(settingsStore: store)

        viewModel.addProfileRequested()
        viewModel.addProfileDraft.modelID = "  owner/new-model  "
        viewModel.addProfileDraft.displayName = "  New Model  "
        viewModel.addProfileDraft.host = "  127.0.0.1  "
        viewModel.addProfileDraft.serverPortText = " 8010 "
        viewModel.addProfileDraft.notes = "  Integration test  "

        XCTAssertTrue(viewModel.saveNewProfile())
        XCTAssertEqual(viewModel.selectedModelID, "owner/new-model")
        XCTAssertEqual(viewModel.models.last?.displayName, "New Model")
        XCTAssertEqual(viewModel.models.last?.notes, "Integration test")

        let persisted = try store.load()
        XCTAssertEqual(persisted.models.last?.modelID, "owner/new-model")
        XCTAssertEqual(persisted.models.last?.host, "127.0.0.1")
        XCTAssertEqual(persisted.models.last?.serverPort, 8_010)
    }

    func testSaveProfileEditingSurfacesValidatorFailureWithoutPersisting() throws {
        let store = makeStore()
        defer { removeStore(store) }
        let existingModel = makeExistingModel()
        try store.save(settings: .defaults, models: [existingModel])
        let viewModel = AppViewModel(settingsStore: store)

        viewModel.editProfileRequested(for: existingModel)
        viewModel.profileEditorDraft.advancedLaunchOptions.defaultTemperature = "1.5"

        XCTAssertFalse(viewModel.saveProfileEditing())
        XCTAssertEqual(viewModel.profileEditorMessage, "Default Temperature must be between 0 and 1.")
        XCTAssertEqual(viewModel.models, [existingModel])
        XCTAssertEqual(try store.load().models, [existingModel])
    }

    private func makeStore() -> SettingsStore {
        SettingsStore(appDirectoryName: "MLXServerManagerProfileIntegrationTests-\(UUID().uuidString)")
    }

    private func removeStore(_ store: SettingsStore) {
        guard let directory = try? store.settingsDirectoryURL else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeExistingModel() -> ModelConfig {
        ModelConfig(
            modelID: "owner/existing-model",
            displayName: "Existing Model",
            family: "Custom",
            quantization: "User configured",
            localName: "existing-model",
            host: "127.0.0.1",
            serverPort: 8_000,
            enableThinking: false,
            notes: "Existing notes",
            advancedLaunchOptions: nil,
            backend: .mlxLM
        )
    }
}
