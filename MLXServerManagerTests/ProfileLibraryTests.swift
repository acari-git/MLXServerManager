import XCTest
@testable import MLXServerManager

final class ProfileLibraryTests: XCTestCase {
    func testMetadataFiltersSearchAndFavoriteSort() {
        let coding = makeModel(id: "org/coder", name: "Coder", port: 8001)
        let chat = makeModel(id: "org/chat", name: "Chat", port: 8002)
        let metadata = [
            coding.id: ProfileLibraryMetadata(isFavorite: true, category: .coding, tags: ["swift", "local"]),
            chat.id: ProfileLibraryMetadata(isFavorite: false, category: .chat, tags: ["assistant"])
        ]

        let searched = ProfileLibrary.items(
            from: [chat, coding],
            metadataByModelID: metadata,
            searchText: "swift",
            backend: nil,
            category: nil,
            favoritesOnly: false,
            thinkingOnly: false,
            sortOrder: .name
        )
        XCTAssertEqual(searched.map(\.id), [coding.id])

        let categorized = ProfileLibrary.items(
            from: [chat, coding],
            metadataByModelID: metadata,
            searchText: "",
            backend: nil,
            category: .chat,
            favoritesOnly: false,
            thinkingOnly: false,
            sortOrder: .name
        )
        XCTAssertEqual(categorized.map(\.id), [chat.id])

        let sorted = ProfileLibrary.items(
            from: [chat, coding],
            metadataByModelID: metadata,
            searchText: "",
            backend: nil,
            category: nil,
            favoritesOnly: false,
            thinkingOnly: false,
            sortOrder: .favorites
        )
        XCTAssertEqual(sorted.map(\.id), [coding.id, chat.id])
    }

    func testRecentAndTagPresetFiltering() {
        let first = makeModel(id: "org/first", name: "First", port: 8001)
        let second = makeModel(id: "org/second", name: "Second", port: 8002)
        let third = makeModel(id: "org/third", name: "Third", port: 8003)
        let metadata = [
            first.id: ProfileLibraryMetadata(tags: ["swift"]),
            second.id: ProfileLibraryMetadata(tags: ["agent"]),
            third.id: ProfileLibraryMetadata(tags: ["swift"])
        ]

        let recent = ProfileLibrary.items(
            from: [first, second, third],
            metadataByModelID: metadata,
            searchText: "",
            backend: nil,
            recentModelIDs: [third.id, first.id],
            recentOnly: true,
            thinkingOnly: false,
            sortOrder: .name
        )
        XCTAssertEqual(recent.map(\.id), [third.id, first.id])

        let tagged = ProfileLibrary.items(
            from: [first, second, third],
            metadataByModelID: metadata,
            searchText: "",
            backend: nil,
            tag: "SWIFT",
            thinkingOnly: false,
            sortOrder: .name
        )
        XCTAssertEqual(tagged.map(\.id), [first.id, third.id])
        XCTAssertEqual(ProfileLibrary.availableTags(in: metadata), ["agent", "swift"])
    }

    func testRecentStoreMovesSelectionToFrontAndCapsHistory() {
        let suiteName = "ProfileLibraryRecentTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        for index in 0..<10 {
            ProfileLibraryRecentStore.record("model-\(index)", defaults: defaults)
        }
        var recent = ProfileLibraryRecentStore.load(defaults: defaults)
        XCTAssertEqual(recent.count, ProfileLibraryRecentStore.maximumCount)
        XCTAssertEqual(recent.first, "model-9")

