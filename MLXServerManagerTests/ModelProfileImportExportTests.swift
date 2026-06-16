import XCTest
@testable import MLXServerManager

@MainActor
final class ModelProfileImportExportTests: XCTestCase {
    private let importService = ModelProfileImportPreviewService()

    func testValidSingleProfileFixtureIsImportableAndImportsMetadata() throws {
        let preview = try previewFixture("valid_single_profile")

        XCTAssertEqual(preview.totalProfiles, 1)
        XCTAssertEqual(preview.invalidProfilesCount, 0)
        XCTAssertTrue(preview.canProceedToFutureImport)
        XCTAssertTrue(try XCTUnwrap(preview.profiles.first).isImportable)

        let result = importService.importSelectedProfiles(
            from: preview,
            requests: [.init(sourceIndex: 1, action: .importProfile)],
            existingModels: []
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.renamedCount, 0)
        XCTAssertEqual(result.replacedCount, 0)
        XCTAssertEqual(result.modelsAfterImport.count, 1)

        let imported = try XCTUnwrap(result.importedModels.first)
        XCTAssertEqual(imported.displayName, "Valid Single")
        XCTAssertEqual(imported.modelID, "test/valid-single-mlx-4bit")
        XCTAssertEqual(imported.host, "127.0.0.1")
        XCTAssertEqual(imported.serverPort, 8081)
        XCTAssertEqual(imported.advancedLaunchOptions?.defaultTemperature, "0.2")
        XCTAssertEqual(imported.advancedLaunchOptions?.promptCacheSize, "256")
    }

    func testInvalidProfilesAndDocumentErrorsRemainBlocked() throws {
        let missingRequired = try previewFixture("invalid_missing_required_fields")
        XCTAssertEqual(missingRequired.invalidProfilesCount, 1)
        XCTAssertFalse(missingRequired.canProceedToFutureImport)

        let whitespaceName = try previewFixture("invalid_whitespace_name")
        XCTAssertEqual(whitespaceName.invalidProfilesCount, 1)
        XCTAssertFalse(whitespaceName.canProceedToFutureImport)

        let unsupportedSchemaData = Data("""
        {
          "app": "MLXServerManager",
          "profiles": [],
          "schemaVersion": 2
        }
        """.utf8)
        let unsupportedSchema = importService.preview(
            data: unsupportedSchemaData,
            sourceFileName: "unsupported-schema.json",
            existingModels: []
        )
        XCTAssertTrue(unsupportedSchema.documentMessages.contains { $0.severity == .error })
        XCTAssertFalse(unsupportedSchema.canProceedToFutureImport)
    }

    func testImportPreviewDetectsNameRuntimeAndDuplicateConflicts() throws {
        let existing = [existingLocalProfile()]

        let nameConflict = try XCTUnwrap(try previewFixture("name_conflict", existingModels: existing).profiles.first)
        XCTAssertTrue(nameConflict.conflictKinds.contains(.existingName))
        XCTAssertTrue(nameConflict.canImportWithRename)
        XCTAssertTrue(nameConflict.canImportWithReplace)

        let runtimeConflict = try XCTUnwrap(try previewFixture("runtime_identity_conflict", existingModels: existing).profiles.first)
        XCTAssertTrue(runtimeConflict.conflictKinds.contains(.existingModelID))
        XCTAssertTrue(runtimeConflict.conflictKinds.contains(.existingEndpoint))
        XCTAssertFalse(runtimeConflict.canImportWithRename)
        XCTAssertTrue(runtimeConflict.canImportWithReplace)

        let duplicateNames = try previewFixture("duplicate_profile_names")
        XCTAssertEqual(duplicateNames.profiles.count, 2)
        XCTAssertTrue(duplicateNames.profiles.allSatisfy { $0.conflictKinds.contains(.importedNameDuplicate) })

        let duplicateEndpoint = try previewFixture("duplicate_endpoint")
        XCTAssertEqual(duplicateEndpoint.profiles.count, 2)
        XCTAssertTrue(duplicateEndpoint.profiles.allSatisfy { $0.conflictKinds.contains(.importedEndpointDuplicate) })
    }

    func testRenameNameConflictImportsNewProfileWithoutChangingRuntimeFields() throws {
        let existing = [existingLocalProfile()]
        let preview = try previewFixture("name_conflict", existingModels: existing)

        let result = importService.importSelectedProfiles(
            from: preview,
            requests: [.init(sourceIndex: 1, action: .rename, renamedName: "Renamed Import")],
            existingModels: existing
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.renamedCount, 1)
        XCTAssertEqual(result.replacedCount, 0)
        XCTAssertEqual(result.modelsAfterImport.count, 2)

        let imported = try XCTUnwrap(result.importedModels.first)
        XCTAssertEqual(imported.displayName, "Renamed Import")
        XCTAssertEqual(imported.modelID, "test/name-conflict-imported-mlx-4bit")
        XCTAssertEqual(imported.host, "127.0.0.1")
        XCTAssertEqual(imported.serverPort, 8082)
        XCTAssertEqual(imported.advancedLaunchOptions?.defaultTopP, "0.8")
    }

    func testRenameValidationRejectsEmptyExistingAndSelectedNameCollisions() throws {
        let existing = [existingLocalProfile()]
        let preview = try previewFixture("name_conflict", existingModels: existing)

        let emptyRename = importService.importSelectedProfiles(
            from: preview,
            requests: [.init(sourceIndex: 1, action: .rename, renamedName: "   ")],
            existingModels: existing
        )
        XCTAssertFalse(emptyRename.didChangeModels)

        let existingNameRename = importService.importSelectedProfiles(
            from: preview,
            requests: [.init(sourceIndex: 1, action: .rename, renamedName: "Existing Local Profile")],
            existingModels: existing
        )
        XCTAssertFalse(existingNameRename.didChangeModels)

        let duplicateNames = try previewFixture("duplicate_profile_names")
        let selectedCollision = importService.importSelectedProfiles(
            from: duplicateNames,
            requests: [
                .init(sourceIndex: 1, action: .rename, renamedName: "Same Final Name"),
                .init(sourceIndex: 2, action: .rename, renamedName: "Same Final Name")
            ],
            existingModels: []
        )
        XCTAssertFalse(selectedCollision.didChangeModels)
    }

    func testRenameDoesNotResolveRuntimeIdentityConflicts() throws {
        let existing = [existingLocalProfile()]
        let preview = try previewFixture("runtime_identity_conflict", existingModels: existing)

        let result = importService.importSelectedProfiles(
            from: preview,
            requests: [.init(sourceIndex: 1, action: .rename, renamedName: "Unique Runtime Rename")],
            existingModels: existing
        )

        XCTAssertFalse(result.didChangeModels)
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testReplaceTargetCanBeDetectedByNameModelIDAndEndpoint() throws {
        let existing = [existingLocalProfile()]

        let byName = try XCTUnwrap(try previewFixture("replace_name_conflict", existingModels: existing).profiles.first)
        XCTAssertEqual(byName.replaceTarget?.modelID, "test/local-existing-mlx-4bit")

        let byModelID = try XCTUnwrap(try previewFixture("replace_modelid_conflict", existingModels: existing).profiles.first)
        XCTAssertEqual(byModelID.replaceTarget?.modelID, "test/local-existing-mlx-4bit")

        let byEndpoint = try XCTUnwrap(try previewFixture("replace_endpoint_conflict", existingModels: existing).profiles.first)
        XCTAssertEqual(byEndpoint.replaceTarget?.modelID, "test/local-existing-mlx-4bit")
    }

    func testReplaceUpdatesSchemaMetadataAndPreservesLocalOnlyFields() throws {
        let existing = [existingLocalProfile()]
        let preview = try previewFixture("replace_name_conflict", existingModels: existing)

        let result = importService.importSelectedProfiles(
            from: preview,
            requests: [.init(sourceIndex: 1, action: .replace)],
            existingModels: existing
        )

        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.replacedCount, 1)
        XCTAssertEqual(result.modelsAfterImport.count, 1)

        let replaced = try XCTUnwrap(result.modelsAfterImport.first)
        XCTAssertEqual(replaced.displayName, "Existing Local Profile")
        XCTAssertEqual(replaced.modelID, "test/replacement-by-name-mlx-4bit")
        XCTAssertEqual(replaced.host, "127.0.0.1")
        XCTAssertEqual(replaced.serverPort, 8090)
        XCTAssertEqual(replaced.advancedLaunchOptions?.defaultTemperature, "0.4")
        XCTAssertEqual(replaced.advancedLaunchOptions?.promptCacheBytes, "1024")

        XCTAssertEqual(replaced.family, "Local Family")
        XCTAssertEqual(replaced.quantization, "Local Quantization")
        XCTAssertEqual(replaced.enableThinking, true)
        XCTAssertEqual(replaced.notes, "Local user note")
        XCTAssertEqual(replaced.localName, "replacement-by-name-mlx-4bit")
    }