        recent = ProfileLibraryRecentStore.record("model-5", defaults: defaults)
        XCTAssertEqual(recent.first, "model-5")
        XCTAssertEqual(recent.filter { $0 == "model-5" }.count, 1)
    }

    func testMetadataNormalizationAndRoundTrip() {
        var metadata = ProfileLibraryMetadata(tags: [" swift ", "swift", "", "Agent"])
        metadata.normalize()
        XCTAssertEqual(metadata.tags, ["Agent", "swift"])

        let suiteName = "ProfileLibraryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ProfileLibraryMetadataStore.save(["model": metadata], defaults: defaults)
        XCTAssertEqual(ProfileLibraryMetadataStore.load(defaults: defaults)["model"], metadata)
    }

    func testComparisonRowsMarkOnlyChangedSettings() {
        var first = makeModel(id: "org/a", name: "A", port: 8001)
        var second = makeModel(id: "org/b", name: "B", port: 8002)
        second.family = first.family
        second.quantization = first.quantization
        second.enableThinking = first.enableThinking

        let rows = ProfileLibrary.comparisonRows(for: [first, second])
        XCTAssertTrue(rows.first(where: { $0.key == "Model ID" })?.hasDifference == true)
        XCTAssertTrue(rows.first(where: { $0.key == "Port" })?.hasDifference == true)
        XCTAssertTrue(rows.first(where: { $0.key == "Family" })?.hasDifference == false)
        XCTAssertTrue(rows.first(where: { $0.key == "Quantization" })?.hasDifference == false)
    }

    func testComparisonRequiresAtLeastTwoProfiles() {
        XCTAssertTrue(ProfileLibrary.comparisonRows(for: [makeModel(id: "org/a", name: "A", port: 8001)]).isEmpty)
    }

    func testReconciledStateRemovesOrphanedLibraryData() {
        let valid = makeModel(id: "org/valid", name: "Valid", port: 8001)
        let state = ProfileLibrary.reconciledState(
            models: [valid],
            metadataByModelID: [
                valid.id: ProfileLibraryMetadata(isFavorite: true),
                "org/deleted": ProfileLibraryMetadata(tags: ["orphan"])
            ],
            recentModelIDs: ["org/deleted", valid.id],
            comparisonModelIDs: [valid.id, "org/deleted"]
        )

        XCTAssertEqual(Set(state.metadataByModelID.keys), [valid.id])
        XCTAssertEqual(state.recentModelIDs, [valid.id])
        XCTAssertEqual(state.comparisonModelIDs, [valid.id])
    }

    func testStoresMigrateRenamedProfileAndPruneDeletedProfiles() {
        let suiteName = "ProfileLibraryReconcileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let metadata = ProfileLibraryMetadata(isFavorite: true, category: .agent, tags: ["swift"])
        ProfileLibraryMetadataStore.save(["old": metadata, "deleted": ProfileLibraryMetadata()], defaults: defaults)
        defaults.set(["deleted", "old", "old"], forKey: ProfileLibraryRecentStore.defaultsKey)

        let validIDs: Set<String> = ["new"]
        let migratedMetadata = ProfileLibraryMetadataStore.reconcile(
            validModelIDs: validIDs,
            renamedModelID: (old: "old", new: "new"),
            defaults: defaults
        )
        let migratedRecent = ProfileLibraryRecentStore.reconcile(
            validModelIDs: validIDs,
            renamedModelID: (old: "old", new: "new"),
            defaults: defaults
        )

        XCTAssertEqual(migratedMetadata, ["new": metadata])
        XCTAssertEqual(migratedRecent, ["new"])
    }

    func testComposedDraftUsesSelectedSources() {
        let identity = makeModel(id: "org/identity", name: "Identity", port: 8001)
        var runtime = makeModel(id: "org/runtime", name: "Runtime", port: 9000)
        runtime.host = "0.0.0.0"
        runtime.backend = .rapidMLX
        runtime.enableThinking = false
        var tuning = makeModel(id: "org/tuning", name: "Tuning", port: 8003)
        tuning.advancedLaunchOptions = AdvancedLaunchOptions(defaultTemperature: "0.7", defaultTopP: "0.9")
        var notes = makeModel(id: "org/notes", name: "Notes", port: 8004)
        notes.notes = "composed notes"

        let selection = ProfileCompositionSelection(
            identityModelID: identity.id,
            runtimeModelID: runtime.id,
            tuningModelID: tuning.id,
            notesModelID: notes.id
        )
        let draft = ProfileLibrary.composedDraft(
            models: [identity, runtime, tuning, notes],
            selection: selection,
            suggestedPort: 9001
        )

        XCTAssertEqual(draft?.displayName, "Identity Composite")
        XCTAssertEqual(draft?.modelID, "org/identity-composite")
        XCTAssertEqual(draft?.host, "0.0.0.0")
        XCTAssertEqual(draft?.serverPortText, "9001")
        XCTAssertEqual(draft?.backend, .rapidMLX)
        XCTAssertEqual(draft?.enableThinking, false)
        XCTAssertEqual(draft?.advancedLaunchOptions.defaultTemperature, "0.7")
        XCTAssertEqual(draft?.advancedLaunchOptions.defaultTopP, "0.9")
        XCTAssertEqual(draft?.notes, "composed notes")
    }

    func testComposedDraftRejectsMissingSelectionSource() {
        let model = makeModel(id: "org/model", name: "Model", port: 8001)
        let selection = ProfileCompositionSelection(
            identityModelID: model.id,
            runtimeModelID: "missing",
            tuningModelID: model.id,
            notesModelID: model.id
        )
        XCTAssertNil(ProfileLibrary.composedDraft(models: [model], selection: selection, suggestedPort: 8002))
    }

    private func makeModel(id: String, name: String, port: Int) -> ModelConfig {
        ModelConfig(
            modelID: id,
            displayName: name,
            family: "Test",
            quantization: "4-bit",
            localName: name,
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: true,
            notes: "",
            advancedLaunchOptions: nil
        )
    }
}