    func testReplaceIsBlockedForAmbiguousAndDuplicateTargets() throws {
        let ambiguousExisting = [
            existingLocalProfile(),
            model(
                modelID: "test/second-existing-mlx-4bit",
                displayName: "Second Existing Profile",
                host: "127.0.0.1",
                port: 8085
            )
        ]
        let ambiguousProfile = try XCTUnwrap(try previewFixture("ambiguous_replace_target", existingModels: ambiguousExisting).profiles.first)
        XCTAssertNil(ambiguousProfile.replaceTarget)
        XCTAssertFalse(ambiguousProfile.canImportWithReplace)

        let duplicatePreview = try previewFixture("duplicate_replace_target", existingModels: [existingLocalProfile()])
        let duplicateResult = importService.importSelectedProfiles(
            from: duplicatePreview,
            requests: [
                .init(sourceIndex: 1, action: .replace),
                .init(sourceIndex: 2, action: .replace)
            ],
            existingModels: [existingLocalProfile()]
        )

        XCTAssertEqual(duplicateResult.replacedCount, 0)
        XCTAssertFalse(duplicateResult.didChangeModels)
    }

    func testExportEmitsDocumentedSchemaWithoutLocalOnlyOrSecretFields() throws {
        let data = try ModelProfileExportService().exportData(
            from: [
                model(
                    modelID: "test/export-round-trip-mlx-4bit",
                    displayName: "Export Round Trip",
                    host: "127.0.0.1",
                    port: 8083,
                    advancedLaunchOptions: AdvancedLaunchOptions(
                        rawExtraArgs: "--trust-remote-code",
                        defaultTemperature: "0.3"
                    )
                )
            ],
            exportedAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-16T00:00:00Z"))
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["app"] as? String, "MLXServerManager")

        let profiles = try XCTUnwrap(object["profiles"] as? [[String: Any]])
        let profile = try XCTUnwrap(profiles.first)
        XCTAssertEqual(Set(profile.keys), ["name", "modelID", "host", "port", "advancedLaunchOptions"])

        let exportedText = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(exportedText.contains("notes"))
        XCTAssertFalse(exportedText.contains("enableThinking"))
        XCTAssertFalse(exportedText.contains("executable"))
        XCTAssertFalse(exportedText.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(exportedText.localizedCaseInsensitiveContains("secret"))
    }

    func testExportedFixtureCanBePreviewedForRoundTripCompatibility() throws {
        let preview = try previewFixture("export_round_trip_schema_v1")

        XCTAssertEqual(preview.totalProfiles, 1)
        XCTAssertEqual(preview.invalidProfilesCount, 0)
        XCTAssertTrue(try XCTUnwrap(preview.profiles.first).isImportable)
    }

    func testSelectionHelperTracksOnlyExplicitReplacedProfile() {
        let replacement = ImportReplacedProfileSummary(
            previousModelID: "test/old-selected",
            replacementModelID: "test/new-selected",
            previousDisplayName: "Old Selected",
            replacementDisplayName: "New Selected"
        )

        let preserved = ModelProfileImportSelectionUpdate.preservingSelection(
            previousSelectedModelID: "test/old-selected",
            nextModels: [model(modelID: "test/new-selected", displayName: "New Selected")],
            replacedProfiles: [replacement]
        )
        XCTAssertEqual(preserved.selectedModelID, "test/new-selected")
        XCTAssertTrue(preserved.preservedThroughReplacement)

        let unrelated = ModelProfileImportSelectionUpdate.preservingSelection(
            previousSelectedModelID: "test/old-selected",
            nextModels: [model(modelID: "test/unrelated", displayName: "Unrelated")],
            replacedProfiles: []
        )
        XCTAssertEqual(unrelated.selectedModelID, "test/old-selected")
        XCTAssertFalse(unrelated.preservedThroughReplacement)
    }

    private func previewFixture(
        _ name: String,
        existingModels: [ModelConfig] = []
    ) throws -> ImportPreviewResult {
        importService.preview(
            data: try fixtureData(named: name),
            sourceFileName: "\(name).json",
            existingModels: existingModels
        )
    }

    private func fixtureData(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: name, withExtension: "json"),
            "Missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    private func existingLocalProfile() -> ModelConfig {
        model(
            modelID: "test/local-existing-mlx-4bit",
            displayName: "Existing Local Profile",
            host: "127.0.0.1",
            port: 8081,
            family: "Local Family",
            quantization: "Local Quantization",
            enableThinking: true,
            notes: "Local user note"
        )
    }

    private func model(
        modelID: String,
        displayName: String,
        host: String = "127.0.0.1",
        port: Int = 8081,
        family: String = "Test Family",
        quantization: String = "Test Quantization",
        enableThinking: Bool = false,
        notes: String = "",
        advancedLaunchOptions: AdvancedLaunchOptions? = nil
    ) -> ModelConfig {
        ModelConfig(
            modelID: modelID,
            displayName: displayName,
            family: family,
            quantization: quantization,
            localName: modelID.split(separator: "/").last.map(String.init) ?? modelID,
            host: host,
            serverPort: port,
            enableThinking: enableThinking,
            notes: notes,
            advancedLaunchOptions: advancedLaunchOptions
        )
    }
}
